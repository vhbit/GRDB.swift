import XCTest
#if USING_SQLCIPHER
    import GRDBCipher
#elseif USING_CUSTOMSQLITE
    import GRDBCustomSQLite
#else
    import GRDB
#endif

struct AnyRecord: RowConvertible, Equatable {
    let row: Row
    
    init(row: Row) {
        self.row = row.copy()
    }
    
    static func == (lhs: AnyRecord, rhs: AnyRecord) -> Bool {
        return lhs.row == rhs.row
    }
}

class FetchedCollectionTests : GRDBTestCase {
    
    func testFetchedCollectionFetch() {
        assertNoError {
            let dbPool = try makeDatabasePool()
            let sql = "SELECT ? AS name, ? AS id UNION ALL SELECT ?, ?"
            let arguments: StatementArguments = ["a", 1, "b", 2]
            let sqlRequest = SQLRequest(sql, arguments: arguments)
            
            let valuesFromSQL = try FetchedCollection<String>(dbPool, sql: sql, arguments: arguments)
            let valuesFromRequest = try FetchedCollection(dbPool, request: sqlRequest.bound(to: String.self))
            let optionalValuesFromSQL = try FetchedCollection<String?>(dbPool, sql: sql, arguments: arguments)
            let optionalValuesFromRequest = try FetchedCollection(dbPool, request: sqlRequest.bound(to: Optional<String>.self))
            let rowsFromSQL = try FetchedCollection<Row>(dbPool, sql: sql, arguments: arguments)
            let rowsFromRequest = try FetchedCollection(dbPool, request: sqlRequest.bound(to: Row.self))
            let recordsFromSQL = try FetchedCollection<AnyRecord>(dbPool, sql: sql, arguments: arguments)
            let recordsFromRequest = try FetchedCollection(dbPool, request: sqlRequest.bound(to: AnyRecord.self))
            
            try valuesFromSQL.fetch()
            try valuesFromRequest.fetch()
            try optionalValuesFromSQL.fetch()
            try optionalValuesFromRequest.fetch()
            try rowsFromSQL.fetch()
            try rowsFromRequest.fetch()
            try recordsFromSQL.fetch()
            try recordsFromRequest.fetch()
            
            XCTAssertEqual(Array(valuesFromSQL), ["a", "b"])
            XCTAssertEqual(Array(valuesFromRequest), ["a", "b"])
            XCTAssertEqual(Array(optionalValuesFromSQL).map { $0! }, ["a", "b"])
            XCTAssertEqual(Array(optionalValuesFromRequest).map { $0! }, ["a", "b"])
            XCTAssertEqual(Array(rowsFromSQL), [["name": "a", "id": 1], ["name": "b", "id": 2]])
            XCTAssertEqual(Array(rowsFromRequest), [["name": "a", "id": 1], ["name": "b", "id": 2]])
            XCTAssertEqual(Array(recordsFromSQL), [AnyRecord(row: ["name": "a", "id": 1]), AnyRecord(row: ["name": "b", "id": 2])])
            XCTAssertEqual(Array(recordsFromRequest), [AnyRecord(row: ["name": "a", "id": 1]), AnyRecord(row: ["name": "b", "id": 2])])
        }
    }
    
    func testFetchedCollectionAsCollection() {
        assertNoError {
            let dbPool = try makeDatabasePool()
            let sql = "SELECT ? AS name, ? AS id UNION ALL SELECT ?, ?"
            let arguments: StatementArguments = ["a", 1, "b", 2]
            let sqlRequest = SQLRequest(sql, arguments: arguments)
            
            let valuesFromSQL = try FetchedCollection<String>(dbPool, sql: sql, arguments: arguments)
            let valuesFromRequest = try FetchedCollection(dbPool, request: sqlRequest.bound(to: String.self))
            let optionalValuesFromSQL = try FetchedCollection<String?>(dbPool, sql: sql, arguments: arguments)
            let optionalValuesFromRequest = try FetchedCollection(dbPool, request: sqlRequest.bound(to: Optional<String>.self))
            let rowsFromSQL = try FetchedCollection<Row>(dbPool, sql: sql, arguments: arguments)
            let rowsFromRequest = try FetchedCollection(dbPool, request: sqlRequest.bound(to: Row.self))
            let recordsFromSQL = try FetchedCollection<AnyRecord>(dbPool, sql: sql, arguments: arguments)
            let recordsFromRequest = try FetchedCollection(dbPool, request: sqlRequest.bound(to: AnyRecord.self))
            
            try valuesFromSQL.fetch()
            try valuesFromRequest.fetch()
            try optionalValuesFromSQL.fetch()
            try optionalValuesFromRequest.fetch()
            try rowsFromSQL.fetch()
            try rowsFromRequest.fetch()
            try recordsFromSQL.fetch()
            try recordsFromRequest.fetch()
            
            XCTAssertEqual(valuesFromSQL.count, 2)
            XCTAssertEqual(valuesFromRequest.count, 2)
            XCTAssertEqual(optionalValuesFromSQL.count, 2)
            XCTAssertEqual(optionalValuesFromRequest.count, 2)
            XCTAssertEqual(rowsFromSQL.count, 2)
            XCTAssertEqual(rowsFromRequest.count, 2)
            XCTAssertEqual(recordsFromSQL.count, 2)
            XCTAssertEqual(recordsFromRequest.count, 2)
            
            XCTAssertEqual(valuesFromSQL.startIndex, 0)
            XCTAssertEqual(valuesFromRequest.startIndex, 0)
            XCTAssertEqual(optionalValuesFromSQL.startIndex, 0)
            XCTAssertEqual(optionalValuesFromRequest.startIndex, 0)
            XCTAssertEqual(rowsFromSQL.startIndex, 0)
            XCTAssertEqual(rowsFromRequest.startIndex, 0)
            XCTAssertEqual(recordsFromSQL.startIndex, 0)
            XCTAssertEqual(recordsFromRequest.startIndex, 0)
            
            XCTAssertEqual(valuesFromSQL.endIndex, 2)
            XCTAssertEqual(valuesFromRequest.endIndex, 2)
            XCTAssertEqual(optionalValuesFromSQL.endIndex, 2)
            XCTAssertEqual(optionalValuesFromRequest.endIndex, 2)
            XCTAssertEqual(rowsFromSQL.endIndex, 2)
            XCTAssertEqual(rowsFromRequest.endIndex, 2)
            XCTAssertEqual(recordsFromSQL.endIndex, 2)
            XCTAssertEqual(recordsFromRequest.endIndex, 2)
            
            XCTAssertEqual(valuesFromSQL[0], "a")
            XCTAssertEqual(valuesFromRequest[0], "a")
            XCTAssertEqual(optionalValuesFromSQL[0], "a")
            XCTAssertEqual(optionalValuesFromRequest[0], "a")
            XCTAssertEqual(rowsFromSQL[0], ["name": "a", "id": 1])
            XCTAssertEqual(rowsFromRequest[0], ["name": "a", "id": 1])
            XCTAssertEqual(recordsFromSQL[0], AnyRecord(row: ["name": "a", "id": 1]))
            XCTAssertEqual(recordsFromRequest[0], AnyRecord(row: ["name": "a", "id": 1]))
            
            XCTAssertEqual(valuesFromSQL[1], "b")
            XCTAssertEqual(valuesFromRequest[1], "b")
            XCTAssertEqual(optionalValuesFromSQL[1], "b")
            XCTAssertEqual(optionalValuesFromRequest[1], "b")
            XCTAssertEqual(rowsFromSQL[1], ["name": "b", "id": 2])
            XCTAssertEqual(rowsFromRequest[1], ["name": "b", "id": 2])
            XCTAssertEqual(recordsFromSQL[1], AnyRecord(row: ["name": "b", "id": 2]))
            XCTAssertEqual(recordsFromRequest[1], AnyRecord(row: ["name": "b", "id": 2]))
            
            XCTAssertEqual(Array(valuesFromSQL.reversed()), ["b", "a"])
            XCTAssertEqual(Array(valuesFromRequest.reversed()), ["b", "a"])
            XCTAssertEqual(Array(optionalValuesFromSQL.reversed()).map { $0! }, ["b", "a"])
            XCTAssertEqual(Array(optionalValuesFromRequest.reversed()).map { $0! }, ["b", "a"])
            XCTAssertEqual(Array(rowsFromSQL.reversed()), [["name": "b", "id": 2], ["name": "a", "id": 1]])
            XCTAssertEqual(Array(rowsFromRequest.reversed()), [["name": "b", "id": 2], ["name": "a", "id": 1]])
            XCTAssertEqual(Array(recordsFromSQL.reversed()), [AnyRecord(row: ["name": "b", "id": 2]), AnyRecord(row: ["name": "a", "id": 1])])
            XCTAssertEqual(Array(recordsFromRequest.reversed()), [AnyRecord(row: ["name": "b", "id": 2]), AnyRecord(row: ["name": "a", "id": 1])])
        }
    }
    
    func testFetchedCollectionSetRequestCanBeCalledBeforeFetch() {
        assertNoError {
            let dbPool = try makeDatabasePool()
            let sql1 = "SELECT ?"
            let arguments1: StatementArguments = [nil]
            let sqlRequest1 = SQLRequest(sql1, arguments: arguments1)
            
            let valuesFromSQL = try FetchedCollection<String>(dbPool, sql: sql1, arguments: arguments1)
            let valuesFromRequest = try FetchedCollection(dbPool, request: sqlRequest1.bound(to: String.self))
            let optionalValuesFromSQL = try FetchedCollection<String?>(dbPool, sql: sql1, arguments: arguments1)
            let optionalValuesFromRequest = try FetchedCollection(dbPool, request: sqlRequest1.bound(to: Optional<String>.self))
            let rowsFromSQL = try FetchedCollection<Row>(dbPool, sql: sql1, arguments: arguments1)
            let rowsFromRequest = try FetchedCollection(dbPool, request: sqlRequest1.bound(to: Row.self))
            let recordsFromSQL = try FetchedCollection<AnyRecord>(dbPool, sql: sql1, arguments: arguments1)
            let recordsFromRequest = try FetchedCollection(dbPool, request: sqlRequest1.bound(to: AnyRecord.self))
            
            // setRequest before fetching
            let sql2 = "SELECT ? AS name, ? AS id UNION ALL SELECT ?, ?"
            let arguments2: StatementArguments = ["a", 1, "b", 2]
            let sqlRequest2 = SQLRequest(sql2, arguments: arguments2)
            
            try valuesFromSQL.setRequest(sql: sql2, arguments: arguments2)
            try valuesFromRequest.setRequest(sqlRequest2.bound(to: String.self))
            try optionalValuesFromSQL.setRequest(sql: sql2, arguments: arguments2)
            try optionalValuesFromRequest.setRequest(sqlRequest2.bound(to: Optional<String>.self))
            try rowsFromSQL.setRequest(sql: sql2, arguments: arguments2)
            try rowsFromRequest.setRequest(sqlRequest2.bound(to: Row.self))
            try recordsFromSQL.setRequest(sql: sql2, arguments: arguments2)
            try recordsFromRequest.setRequest(sqlRequest2.bound(to: AnyRecord.self))
            
            try valuesFromSQL.fetch()
            try valuesFromRequest.fetch()
            try optionalValuesFromSQL.fetch()
            try optionalValuesFromRequest.fetch()
            try rowsFromSQL.fetch()
            try rowsFromRequest.fetch()
            try recordsFromSQL.fetch()
            try recordsFromRequest.fetch()
            
            // collection contains values from request 2
            XCTAssertEqual(Array(valuesFromSQL), ["a", "b"])
            XCTAssertEqual(Array(valuesFromRequest), ["a", "b"])
            XCTAssertEqual(Array(optionalValuesFromSQL).map { $0! }, ["a", "b"])
            XCTAssertEqual(Array(optionalValuesFromRequest).map { $0! }, ["a", "b"])
            XCTAssertEqual(Array(rowsFromSQL), [["name": "a", "id": 1], ["name": "b", "id": 2]])
            XCTAssertEqual(Array(rowsFromRequest), [["name": "a", "id": 1], ["name": "b", "id": 2]])
            XCTAssertEqual(Array(recordsFromSQL), [AnyRecord(row: ["name": "a", "id": 1]), AnyRecord(row: ["name": "b", "id": 2])])
            XCTAssertEqual(Array(recordsFromRequest), [AnyRecord(row: ["name": "a", "id": 1]), AnyRecord(row: ["name": "b", "id": 2])])
        }
    }
    
    func testFetchedCollectionSetRequestDoesNotUpdateContentsButFetchDoes() {
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
            let recordsFromSQL = try FetchedCollection<AnyRecord>(dbPool, sql: sql1, arguments: arguments1)
            let recordsFromRequest = try FetchedCollection(dbPool, request: sqlRequest1.bound(to: AnyRecord.self))
            
            try valuesFromSQL.fetch()
            try valuesFromRequest.fetch()
            try optionalValuesFromSQL.fetch()
            try optionalValuesFromRequest.fetch()
            try rowsFromSQL.fetch()
            try rowsFromRequest.fetch()
            try recordsFromSQL.fetch()
            try recordsFromRequest.fetch()
            
            // setRequest after fetching
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
            try recordsFromRequest.setRequest(sqlRequest2.bound(to: AnyRecord.self))
            
            // collection still contains values from request 1
            XCTAssertEqual(Array(valuesFromSQL), ["a", "b"])
            XCTAssertEqual(Array(valuesFromRequest), ["a", "b"])
            XCTAssertEqual(Array(optionalValuesFromSQL).map { $0! }, ["a", "b"])
            XCTAssertEqual(Array(optionalValuesFromRequest).map { $0! }, ["a", "b"])
            XCTAssertEqual(Array(rowsFromSQL), [["name": "a", "id": 1], ["name": "b", "id": 2]])
            XCTAssertEqual(Array(rowsFromRequest), [["name": "a", "id": 1], ["name": "b", "id": 2]])
            XCTAssertEqual(Array(recordsFromSQL), [AnyRecord(row: ["name": "a", "id": 1]), AnyRecord(row: ["name": "b", "id": 2])])
            XCTAssertEqual(Array(recordsFromRequest), [AnyRecord(row: ["name": "a", "id": 1]), AnyRecord(row: ["name": "b", "id": 2])])
            
            // fetch
            try valuesFromSQL.fetch()
            try valuesFromRequest.fetch()
            try optionalValuesFromSQL.fetch()
            try optionalValuesFromRequest.fetch()
            try rowsFromSQL.fetch()
            try rowsFromRequest.fetch()
            try recordsFromSQL.fetch()
            try recordsFromRequest.fetch()
            
            // collection now contains values from request 2
            XCTAssertEqual(Array(valuesFromSQL), ["c", "d"])
            XCTAssertEqual(Array(valuesFromRequest), ["c", "d"])
            XCTAssertEqual(Array(optionalValuesFromSQL).map { $0! }, ["c", "d"])
            XCTAssertEqual(Array(optionalValuesFromRequest).map { $0! }, ["c", "d"])
            XCTAssertEqual(Array(rowsFromSQL), [["name": "c", "id": 3], ["name": "d", "id": 4]])
            XCTAssertEqual(Array(rowsFromRequest), [["name": "c", "id": 3], ["name": "d", "id": 4]])
            XCTAssertEqual(Array(recordsFromSQL), [AnyRecord(row: ["name": "c", "id": 3]), AnyRecord(row: ["name": "d", "id": 4])])
            XCTAssertEqual(Array(recordsFromRequest), [AnyRecord(row: ["name": "c", "id": 3]), AnyRecord(row: ["name": "d", "id": 4])])
       }
    }
}
