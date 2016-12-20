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
    var expectation: XCTestExpectation? {
        didSet {
            elementsBeforeChanges = nil
            elementsAfterChanges = nil
            fetchedAlongsideAfterChanges = nil
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
            let sql2 = "SELECT ? AS name, ? AS id UNION ALL SELECT ?, ?"
            let arguments2: StatementArguments = ["c", 3, "d", 4]
            let sqlRequest2 = SQLRequest(sql2, arguments: arguments2)
            
            try valuesFromSQL.setRequest(sql: sql2, arguments: arguments2)
            try valuesFromRequest.setRequest(sqlRequest2.bound(to: String.self))
            try optionalValuesFromSQL.setRequest(sql: sql2, arguments: arguments2)
            try optionalValuesFromRequest.setRequest(sqlRequest2.bound(to: Optional<String>.self))
            try rowsFromSQL.setRequest(sql: sql2, arguments: arguments2)
            try rowsFromRequest.setRequest(sqlRequest2.bound(to: Row.self))
            try recordsFromSQL.setRequest(sql: sql2, arguments: arguments2)
            try recordsFromRequest.setRequest(sqlRequest2.bound(to: AnyRowConvertible.self))
            
            // collection still contains initial values
            XCTAssertEqual(Array(valuesFromSQL), ["a", "b"])
            XCTAssertEqual(Array(valuesFromRequest), ["a", "b"])
            XCTAssertEqual(Array(optionalValuesFromSQL).map { $0! }, ["a", "b"])
            XCTAssertEqual(Array(optionalValuesFromRequest).map { $0! }, ["a", "b"])
            XCTAssertEqual(Array(rowsFromSQL), [["name": "a", "id": 1], ["name": "b", "id": 2]])
            XCTAssertEqual(Array(rowsFromRequest), [["name": "a", "id": 1], ["name": "b", "id": 2]])
            XCTAssertEqual(Array(recordsFromSQL), [AnyRowConvertible(row: ["name": "a", "id": 1]), AnyRowConvertible(row: ["name": "b", "id": 2])])
            XCTAssertEqual(Array(recordsFromRequest), [AnyRowConvertible(row: ["name": "a", "id": 1]), AnyRowConvertible(row: ["name": "b", "id": 2])])
            
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
            XCTAssertEqual(Array(valuesFromSQL), ["c", "d"])
            XCTAssertEqual(Array(valuesFromRequest), ["c", "d"])
            XCTAssertEqual(Array(optionalValuesFromSQL).map { $0! }, ["c", "d"])
            XCTAssertEqual(Array(optionalValuesFromRequest).map { $0! }, ["c", "d"])
            XCTAssertEqual(Array(rowsFromSQL), [["name": "c", "id": 3], ["name": "d", "id": 4]])
            XCTAssertEqual(Array(rowsFromRequest), [["name": "c", "id": 3], ["name": "d", "id": 4]])
            XCTAssertEqual(Array(recordsFromSQL), [AnyRowConvertible(row: ["name": "c", "id": 3]), AnyRowConvertible(row: ["name": "d", "id": 4])])
            XCTAssertEqual(Array(recordsFromRequest), [AnyRowConvertible(row: ["name": "c", "id": 3]), AnyRowConvertible(row: ["name": "d", "id": 4])])
            
            XCTAssertEqual(valuesFromSQLChangesRecorder.elementsBeforeChanges, ["a", "b"])
            XCTAssertEqual(valuesFromRequestChangesRecorder.elementsBeforeChanges, ["a", "b"])
            XCTAssertEqual(optionalValuesFromSQLChangesRecorder.elementsBeforeChanges.map { $0! }, ["a", "b"])
            XCTAssertEqual(optionalValuesFromRequestChangesRecorder.elementsBeforeChanges.map { $0! }, ["a", "b"])
            XCTAssertEqual(rowsFromSQLChangesRecorder.elementsBeforeChanges, [["name": "a", "id": 1], ["name": "b", "id": 2]])
            XCTAssertEqual(rowsFromRequestChangesRecorder.elementsBeforeChanges, [["name": "a", "id": 1], ["name": "b", "id": 2]])
            XCTAssertEqual(recordsFromSQLChangesRecorder.elementsBeforeChanges, [AnyRowConvertible(row: ["name": "a", "id": 1]), AnyRowConvertible(row: ["name": "b", "id": 2])])
            XCTAssertEqual(recordsFromRequestChangesRecorder.elementsBeforeChanges, [AnyRowConvertible(row: ["name": "a", "id": 1]), AnyRowConvertible(row: ["name": "b", "id": 2])])
            
            XCTAssertEqual(valuesFromSQLChangesRecorder.elementsAfterChanges, ["c", "d"])
            XCTAssertEqual(valuesFromRequestChangesRecorder.elementsAfterChanges, ["c", "d"])
            XCTAssertEqual(optionalValuesFromSQLChangesRecorder.elementsAfterChanges.map { $0! }, ["c", "d"])
            XCTAssertEqual(optionalValuesFromRequestChangesRecorder.elementsAfterChanges.map { $0! }, ["c", "d"])
            XCTAssertEqual(rowsFromSQLChangesRecorder.elementsAfterChanges, [["name": "c", "id": 3], ["name": "d", "id": 4]])
            XCTAssertEqual(rowsFromRequestChangesRecorder.elementsAfterChanges, [["name": "c", "id": 3], ["name": "d", "id": 4]])
            XCTAssertEqual(recordsFromSQLChangesRecorder.elementsAfterChanges, [AnyRowConvertible(row: ["name": "c", "id": 3]), AnyRowConvertible(row: ["name": "d", "id": 4])])
            XCTAssertEqual(recordsFromRequestChangesRecorder.elementsAfterChanges, [AnyRowConvertible(row: ["name": "c", "id": 3]), AnyRowConvertible(row: ["name": "d", "id": 4])])
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
            
            // transaction
            try dbPool.writeInTransaction { db in
                try db.execute("DELETE FROM table1")
                try db.execute("INSERT INTO table1 (id, name) VALUES (?, ?)", arguments: [3, "c"])
                try db.execute("INSERT INTO table1 (id, name) VALUES (?, ?)", arguments: [4, "d"])
                return .commit
            }
            
            // collection still contains initial values
            XCTAssertEqual(Array(valuesFromSQL), ["a", "b"])
            XCTAssertEqual(Array(valuesFromRequest), ["a", "b"])
            XCTAssertEqual(Array(optionalValuesFromSQL).map { $0! }, ["a", "b"])
            XCTAssertEqual(Array(optionalValuesFromRequest).map { $0! }, ["a", "b"])
            XCTAssertEqual(Array(rowsFromSQL), [["name": "a", "id": 1], ["name": "b", "id": 2]])
            XCTAssertEqual(Array(rowsFromRequest), [["name": "a", "id": 1], ["name": "b", "id": 2]])
            XCTAssertEqual(Array(recordsFromSQL), [AnyRowConvertible(row: ["name": "a", "id": 1]), AnyRowConvertible(row: ["name": "b", "id": 2])])
            XCTAssertEqual(Array(recordsFromRequest), [AnyRowConvertible(row: ["name": "a", "id": 1]), AnyRowConvertible(row: ["name": "b", "id": 2])])
            
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
            XCTAssertEqual(Array(valuesFromSQL), ["c", "d"])
            XCTAssertEqual(Array(valuesFromRequest), ["c", "d"])
            XCTAssertEqual(Array(optionalValuesFromSQL).map { $0! }, ["c", "d"])
            XCTAssertEqual(Array(optionalValuesFromRequest).map { $0! }, ["c", "d"])
            XCTAssertEqual(Array(rowsFromSQL), [["name": "c", "id": 3], ["name": "d", "id": 4]])
            XCTAssertEqual(Array(rowsFromRequest), [["name": "c", "id": 3], ["name": "d", "id": 4]])
            XCTAssertEqual(Array(recordsFromSQL), [AnyRowConvertible(row: ["name": "c", "id": 3]), AnyRowConvertible(row: ["name": "d", "id": 4])])
            XCTAssertEqual(Array(recordsFromRequest), [AnyRowConvertible(row: ["name": "c", "id": 3]), AnyRowConvertible(row: ["name": "d", "id": 4])])
            
            XCTAssertEqual(valuesFromSQLChangesRecorder.elementsBeforeChanges, ["a", "b"])
            XCTAssertEqual(valuesFromRequestChangesRecorder.elementsBeforeChanges, ["a", "b"])
            XCTAssertEqual(optionalValuesFromSQLChangesRecorder.elementsBeforeChanges.map { $0! }, ["a", "b"])
            XCTAssertEqual(optionalValuesFromRequestChangesRecorder.elementsBeforeChanges.map { $0! }, ["a", "b"])
            XCTAssertEqual(rowsFromSQLChangesRecorder.elementsBeforeChanges, [["name": "a", "id": 1], ["name": "b", "id": 2]])
            XCTAssertEqual(rowsFromRequestChangesRecorder.elementsBeforeChanges, [["name": "a", "id": 1], ["name": "b", "id": 2]])
            XCTAssertEqual(recordsFromSQLChangesRecorder.elementsBeforeChanges, [AnyRowConvertible(row: ["name": "a", "id": 1]), AnyRowConvertible(row: ["name": "b", "id": 2])])
            XCTAssertEqual(recordsFromRequestChangesRecorder.elementsBeforeChanges, [AnyRowConvertible(row: ["name": "a", "id": 1]), AnyRowConvertible(row: ["name": "b", "id": 2])])
            
            XCTAssertEqual(valuesFromSQLChangesRecorder.elementsAfterChanges, ["c", "d"])
            XCTAssertEqual(valuesFromRequestChangesRecorder.elementsAfterChanges, ["c", "d"])
            XCTAssertEqual(optionalValuesFromSQLChangesRecorder.elementsAfterChanges.map { $0! }, ["c", "d"])
            XCTAssertEqual(optionalValuesFromRequestChangesRecorder.elementsAfterChanges.map { $0! }, ["c", "d"])
            XCTAssertEqual(rowsFromSQLChangesRecorder.elementsAfterChanges, [["name": "c", "id": 3], ["name": "d", "id": 4]])
            XCTAssertEqual(rowsFromRequestChangesRecorder.elementsAfterChanges, [["name": "c", "id": 3], ["name": "d", "id": 4]])
            XCTAssertEqual(recordsFromSQLChangesRecorder.elementsAfterChanges, [AnyRowConvertible(row: ["name": "c", "id": 3]), AnyRowConvertible(row: ["name": "d", "id": 4])])
            XCTAssertEqual(recordsFromRequestChangesRecorder.elementsAfterChanges, [AnyRowConvertible(row: ["name": "c", "id": 3]), AnyRowConvertible(row: ["name": "d", "id": 4])])
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
            XCTAssertEqual(Array(valuesFromSQL), ["a", "b"])
            XCTAssertEqual(Array(valuesFromRequest), ["a", "b"])
            XCTAssertEqual(Array(optionalValuesFromSQL).map { $0! }, ["a", "b"])
            XCTAssertEqual(Array(optionalValuesFromRequest).map { $0! }, ["a", "b"])
            XCTAssertEqual(Array(rowsFromSQL), [["name": "a", "id": 1], ["name": "b", "id": 2]])
            XCTAssertEqual(Array(rowsFromRequest), [["name": "a", "id": 1], ["name": "b", "id": 2]])
            XCTAssertEqual(Array(recordsFromSQL), [AnyRowConvertible(row: ["name": "a", "id": 1]), AnyRowConvertible(row: ["name": "b", "id": 2])])
            XCTAssertEqual(Array(recordsFromRequest), [AnyRowConvertible(row: ["name": "a", "id": 1]), AnyRowConvertible(row: ["name": "b", "id": 2])])
            
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
            XCTAssertEqual(Array(valuesFromSQL), ["b", "c"])
            XCTAssertEqual(Array(valuesFromRequest), ["b", "c"])
            XCTAssertEqual(Array(optionalValuesFromSQL).map { $0! }, ["b", "c"])
            XCTAssertEqual(Array(optionalValuesFromRequest).map { $0! }, ["b", "c"])
            XCTAssertEqual(Array(rowsFromSQL), [["name": "b", "id": 2], ["name": "c", "id": 3]])
            XCTAssertEqual(Array(rowsFromRequest), [["name": "b", "id": 2], ["name": "c", "id": 3]])
            XCTAssertEqual(Array(recordsFromSQL), [AnyRowConvertible(row: ["name": "b", "id": 2]), AnyRowConvertible(row: ["name": "c", "id": 3])])
            XCTAssertEqual(Array(recordsFromRequest), [AnyRowConvertible(row: ["name": "b", "id": 2]), AnyRowConvertible(row: ["name": "c", "id": 3])])
            
            XCTAssertEqual(valuesFromSQLChangesRecorder.elementsBeforeChanges, ["a", "b"])
            XCTAssertEqual(valuesFromRequestChangesRecorder.elementsBeforeChanges, ["a", "b"])
            XCTAssertEqual(optionalValuesFromSQLChangesRecorder.elementsBeforeChanges.map { $0! }, ["a", "b"])
            XCTAssertEqual(optionalValuesFromRequestChangesRecorder.elementsBeforeChanges.map { $0! }, ["a", "b"])
            XCTAssertEqual(rowsFromSQLChangesRecorder.elementsBeforeChanges, [["name": "a", "id": 1], ["name": "b", "id": 2]])
            XCTAssertEqual(rowsFromRequestChangesRecorder.elementsBeforeChanges, [["name": "a", "id": 1], ["name": "b", "id": 2]])
            XCTAssertEqual(recordsFromSQLChangesRecorder.elementsBeforeChanges, [AnyRowConvertible(row: ["name": "a", "id": 1]), AnyRowConvertible(row: ["name": "b", "id": 2])])
            XCTAssertEqual(recordsFromRequestChangesRecorder.elementsBeforeChanges, [AnyRowConvertible(row: ["name": "a", "id": 1]), AnyRowConvertible(row: ["name": "b", "id": 2])])
            
            XCTAssertEqual(valuesFromSQLChangesRecorder.elementsAfterChanges, ["b", "c"])
            XCTAssertEqual(valuesFromRequestChangesRecorder.elementsAfterChanges, ["b", "c"])
            XCTAssertEqual(optionalValuesFromSQLChangesRecorder.elementsAfterChanges.map { $0! }, ["b", "c"])
            XCTAssertEqual(optionalValuesFromRequestChangesRecorder.elementsAfterChanges.map { $0! }, ["b", "c"])
            XCTAssertEqual(rowsFromSQLChangesRecorder.elementsAfterChanges, [["name": "b", "id": 2], ["name": "c", "id": 3]])
            XCTAssertEqual(rowsFromRequestChangesRecorder.elementsAfterChanges, [["name": "b", "id": 2], ["name": "c", "id": 3]])
            XCTAssertEqual(recordsFromSQLChangesRecorder.elementsAfterChanges, [AnyRowConvertible(row: ["name": "b", "id": 2]), AnyRowConvertible(row: ["name": "c", "id": 3])])
            XCTAssertEqual(recordsFromRequestChangesRecorder.elementsAfterChanges, [AnyRowConvertible(row: ["name": "b", "id": 2]), AnyRowConvertible(row: ["name": "c", "id": 3])])
            
            // modify table2
            try dbPool.writeInTransaction { db in
                try db.execute("DELETE FROM table2")
                try db.execute("INSERT INTO table2 (id, name) VALUES (?, ?)", arguments: [4, "d"])
                return .commit
            }
            
            // collection still contains initial values
            XCTAssertEqual(Array(valuesFromSQL), ["b", "c"])
            XCTAssertEqual(Array(valuesFromRequest), ["b", "c"])
            XCTAssertEqual(Array(optionalValuesFromSQL).map { $0! }, ["b", "c"])
            XCTAssertEqual(Array(optionalValuesFromRequest).map { $0! }, ["b", "c"])
            XCTAssertEqual(Array(rowsFromSQL), [["name": "b", "id": 2], ["name": "c", "id": 3]])
            XCTAssertEqual(Array(rowsFromRequest), [["name": "b", "id": 2], ["name": "c", "id": 3]])
            XCTAssertEqual(Array(recordsFromSQL), [AnyRowConvertible(row: ["name": "b", "id": 2]), AnyRowConvertible(row: ["name": "c", "id": 3])])
            XCTAssertEqual(Array(recordsFromRequest), [AnyRowConvertible(row: ["name": "b", "id": 2]), AnyRowConvertible(row: ["name": "c", "id": 3])])
            
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
            XCTAssertEqual(Array(valuesFromSQL), ["c", "d"])
            XCTAssertEqual(Array(valuesFromRequest), ["c", "d"])
            XCTAssertEqual(Array(optionalValuesFromSQL).map { $0! }, ["c", "d"])
            XCTAssertEqual(Array(optionalValuesFromRequest).map { $0! }, ["c", "d"])
            XCTAssertEqual(Array(rowsFromSQL), [["name": "c", "id": 3], ["name": "d", "id": 4]])
            XCTAssertEqual(Array(rowsFromRequest), [["name": "c", "id": 3], ["name": "d", "id": 4]])
            XCTAssertEqual(Array(recordsFromSQL), [AnyRowConvertible(row: ["name": "c", "id": 3]), AnyRowConvertible(row: ["name": "d", "id": 4])])
            XCTAssertEqual(Array(recordsFromRequest), [AnyRowConvertible(row: ["name": "c", "id": 3]), AnyRowConvertible(row: ["name": "d", "id": 4])])
            
            XCTAssertEqual(valuesFromSQLChangesRecorder.elementsBeforeChanges, ["b", "c"])
            XCTAssertEqual(valuesFromRequestChangesRecorder.elementsBeforeChanges, ["b", "c"])
            XCTAssertEqual(optionalValuesFromSQLChangesRecorder.elementsBeforeChanges.map { $0! }, ["b", "c"])
            XCTAssertEqual(optionalValuesFromRequestChangesRecorder.elementsBeforeChanges.map { $0! }, ["b", "c"])
            XCTAssertEqual(rowsFromSQLChangesRecorder.elementsBeforeChanges, [["name": "b", "id": 2], ["name": "c", "id": 3]])
            XCTAssertEqual(rowsFromRequestChangesRecorder.elementsBeforeChanges, [["name": "b", "id": 2], ["name": "c", "id": 3]])
            XCTAssertEqual(recordsFromSQLChangesRecorder.elementsBeforeChanges, [AnyRowConvertible(row: ["name": "b", "id": 2]), AnyRowConvertible(row: ["name": "c", "id": 3])])
            XCTAssertEqual(recordsFromRequestChangesRecorder.elementsBeforeChanges, [AnyRowConvertible(row: ["name": "b", "id": 2]), AnyRowConvertible(row: ["name": "c", "id": 3])])
            
            XCTAssertEqual(valuesFromSQLChangesRecorder.elementsAfterChanges, ["c", "d"])
            XCTAssertEqual(valuesFromRequestChangesRecorder.elementsAfterChanges, ["c", "d"])
            XCTAssertEqual(optionalValuesFromSQLChangesRecorder.elementsAfterChanges.map { $0! }, ["c", "d"])
            XCTAssertEqual(optionalValuesFromRequestChangesRecorder.elementsAfterChanges.map { $0! }, ["c", "d"])
            XCTAssertEqual(rowsFromSQLChangesRecorder.elementsAfterChanges, [["name": "c", "id": 3], ["name": "d", "id": 4]])
            XCTAssertEqual(rowsFromRequestChangesRecorder.elementsAfterChanges, [["name": "c", "id": 3], ["name": "d", "id": 4]])
            XCTAssertEqual(recordsFromSQLChangesRecorder.elementsAfterChanges, [AnyRowConvertible(row: ["name": "c", "id": 3]), AnyRowConvertible(row: ["name": "d", "id": 4])])
            XCTAssertEqual(recordsFromRequestChangesRecorder.elementsAfterChanges, [AnyRowConvertible(row: ["name": "c", "id": 3]), AnyRowConvertible(row: ["name": "d", "id": 4])])
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
            XCTAssertEqual(Array(valuesFromSQL), ["b"])
            XCTAssertEqual(Array(valuesFromRequest), ["b"])
            XCTAssertEqual(Array(optionalValuesFromSQL).map { $0! }, ["b"])
            XCTAssertEqual(Array(optionalValuesFromRequest).map { $0! }, ["b"])
            XCTAssertEqual(Array(rowsFromSQL), [["name": "b", "id": 2]])
            XCTAssertEqual(Array(rowsFromRequest), [["name": "b", "id": 2]])
            XCTAssertEqual(Array(recordsFromSQL), [AnyRowConvertible(row: ["name": "b", "id": 2])])
            XCTAssertEqual(Array(recordsFromRequest), [AnyRowConvertible(row: ["name": "b", "id": 2])])
            
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
            XCTAssertEqual(Array(valuesFromSQL), ["b", "c"])
            XCTAssertEqual(Array(valuesFromRequest), ["b", "c"])
            XCTAssertEqual(Array(optionalValuesFromSQL).map { $0! }, ["b", "c"])
            XCTAssertEqual(Array(optionalValuesFromRequest).map { $0! }, ["b", "c"])
            XCTAssertEqual(Array(rowsFromSQL), [["name": "b", "id": 2], ["name": "c", "id": 3]])
            XCTAssertEqual(Array(rowsFromRequest), [["name": "b", "id": 2], ["name": "c", "id": 3]])
            XCTAssertEqual(Array(recordsFromSQL), [AnyRowConvertible(row: ["name": "b", "id": 2]), AnyRowConvertible(row: ["name": "c", "id": 3])])
            XCTAssertEqual(Array(recordsFromRequest), [AnyRowConvertible(row: ["name": "b", "id": 2]), AnyRowConvertible(row: ["name": "c", "id": 3])])
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
            
            // collection now contains new values
            XCTAssertEqual(valuesFromSQLChangesRecorder.elementsAfterChanges, ["c", "d"])
            XCTAssertEqual(valuesFromRequestChangesRecorder.elementsAfterChanges, ["c", "d"])
            XCTAssertEqual(optionalValuesFromSQLChangesRecorder.elementsAfterChanges.map { $0! }, ["c", "d"])
            XCTAssertEqual(optionalValuesFromRequestChangesRecorder.elementsAfterChanges.map { $0! }, ["c", "d"])
            XCTAssertEqual(rowsFromSQLChangesRecorder.elementsAfterChanges, [["name": "c", "id": 3], ["name": "d", "id": 4]])
            XCTAssertEqual(rowsFromRequestChangesRecorder.elementsAfterChanges, [["name": "c", "id": 3], ["name": "d", "id": 4]])
            XCTAssertEqual(recordsFromSQLChangesRecorder.elementsAfterChanges, [AnyRowConvertible(row: ["name": "c", "id": 3]), AnyRowConvertible(row: ["name": "d", "id": 4])])
            XCTAssertEqual(recordsFromRequestChangesRecorder.elementsAfterChanges, [AnyRowConvertible(row: ["name": "c", "id": 3]), AnyRowConvertible(row: ["name": "d", "id": 4])])
        }
    }
    
}
