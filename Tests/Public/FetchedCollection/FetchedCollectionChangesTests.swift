import XCTest
#if USING_SQLCIPHER
    import GRDBCipher
#elseif USING_CUSTOMSQLITE
    import GRDBCustomSQLite
#else
    import GRDB
#endif

private class ChangesRecorder<Fetched, T> {
    var elementsBeforeChanges: [Fetched]!
    var elementsAfterChanges: [Fetched]!
    var fetchedAlongsideAfterChanges: T?
    var error: Error?
    var expectation: XCTestExpectation? {
        didSet {
            elementsBeforeChanges = nil
            elementsAfterChanges = nil
            fetchedAlongsideAfterChanges = nil
        }
    }
    
    func trackErrors(in collection: FetchedCollection<Fetched>) {
        collection.trackErrors { (collection, error) in
            self.collection(collection, didFailWith: error)
        }
    }
    
    func trackChanges(in collection: FetchedCollection<Fetched>) {
        collection.trackChanges(
            willChange: { collection in self.collectionWillChange(collection) },
            didChange: { collection in self.collectionDidChange(collection) })
    }
    
    func trackChanges(in collection: FetchedCollection<Fetched>, fetchAlongside: @escaping (Database) throws -> T) {
        collection.trackChanges(
            fetchAlongside: fetchAlongside,
            willChange: { collection in self.collectionWillChange(collection) },
            didChange: { (collection, fetchedAlonside) in self.collectionDidChange(collection, fetchedAlongside: fetchedAlonside) })
    }
    
    func collectionWillChange(_ collection: FetchedCollection<Fetched>) {
        elementsBeforeChanges = Array(collection)
    }
    
    func collectionDidChange(_ collection: FetchedCollection<Fetched>) {
        elementsAfterChanges = Array(collection)
        expectation?.fulfill()
    }
    
    func collectionDidChange(_ collection: FetchedCollection<Fetched>, fetchedAlongside: T) {
        elementsAfterChanges = Array(collection)
        fetchedAlongsideAfterChanges = fetchedAlongside
        expectation?.fulfill()
    }
    
    func collection(_ collection: FetchedCollection<Fetched>, didFailWith error: Error) {
        self.error = error
        expectation?.fulfill()
    }
}

private struct AnyRowConvertible: RowConvertible, Equatable {
    let row: Row
    
    init(row: Row) {
        self.row = row.copy()
    }
    
    static func == (lhs: AnyRowConvertible, rhs: AnyRowConvertible) -> Bool {
        return lhs.row == rhs.row
    }
}

class FetchedCollectionChangesTests: GRDBTestCase {
    
    func testChangesError() {
        assertNoError {
            let dbPool = try makeDatabasePool()
            try dbPool.write { db in
                try db.create(table: "table1") { t in
                    t.column("id", .integer).primaryKey()
                    t.column("name", .text)
                }
                try db.execute("INSERT INTO table1 (id, name) VALUES (?, ?)", arguments: [1, "a"])
            }
            
            let sql = "SELECT name, id FROM table1 ORDER BY id"
            let sqlRequest = SQLRequest(sql)
            
            let valuesFromSQL = try FetchedCollection<String>(dbPool, sql: sql)
            let valuesFromRequest = try FetchedCollection(dbPool, request: sqlRequest.bound(to: String.self))
            let optionalValuesFromSQL = try FetchedCollection<String?>(dbPool, sql: sql)
            let optionalValuesFromRequest = try FetchedCollection(dbPool, request: sqlRequest.bound(to: Optional<String>.self))
            let rowsFromSQL = try FetchedCollection<Row>(dbPool, sql: sql)
            let rowsFromRequest = try FetchedCollection(dbPool, request: sqlRequest.bound(to: Row.self))
            let recordsFromSQL = try FetchedCollection<AnyRowConvertible>(dbPool, sql: sql)
            let recordsFromRequest = try FetchedCollection(dbPool, request: sqlRequest.bound(to: AnyRowConvertible.self))
            
            try valuesFromSQL.fetch()
            try valuesFromRequest.fetch()
            try optionalValuesFromSQL.fetch()
            try optionalValuesFromRequest.fetch()
            try rowsFromSQL.fetch()
            try rowsFromRequest.fetch()
            try recordsFromSQL.fetch()
            try recordsFromRequest.fetch()
            
            let valuesFromSQLChangesRecorder = ChangesRecorder<String, Void>()
            let valuesFromRequestChangesRecorder = ChangesRecorder<String, Void>()
            let optionalValuesFromSQLChangesRecorder = ChangesRecorder<String?, Void>()
            let optionalValuesFromRequestChangesRecorder = ChangesRecorder<String?, Void>()
            let rowsFromSQLChangesRecorder = ChangesRecorder<Row, Void>()
            let rowsFromRequestChangesRecorder = ChangesRecorder<Row, Void>()
            let recordsFromSQLChangesRecorder = ChangesRecorder<AnyRowConvertible, Void>()
            let recordsFromRequestChangesRecorder = ChangesRecorder<AnyRowConvertible, Void>()
            
            valuesFromSQLChangesRecorder.trackChanges(in: valuesFromSQL)
            valuesFromRequestChangesRecorder.trackChanges(in: valuesFromRequest)
            optionalValuesFromSQLChangesRecorder.trackChanges(in: optionalValuesFromSQL)
            optionalValuesFromRequestChangesRecorder.trackChanges(in: optionalValuesFromRequest)
            rowsFromSQLChangesRecorder.trackChanges(in: rowsFromSQL)
            rowsFromRequestChangesRecorder.trackChanges(in: rowsFromRequest)
            recordsFromSQLChangesRecorder.trackChanges(in: recordsFromSQL)
            recordsFromRequestChangesRecorder.trackChanges(in: recordsFromRequest)
            
            valuesFromSQLChangesRecorder.trackErrors(in: valuesFromSQL)
            valuesFromRequestChangesRecorder.trackErrors(in: valuesFromRequest)
            optionalValuesFromSQLChangesRecorder.trackErrors(in: optionalValuesFromSQL)
            optionalValuesFromRequestChangesRecorder.trackErrors(in: optionalValuesFromRequest)
            rowsFromSQLChangesRecorder.trackErrors(in: rowsFromSQL)
            rowsFromRequestChangesRecorder.trackErrors(in: rowsFromRequest)
            recordsFromSQLChangesRecorder.trackErrors(in: recordsFromSQL)
            recordsFromRequestChangesRecorder.trackErrors(in: recordsFromRequest)
            
            // Perform a change that triggers an error
            try dbPool.writeInTransaction { db in
                try db.execute("DELETE FROM table1")
                try db.drop(table: "table1")
                return .commit
            }
            
            valuesFromSQLChangesRecorder.expectation = expectation(description: "valuesFromSQL")
            valuesFromRequestChangesRecorder.expectation = expectation(description: "valuesFromRequest")
            optionalValuesFromSQLChangesRecorder.expectation = expectation(description: "optionalValuesFromSQL")
            optionalValuesFromRequestChangesRecorder.expectation = expectation(description: "optionalValuesFromRequest")
            rowsFromSQLChangesRecorder.expectation = expectation(description: "rowsFromSQL")
            rowsFromRequestChangesRecorder.expectation = expectation(description: "rowsFromRequest")
            recordsFromSQLChangesRecorder.expectation = expectation(description: "recordsFromSQL")
            recordsFromRequestChangesRecorder.expectation = expectation(description: "recordsFromRequest")
            waitForExpectations(timeout: 1, handler: nil)
            
            func test(_ error: Error?) {
                if let error = error as? DatabaseError {
                    XCTAssertEqual(error.code, 1) // SQLITE_ERROR
                    XCTAssertEqual(error.message, "no such table: table1")
                    XCTAssertEqual(error.sql!, "SELECT name, id FROM table1 ORDER BY id")
                    XCTAssertEqual(error.description, "SQLite error 1 with statement `SELECT name, id FROM table1 ORDER BY id`: no such table: table1")
                } else {
                    XCTFail("Expected DatabaseError")
                }
            }
            test(valuesFromSQLChangesRecorder.error)
            test(valuesFromRequestChangesRecorder.error)
            test(optionalValuesFromSQLChangesRecorder.error)
            test(optionalValuesFromRequestChangesRecorder.error)
            test(rowsFromSQLChangesRecorder.error)
            test(rowsFromRequestChangesRecorder.error)
            test(recordsFromSQLChangesRecorder.error)
            test(recordsFromRequestChangesRecorder.error)
        }
    }

    func testSetRequestChanges() {
        assertNoError {
            let dbPool = try makeDatabasePool()
            let sql1 = "SELECT ? AS name, ? AS id UNION ALL SELECT ?, ?"
            let arguments1: StatementArguments = ["a", 1, "b", 2]
            let sqlRequest1 = SQLRequest(sql1, arguments: arguments1)
            
            let valuesFromSQL = try FetchedCollection<String>(dbPool, sql: sql1, arguments: arguments1)
            let valuesFromRequest = try FetchedCollection(dbPool, request: sqlRequest1.bound(to: String.self))
            let optionalValuesFromSQL = try FetchedCollection<String?>(dbPool, sql: sql1, arguments: arguments1)
            let optionalValuesFromRequest = try FetchedCollection(dbPool, request: sqlRequest1.bound(to: Optional<String>.self))
            let rowsFromSQL = try FetchedCollection<Row>(dbPool, sql: sql1, arguments: arguments1)
            let rowsFromRequest = try FetchedCollection(dbPool, request: sqlRequest1.bound(to: Row.self))
            let recordsFromSQL = try FetchedCollection<AnyRowConvertible>(dbPool, sql: sql1, arguments: arguments1)
            let recordsFromRequest = try FetchedCollection(dbPool, request: sqlRequest1.bound(to: AnyRowConvertible.self))
            
            let valuesFromSQLChangesRecorder = ChangesRecorder<String, Void>()
            let valuesFromRequestChangesRecorder = ChangesRecorder<String, Void>()
            let optionalValuesFromSQLChangesRecorder = ChangesRecorder<String?, Void>()
            let optionalValuesFromRequestChangesRecorder = ChangesRecorder<String?, Void>()
            let rowsFromSQLChangesRecorder = ChangesRecorder<Row, Void>()
            let rowsFromRequestChangesRecorder = ChangesRecorder<Row, Void>()
            let recordsFromSQLChangesRecorder = ChangesRecorder<AnyRowConvertible, Void>()
            let recordsFromRequestChangesRecorder = ChangesRecorder<AnyRowConvertible, Void>()
            
            valuesFromSQLChangesRecorder.trackChanges(in: valuesFromSQL)
            valuesFromRequestChangesRecorder.trackChanges(in: valuesFromRequest)
            optionalValuesFromSQLChangesRecorder.trackChanges(in: optionalValuesFromSQL)
            optionalValuesFromRequestChangesRecorder.trackChanges(in: optionalValuesFromRequest)
            rowsFromSQLChangesRecorder.trackChanges(in: rowsFromSQL)
            rowsFromRequestChangesRecorder.trackChanges(in: rowsFromRequest)
            recordsFromSQLChangesRecorder.trackChanges(in: recordsFromSQL)
            recordsFromRequestChangesRecorder.trackChanges(in: recordsFromRequest)
            
            try valuesFromSQL.fetch()
            try valuesFromRequest.fetch()
            try optionalValuesFromSQL.fetch()
            try optionalValuesFromRequest.fetch()
            try rowsFromSQL.fetch()
            try rowsFromRequest.fetch()
            try recordsFromSQL.fetch()
            try recordsFromRequest.fetch()
            
            // change request
            let sql2 = "SELECT NULL AS ignored, ? AS name, ? AS id UNION ALL SELECT NULL, ?, ?"
            let arguments2: StatementArguments = ["c", 3, "d", 4]
            let adapter2 = SuffixRowAdapter(fromIndex: 1)
            let sqlRequest2 = SQLRequest(sql2, arguments: arguments2, adapter: adapter2)
            
            try valuesFromSQL.setRequest(sql: sql2, arguments: arguments2, adapter: adapter2)
            try valuesFromRequest.setRequest(sqlRequest2.bound(to: String.self))
            try optionalValuesFromSQL.setRequest(sql: sql2, arguments: arguments2, adapter: adapter2)
            try optionalValuesFromRequest.setRequest(sqlRequest2.bound(to: Optional<String>.self))
            try rowsFromSQL.setRequest(sql: sql2, arguments: arguments2, adapter: adapter2)
            try rowsFromRequest.setRequest(sqlRequest2.bound(to: Row.self))
            try recordsFromSQL.setRequest(sql: sql2, arguments: arguments2, adapter: adapter2)
            try recordsFromRequest.setRequest(sqlRequest2.bound(to: AnyRowConvertible.self))
            
            // collection still contains initial values
            do {
                let expectedRows: [Row] = [["name": "a", "id": 1], ["name": "b", "id": 2]]
                XCTAssertEqual(Array(valuesFromSQL), expectedRows.map { $0.value(atIndex: 0) })
                XCTAssertEqual(Array(valuesFromRequest), expectedRows.map { $0.value(atIndex: 0) })
                XCTAssertEqual(Array(optionalValuesFromSQL).map { $0! }, expectedRows.map { $0.value(atIndex: 0) })
                XCTAssertEqual(Array(optionalValuesFromRequest).map { $0! }, expectedRows.map { $0.value(atIndex: 0) })
                XCTAssertEqual(Array(rowsFromSQL), expectedRows)
                XCTAssertEqual(Array(rowsFromRequest), expectedRows)
                XCTAssertEqual(Array(recordsFromSQL), expectedRows.map { AnyRowConvertible(row: $0) })
                XCTAssertEqual(Array(recordsFromRequest), expectedRows.map { AnyRowConvertible(row: $0) })
            }
            
            valuesFromSQLChangesRecorder.expectation = expectation(description: "valuesFromSQL")
            valuesFromRequestChangesRecorder.expectation = expectation(description: "valuesFromRequest")
            optionalValuesFromSQLChangesRecorder.expectation = expectation(description: "optionalValuesFromSQL")
            optionalValuesFromRequestChangesRecorder.expectation = expectation(description: "optionalValuesFromRequest")
            rowsFromSQLChangesRecorder.expectation = expectation(description: "rowsFromSQL")
            rowsFromRequestChangesRecorder.expectation = expectation(description: "rowsFromRequest")
            recordsFromSQLChangesRecorder.expectation = expectation(description: "recordsFromSQL")
            recordsFromRequestChangesRecorder.expectation = expectation(description: "recordsFromRequest")
            waitForExpectations(timeout: 1, handler: nil)
            
            // collection now contains new values
            do {
                let expectedRows: [Row] = [["name": "c", "id": 3], ["name": "d", "id": 4]]
                XCTAssertEqual(Array(valuesFromSQL), expectedRows.map { $0.value(atIndex: 0) })
                XCTAssertEqual(Array(valuesFromRequest), expectedRows.map { $0.value(atIndex: 0) })
                XCTAssertEqual(Array(optionalValuesFromSQL).map { $0! }, expectedRows.map { $0.value(atIndex: 0) })
                XCTAssertEqual(Array(optionalValuesFromRequest).map { $0! }, expectedRows.map { $0.value(atIndex: 0) })
                XCTAssertEqual(Array(rowsFromSQL), expectedRows)
                XCTAssertEqual(Array(rowsFromRequest), expectedRows)
                XCTAssertEqual(Array(recordsFromSQL), expectedRows.map { AnyRowConvertible(row: $0) })
                XCTAssertEqual(Array(recordsFromRequest), expectedRows.map { AnyRowConvertible(row: $0) })
            }
            do {
                let expectedRows: [Row] = [["name": "a", "id": 1], ["name": "b", "id": 2]]
                XCTAssertEqual(valuesFromSQLChangesRecorder.elementsBeforeChanges, expectedRows.map { $0.value(atIndex: 0) })
                XCTAssertEqual(valuesFromRequestChangesRecorder.elementsBeforeChanges, expectedRows.map { $0.value(atIndex: 0) })
                XCTAssertEqual(optionalValuesFromSQLChangesRecorder.elementsBeforeChanges.map { $0! }, expectedRows.map { $0.value(atIndex: 0) })
                XCTAssertEqual(optionalValuesFromRequestChangesRecorder.elementsBeforeChanges.map { $0! }, expectedRows.map { $0.value(atIndex: 0) })
                XCTAssertEqual(rowsFromSQLChangesRecorder.elementsBeforeChanges, expectedRows)
                XCTAssertEqual(rowsFromRequestChangesRecorder.elementsBeforeChanges, expectedRows)
                XCTAssertEqual(recordsFromSQLChangesRecorder.elementsBeforeChanges, expectedRows.map { AnyRowConvertible(row: $0) })
                XCTAssertEqual(recordsFromRequestChangesRecorder.elementsBeforeChanges, expectedRows.map { AnyRowConvertible(row: $0) })
            }
            do {
                let expectedRows: [Row] = [["name": "c", "id": 3], ["name": "d", "id": 4]]
                XCTAssertEqual(valuesFromSQLChangesRecorder.elementsAfterChanges, expectedRows.map { $0.value(atIndex: 0) })
                XCTAssertEqual(valuesFromRequestChangesRecorder.elementsAfterChanges, expectedRows.map { $0.value(atIndex: 0) })
                XCTAssertEqual(optionalValuesFromSQLChangesRecorder.elementsAfterChanges.map { $0! }, expectedRows.map { $0.value(atIndex: 0) })
                XCTAssertEqual(optionalValuesFromRequestChangesRecorder.elementsAfterChanges.map { $0! }, expectedRows.map { $0.value(atIndex: 0) })
                XCTAssertEqual(rowsFromSQLChangesRecorder.elementsAfterChanges, expectedRows)
                XCTAssertEqual(rowsFromRequestChangesRecorder.elementsAfterChanges, expectedRows)
                XCTAssertEqual(recordsFromSQLChangesRecorder.elementsAfterChanges, expectedRows.map { AnyRowConvertible(row: $0) })
                XCTAssertEqual(recordsFromRequestChangesRecorder.elementsAfterChanges, expectedRows.map { AnyRowConvertible(row: $0) })
            }
        }
    }
    
    func testTransactionChanges() {
        assertNoError {
            let dbPool = try makeDatabasePool()
            try dbPool.write { db in
                try db.create(table: "table1") { t in
                    t.column("id", .integer).primaryKey()
                    t.column("name", .text)
                }
                try db.execute("INSERT INTO table1 (id, name) VALUES (?, ?)", arguments: [1, "a"])
                try db.execute("INSERT INTO table1 (id, name) VALUES (?, ?)", arguments: [2, "b"])
            }
            
            let sql = "SELECT name, id FROM table1 ORDER BY id"
            let sqlRequest = SQLRequest(sql)
            
            let valuesFromSQL = try FetchedCollection<String>(dbPool, sql: sql)
            let valuesFromRequest = try FetchedCollection(dbPool, request: sqlRequest.bound(to: String.self))
            let optionalValuesFromSQL = try FetchedCollection<String?>(dbPool, sql: sql)
            let optionalValuesFromRequest = try FetchedCollection(dbPool, request: sqlRequest.bound(to: Optional<String>.self))
            let rowsFromSQL = try FetchedCollection<Row>(dbPool, sql: sql)
            let rowsFromRequest = try FetchedCollection(dbPool, request: sqlRequest.bound(to: Row.self))
            let recordsFromSQL = try FetchedCollection<AnyRowConvertible>(dbPool, sql: sql)
            let recordsFromRequest = try FetchedCollection(dbPool, request: sqlRequest.bound(to: AnyRowConvertible.self))
            
            let valuesFromSQLChangesRecorder = ChangesRecorder<String, Void>()
            let valuesFromRequestChangesRecorder = ChangesRecorder<String, Void>()
            let optionalValuesFromSQLChangesRecorder = ChangesRecorder<String?, Void>()
            let optionalValuesFromRequestChangesRecorder = ChangesRecorder<String?, Void>()
            let rowsFromSQLChangesRecorder = ChangesRecorder<Row, Void>()
            let rowsFromRequestChangesRecorder = ChangesRecorder<Row, Void>()
            let recordsFromSQLChangesRecorder = ChangesRecorder<AnyRowConvertible, Void>()
            let recordsFromRequestChangesRecorder = ChangesRecorder<AnyRowConvertible, Void>()
            
            valuesFromSQLChangesRecorder.trackChanges(in: valuesFromSQL)
            valuesFromRequestChangesRecorder.trackChanges(in: valuesFromRequest)
            optionalValuesFromSQLChangesRecorder.trackChanges(in: optionalValuesFromSQL)
            optionalValuesFromRequestChangesRecorder.trackChanges(in: optionalValuesFromRequest)
            rowsFromSQLChangesRecorder.trackChanges(in: rowsFromSQL)
            rowsFromRequestChangesRecorder.trackChanges(in: rowsFromRequest)
            recordsFromSQLChangesRecorder.trackChanges(in: recordsFromSQL)
            recordsFromRequestChangesRecorder.trackChanges(in: recordsFromRequest)
            
            try valuesFromSQL.fetch()
            try valuesFromRequest.fetch()
            try optionalValuesFromSQL.fetch()
            try optionalValuesFromRequest.fetch()
            try rowsFromSQL.fetch()
            try rowsFromRequest.fetch()
            try recordsFromSQL.fetch()
            try recordsFromRequest.fetch()
            
            // transaction: delete
            try dbPool.writeInTransaction { db in
                try db.execute("DELETE FROM table1")  // here we are also testing that truncate optimization doesn't break FetchedCollection
                return .commit
            }
            
            // collection still contains initial values
            do {
                let expectedRows: [Row] = [["name": "a", "id": 1], ["name": "b", "id": 2]]
                XCTAssertEqual(Array(valuesFromSQL), expectedRows.map { $0.value(atIndex: 0) })
                XCTAssertEqual(Array(valuesFromRequest), expectedRows.map { $0.value(atIndex: 0) })
                XCTAssertEqual(Array(optionalValuesFromSQL).map { $0! }, expectedRows.map { $0.value(atIndex: 0) })
                XCTAssertEqual(Array(optionalValuesFromRequest).map { $0! }, expectedRows.map { $0.value(atIndex: 0) })
                XCTAssertEqual(Array(rowsFromSQL), expectedRows)
                XCTAssertEqual(Array(rowsFromRequest), expectedRows)
                XCTAssertEqual(Array(recordsFromSQL), expectedRows.map { AnyRowConvertible(row: $0) })
                XCTAssertEqual(Array(recordsFromRequest), expectedRows.map { AnyRowConvertible(row: $0) })
            }
            
            valuesFromSQLChangesRecorder.expectation = expectation(description: "valuesFromSQL")
            valuesFromRequestChangesRecorder.expectation = expectation(description: "valuesFromRequest")
            optionalValuesFromSQLChangesRecorder.expectation = expectation(description: "optionalValuesFromSQL")
            optionalValuesFromRequestChangesRecorder.expectation = expectation(description: "optionalValuesFromRequest")
            rowsFromSQLChangesRecorder.expectation = expectation(description: "rowsFromSQL")
            rowsFromRequestChangesRecorder.expectation = expectation(description: "rowsFromRequest")
            recordsFromSQLChangesRecorder.expectation = expectation(description: "recordsFromSQL")
            recordsFromRequestChangesRecorder.expectation = expectation(description: "recordsFromRequest")
            waitForExpectations(timeout: 1, handler: nil)
            
            // collection now contains new values
            do {
                let expectedRows: [Row] = []
                XCTAssertEqual(Array(valuesFromSQL), expectedRows.map { $0.value(atIndex: 0) })
                XCTAssertEqual(Array(valuesFromRequest), expectedRows.map { $0.value(atIndex: 0) })
                XCTAssertEqual(Array(optionalValuesFromSQL).map { $0! }, expectedRows.map { $0.value(atIndex: 0) })
                XCTAssertEqual(Array(optionalValuesFromRequest).map { $0! }, expectedRows.map { $0.value(atIndex: 0) })
                XCTAssertEqual(Array(rowsFromSQL), expectedRows)
                XCTAssertEqual(Array(rowsFromRequest), expectedRows)
                XCTAssertEqual(Array(recordsFromSQL), expectedRows.map { AnyRowConvertible(row: $0) })
                XCTAssertEqual(Array(recordsFromRequest), expectedRows.map { AnyRowConvertible(row: $0) })
            }
            do {
                let expectedRows: [Row] = [["name": "a", "id": 1], ["name": "b", "id": 2]]
                XCTAssertEqual(valuesFromSQLChangesRecorder.elementsBeforeChanges, expectedRows.map { $0.value(atIndex: 0) })
                XCTAssertEqual(valuesFromRequestChangesRecorder.elementsBeforeChanges, expectedRows.map { $0.value(atIndex: 0) })
                XCTAssertEqual(optionalValuesFromSQLChangesRecorder.elementsBeforeChanges.map { $0! }, expectedRows.map { $0.value(atIndex: 0) })
                XCTAssertEqual(optionalValuesFromRequestChangesRecorder.elementsBeforeChanges.map { $0! }, expectedRows.map { $0.value(atIndex: 0) })
                XCTAssertEqual(rowsFromSQLChangesRecorder.elementsBeforeChanges, expectedRows)
                XCTAssertEqual(rowsFromRequestChangesRecorder.elementsBeforeChanges, expectedRows)
                XCTAssertEqual(recordsFromSQLChangesRecorder.elementsBeforeChanges, expectedRows.map { AnyRowConvertible(row: $0) })
                XCTAssertEqual(recordsFromRequestChangesRecorder.elementsBeforeChanges, expectedRows.map { AnyRowConvertible(row: $0) })
            }
            do {
                let expectedRows: [Row] = []
                XCTAssertEqual(valuesFromSQLChangesRecorder.elementsAfterChanges, expectedRows.map { $0.value(atIndex: 0) })
                XCTAssertEqual(valuesFromRequestChangesRecorder.elementsAfterChanges, expectedRows.map { $0.value(atIndex: 0) })
                XCTAssertEqual(optionalValuesFromSQLChangesRecorder.elementsAfterChanges.map { $0! }, expectedRows.map { $0.value(atIndex: 0) })
                XCTAssertEqual(optionalValuesFromRequestChangesRecorder.elementsAfterChanges.map { $0! }, expectedRows.map { $0.value(atIndex: 0) })
                XCTAssertEqual(rowsFromSQLChangesRecorder.elementsAfterChanges, expectedRows)
                XCTAssertEqual(rowsFromRequestChangesRecorder.elementsAfterChanges, expectedRows)
                XCTAssertEqual(recordsFromSQLChangesRecorder.elementsAfterChanges, expectedRows.map { AnyRowConvertible(row: $0) })
                XCTAssertEqual(recordsFromRequestChangesRecorder.elementsAfterChanges, expectedRows.map { AnyRowConvertible(row: $0) })
            }
            
            // transaction: insert
            try dbPool.writeInTransaction { db in
                try db.execute("INSERT INTO table1 (id, name) VALUES (?, ?)", arguments: [3, "c"])
                try db.execute("INSERT INTO table1 (id, name) VALUES (?, ?)", arguments: [4, "d"])
                return .commit
            }
            
            // collection still contains initial values
            do {
                let expectedRows: [Row] = []
                XCTAssertEqual(Array(valuesFromSQL), expectedRows.map { $0.value(atIndex: 0) })
                XCTAssertEqual(Array(valuesFromRequest), expectedRows.map { $0.value(atIndex: 0) })
                XCTAssertEqual(Array(optionalValuesFromSQL).map { $0! }, expectedRows.map { $0.value(atIndex: 0) })
                XCTAssertEqual(Array(optionalValuesFromRequest).map { $0! }, expectedRows.map { $0.value(atIndex: 0) })
                XCTAssertEqual(Array(rowsFromSQL), expectedRows)
                XCTAssertEqual(Array(rowsFromRequest), expectedRows)
                XCTAssertEqual(Array(recordsFromSQL), expectedRows.map { AnyRowConvertible(row: $0) })
                XCTAssertEqual(Array(recordsFromRequest), expectedRows.map { AnyRowConvertible(row: $0) })
            }
            
            valuesFromSQLChangesRecorder.expectation = expectation(description: "valuesFromSQL")
            valuesFromRequestChangesRecorder.expectation = expectation(description: "valuesFromRequest")
            optionalValuesFromSQLChangesRecorder.expectation = expectation(description: "optionalValuesFromSQL")
            optionalValuesFromRequestChangesRecorder.expectation = expectation(description: "optionalValuesFromRequest")
            rowsFromSQLChangesRecorder.expectation = expectation(description: "rowsFromSQL")
            rowsFromRequestChangesRecorder.expectation = expectation(description: "rowsFromRequest")
            recordsFromSQLChangesRecorder.expectation = expectation(description: "recordsFromSQL")
            recordsFromRequestChangesRecorder.expectation = expectation(description: "recordsFromRequest")
            waitForExpectations(timeout: 1, handler: nil)
            
            // collection now contains new values
            do {
                let expectedRows: [Row] = [["name": "c", "id": 3], ["name": "d", "id": 4]]
                XCTAssertEqual(Array(valuesFromSQL), expectedRows.map { $0.value(atIndex: 0) })
                XCTAssertEqual(Array(valuesFromRequest), expectedRows.map { $0.value(atIndex: 0) })
                XCTAssertEqual(Array(optionalValuesFromSQL).map { $0! }, expectedRows.map { $0.value(atIndex: 0) })
                XCTAssertEqual(Array(optionalValuesFromRequest).map { $0! }, expectedRows.map { $0.value(atIndex: 0) })
                XCTAssertEqual(Array(rowsFromSQL), expectedRows)
                XCTAssertEqual(Array(rowsFromRequest), expectedRows)
                XCTAssertEqual(Array(recordsFromSQL), expectedRows.map { AnyRowConvertible(row: $0) })
                XCTAssertEqual(Array(recordsFromRequest), expectedRows.map { AnyRowConvertible(row: $0) })
            }
            do {
                let expectedRows: [Row] = []
                XCTAssertEqual(valuesFromSQLChangesRecorder.elementsBeforeChanges, expectedRows.map { $0.value(atIndex: 0) })
                XCTAssertEqual(valuesFromRequestChangesRecorder.elementsBeforeChanges, expectedRows.map { $0.value(atIndex: 0) })
                XCTAssertEqual(optionalValuesFromSQLChangesRecorder.elementsBeforeChanges.map { $0! }, expectedRows.map { $0.value(atIndex: 0) })
                XCTAssertEqual(optionalValuesFromRequestChangesRecorder.elementsBeforeChanges.map { $0! }, expectedRows.map { $0.value(atIndex: 0) })
                XCTAssertEqual(rowsFromSQLChangesRecorder.elementsBeforeChanges, expectedRows)
                XCTAssertEqual(rowsFromRequestChangesRecorder.elementsBeforeChanges, expectedRows)
                XCTAssertEqual(recordsFromSQLChangesRecorder.elementsBeforeChanges, expectedRows.map { AnyRowConvertible(row: $0) })
                XCTAssertEqual(recordsFromRequestChangesRecorder.elementsBeforeChanges, expectedRows.map { AnyRowConvertible(row: $0) })
            }
            do {
                let expectedRows: [Row] = [["name": "c", "id": 3], ["name": "d", "id": 4]]
                XCTAssertEqual(valuesFromSQLChangesRecorder.elementsAfterChanges, expectedRows.map { $0.value(atIndex: 0) })
                XCTAssertEqual(valuesFromRequestChangesRecorder.elementsAfterChanges, expectedRows.map { $0.value(atIndex: 0) })
                XCTAssertEqual(optionalValuesFromSQLChangesRecorder.elementsAfterChanges.map { $0! }, expectedRows.map { $0.value(atIndex: 0) })
                XCTAssertEqual(optionalValuesFromRequestChangesRecorder.elementsAfterChanges.map { $0! }, expectedRows.map { $0.value(atIndex: 0) })
                XCTAssertEqual(rowsFromSQLChangesRecorder.elementsAfterChanges, expectedRows)
                XCTAssertEqual(rowsFromRequestChangesRecorder.elementsAfterChanges, expectedRows)
                XCTAssertEqual(recordsFromSQLChangesRecorder.elementsAfterChanges, expectedRows.map { AnyRowConvertible(row: $0) })
                XCTAssertEqual(recordsFromRequestChangesRecorder.elementsAfterChanges, expectedRows.map { AnyRowConvertible(row: $0) })
            }
            
            // transaction: update
            try dbPool.writeInTransaction { db in
                try db.execute("UPDATE table1 SET name = ? WHERE id = ?", arguments: ["e", 3])
                return .commit
            }
            
            // collection still contains initial values
            do {
                let expectedRows: [Row] = [["name": "c", "id": 3], ["name": "d", "id": 4]]
                XCTAssertEqual(Array(valuesFromSQL), expectedRows.map { $0.value(atIndex: 0) })
                XCTAssertEqual(Array(valuesFromRequest), expectedRows.map { $0.value(atIndex: 0) })
                XCTAssertEqual(Array(optionalValuesFromSQL).map { $0! }, expectedRows.map { $0.value(atIndex: 0) })
                XCTAssertEqual(Array(optionalValuesFromRequest).map { $0! }, expectedRows.map { $0.value(atIndex: 0) })
                XCTAssertEqual(Array(rowsFromSQL), expectedRows)
                XCTAssertEqual(Array(rowsFromRequest), expectedRows)
                XCTAssertEqual(Array(recordsFromSQL), expectedRows.map { AnyRowConvertible(row: $0) })
                XCTAssertEqual(Array(recordsFromRequest), expectedRows.map { AnyRowConvertible(row: $0) })
            }
            
            valuesFromSQLChangesRecorder.expectation = expectation(description: "valuesFromSQL")
            valuesFromRequestChangesRecorder.expectation = expectation(description: "valuesFromRequest")
            optionalValuesFromSQLChangesRecorder.expectation = expectation(description: "optionalValuesFromSQL")
            optionalValuesFromRequestChangesRecorder.expectation = expectation(description: "optionalValuesFromRequest")
            rowsFromSQLChangesRecorder.expectation = expectation(description: "rowsFromSQL")
            rowsFromRequestChangesRecorder.expectation = expectation(description: "rowsFromRequest")
            recordsFromSQLChangesRecorder.expectation = expectation(description: "recordsFromSQL")
            recordsFromRequestChangesRecorder.expectation = expectation(description: "recordsFromRequest")
            waitForExpectations(timeout: 1, handler: nil)
            
            // collection now contains new values
            do {
                let expectedRows: [Row] = [["name": "e", "id": 3], ["name": "d", "id": 4]]
                XCTAssertEqual(Array(valuesFromSQL), expectedRows.map { $0.value(atIndex: 0) })
                XCTAssertEqual(Array(valuesFromRequest), expectedRows.map { $0.value(atIndex: 0) })
                XCTAssertEqual(Array(optionalValuesFromSQL).map { $0! }, expectedRows.map { $0.value(atIndex: 0) })
                XCTAssertEqual(Array(optionalValuesFromRequest).map { $0! }, expectedRows.map { $0.value(atIndex: 0) })
                XCTAssertEqual(Array(rowsFromSQL), expectedRows)
                XCTAssertEqual(Array(rowsFromRequest), expectedRows)
                XCTAssertEqual(Array(recordsFromSQL), expectedRows.map { AnyRowConvertible(row: $0) })
                XCTAssertEqual(Array(recordsFromRequest), expectedRows.map { AnyRowConvertible(row: $0) })
            }
            do {
                let expectedRows: [Row] = [["name": "c", "id": 3], ["name": "d", "id": 4]]
                XCTAssertEqual(valuesFromSQLChangesRecorder.elementsBeforeChanges, expectedRows.map { $0.value(atIndex: 0) })
                XCTAssertEqual(valuesFromRequestChangesRecorder.elementsBeforeChanges, expectedRows.map { $0.value(atIndex: 0) })
                XCTAssertEqual(optionalValuesFromSQLChangesRecorder.elementsBeforeChanges.map { $0! }, expectedRows.map { $0.value(atIndex: 0) })
                XCTAssertEqual(optionalValuesFromRequestChangesRecorder.elementsBeforeChanges.map { $0! }, expectedRows.map { $0.value(atIndex: 0) })
                XCTAssertEqual(rowsFromSQLChangesRecorder.elementsBeforeChanges, expectedRows)
                XCTAssertEqual(rowsFromRequestChangesRecorder.elementsBeforeChanges, expectedRows)
                XCTAssertEqual(recordsFromSQLChangesRecorder.elementsBeforeChanges, expectedRows.map { AnyRowConvertible(row: $0) })
                XCTAssertEqual(recordsFromRequestChangesRecorder.elementsBeforeChanges, expectedRows.map { AnyRowConvertible(row: $0) })
            }
            do {
                let expectedRows: [Row] = [["name": "e", "id": 3], ["name": "d", "id": 4]]
                XCTAssertEqual(valuesFromSQLChangesRecorder.elementsAfterChanges, expectedRows.map { $0.value(atIndex: 0) })
                XCTAssertEqual(valuesFromRequestChangesRecorder.elementsAfterChanges, expectedRows.map { $0.value(atIndex: 0) })
                XCTAssertEqual(optionalValuesFromSQLChangesRecorder.elementsAfterChanges.map { $0! }, expectedRows.map { $0.value(atIndex: 0) })
                XCTAssertEqual(optionalValuesFromRequestChangesRecorder.elementsAfterChanges.map { $0! }, expectedRows.map { $0.value(atIndex: 0) })
                XCTAssertEqual(rowsFromSQLChangesRecorder.elementsAfterChanges, expectedRows)
                XCTAssertEqual(rowsFromRequestChangesRecorder.elementsAfterChanges, expectedRows)
                XCTAssertEqual(recordsFromSQLChangesRecorder.elementsAfterChanges, expectedRows.map { AnyRowConvertible(row: $0) })
                XCTAssertEqual(recordsFromRequestChangesRecorder.elementsAfterChanges, expectedRows.map { AnyRowConvertible(row: $0) })
            }
        }
    }
    
    func testFetchThenChangeThenTrack() {
        assertNoError {
            let dbPool = try makeDatabasePool()
            try dbPool.write { db in
                try db.create(table: "table1") { t in
                    t.column("id", .integer).primaryKey()
                    t.column("name", .text)
                }
                try db.execute("INSERT INTO table1 (id, name) VALUES (?, ?)", arguments: [1, "a"])
                try db.execute("INSERT INTO table1 (id, name) VALUES (?, ?)", arguments: [2, "b"])
            }
            
            let sql = "SELECT name, id FROM table1 ORDER BY id"
            let sqlRequest = SQLRequest(sql)
            
            let valuesFromSQL = try FetchedCollection<String>(dbPool, sql: sql)
            let valuesFromRequest = try FetchedCollection(dbPool, request: sqlRequest.bound(to: String.self))
            let optionalValuesFromSQL = try FetchedCollection<String?>(dbPool, sql: sql)
            let optionalValuesFromRequest = try FetchedCollection(dbPool, request: sqlRequest.bound(to: Optional<String>.self))
            let rowsFromSQL = try FetchedCollection<Row>(dbPool, sql: sql)
            let rowsFromRequest = try FetchedCollection(dbPool, request: sqlRequest.bound(to: Row.self))
            let recordsFromSQL = try FetchedCollection<AnyRowConvertible>(dbPool, sql: sql)
            let recordsFromRequest = try FetchedCollection(dbPool, request: sqlRequest.bound(to: AnyRowConvertible.self))
            
            // fetch
            try valuesFromSQL.fetch()
            try valuesFromRequest.fetch()
            try optionalValuesFromSQL.fetch()
            try optionalValuesFromRequest.fetch()
            try rowsFromSQL.fetch()
            try rowsFromRequest.fetch()
            try recordsFromSQL.fetch()
            try recordsFromRequest.fetch()
            
            // change
            try dbPool.writeInTransaction { db in
                try db.execute("DELETE FROM table1")  // here we are also testing that truncate optimization doesn't break FetchedCollection
                try db.execute("INSERT INTO table1 (id, name) VALUES (?, ?)", arguments: [3, "c"])
                try db.execute("INSERT INTO table1 (id, name) VALUES (?, ?)", arguments: [4, "d"])
                return .commit
            }
            
            // track
            let valuesFromSQLChangesRecorder = ChangesRecorder<String, Void>()
            let valuesFromRequestChangesRecorder = ChangesRecorder<String, Void>()
            let optionalValuesFromSQLChangesRecorder = ChangesRecorder<String?, Void>()
            let optionalValuesFromRequestChangesRecorder = ChangesRecorder<String?, Void>()
            let rowsFromSQLChangesRecorder = ChangesRecorder<Row, Void>()
            let rowsFromRequestChangesRecorder = ChangesRecorder<Row, Void>()
            let recordsFromSQLChangesRecorder = ChangesRecorder<AnyRowConvertible, Void>()
            let recordsFromRequestChangesRecorder = ChangesRecorder<AnyRowConvertible, Void>()
            
            valuesFromSQLChangesRecorder.trackChanges(in: valuesFromSQL)
            valuesFromRequestChangesRecorder.trackChanges(in: valuesFromRequest)
            optionalValuesFromSQLChangesRecorder.trackChanges(in: optionalValuesFromSQL)
            optionalValuesFromRequestChangesRecorder.trackChanges(in: optionalValuesFromRequest)
            rowsFromSQLChangesRecorder.trackChanges(in: rowsFromSQL)
            rowsFromRequestChangesRecorder.trackChanges(in: rowsFromRequest)
            recordsFromSQLChangesRecorder.trackChanges(in: recordsFromSQL)
            recordsFromRequestChangesRecorder.trackChanges(in: recordsFromRequest)
            
            valuesFromSQLChangesRecorder.expectation = expectation(description: "valuesFromSQL")
            valuesFromRequestChangesRecorder.expectation = expectation(description: "valuesFromRequest")
            optionalValuesFromSQLChangesRecorder.expectation = expectation(description: "optionalValuesFromSQL")
            optionalValuesFromRequestChangesRecorder.expectation = expectation(description: "optionalValuesFromRequest")
            rowsFromSQLChangesRecorder.expectation = expectation(description: "rowsFromSQL")
            rowsFromRequestChangesRecorder.expectation = expectation(description: "rowsFromRequest")
            recordsFromSQLChangesRecorder.expectation = expectation(description: "recordsFromSQL")
            recordsFromRequestChangesRecorder.expectation = expectation(description: "recordsFromRequest")
            waitForExpectations(timeout: 1, handler: nil)
            
            // collection now contains new values
            do {
                let expectedRows: [Row] = [["name": "c", "id": 3], ["name": "d", "id": 4]]
                XCTAssertEqual(Array(valuesFromSQL), expectedRows.map { $0.value(atIndex: 0) })
                XCTAssertEqual(Array(valuesFromRequest), expectedRows.map { $0.value(atIndex: 0) })
                XCTAssertEqual(Array(optionalValuesFromSQL).map { $0! }, expectedRows.map { $0.value(atIndex: 0) })
                XCTAssertEqual(Array(optionalValuesFromRequest).map { $0! }, expectedRows.map { $0.value(atIndex: 0) })
                XCTAssertEqual(Array(rowsFromSQL), expectedRows)
                XCTAssertEqual(Array(rowsFromRequest), expectedRows)
                XCTAssertEqual(Array(recordsFromSQL), expectedRows.map { AnyRowConvertible(row: $0) })
                XCTAssertEqual(Array(recordsFromRequest), expectedRows.map { AnyRowConvertible(row: $0) })
            }
            do {
                let expectedRows: [Row] = [["name": "a", "id": 1], ["name": "b", "id": 2]]
                XCTAssertEqual(valuesFromSQLChangesRecorder.elementsBeforeChanges, expectedRows.map { $0.value(atIndex: 0) })
                XCTAssertEqual(valuesFromRequestChangesRecorder.elementsBeforeChanges, expectedRows.map { $0.value(atIndex: 0) })
                XCTAssertEqual(optionalValuesFromSQLChangesRecorder.elementsBeforeChanges.map { $0! }, expectedRows.map { $0.value(atIndex: 0) })
                XCTAssertEqual(optionalValuesFromRequestChangesRecorder.elementsBeforeChanges.map { $0! }, expectedRows.map { $0.value(atIndex: 0) })
                XCTAssertEqual(rowsFromSQLChangesRecorder.elementsBeforeChanges, expectedRows)
                XCTAssertEqual(rowsFromRequestChangesRecorder.elementsBeforeChanges, expectedRows)
                XCTAssertEqual(recordsFromSQLChangesRecorder.elementsBeforeChanges, expectedRows.map { AnyRowConvertible(row: $0) })
                XCTAssertEqual(recordsFromRequestChangesRecorder.elementsBeforeChanges, expectedRows.map { AnyRowConvertible(row: $0) })
            }
            do {
                let expectedRows: [Row] = [["name": "c", "id": 3], ["name": "d", "id": 4]]
                XCTAssertEqual(valuesFromSQLChangesRecorder.elementsAfterChanges, expectedRows.map { $0.value(atIndex: 0) })
                XCTAssertEqual(valuesFromRequestChangesRecorder.elementsAfterChanges, expectedRows.map { $0.value(atIndex: 0) })
                XCTAssertEqual(optionalValuesFromSQLChangesRecorder.elementsAfterChanges.map { $0! }, expectedRows.map { $0.value(atIndex: 0) })
                XCTAssertEqual(optionalValuesFromRequestChangesRecorder.elementsAfterChanges.map { $0! }, expectedRows.map { $0.value(atIndex: 0) })
                XCTAssertEqual(rowsFromSQLChangesRecorder.elementsAfterChanges, expectedRows)
                XCTAssertEqual(rowsFromRequestChangesRecorder.elementsAfterChanges, expectedRows)
                XCTAssertEqual(recordsFromSQLChangesRecorder.elementsAfterChanges, expectedRows.map { AnyRowConvertible(row: $0) })
                XCTAssertEqual(recordsFromRequestChangesRecorder.elementsAfterChanges, expectedRows.map { AnyRowConvertible(row: $0) })
            }
        }
    }
    
    func testFetchThenTrackThenChange() {
        assertNoError {
            let dbPool = try makeDatabasePool()
            try dbPool.write { db in
                try db.create(table: "table1") { t in
                    t.column("id", .integer).primaryKey()
                    t.column("name", .text)
                }
                try db.execute("INSERT INTO table1 (id, name) VALUES (?, ?)", arguments: [1, "a"])
                try db.execute("INSERT INTO table1 (id, name) VALUES (?, ?)", arguments: [2, "b"])
            }
            
            let sql = "SELECT name, id FROM table1 ORDER BY id"
            let sqlRequest = SQLRequest(sql)
            
            let valuesFromSQL = try FetchedCollection<String>(dbPool, sql: sql)
            let valuesFromRequest = try FetchedCollection(dbPool, request: sqlRequest.bound(to: String.self))
            let optionalValuesFromSQL = try FetchedCollection<String?>(dbPool, sql: sql)
            let optionalValuesFromRequest = try FetchedCollection(dbPool, request: sqlRequest.bound(to: Optional<String>.self))
            let rowsFromSQL = try FetchedCollection<Row>(dbPool, sql: sql)
            let rowsFromRequest = try FetchedCollection(dbPool, request: sqlRequest.bound(to: Row.self))
            let recordsFromSQL = try FetchedCollection<AnyRowConvertible>(dbPool, sql: sql)
            let recordsFromRequest = try FetchedCollection(dbPool, request: sqlRequest.bound(to: AnyRowConvertible.self))
            
            // fetch
            try valuesFromSQL.fetch()
            try valuesFromRequest.fetch()
            try optionalValuesFromSQL.fetch()
            try optionalValuesFromRequest.fetch()
            try rowsFromSQL.fetch()
            try rowsFromRequest.fetch()
            try recordsFromSQL.fetch()
            try recordsFromRequest.fetch()
            
            // track
            let valuesFromSQLChangesRecorder = ChangesRecorder<String, Void>()
            let valuesFromRequestChangesRecorder = ChangesRecorder<String, Void>()
            let optionalValuesFromSQLChangesRecorder = ChangesRecorder<String?, Void>()
            let optionalValuesFromRequestChangesRecorder = ChangesRecorder<String?, Void>()
            let rowsFromSQLChangesRecorder = ChangesRecorder<Row, Void>()
            let rowsFromRequestChangesRecorder = ChangesRecorder<Row, Void>()
            let recordsFromSQLChangesRecorder = ChangesRecorder<AnyRowConvertible, Void>()
            let recordsFromRequestChangesRecorder = ChangesRecorder<AnyRowConvertible, Void>()
            
            valuesFromSQLChangesRecorder.trackChanges(in: valuesFromSQL)
            valuesFromRequestChangesRecorder.trackChanges(in: valuesFromRequest)
            optionalValuesFromSQLChangesRecorder.trackChanges(in: optionalValuesFromSQL)
            optionalValuesFromRequestChangesRecorder.trackChanges(in: optionalValuesFromRequest)
            rowsFromSQLChangesRecorder.trackChanges(in: rowsFromSQL)
            rowsFromRequestChangesRecorder.trackChanges(in: rowsFromRequest)
            recordsFromSQLChangesRecorder.trackChanges(in: recordsFromSQL)
            recordsFromRequestChangesRecorder.trackChanges(in: recordsFromRequest)
            
            // change
            try dbPool.writeInTransaction { db in
                try db.execute("DELETE FROM table1")  // here we are also testing that truncate optimization doesn't break FetchedCollection
                try db.execute("INSERT INTO table1 (id, name) VALUES (?, ?)", arguments: [3, "c"])
                try db.execute("INSERT INTO table1 (id, name) VALUES (?, ?)", arguments: [4, "d"])
                return .commit
            }
            
            valuesFromSQLChangesRecorder.expectation = expectation(description: "valuesFromSQL")
            valuesFromRequestChangesRecorder.expectation = expectation(description: "valuesFromRequest")
            optionalValuesFromSQLChangesRecorder.expectation = expectation(description: "optionalValuesFromSQL")
            optionalValuesFromRequestChangesRecorder.expectation = expectation(description: "optionalValuesFromRequest")
            rowsFromSQLChangesRecorder.expectation = expectation(description: "rowsFromSQL")
            rowsFromRequestChangesRecorder.expectation = expectation(description: "rowsFromRequest")
            recordsFromSQLChangesRecorder.expectation = expectation(description: "recordsFromSQL")
            recordsFromRequestChangesRecorder.expectation = expectation(description: "recordsFromRequest")
            waitForExpectations(timeout: 1, handler: nil)
            
            // collection now contains new values
            do {
                let expectedRows: [Row] = [["name": "c", "id": 3], ["name": "d", "id": 4]]
                XCTAssertEqual(Array(valuesFromSQL), expectedRows.map { $0.value(atIndex: 0) })
                XCTAssertEqual(Array(valuesFromRequest), expectedRows.map { $0.value(atIndex: 0) })
                XCTAssertEqual(Array(optionalValuesFromSQL).map { $0! }, expectedRows.map { $0.value(atIndex: 0) })
                XCTAssertEqual(Array(optionalValuesFromRequest).map { $0! }, expectedRows.map { $0.value(atIndex: 0) })
                XCTAssertEqual(Array(rowsFromSQL), expectedRows)
                XCTAssertEqual(Array(rowsFromRequest), expectedRows)
                XCTAssertEqual(Array(recordsFromSQL), expectedRows.map { AnyRowConvertible(row: $0) })
                XCTAssertEqual(Array(recordsFromRequest), expectedRows.map { AnyRowConvertible(row: $0) })
            }
            do {
                let expectedRows: [Row] = [["name": "a", "id": 1], ["name": "b", "id": 2]]
                XCTAssertEqual(valuesFromSQLChangesRecorder.elementsBeforeChanges, expectedRows.map { $0.value(atIndex: 0) })
                XCTAssertEqual(valuesFromRequestChangesRecorder.elementsBeforeChanges, expectedRows.map { $0.value(atIndex: 0) })
                XCTAssertEqual(optionalValuesFromSQLChangesRecorder.elementsBeforeChanges.map { $0! }, expectedRows.map { $0.value(atIndex: 0) })
                XCTAssertEqual(optionalValuesFromRequestChangesRecorder.elementsBeforeChanges.map { $0! }, expectedRows.map { $0.value(atIndex: 0) })
                XCTAssertEqual(rowsFromSQLChangesRecorder.elementsBeforeChanges, expectedRows)
                XCTAssertEqual(rowsFromRequestChangesRecorder.elementsBeforeChanges, expectedRows)
                XCTAssertEqual(recordsFromSQLChangesRecorder.elementsBeforeChanges, expectedRows.map { AnyRowConvertible(row: $0) })
                XCTAssertEqual(recordsFromRequestChangesRecorder.elementsBeforeChanges, expectedRows.map { AnyRowConvertible(row: $0) })
            }
            do {
                let expectedRows: [Row] = [["name": "c", "id": 3], ["name": "d", "id": 4]]
                XCTAssertEqual(valuesFromSQLChangesRecorder.elementsAfterChanges, expectedRows.map { $0.value(atIndex: 0) })
                XCTAssertEqual(valuesFromRequestChangesRecorder.elementsAfterChanges, expectedRows.map { $0.value(atIndex: 0) })
                XCTAssertEqual(optionalValuesFromSQLChangesRecorder.elementsAfterChanges.map { $0! }, expectedRows.map { $0.value(atIndex: 0) })
                XCTAssertEqual(optionalValuesFromRequestChangesRecorder.elementsAfterChanges.map { $0! }, expectedRows.map { $0.value(atIndex: 0) })
                XCTAssertEqual(rowsFromSQLChangesRecorder.elementsAfterChanges, expectedRows)
                XCTAssertEqual(rowsFromRequestChangesRecorder.elementsAfterChanges, expectedRows)
                XCTAssertEqual(recordsFromSQLChangesRecorder.elementsAfterChanges, expectedRows.map { AnyRowConvertible(row: $0) })
                XCTAssertEqual(recordsFromRequestChangesRecorder.elementsAfterChanges, expectedRows.map { AnyRowConvertible(row: $0) })
            }
        }
    }
    
    func testTrackThenFetchThenChange() {
        assertNoError {
            let dbPool = try makeDatabasePool()
            try dbPool.write { db in
                try db.create(table: "table1") { t in
                    t.column("id", .integer).primaryKey()
                    t.column("name", .text)
                }
                try db.execute("INSERT INTO table1 (id, name) VALUES (?, ?)", arguments: [1, "a"])
                try db.execute("INSERT INTO table1 (id, name) VALUES (?, ?)", arguments: [2, "b"])
            }
            
            let sql = "SELECT name, id FROM table1 ORDER BY id"
            let sqlRequest = SQLRequest(sql)
            
            let valuesFromSQL = try FetchedCollection<String>(dbPool, sql: sql)
            let valuesFromRequest = try FetchedCollection(dbPool, request: sqlRequest.bound(to: String.self))
            let optionalValuesFromSQL = try FetchedCollection<String?>(dbPool, sql: sql)
            let optionalValuesFromRequest = try FetchedCollection(dbPool, request: sqlRequest.bound(to: Optional<String>.self))
            let rowsFromSQL = try FetchedCollection<Row>(dbPool, sql: sql)
            let rowsFromRequest = try FetchedCollection(dbPool, request: sqlRequest.bound(to: Row.self))
            let recordsFromSQL = try FetchedCollection<AnyRowConvertible>(dbPool, sql: sql)
            let recordsFromRequest = try FetchedCollection(dbPool, request: sqlRequest.bound(to: AnyRowConvertible.self))
            
            // track
            let valuesFromSQLChangesRecorder = ChangesRecorder<String, Void>()
            let valuesFromRequestChangesRecorder = ChangesRecorder<String, Void>()
            let optionalValuesFromSQLChangesRecorder = ChangesRecorder<String?, Void>()
            let optionalValuesFromRequestChangesRecorder = ChangesRecorder<String?, Void>()
            let rowsFromSQLChangesRecorder = ChangesRecorder<Row, Void>()
            let rowsFromRequestChangesRecorder = ChangesRecorder<Row, Void>()
            let recordsFromSQLChangesRecorder = ChangesRecorder<AnyRowConvertible, Void>()
            let recordsFromRequestChangesRecorder = ChangesRecorder<AnyRowConvertible, Void>()
            
            valuesFromSQLChangesRecorder.trackChanges(in: valuesFromSQL)
            valuesFromRequestChangesRecorder.trackChanges(in: valuesFromRequest)
            optionalValuesFromSQLChangesRecorder.trackChanges(in: optionalValuesFromSQL)
            optionalValuesFromRequestChangesRecorder.trackChanges(in: optionalValuesFromRequest)
            rowsFromSQLChangesRecorder.trackChanges(in: rowsFromSQL)
            rowsFromRequestChangesRecorder.trackChanges(in: rowsFromRequest)
            recordsFromSQLChangesRecorder.trackChanges(in: recordsFromSQL)
            recordsFromRequestChangesRecorder.trackChanges(in: recordsFromRequest)
            
            // fetch
            try valuesFromSQL.fetch()
            try valuesFromRequest.fetch()
            try optionalValuesFromSQL.fetch()
            try optionalValuesFromRequest.fetch()
            try rowsFromSQL.fetch()
            try rowsFromRequest.fetch()
            try recordsFromSQL.fetch()
            try recordsFromRequest.fetch()
            
            // change
            try dbPool.writeInTransaction { db in
                try db.execute("DELETE FROM table1")  // here we are also testing that truncate optimization doesn't break FetchedCollection
                try db.execute("INSERT INTO table1 (id, name) VALUES (?, ?)", arguments: [3, "c"])
                try db.execute("INSERT INTO table1 (id, name) VALUES (?, ?)", arguments: [4, "d"])
                return .commit
            }
            
            valuesFromSQLChangesRecorder.expectation = expectation(description: "valuesFromSQL")
            valuesFromRequestChangesRecorder.expectation = expectation(description: "valuesFromRequest")
            optionalValuesFromSQLChangesRecorder.expectation = expectation(description: "optionalValuesFromSQL")
            optionalValuesFromRequestChangesRecorder.expectation = expectation(description: "optionalValuesFromRequest")
            rowsFromSQLChangesRecorder.expectation = expectation(description: "rowsFromSQL")
            rowsFromRequestChangesRecorder.expectation = expectation(description: "rowsFromRequest")
            recordsFromSQLChangesRecorder.expectation = expectation(description: "recordsFromSQL")
            recordsFromRequestChangesRecorder.expectation = expectation(description: "recordsFromRequest")
            waitForExpectations(timeout: 1, handler: nil)
            
            // collection now contains new values
            do {
                let expectedRows: [Row] = [["name": "c", "id": 3], ["name": "d", "id": 4]]
                XCTAssertEqual(Array(valuesFromSQL), expectedRows.map { $0.value(atIndex: 0) })
                XCTAssertEqual(Array(valuesFromRequest), expectedRows.map { $0.value(atIndex: 0) })
                XCTAssertEqual(Array(optionalValuesFromSQL).map { $0! }, expectedRows.map { $0.value(atIndex: 0) })
                XCTAssertEqual(Array(optionalValuesFromRequest).map { $0! }, expectedRows.map { $0.value(atIndex: 0) })
                XCTAssertEqual(Array(rowsFromSQL), expectedRows)
                XCTAssertEqual(Array(rowsFromRequest), expectedRows)
                XCTAssertEqual(Array(recordsFromSQL), expectedRows.map { AnyRowConvertible(row: $0) })
                XCTAssertEqual(Array(recordsFromRequest), expectedRows.map { AnyRowConvertible(row: $0) })
            }
            do {
                let expectedRows: [Row] = [["name": "a", "id": 1], ["name": "b", "id": 2]]
                XCTAssertEqual(valuesFromSQLChangesRecorder.elementsBeforeChanges, expectedRows.map { $0.value(atIndex: 0) })
                XCTAssertEqual(valuesFromRequestChangesRecorder.elementsBeforeChanges, expectedRows.map { $0.value(atIndex: 0) })
                XCTAssertEqual(optionalValuesFromSQLChangesRecorder.elementsBeforeChanges.map { $0! }, expectedRows.map { $0.value(atIndex: 0) })
                XCTAssertEqual(optionalValuesFromRequestChangesRecorder.elementsBeforeChanges.map { $0! }, expectedRows.map { $0.value(atIndex: 0) })
                XCTAssertEqual(rowsFromSQLChangesRecorder.elementsBeforeChanges, expectedRows)
                XCTAssertEqual(rowsFromRequestChangesRecorder.elementsBeforeChanges, expectedRows)
                XCTAssertEqual(recordsFromSQLChangesRecorder.elementsBeforeChanges, expectedRows.map { AnyRowConvertible(row: $0) })
                XCTAssertEqual(recordsFromRequestChangesRecorder.elementsBeforeChanges, expectedRows.map { AnyRowConvertible(row: $0) })
            }
            do {
                let expectedRows: [Row] = [["name": "c", "id": 3], ["name": "d", "id": 4]]
                XCTAssertEqual(valuesFromSQLChangesRecorder.elementsAfterChanges, expectedRows.map { $0.value(atIndex: 0) })
                XCTAssertEqual(valuesFromRequestChangesRecorder.elementsAfterChanges, expectedRows.map { $0.value(atIndex: 0) })
                XCTAssertEqual(optionalValuesFromSQLChangesRecorder.elementsAfterChanges.map { $0! }, expectedRows.map { $0.value(atIndex: 0) })
                XCTAssertEqual(optionalValuesFromRequestChangesRecorder.elementsAfterChanges.map { $0! }, expectedRows.map { $0.value(atIndex: 0) })
                XCTAssertEqual(rowsFromSQLChangesRecorder.elementsAfterChanges, expectedRows)
                XCTAssertEqual(rowsFromRequestChangesRecorder.elementsAfterChanges, expectedRows)
                XCTAssertEqual(recordsFromSQLChangesRecorder.elementsAfterChanges, expectedRows.map { AnyRowConvertible(row: $0) })
                XCTAssertEqual(recordsFromRequestChangesRecorder.elementsAfterChanges, expectedRows.map { AnyRowConvertible(row: $0) })
            }
        }
    }
    
    func testMultipleTablesChanges() {
        assertNoError {
            let dbPool = try makeDatabasePool()
            try dbPool.write { db in
                try db.create(table: "table1") { t in
                    t.column("id", .integer).primaryKey()
                    t.column("name", .text)
                }
                try db.create(table: "table2") { t in
                    t.column("id", .integer).primaryKey()
                    t.column("name", .text)
                }
                try db.execute("INSERT INTO table1 (id, name) VALUES (?, ?)", arguments: [1, "a"])
                try db.execute("INSERT INTO table2 (id, name) VALUES (?, ?)", arguments: [2, "b"])
            }
            
            let sql = "SELECT name, id FROM (SELECT name, id FROM table1 UNION ALL SELECT name, id FROM table2) ORDER BY id"
            let sqlRequest = SQLRequest(sql)
            
            let valuesFromSQL = try FetchedCollection<String>(dbPool, sql: sql)
            let valuesFromRequest = try FetchedCollection(dbPool, request: sqlRequest.bound(to: String.self))
            let optionalValuesFromSQL = try FetchedCollection<String?>(dbPool, sql: sql)
            let optionalValuesFromRequest = try FetchedCollection(dbPool, request: sqlRequest.bound(to: Optional<String>.self))
            let rowsFromSQL = try FetchedCollection<Row>(dbPool, sql: sql)
            let rowsFromRequest = try FetchedCollection(dbPool, request: sqlRequest.bound(to: Row.self))
            let recordsFromSQL = try FetchedCollection<AnyRowConvertible>(dbPool, sql: sql)
            let recordsFromRequest = try FetchedCollection(dbPool, request: sqlRequest.bound(to: AnyRowConvertible.self))
            
            let valuesFromSQLChangesRecorder = ChangesRecorder<String, Void>()
            let valuesFromRequestChangesRecorder = ChangesRecorder<String, Void>()
            let optionalValuesFromSQLChangesRecorder = ChangesRecorder<String?, Void>()
            let optionalValuesFromRequestChangesRecorder = ChangesRecorder<String?, Void>()
            let rowsFromSQLChangesRecorder = ChangesRecorder<Row, Void>()
            let rowsFromRequestChangesRecorder = ChangesRecorder<Row, Void>()
            let recordsFromSQLChangesRecorder = ChangesRecorder<AnyRowConvertible, Void>()
            let recordsFromRequestChangesRecorder = ChangesRecorder<AnyRowConvertible, Void>()
            
            valuesFromSQLChangesRecorder.trackChanges(in: valuesFromSQL)
            valuesFromRequestChangesRecorder.trackChanges(in: valuesFromRequest)
            optionalValuesFromSQLChangesRecorder.trackChanges(in: optionalValuesFromSQL)
            optionalValuesFromRequestChangesRecorder.trackChanges(in: optionalValuesFromRequest)
            rowsFromSQLChangesRecorder.trackChanges(in: rowsFromSQL)
            rowsFromRequestChangesRecorder.trackChanges(in: rowsFromRequest)
            recordsFromSQLChangesRecorder.trackChanges(in: recordsFromSQL)
            recordsFromRequestChangesRecorder.trackChanges(in: recordsFromRequest)
            
            try valuesFromSQL.fetch()
            try valuesFromRequest.fetch()
            try optionalValuesFromSQL.fetch()
            try optionalValuesFromRequest.fetch()
            try rowsFromSQL.fetch()
            try rowsFromRequest.fetch()
            try recordsFromSQL.fetch()
            try recordsFromRequest.fetch()
            
            // modify table1
            try dbPool.writeInTransaction { db in
                try db.execute("DELETE FROM table1")
                try db.execute("INSERT INTO table1 (id, name) VALUES (?, ?)", arguments: [3, "c"])
                return .commit
            }
            
            // collection still contains initial values
            do {
                let expectedRows: [Row] = [["name": "a", "id": 1], ["name": "b", "id": 2]]
                XCTAssertEqual(Array(valuesFromSQL), expectedRows.map { $0.value(atIndex: 0) })
                XCTAssertEqual(Array(valuesFromRequest), expectedRows.map { $0.value(atIndex: 0) })
                XCTAssertEqual(Array(optionalValuesFromSQL).map { $0! }, expectedRows.map { $0.value(atIndex: 0) })
                XCTAssertEqual(Array(optionalValuesFromRequest).map { $0! }, expectedRows.map { $0.value(atIndex: 0) })
                XCTAssertEqual(Array(rowsFromSQL), expectedRows)
                XCTAssertEqual(Array(rowsFromRequest), expectedRows)
                XCTAssertEqual(Array(recordsFromSQL), expectedRows.map { AnyRowConvertible(row: $0) })
                XCTAssertEqual(Array(recordsFromRequest), expectedRows.map { AnyRowConvertible(row: $0) })
            }
            
            valuesFromSQLChangesRecorder.expectation = expectation(description: "valuesFromSQL")
            valuesFromRequestChangesRecorder.expectation = expectation(description: "valuesFromRequest")
            optionalValuesFromSQLChangesRecorder.expectation = expectation(description: "optionalValuesFromSQL")
            optionalValuesFromRequestChangesRecorder.expectation = expectation(description: "optionalValuesFromRequest")
            rowsFromSQLChangesRecorder.expectation = expectation(description: "rowsFromSQL")
            rowsFromRequestChangesRecorder.expectation = expectation(description: "rowsFromRequest")
            recordsFromSQLChangesRecorder.expectation = expectation(description: "recordsFromSQL")
            recordsFromRequestChangesRecorder.expectation = expectation(description: "recordsFromRequest")
            waitForExpectations(timeout: 1, handler: nil)
            
            // collection now contains new values
            do {
                let expectedRows: [Row] = [["name": "b", "id": 2], ["name": "c", "id": 3]]
                XCTAssertEqual(Array(valuesFromSQL), expectedRows.map { $0.value(atIndex: 0) })
                XCTAssertEqual(Array(valuesFromRequest), expectedRows.map { $0.value(atIndex: 0) })
                XCTAssertEqual(Array(optionalValuesFromSQL).map { $0! }, expectedRows.map { $0.value(atIndex: 0) })
                XCTAssertEqual(Array(optionalValuesFromRequest).map { $0! }, expectedRows.map { $0.value(atIndex: 0) })
                XCTAssertEqual(Array(rowsFromSQL), expectedRows)
                XCTAssertEqual(Array(rowsFromRequest), expectedRows)
                XCTAssertEqual(Array(recordsFromSQL), expectedRows.map { AnyRowConvertible(row: $0) })
                XCTAssertEqual(Array(recordsFromRequest), expectedRows.map { AnyRowConvertible(row: $0) })
            }
            do {
                let expectedRows: [Row] = [["name": "a", "id": 1], ["name": "b", "id": 2]]
                XCTAssertEqual(valuesFromSQLChangesRecorder.elementsBeforeChanges, expectedRows.map { $0.value(atIndex: 0) })
                XCTAssertEqual(valuesFromRequestChangesRecorder.elementsBeforeChanges, expectedRows.map { $0.value(atIndex: 0) })
                XCTAssertEqual(optionalValuesFromSQLChangesRecorder.elementsBeforeChanges.map { $0! }, expectedRows.map { $0.value(atIndex: 0) })
                XCTAssertEqual(optionalValuesFromRequestChangesRecorder.elementsBeforeChanges.map { $0! }, expectedRows.map { $0.value(atIndex: 0) })
                XCTAssertEqual(rowsFromSQLChangesRecorder.elementsBeforeChanges, expectedRows)
                XCTAssertEqual(rowsFromRequestChangesRecorder.elementsBeforeChanges, expectedRows)
                XCTAssertEqual(recordsFromSQLChangesRecorder.elementsBeforeChanges, expectedRows.map { AnyRowConvertible(row: $0) })
                XCTAssertEqual(recordsFromRequestChangesRecorder.elementsBeforeChanges, expectedRows.map { AnyRowConvertible(row: $0) })
            }
            do {
                let expectedRows: [Row] = [["name": "b", "id": 2], ["name": "c", "id": 3]]
                XCTAssertEqual(valuesFromSQLChangesRecorder.elementsAfterChanges, expectedRows.map { $0.value(atIndex: 0) })
                XCTAssertEqual(valuesFromRequestChangesRecorder.elementsAfterChanges, expectedRows.map { $0.value(atIndex: 0) })
                XCTAssertEqual(optionalValuesFromSQLChangesRecorder.elementsAfterChanges.map { $0! }, expectedRows.map { $0.value(atIndex: 0) })
                XCTAssertEqual(optionalValuesFromRequestChangesRecorder.elementsAfterChanges.map { $0! }, expectedRows.map { $0.value(atIndex: 0) })
                XCTAssertEqual(rowsFromSQLChangesRecorder.elementsAfterChanges, expectedRows)
                XCTAssertEqual(rowsFromRequestChangesRecorder.elementsAfterChanges, expectedRows)
                XCTAssertEqual(recordsFromSQLChangesRecorder.elementsAfterChanges, expectedRows.map { AnyRowConvertible(row: $0) })
                XCTAssertEqual(recordsFromRequestChangesRecorder.elementsAfterChanges, expectedRows.map { AnyRowConvertible(row: $0) })
            }
            
            // modify table2
            try dbPool.writeInTransaction { db in
                try db.execute("DELETE FROM table2")
                try db.execute("INSERT INTO table2 (id, name) VALUES (?, ?)", arguments: [4, "d"])
                return .commit
            }
            
            // collection still contains initial values
            do {
                let expectedRows: [Row] = [["name": "b", "id": 2], ["name": "c", "id": 3]]
                XCTAssertEqual(Array(valuesFromSQL), expectedRows.map { $0.value(atIndex: 0) })
                XCTAssertEqual(Array(valuesFromRequest), expectedRows.map { $0.value(atIndex: 0) })
                XCTAssertEqual(Array(optionalValuesFromSQL).map { $0! }, expectedRows.map { $0.value(atIndex: 0) })
                XCTAssertEqual(Array(optionalValuesFromRequest).map { $0! }, expectedRows.map { $0.value(atIndex: 0) })
                XCTAssertEqual(Array(rowsFromSQL), expectedRows)
                XCTAssertEqual(Array(rowsFromRequest), expectedRows)
                XCTAssertEqual(Array(recordsFromSQL), expectedRows.map { AnyRowConvertible(row: $0) })
                XCTAssertEqual(Array(recordsFromRequest), expectedRows.map { AnyRowConvertible(row: $0) })
            }
            
            valuesFromSQLChangesRecorder.expectation = expectation(description: "valuesFromSQL")
            valuesFromRequestChangesRecorder.expectation = expectation(description: "valuesFromRequest")
            optionalValuesFromSQLChangesRecorder.expectation = expectation(description: "optionalValuesFromSQL")
            optionalValuesFromRequestChangesRecorder.expectation = expectation(description: "optionalValuesFromRequest")
            rowsFromSQLChangesRecorder.expectation = expectation(description: "rowsFromSQL")
            rowsFromRequestChangesRecorder.expectation = expectation(description: "rowsFromRequest")
            recordsFromSQLChangesRecorder.expectation = expectation(description: "recordsFromSQL")
            recordsFromRequestChangesRecorder.expectation = expectation(description: "recordsFromRequest")
            waitForExpectations(timeout: 1, handler: nil)
            
            // collection now contains new values
            do {
                let expectedRows: [Row] = [["name": "c", "id": 3], ["name": "d", "id": 4]]
                XCTAssertEqual(Array(valuesFromSQL), expectedRows.map { $0.value(atIndex: 0) })
                XCTAssertEqual(Array(valuesFromRequest), expectedRows.map { $0.value(atIndex: 0) })
                XCTAssertEqual(Array(optionalValuesFromSQL).map { $0! }, expectedRows.map { $0.value(atIndex: 0) })
                XCTAssertEqual(Array(optionalValuesFromRequest).map { $0! }, expectedRows.map { $0.value(atIndex: 0) })
                XCTAssertEqual(Array(rowsFromSQL), expectedRows)
                XCTAssertEqual(Array(rowsFromRequest), expectedRows)
                XCTAssertEqual(Array(recordsFromSQL), expectedRows.map { AnyRowConvertible(row: $0) })
                XCTAssertEqual(Array(recordsFromRequest), expectedRows.map { AnyRowConvertible(row: $0) })
            }
            do {
                let expectedRows: [Row] = [["name": "b", "id": 2], ["name": "c", "id": 3]]
                XCTAssertEqual(valuesFromSQLChangesRecorder.elementsBeforeChanges, expectedRows.map { $0.value(atIndex: 0) })
                XCTAssertEqual(valuesFromRequestChangesRecorder.elementsBeforeChanges, expectedRows.map { $0.value(atIndex: 0) })
                XCTAssertEqual(optionalValuesFromSQLChangesRecorder.elementsBeforeChanges.map { $0! }, expectedRows.map { $0.value(atIndex: 0) })
                XCTAssertEqual(optionalValuesFromRequestChangesRecorder.elementsBeforeChanges.map { $0! }, expectedRows.map { $0.value(atIndex: 0) })
                XCTAssertEqual(rowsFromSQLChangesRecorder.elementsBeforeChanges, expectedRows)
                XCTAssertEqual(rowsFromRequestChangesRecorder.elementsBeforeChanges, expectedRows)
                XCTAssertEqual(recordsFromSQLChangesRecorder.elementsBeforeChanges, expectedRows.map { AnyRowConvertible(row: $0) })
                XCTAssertEqual(recordsFromRequestChangesRecorder.elementsBeforeChanges, expectedRows.map { AnyRowConvertible(row: $0) })
            }
            do {
                let expectedRows: [Row] = [["name": "c", "id": 3], ["name": "d", "id": 4]]
                XCTAssertEqual(valuesFromSQLChangesRecorder.elementsAfterChanges, expectedRows.map { $0.value(atIndex: 0) })
                XCTAssertEqual(valuesFromRequestChangesRecorder.elementsAfterChanges, expectedRows.map { $0.value(atIndex: 0) })
                XCTAssertEqual(optionalValuesFromSQLChangesRecorder.elementsAfterChanges.map { $0! }, expectedRows.map { $0.value(atIndex: 0) })
                XCTAssertEqual(optionalValuesFromRequestChangesRecorder.elementsAfterChanges.map { $0! }, expectedRows.map { $0.value(atIndex: 0) })
                XCTAssertEqual(rowsFromSQLChangesRecorder.elementsAfterChanges, expectedRows)
                XCTAssertEqual(rowsFromRequestChangesRecorder.elementsAfterChanges, expectedRows)
                XCTAssertEqual(recordsFromSQLChangesRecorder.elementsAfterChanges, expectedRows.map { AnyRowConvertible(row: $0) })
                XCTAssertEqual(recordsFromRequestChangesRecorder.elementsAfterChanges, expectedRows.map { AnyRowConvertible(row: $0) })
            }
        }
    }
    
    func testTrackedTablesChanges() {
        assertNoError {
            let dbPool = try makeDatabasePool()
            try dbPool.write { db in
                try db.create(table: "table1") { t in
                    t.column("id", .integer).primaryKey()
                    t.column("name", .text)
                }
                try db.create(table: "table2") { t in
                    t.column("id", .integer).primaryKey()
                    t.column("name", .text)
                }
                try db.execute("INSERT INTO table1 (id, name) VALUES (?, ?)", arguments: [1, "a"])
                try db.execute("INSERT INTO table2 (id, name) VALUES (?, ?)", arguments: [2, "b"])
            }
            
            let sql1 = "SELECT name, id FROM table1 ORDER BY id"
            let sqlRequest1 = SQLRequest(sql1)
            
            let valuesFromSQL = try FetchedCollection<String>(dbPool, sql: sql1)
            let valuesFromRequest = try FetchedCollection(dbPool, request: sqlRequest1.bound(to: String.self))
            let optionalValuesFromSQL = try FetchedCollection<String?>(dbPool, sql: sql1)
            let optionalValuesFromRequest = try FetchedCollection(dbPool, request: sqlRequest1.bound(to: Optional<String>.self))
            let rowsFromSQL = try FetchedCollection<Row>(dbPool, sql: sql1)
            let rowsFromRequest = try FetchedCollection(dbPool, request: sqlRequest1.bound(to: Row.self))
            let recordsFromSQL = try FetchedCollection<AnyRowConvertible>(dbPool, sql: sql1)
            let recordsFromRequest = try FetchedCollection(dbPool, request: sqlRequest1.bound(to: AnyRowConvertible.self))
            
            let valuesFromSQLChangesRecorder = ChangesRecorder<String, Void>()
            let valuesFromRequestChangesRecorder = ChangesRecorder<String, Void>()
            let optionalValuesFromSQLChangesRecorder = ChangesRecorder<String?, Void>()
            let optionalValuesFromRequestChangesRecorder = ChangesRecorder<String?, Void>()
            let rowsFromSQLChangesRecorder = ChangesRecorder<Row, Void>()
            let rowsFromRequestChangesRecorder = ChangesRecorder<Row, Void>()
            let recordsFromSQLChangesRecorder = ChangesRecorder<AnyRowConvertible, Void>()
            let recordsFromRequestChangesRecorder = ChangesRecorder<AnyRowConvertible, Void>()
            
            valuesFromSQLChangesRecorder.trackChanges(in: valuesFromSQL)
            valuesFromRequestChangesRecorder.trackChanges(in: valuesFromRequest)
            optionalValuesFromSQLChangesRecorder.trackChanges(in: optionalValuesFromSQL)
            optionalValuesFromRequestChangesRecorder.trackChanges(in: optionalValuesFromRequest)
            rowsFromSQLChangesRecorder.trackChanges(in: rowsFromSQL)
            rowsFromRequestChangesRecorder.trackChanges(in: rowsFromRequest)
            recordsFromSQLChangesRecorder.trackChanges(in: recordsFromSQL)
            recordsFromRequestChangesRecorder.trackChanges(in: recordsFromRequest)
            
            try valuesFromSQL.fetch()
            try valuesFromRequest.fetch()
            try optionalValuesFromSQL.fetch()
            try optionalValuesFromRequest.fetch()
            try rowsFromSQL.fetch()
            try rowsFromRequest.fetch()
            try recordsFromSQL.fetch()
            try recordsFromRequest.fetch()
            
            // change request
            let sql2 = "SELECT name, id FROM table2 ORDER BY id"
            let sqlRequest2 = SQLRequest(sql2)
            
            try valuesFromSQL.setRequest(sql: sql2)
            try valuesFromRequest.setRequest(sqlRequest2.bound(to: String.self))
            try optionalValuesFromSQL.setRequest(sql: sql2)
            try optionalValuesFromRequest.setRequest(sqlRequest2.bound(to: Optional<String>.self))
            try rowsFromSQL.setRequest(sql: sql2)
            try rowsFromRequest.setRequest(sqlRequest2.bound(to: Row.self))
            try recordsFromSQL.setRequest(sql: sql2)
            try recordsFromRequest.setRequest(sqlRequest2.bound(to: AnyRowConvertible.self))
            
            valuesFromSQLChangesRecorder.expectation = expectation(description: "valuesFromSQL")
            valuesFromRequestChangesRecorder.expectation = expectation(description: "valuesFromRequest")
            optionalValuesFromSQLChangesRecorder.expectation = expectation(description: "optionalValuesFromSQL")
            optionalValuesFromRequestChangesRecorder.expectation = expectation(description: "optionalValuesFromRequest")
            rowsFromSQLChangesRecorder.expectation = expectation(description: "rowsFromSQL")
            rowsFromRequestChangesRecorder.expectation = expectation(description: "rowsFromRequest")
            recordsFromSQLChangesRecorder.expectation = expectation(description: "recordsFromSQL")
            recordsFromRequestChangesRecorder.expectation = expectation(description: "recordsFromRequest")
            waitForExpectations(timeout: 1, handler: nil)
            
            // collection now contains new values
            do {
                let expectedRows: [Row] = [["name": "b", "id": 2]]
                XCTAssertEqual(Array(valuesFromSQL), expectedRows.map { $0.value(atIndex: 0) })
                XCTAssertEqual(Array(valuesFromRequest), expectedRows.map { $0.value(atIndex: 0) })
                XCTAssertEqual(Array(optionalValuesFromSQL).map { $0! }, expectedRows.map { $0.value(atIndex: 0) })
                XCTAssertEqual(Array(optionalValuesFromRequest).map { $0! }, expectedRows.map { $0.value(atIndex: 0) })
                XCTAssertEqual(Array(rowsFromSQL), expectedRows)
                XCTAssertEqual(Array(rowsFromRequest), expectedRows)
                XCTAssertEqual(Array(recordsFromSQL), expectedRows.map { AnyRowConvertible(row: $0) })
                XCTAssertEqual(Array(recordsFromRequest), expectedRows.map { AnyRowConvertible(row: $0) })
            }
            
            // modify table2
            try dbPool.writeInTransaction { db in
                try db.execute("INSERT INTO table2 (id, name) VALUES (?, ?)", arguments: [3, "c"])
                return .commit
            }
            
            valuesFromSQLChangesRecorder.expectation = expectation(description: "valuesFromSQL")
            valuesFromRequestChangesRecorder.expectation = expectation(description: "valuesFromRequest")
            optionalValuesFromSQLChangesRecorder.expectation = expectation(description: "optionalValuesFromSQL")
            optionalValuesFromRequestChangesRecorder.expectation = expectation(description: "optionalValuesFromRequest")
            rowsFromSQLChangesRecorder.expectation = expectation(description: "rowsFromSQL")
            rowsFromRequestChangesRecorder.expectation = expectation(description: "rowsFromRequest")
            recordsFromSQLChangesRecorder.expectation = expectation(description: "recordsFromSQL")
            recordsFromRequestChangesRecorder.expectation = expectation(description: "recordsFromRequest")
            waitForExpectations(timeout: 1, handler: nil)
            
            // collection now contains new values
            do {
                let expectedRows: [Row] = [["name": "b", "id": 2], ["name": "c", "id": 3]]
                XCTAssertEqual(Array(valuesFromSQL), expectedRows.map { $0.value(atIndex: 0) })
                XCTAssertEqual(Array(valuesFromRequest), expectedRows.map { $0.value(atIndex: 0) })
                XCTAssertEqual(Array(optionalValuesFromSQL).map { $0! }, expectedRows.map { $0.value(atIndex: 0) })
                XCTAssertEqual(Array(optionalValuesFromRequest).map { $0! }, expectedRows.map { $0.value(atIndex: 0) })
                XCTAssertEqual(Array(rowsFromSQL), expectedRows)
                XCTAssertEqual(Array(rowsFromRequest), expectedRows)
                XCTAssertEqual(Array(recordsFromSQL), expectedRows.map { AnyRowConvertible(row: $0) })
                XCTAssertEqual(Array(recordsFromRequest), expectedRows.map { AnyRowConvertible(row: $0) })
            }
        }
    }
    
    func testFetchAlongside() {
        assertNoError {
            let dbPool = try makeDatabasePool()
            try dbPool.write { db in
                try db.create(table: "table1") { t in
                    t.column("id", .integer).primaryKey()
                    t.column("name", .text)
                }
            }
            
            let sql = "SELECT name, id FROM table1 ORDER BY id"
            let sqlRequest = SQLRequest(sql)
            
            let valuesFromSQL = try FetchedCollection<String>(dbPool, sql: sql)
            let valuesFromRequest = try FetchedCollection(dbPool, request: sqlRequest.bound(to: String.self))
            let optionalValuesFromSQL = try FetchedCollection<String?>(dbPool, sql: sql)
            let optionalValuesFromRequest = try FetchedCollection(dbPool, request: sqlRequest.bound(to: Optional<String>.self))
            let rowsFromSQL = try FetchedCollection<Row>(dbPool, sql: sql)
            let rowsFromRequest = try FetchedCollection(dbPool, request: sqlRequest.bound(to: Row.self))
            let recordsFromSQL = try FetchedCollection<AnyRowConvertible>(dbPool, sql: sql)
            let recordsFromRequest = try FetchedCollection(dbPool, request: sqlRequest.bound(to: AnyRowConvertible.self))
            
            let valuesFromSQLChangesRecorder = ChangesRecorder<String, Int>()
            let valuesFromRequestChangesRecorder = ChangesRecorder<String, Int>()
            let optionalValuesFromSQLChangesRecorder = ChangesRecorder<String?, Int>()
            let optionalValuesFromRequestChangesRecorder = ChangesRecorder<String?, Int>()
            let rowsFromSQLChangesRecorder = ChangesRecorder<Row, Int>()
            let rowsFromRequestChangesRecorder = ChangesRecorder<Row, Int>()
            let recordsFromSQLChangesRecorder = ChangesRecorder<AnyRowConvertible, Int>()
            let recordsFromRequestChangesRecorder = ChangesRecorder<AnyRowConvertible, Int>()
            
            let fetchAlongside = { (db: Database) in try Int.fetchOne(db, "SELECT COUNT(*) FROM table1")! }
            valuesFromSQLChangesRecorder.trackChanges(in: valuesFromSQL, fetchAlongside: fetchAlongside)
            valuesFromRequestChangesRecorder.trackChanges(in: valuesFromRequest, fetchAlongside: fetchAlongside)
            optionalValuesFromSQLChangesRecorder.trackChanges(in: optionalValuesFromSQL, fetchAlongside: fetchAlongside)
            optionalValuesFromRequestChangesRecorder.trackChanges(in: optionalValuesFromRequest, fetchAlongside: fetchAlongside)
            rowsFromSQLChangesRecorder.trackChanges(in: rowsFromSQL, fetchAlongside: fetchAlongside)
            rowsFromRequestChangesRecorder.trackChanges(in: rowsFromRequest, fetchAlongside: fetchAlongside)
            recordsFromSQLChangesRecorder.trackChanges(in: recordsFromSQL, fetchAlongside: fetchAlongside)
            recordsFromRequestChangesRecorder.trackChanges(in: recordsFromRequest, fetchAlongside: fetchAlongside)
            
            try valuesFromSQL.fetch()
            try valuesFromRequest.fetch()
            try optionalValuesFromSQL.fetch()
            try optionalValuesFromRequest.fetch()
            try rowsFromSQL.fetch()
            try rowsFromRequest.fetch()
            try recordsFromSQL.fetch()
            try recordsFromRequest.fetch()
            
            // change the value that is fetched alongside
            try dbPool.writeInTransaction { db in
                try db.execute("INSERT INTO table1 (id, name) VALUES (?, ?)", arguments: [1, "a"])
                return .commit
            }
            
            valuesFromSQLChangesRecorder.expectation = expectation(description: "valuesFromSQL")
            valuesFromRequestChangesRecorder.expectation = expectation(description: "valuesFromRequest")
            optionalValuesFromSQLChangesRecorder.expectation = expectation(description: "optionalValuesFromSQL")
            optionalValuesFromRequestChangesRecorder.expectation = expectation(description: "optionalValuesFromRequest")
            rowsFromSQLChangesRecorder.expectation = expectation(description: "rowsFromSQL")
            rowsFromRequestChangesRecorder.expectation = expectation(description: "rowsFromRequest")
            recordsFromSQLChangesRecorder.expectation = expectation(description: "recordsFromSQL")
            recordsFromRequestChangesRecorder.expectation = expectation(description: "recordsFromRequest")
            waitForExpectations(timeout: 1, handler: nil)
            
            XCTAssertEqual(valuesFromSQLChangesRecorder.fetchedAlongsideAfterChanges, 1)
            XCTAssertEqual(valuesFromRequestChangesRecorder.fetchedAlongsideAfterChanges, 1)
            XCTAssertEqual(optionalValuesFromSQLChangesRecorder.fetchedAlongsideAfterChanges, 1)
            XCTAssertEqual(optionalValuesFromRequestChangesRecorder.fetchedAlongsideAfterChanges, 1)
            XCTAssertEqual(rowsFromSQLChangesRecorder.fetchedAlongsideAfterChanges, 1)
            XCTAssertEqual(rowsFromRequestChangesRecorder.fetchedAlongsideAfterChanges, 1)
            XCTAssertEqual(recordsFromSQLChangesRecorder.fetchedAlongsideAfterChanges, 1)
            XCTAssertEqual(recordsFromRequestChangesRecorder.fetchedAlongsideAfterChanges, 1)
            
            // change the value that is fetched alongside
            try dbPool.writeInTransaction { db in
                try db.execute("INSERT INTO table1 (id, name) VALUES (?, ?)", arguments: [2, "b"])
                return .commit
            }
            
            valuesFromSQLChangesRecorder.expectation = expectation(description: "valuesFromSQL")
            valuesFromRequestChangesRecorder.expectation = expectation(description: "valuesFromRequest")
            optionalValuesFromSQLChangesRecorder.expectation = expectation(description: "optionalValuesFromSQL")
            optionalValuesFromRequestChangesRecorder.expectation = expectation(description: "optionalValuesFromRequest")
            rowsFromSQLChangesRecorder.expectation = expectation(description: "rowsFromSQL")
            rowsFromRequestChangesRecorder.expectation = expectation(description: "rowsFromRequest")
            recordsFromSQLChangesRecorder.expectation = expectation(description: "recordsFromSQL")
            recordsFromRequestChangesRecorder.expectation = expectation(description: "recordsFromRequest")
            waitForExpectations(timeout: 1, handler: nil)
            
            XCTAssertEqual(valuesFromSQLChangesRecorder.fetchedAlongsideAfterChanges, 2)
            XCTAssertEqual(valuesFromRequestChangesRecorder.fetchedAlongsideAfterChanges, 2)
            XCTAssertEqual(optionalValuesFromSQLChangesRecorder.fetchedAlongsideAfterChanges, 2)
            XCTAssertEqual(optionalValuesFromRequestChangesRecorder.fetchedAlongsideAfterChanges, 2)
            XCTAssertEqual(rowsFromSQLChangesRecorder.fetchedAlongsideAfterChanges, 2)
            XCTAssertEqual(rowsFromRequestChangesRecorder.fetchedAlongsideAfterChanges, 2)
            XCTAssertEqual(recordsFromSQLChangesRecorder.fetchedAlongsideAfterChanges, 2)
            XCTAssertEqual(recordsFromRequestChangesRecorder.fetchedAlongsideAfterChanges, 2)
        }
    }
    
    func testTrackChangesWithTrailingClosure() {
        assertNoError {
            let dbPool = try makeDatabasePool()
            try dbPool.write { db in
                try db.create(table: "table1") { t in
                    t.column("id", .integer).primaryKey()
                    t.column("name", .text)
                }
                try db.execute("INSERT INTO table1 (id, name) VALUES (?, ?)", arguments: [1, "a"])
                try db.execute("INSERT INTO table1 (id, name) VALUES (?, ?)", arguments: [2, "b"])
            }
            
            let sql = "SELECT name, id FROM table1 ORDER BY id"
            let sqlRequest = SQLRequest(sql)
            
            let valuesFromSQL = try FetchedCollection<String>(dbPool, sql: sql)
            let valuesFromRequest = try FetchedCollection(dbPool, request: sqlRequest.bound(to: String.self))
            let optionalValuesFromSQL = try FetchedCollection<String?>(dbPool, sql: sql)
            let optionalValuesFromRequest = try FetchedCollection(dbPool, request: sqlRequest.bound(to: Optional<String>.self))
            let rowsFromSQL = try FetchedCollection<Row>(dbPool, sql: sql)
            let rowsFromRequest = try FetchedCollection(dbPool, request: sqlRequest.bound(to: Row.self))
            let recordsFromSQL = try FetchedCollection<AnyRowConvertible>(dbPool, sql: sql)
            let recordsFromRequest = try FetchedCollection(dbPool, request: sqlRequest.bound(to: AnyRowConvertible.self))
            
            let valuesFromSQLChangesRecorder = ChangesRecorder<String, Void>()
            let valuesFromRequestChangesRecorder = ChangesRecorder<String, Void>()
            let optionalValuesFromSQLChangesRecorder = ChangesRecorder<String?, Void>()
            let optionalValuesFromRequestChangesRecorder = ChangesRecorder<String?, Void>()
            let rowsFromSQLChangesRecorder = ChangesRecorder<Row, Void>()
            let rowsFromRequestChangesRecorder = ChangesRecorder<Row, Void>()
            let recordsFromSQLChangesRecorder = ChangesRecorder<AnyRowConvertible, Void>()
            let recordsFromRequestChangesRecorder = ChangesRecorder<AnyRowConvertible, Void>()
            
            func trackChangesWithTrailingClosure<Fetched>(in collection: FetchedCollection<Fetched>, with recorder: ChangesRecorder<Fetched, Void>) {
                collection.trackChanges { collection in recorder.collectionDidChange(collection) }
            }
            trackChangesWithTrailingClosure(in: valuesFromSQL, with: valuesFromSQLChangesRecorder)
            trackChangesWithTrailingClosure(in: valuesFromRequest, with: valuesFromRequestChangesRecorder)
            trackChangesWithTrailingClosure(in: optionalValuesFromSQL, with: optionalValuesFromSQLChangesRecorder)
            trackChangesWithTrailingClosure(in: optionalValuesFromRequest, with: optionalValuesFromRequestChangesRecorder)
            trackChangesWithTrailingClosure(in: rowsFromSQL, with: rowsFromSQLChangesRecorder)
            trackChangesWithTrailingClosure(in: rowsFromRequest, with: rowsFromRequestChangesRecorder)
            trackChangesWithTrailingClosure(in: recordsFromSQL, with: recordsFromSQLChangesRecorder)
            trackChangesWithTrailingClosure(in: recordsFromRequest, with: recordsFromRequestChangesRecorder)
            
            try valuesFromSQL.fetch()
            try valuesFromRequest.fetch()
            try optionalValuesFromSQL.fetch()
            try optionalValuesFromRequest.fetch()
            try rowsFromSQL.fetch()
            try rowsFromRequest.fetch()
            try recordsFromSQL.fetch()
            try recordsFromRequest.fetch()
            
            // transaction
            try dbPool.writeInTransaction { db in
                try db.execute("DELETE FROM table1")
                try db.execute("INSERT INTO table1 (id, name) VALUES (?, ?)", arguments: [3, "c"])
                try db.execute("INSERT INTO table1 (id, name) VALUES (?, ?)", arguments: [4, "d"])
                return .commit
            }
            
            valuesFromSQLChangesRecorder.expectation = expectation(description: "valuesFromSQL")
            valuesFromRequestChangesRecorder.expectation = expectation(description: "valuesFromRequest")
            optionalValuesFromSQLChangesRecorder.expectation = expectation(description: "optionalValuesFromSQL")
            optionalValuesFromRequestChangesRecorder.expectation = expectation(description: "optionalValuesFromRequest")
            rowsFromSQLChangesRecorder.expectation = expectation(description: "rowsFromSQL")
            rowsFromRequestChangesRecorder.expectation = expectation(description: "rowsFromRequest")
            recordsFromSQLChangesRecorder.expectation = expectation(description: "recordsFromSQL")
            recordsFromRequestChangesRecorder.expectation = expectation(description: "recordsFromRequest")
            waitForExpectations(timeout: 1, handler: nil)
            
            do {
                let expectedRows: [Row] = [["name": "c", "id": 3], ["name": "d", "id": 4]]
                XCTAssertEqual(valuesFromSQLChangesRecorder.elementsAfterChanges, expectedRows.map { $0.value(atIndex: 0) })
                XCTAssertEqual(valuesFromRequestChangesRecorder.elementsAfterChanges, expectedRows.map { $0.value(atIndex: 0) })
                XCTAssertEqual(optionalValuesFromSQLChangesRecorder.elementsAfterChanges.map { $0! }, expectedRows.map { $0.value(atIndex: 0) })
                XCTAssertEqual(optionalValuesFromRequestChangesRecorder.elementsAfterChanges.map { $0! }, expectedRows.map { $0.value(atIndex: 0) })
                XCTAssertEqual(rowsFromSQLChangesRecorder.elementsAfterChanges, expectedRows)
                XCTAssertEqual(rowsFromRequestChangesRecorder.elementsAfterChanges, expectedRows)
                XCTAssertEqual(recordsFromSQLChangesRecorder.elementsAfterChanges, expectedRows.map { AnyRowConvertible(row: $0) })
                XCTAssertEqual(recordsFromRequestChangesRecorder.elementsAfterChanges, expectedRows.map { AnyRowConvertible(row: $0) })
            }
        }
    }
    
}
