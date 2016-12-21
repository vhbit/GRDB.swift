#if os(iOS)
    
    import XCTest
    #if USING_SQLCIPHER
        import GRDBCipher
    #elseif USING_CUSTOMSQLITE
        import GRDBCustomSQLite
    #else
        import GRDB
    #endif
    
    private struct AnyRowConvertible: RowConvertible, Equatable {
        let row: Row
        
        init(row: Row) {
            self.row = row.copy()
        }
        
        static func == (lhs: AnyRowConvertible, rhs: AnyRowConvertible) -> Bool {
            return lhs.row == rhs.row
        }
    }
    
    class FetchedCollectionTestsiOS : GRDBTestCase {
        
        func testSectionAsCollection() {
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
                let recordsFromSQL = try FetchedCollection<AnyRowConvertible>(dbPool, sql: sql, arguments: arguments)
                let recordsFromRequest = try FetchedCollection(dbPool, request: sqlRequest.bound(to: AnyRowConvertible.self))
                
                try valuesFromSQL.fetch()
                try valuesFromRequest.fetch()
                try optionalValuesFromSQL.fetch()
                try optionalValuesFromRequest.fetch()
                try rowsFromSQL.fetch()
                try rowsFromRequest.fetch()
                try recordsFromSQL.fetch()
                try recordsFromRequest.fetch()
                
                XCTAssertEqual(valuesFromSQL.sections.count, 1)
                XCTAssertEqual(valuesFromRequest.sections.count, 1)
                XCTAssertEqual(optionalValuesFromSQL.sections.count, 1)
                XCTAssertEqual(optionalValuesFromRequest.sections.count, 1)
                XCTAssertEqual(rowsFromSQL.sections.count, 1)
                XCTAssertEqual(rowsFromRequest.sections.count, 1)
                XCTAssertEqual(recordsFromSQL.sections.count, 1)
                XCTAssertEqual(recordsFromRequest.sections.count, 1)
                
                let valuesFromSQLSection = valuesFromSQL.sections[0]
                let valuesFromRequestSection = valuesFromRequest.sections[0]
                let optionalValuesFromSQLSection = optionalValuesFromSQL.sections[0]
                let optionalValuesFromRequestSection = optionalValuesFromRequest.sections[0]
                let rowsFromSQLSection = rowsFromSQL.sections[0]
                let rowsFromRequestSection = rowsFromRequest.sections[0]
                let recordsFromSQLSection = recordsFromSQL.sections[0]
                let recordsFromRequestSection = recordsFromRequest.sections[0]
                
                XCTAssertFalse(valuesFromSQLSection.isEmpty)
                XCTAssertFalse(valuesFromRequestSection.isEmpty)
                XCTAssertFalse(optionalValuesFromSQLSection.isEmpty)
                XCTAssertFalse(optionalValuesFromRequestSection.isEmpty)
                XCTAssertFalse(rowsFromSQLSection.isEmpty)
                XCTAssertFalse(rowsFromRequestSection.isEmpty)
                XCTAssertFalse(recordsFromSQLSection.isEmpty)
                XCTAssertFalse(recordsFromRequestSection.isEmpty)
                
                XCTAssertEqual(valuesFromSQLSection.count, 2)
                XCTAssertEqual(valuesFromRequestSection.count, 2)
                XCTAssertEqual(optionalValuesFromSQLSection.count, 2)
                XCTAssertEqual(optionalValuesFromRequestSection.count, 2)
                XCTAssertEqual(rowsFromSQLSection.count, 2)
                XCTAssertEqual(rowsFromRequestSection.count, 2)
                XCTAssertEqual(recordsFromSQLSection.count, 2)
                XCTAssertEqual(recordsFromRequestSection.count, 2)
                
                XCTAssertEqual(valuesFromSQLSection.startIndex, 0)
                XCTAssertEqual(valuesFromRequestSection.startIndex, 0)
                XCTAssertEqual(optionalValuesFromSQLSection.startIndex, 0)
                XCTAssertEqual(optionalValuesFromRequestSection.startIndex, 0)
                XCTAssertEqual(rowsFromSQLSection.startIndex, 0)
                XCTAssertEqual(rowsFromRequestSection.startIndex, 0)
                XCTAssertEqual(recordsFromSQLSection.startIndex, 0)
                XCTAssertEqual(recordsFromRequestSection.startIndex, 0)
                
                XCTAssertEqual(valuesFromSQLSection.endIndex, 2)
                XCTAssertEqual(valuesFromRequestSection.endIndex, 2)
                XCTAssertEqual(optionalValuesFromSQLSection.endIndex, 2)
                XCTAssertEqual(optionalValuesFromRequestSection.endIndex, 2)
                XCTAssertEqual(rowsFromSQLSection.endIndex, 2)
                XCTAssertEqual(rowsFromRequestSection.endIndex, 2)
                XCTAssertEqual(recordsFromSQLSection.endIndex, 2)
                XCTAssertEqual(recordsFromRequestSection.endIndex, 2)
                
                XCTAssertEqual(valuesFromSQLSection[0], "a")
                XCTAssertEqual(valuesFromRequestSection[0], "a")
                XCTAssertEqual(optionalValuesFromSQLSection[0], "a")
                XCTAssertEqual(optionalValuesFromRequestSection[0], "a")
                XCTAssertEqual(rowsFromSQLSection[0], ["name": "a", "id": 1])
                XCTAssertEqual(rowsFromRequestSection[0], ["name": "a", "id": 1])
                XCTAssertEqual(recordsFromSQLSection[0], AnyRowConvertible(row: ["name": "a", "id": 1]))
                XCTAssertEqual(recordsFromRequestSection[0], AnyRowConvertible(row: ["name": "a", "id": 1]))
                
                XCTAssertEqual(valuesFromSQLSection[1], "b")
                XCTAssertEqual(valuesFromRequestSection[1], "b")
                XCTAssertEqual(optionalValuesFromSQLSection[1], "b")
                XCTAssertEqual(optionalValuesFromRequestSection[1], "b")
                XCTAssertEqual(rowsFromSQLSection[1], ["name": "b", "id": 2])
                XCTAssertEqual(rowsFromRequestSection[1], ["name": "b", "id": 2])
                XCTAssertEqual(recordsFromSQLSection[1], AnyRowConvertible(row: ["name": "b", "id": 2]))
                XCTAssertEqual(recordsFromRequestSection[1], AnyRowConvertible(row: ["name": "b", "id": 2]))
                
                XCTAssertEqual(Array(valuesFromSQLSection.reversed()), ["b", "a"])
                XCTAssertEqual(Array(valuesFromRequestSection.reversed()), ["b", "a"])
                XCTAssertEqual(Array(optionalValuesFromSQLSection.reversed()).map { $0! }, ["b", "a"])
                XCTAssertEqual(Array(optionalValuesFromRequestSection.reversed()).map { $0! }, ["b", "a"])
                XCTAssertEqual(Array(rowsFromSQLSection.reversed()), [["name": "b", "id": 2], ["name": "a", "id": 1]])
                XCTAssertEqual(Array(rowsFromRequestSection.reversed()), [["name": "b", "id": 2], ["name": "a", "id": 1]])
                XCTAssertEqual(Array(recordsFromSQLSection.reversed()), [AnyRowConvertible(row: ["name": "b", "id": 2]), AnyRowConvertible(row: ["name": "a", "id": 1])])
                XCTAssertEqual(Array(recordsFromRequestSection.reversed()), [AnyRowConvertible(row: ["name": "b", "id": 2]), AnyRowConvertible(row: ["name": "a", "id": 1])])
            }
        }
        
        func testEmptySection() {
            assertNoError {
                let dbPool = try makeDatabasePool()
                let sql = "SELECT 'ignored' WHERE 0"
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
                
                // Just like NSFetchedResultsCollection
                XCTAssertEqual(valuesFromSQL.sections.count, 1)
                XCTAssertEqual(valuesFromRequest.sections.count, 1)
                XCTAssertEqual(optionalValuesFromSQL.sections.count, 1)
                XCTAssertEqual(optionalValuesFromRequest.sections.count, 1)
                XCTAssertEqual(rowsFromSQL.sections.count, 1)
                XCTAssertEqual(rowsFromRequest.sections.count, 1)
                XCTAssertEqual(recordsFromSQL.sections.count, 1)
                XCTAssertEqual(recordsFromRequest.sections.count, 1)
                
                let valuesFromSQLSection = valuesFromSQL.sections[0]
                let valuesFromRequestSection = valuesFromRequest.sections[0]
                let optionalValuesFromSQLSection = optionalValuesFromSQL.sections[0]
                let optionalValuesFromRequestSection = optionalValuesFromRequest.sections[0]
                let rowsFromSQLSection = rowsFromSQL.sections[0]
                let rowsFromRequestSection = rowsFromRequest.sections[0]
                let recordsFromSQLSection = recordsFromSQL.sections[0]
                let recordsFromRequestSection = recordsFromRequest.sections[0]
                
                XCTAssertTrue(valuesFromSQLSection.isEmpty)
                XCTAssertTrue(valuesFromRequestSection.isEmpty)
                XCTAssertTrue(optionalValuesFromSQLSection.isEmpty)
                XCTAssertTrue(optionalValuesFromRequestSection.isEmpty)
                XCTAssertTrue(rowsFromSQLSection.isEmpty)
                XCTAssertTrue(rowsFromRequestSection.isEmpty)
                XCTAssertTrue(recordsFromSQLSection.isEmpty)
                XCTAssertTrue(recordsFromRequestSection.isEmpty)
                
                XCTAssertEqual(valuesFromSQLSection.count, 0)
                XCTAssertEqual(valuesFromRequestSection.count, 0)
                XCTAssertEqual(optionalValuesFromSQLSection.count, 0)
                XCTAssertEqual(optionalValuesFromRequestSection.count, 0)
                XCTAssertEqual(rowsFromSQLSection.count, 0)
                XCTAssertEqual(rowsFromRequestSection.count, 0)
                XCTAssertEqual(recordsFromSQLSection.count, 0)
                XCTAssertEqual(recordsFromRequestSection.count, 0)
                
                XCTAssertEqual(valuesFromSQLSection.startIndex, 0)
                XCTAssertEqual(valuesFromRequestSection.startIndex, 0)
                XCTAssertEqual(optionalValuesFromSQLSection.startIndex, 0)
                XCTAssertEqual(optionalValuesFromRequestSection.startIndex, 0)
                XCTAssertEqual(rowsFromSQLSection.startIndex, 0)
                XCTAssertEqual(rowsFromRequestSection.startIndex, 0)
                XCTAssertEqual(recordsFromSQLSection.startIndex, 0)
                XCTAssertEqual(recordsFromRequestSection.startIndex, 0)
                
                XCTAssertEqual(valuesFromSQLSection.endIndex, 0)
                XCTAssertEqual(valuesFromRequestSection.endIndex, 0)
                XCTAssertEqual(optionalValuesFromSQLSection.endIndex, 0)
                XCTAssertEqual(optionalValuesFromRequestSection.endIndex, 0)
                XCTAssertEqual(rowsFromSQLSection.endIndex, 0)
                XCTAssertEqual(rowsFromRequestSection.endIndex, 0)
                XCTAssertEqual(recordsFromSQLSection.endIndex, 0)
                XCTAssertEqual(recordsFromRequestSection.endIndex, 0)
            }
        }
    }
#endif
