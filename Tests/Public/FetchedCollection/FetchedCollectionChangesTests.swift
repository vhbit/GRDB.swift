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
    var fetchedAlongsideBeforeChanges: T?
    var fetchedAlongsideAfterChanges: T?
    
    func reset() {
        elementsBeforeChanges = nil
        elementsAfterChanges = nil
        fetchedAlongsideBeforeChanges = nil
        fetchedAlongsideAfterChanges = nil
    }
    
    func collectionWillChange(_ collection: FetchedCollection<Fetched>, fetchedAlongside: T) {
        elementsBeforeChanges = Array(collection)
        fetchedAlongsideBeforeChanges = fetchedAlongside
    }
    
    /// The default implementation does nothing.
    func collectionDidChange(_ collection: FetchedCollection<Fetched>, fetchedAlongside: T) {
        elementsAfterChanges = Array(collection)
        fetchedAlongsideAfterChanges = fetchedAlongside
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
            
            let valuesFromSQLExpection = expectation(description: "valuesFromSQL")
            let valuesFromRequestExpection = expectation(description: "valuesFromRequest")
            let optionalValuesFromSQLExpection = expectation(description: "optionalValuesFromSQL")
            let optionalValuesFromRequestExpection = expectation(description: "optionalValuesFromRequest")
            let rowsFromSQLExpection = expectation(description: "rowsFromSQL")
            let rowsFromRequestExpection = expectation(description: "rowsFromRequest")
            let recordsFromSQLExpection = expectation(description: "recordsFromSQL")
            let recordsFromRequestExpection = expectation(description: "recordsFromRequest")
            
            func trackChanges<T>(in collection: FetchedCollection<T>, with recorder: ChangesRecorder<T, Void>, expectation: XCTestExpectation) {
                collection.trackChanges(
                    willChange: { collection in
                        recorder.collectionWillChange(collection, fetchedAlongside: ()) },
                    didChange: { collection in
                        recorder.collectionDidChange(collection, fetchedAlongside: ())
                        expectation.fulfill() })
            }
            trackChanges(in: valuesFromSQL, with: valuesFromSQLChangesRecorder, expectation: valuesFromSQLExpection)
            trackChanges(in: valuesFromRequest, with: valuesFromRequestChangesRecorder, expectation: valuesFromRequestExpection)
            trackChanges(in: optionalValuesFromSQL, with: optionalValuesFromSQLChangesRecorder, expectation: optionalValuesFromSQLExpection)
            trackChanges(in: optionalValuesFromRequest, with: optionalValuesFromRequestChangesRecorder, expectation: optionalValuesFromRequestExpection)
            trackChanges(in: rowsFromSQL, with: rowsFromSQLChangesRecorder, expectation: rowsFromSQLExpection)
            trackChanges(in: rowsFromRequest, with: rowsFromRequestChangesRecorder, expectation: rowsFromRequestExpection)
            trackChanges(in: recordsFromSQL, with: recordsFromSQLChangesRecorder, expectation: recordsFromSQLExpection)
            trackChanges(in: recordsFromRequest, with: recordsFromRequestChangesRecorder, expectation: recordsFromRequestExpection)
            
            try valuesFromSQL.fetch()
            try valuesFromRequest.fetch()
            try optionalValuesFromSQL.fetch()
            try optionalValuesFromRequest.fetch()
            try rowsFromSQL.fetch()
            try rowsFromRequest.fetch()
            try recordsFromSQL.fetch()
            try recordsFromRequest.fetch()
            
            // setRequest
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
            
            let valuesFromSQLExpection = expectation(description: "valuesFromSQL")
            let valuesFromRequestExpection = expectation(description: "valuesFromRequest")
            let optionalValuesFromSQLExpection = expectation(description: "optionalValuesFromSQL")
            let optionalValuesFromRequestExpection = expectation(description: "optionalValuesFromRequest")
            let rowsFromSQLExpection = expectation(description: "rowsFromSQL")
            let rowsFromRequestExpection = expectation(description: "rowsFromRequest")
            let recordsFromSQLExpection = expectation(description: "recordsFromSQL")
            let recordsFromRequestExpection = expectation(description: "recordsFromRequest")
            
            func trackChanges<T>(in collection: FetchedCollection<T>, with recorder: ChangesRecorder<T, Void>, expectation: XCTestExpectation) {
                collection.trackChanges(
                    willChange: { collection in
                        recorder.collectionWillChange(collection, fetchedAlongside: ()) },
                    didChange: { collection in
                        recorder.collectionDidChange(collection, fetchedAlongside: ())
                        expectation.fulfill() })
            }
            trackChanges(in: valuesFromSQL, with: valuesFromSQLChangesRecorder, expectation: valuesFromSQLExpection)
            trackChanges(in: valuesFromRequest, with: valuesFromRequestChangesRecorder, expectation: valuesFromRequestExpection)
            trackChanges(in: optionalValuesFromSQL, with: optionalValuesFromSQLChangesRecorder, expectation: optionalValuesFromSQLExpection)
            trackChanges(in: optionalValuesFromRequest, with: optionalValuesFromRequestChangesRecorder, expectation: optionalValuesFromRequestExpection)
            trackChanges(in: rowsFromSQL, with: rowsFromSQLChangesRecorder, expectation: rowsFromSQLExpection)
            trackChanges(in: rowsFromRequest, with: rowsFromRequestChangesRecorder, expectation: rowsFromRequestExpection)
            trackChanges(in: recordsFromSQL, with: recordsFromSQLChangesRecorder, expectation: recordsFromSQLExpection)
            trackChanges(in: recordsFromRequest, with: recordsFromRequestChangesRecorder, expectation: recordsFromRequestExpection)
            
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
}
