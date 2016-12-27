#if os(iOS)
    
    import XCTest
    #if USING_SQLCIPHER
        import GRDBCipher
    #elseif USING_CUSTOMSQLITE
        import GRDBCustomSQLite
    #else
        import GRDB
    #endif
    
    extension FetchedCollectionChange : Equatable {
        public static func == (lhs: FetchedCollectionChange, rhs: FetchedCollectionChange) -> Bool {
            switch (lhs, rhs) {
            case (.insertion(let lIndexPath), .insertion(let rIndexPath)):
                return lIndexPath == rIndexPath
            case (.deletion(let lIndexPath), .deletion(let rIndexPath)):
                return lIndexPath == rIndexPath
            case (.move(let lIndexPath, let lNewIndexPath, let lChanges), .move(let rIndexPath, let rNewIndexPath, let rChanges)):
                return lIndexPath == rIndexPath && lNewIndexPath == rNewIndexPath && lChanges == rChanges
            case (.update(let lIndexPath, let lChanges), .update(let rIndexPath, let rChanges)):
                return lIndexPath == rIndexPath && lChanges == rChanges
            default:
                return false
            }
        }
    }
    
    private struct RecordedChange<Fetched> {
        let change: FetchedCollectionChange
        let value: Fetched
    }
    
    private func ==<Fetched>(lhs: [RecordedChange<Fetched>], rhs: [RecordedChange<Fetched>]) -> Bool where Fetched: Equatable {
        guard lhs.count == rhs.count else { return false }
        for (lhs, rhs) in zip(lhs, rhs) {
            if lhs.change != rhs.change { return false }
            if lhs.value != rhs.value { return false }
        }
        return true
    }
    
    private class ChangesRecorder<Fetched, T> {
        var elementsBeforeChanges: [Fetched]!
        var elementsAfterChanges: [Fetched]!
        var fetchedAlongsideAfterChanges: T?
        var changes: [RecordedChange<Fetched>] = []
        
        var expectation: XCTestExpectation? {
            didSet {
                elementsBeforeChanges = nil
                elementsAfterChanges = nil
                fetchedAlongsideAfterChanges = nil
                changes = []
            }
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
    
    extension ChangesRecorder where Fetched: Row {
        func trackChanges(in collection: FetchedCollection<Fetched>) {
            collection.trackChanges(
                willChange: { collection in self.collectionWillChange(collection) },
                onChange: { (collection, value, change) in self.changes.append(RecordedChange(change: change, value: value)) },
                didChange: { collection in self.collectionDidChange(collection) })
        }
        
        func trackChanges(in collection: FetchedCollection<Fetched>, fetchAlongside: @escaping (Database) throws -> T) {
            collection.trackChanges(
                fetchAlongside: fetchAlongside,
                willChange: { collection in self.collectionWillChange(collection) },
                onChange: { (collection, value, change) in self.changes.append(RecordedChange(change: change, value: value)) },
                didChange: { (collection, fetchedAlonside) in self.collectionDidChange(collection, fetchedAlongside: fetchedAlonside) })
        }
        
    }
    
    extension ChangesRecorder where Fetched: RowConvertible {
        func trackChanges(in collection: FetchedCollection<Fetched>) {
            collection.trackChanges(
                willChange: { collection in self.collectionWillChange(collection) },
                onChange: { (collection, value, change) in self.changes.append(RecordedChange(change: change, value: value)) },
                didChange: { collection in self.collectionDidChange(collection) })
        }
        
        func trackChanges(in collection: FetchedCollection<Fetched>, fetchAlongside: @escaping (Database) throws -> T) {
            collection.trackChanges(
                fetchAlongside: fetchAlongside,
                willChange: { collection in self.collectionWillChange(collection) },
                onChange: { (collection, value, change) in self.changes.append(RecordedChange(change: change, value: value)) },
                didChange: { (collection, fetchedAlonside) in self.collectionDidChange(collection, fetchedAlongside: fetchedAlonside) })
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
    
    private struct TableMappingWithIntegerPrimaryKey: RowConvertible, TableMapping, Equatable {
        let row: Row
        
        static let databaseTableName = "tableIntegerPrimaryKey"
        
        init(row: Row) {
            self.row = row.copy()
        }
        
        static func == (lhs: TableMappingWithIntegerPrimaryKey, rhs: TableMappingWithIntegerPrimaryKey) -> Bool {
            return lhs.row == rhs.row
        }
    }
    
    private struct TableMappingWithSingleColumnPrimaryKey: RowConvertible, TableMapping, Equatable {
        let row: Row
        
        static let databaseTableName = "tableSingleColumnPrimaryKey"
        
        init(row: Row) {
            self.row = row.copy()
        }
        
        static func == (lhs: TableMappingWithSingleColumnPrimaryKey, rhs: TableMappingWithSingleColumnPrimaryKey) -> Bool {
            return lhs.row == rhs.row
        }
    }
    
    private struct TableMappingWithCompoundPrimaryKey: RowConvertible, TableMapping, Equatable {
        let row: Row
        
        static let databaseTableName = "tableCompoundPrimaryKey"
        
        init(row: Row) {
            self.row = row.copy()
        }
        
        static func == (lhs: TableMappingWithCompoundPrimaryKey, rhs: TableMappingWithCompoundPrimaryKey) -> Bool {
            return lhs.row == rhs.row
        }
    }
    
    private struct TableMappingWithImplicitRowIDPrimaryKey: RowConvertible, TableMapping, Equatable {
        let row: Row
        
        static let databaseTableName = "tableImplicitRowIDPrimaryKey"
        
        init(row: Row) {
            self.row = row.copy()
        }
        
        static func == (lhs: TableMappingWithImplicitRowIDPrimaryKey, rhs: TableMappingWithImplicitRowIDPrimaryKey) -> Bool {
            return lhs.row == rhs.row
        }
    }
    
    class FetchedCollectionChangesTestsiOS: GRDBTestCase {
        
        func testSetRequestChanges() {
            assertNoError {
                let dbPool = try makeDatabasePool()
                let sql1 = "SELECT ? AS name, ? AS id UNION ALL SELECT ?, ?"
                let arguments1: StatementArguments = ["a", 1, "b", 2]
                let sqlRequest1 = SQLRequest(sql1, arguments: arguments1)
                
                let rowsFromSQL = try FetchedCollection<Row>(dbPool, sql: sql1, arguments: arguments1)
                let rowsFromRequest = try FetchedCollection(dbPool, request: sqlRequest1.bound(to: Row.self))
                let recordsFromSQL = try FetchedCollection<AnyRowConvertible>(dbPool, sql: sql1, arguments: arguments1)
                let recordsFromRequest = try FetchedCollection(dbPool, request: sqlRequest1.bound(to: AnyRowConvertible.self))
                
                let rowsFromSQLChangesRecorder = ChangesRecorder<Row, Void>()
                let rowsFromRequestChangesRecorder = ChangesRecorder<Row, Void>()
                let recordsFromSQLChangesRecorder = ChangesRecorder<AnyRowConvertible, Void>()
                let recordsFromRequestChangesRecorder = ChangesRecorder<AnyRowConvertible, Void>()
                
                rowsFromSQLChangesRecorder.trackChanges(in: rowsFromSQL)
                rowsFromRequestChangesRecorder.trackChanges(in: rowsFromRequest)
                recordsFromSQLChangesRecorder.trackChanges(in: recordsFromSQL)
                recordsFromRequestChangesRecorder.trackChanges(in: recordsFromRequest)
                
                try rowsFromSQL.fetch()
                try rowsFromRequest.fetch()
                try recordsFromSQL.fetch()
                try recordsFromRequest.fetch()
                
                // change request
                let sql2 = "SELECT NULL AS ignored, ? AS name, ? AS id UNION ALL SELECT NULL, ?, ?"
                let arguments2: StatementArguments = ["c", 3, "d", 4]
                let adapter2 = SuffixRowAdapter(fromIndex: 1)
                let sqlRequest2 = SQLRequest(sql2, arguments: arguments2, adapter: adapter2)
                
                try rowsFromSQL.setRequest(sql: sql2, arguments: arguments2, adapter: adapter2)
                try rowsFromRequest.setRequest(sqlRequest2.bound(to: Row.self))
                try recordsFromSQL.setRequest(sql: sql2, arguments: arguments2, adapter: adapter2)
                try recordsFromRequest.setRequest(sqlRequest2.bound(to: AnyRowConvertible.self))
                
                // collection still contains initial values
                do {
                    let expectedRows: [Row] = [["name": "a", "id": 1], ["name": "b", "id": 2]]
                    XCTAssertEqual(Array(rowsFromSQL), expectedRows)
                    XCTAssertEqual(Array(rowsFromRequest), expectedRows)
                    XCTAssertEqual(Array(recordsFromSQL), expectedRows.map { AnyRowConvertible(row: $0) })
                    XCTAssertEqual(Array(recordsFromRequest), expectedRows.map { AnyRowConvertible(row: $0) })
                }
                
                rowsFromSQLChangesRecorder.expectation = expectation(description: "rowsFromSQL")
                rowsFromRequestChangesRecorder.expectation = expectation(description: "rowsFromRequest")
                recordsFromSQLChangesRecorder.expectation = expectation(description: "recordsFromSQL")
                recordsFromRequestChangesRecorder.expectation = expectation(description: "recordsFromRequest")
                waitForExpectations(timeout: 1, handler: nil)
                
                // collection now contains new values
                do {
                    let expectedRows: [Row] = [["name": "c", "id": 3], ["name": "d", "id": 4]]
                    XCTAssertEqual(Array(rowsFromSQL), expectedRows)
                    XCTAssertEqual(Array(rowsFromRequest), expectedRows)
                    XCTAssertEqual(Array(recordsFromSQL), expectedRows.map { AnyRowConvertible(row: $0) })
                    XCTAssertEqual(Array(recordsFromRequest), expectedRows.map { AnyRowConvertible(row: $0) })
                }
                do {
                    let expectedRows: [Row] = [["name": "a", "id": 1], ["name": "b", "id": 2]]
                    XCTAssertEqual(rowsFromSQLChangesRecorder.elementsBeforeChanges, expectedRows)
                    XCTAssertEqual(rowsFromRequestChangesRecorder.elementsBeforeChanges, expectedRows)
                    XCTAssertEqual(recordsFromSQLChangesRecorder.elementsBeforeChanges, expectedRows.map { AnyRowConvertible(row: $0) })
                    XCTAssertEqual(recordsFromRequestChangesRecorder.elementsBeforeChanges, expectedRows.map { AnyRowConvertible(row: $0) })
                }
                do {
                    let expectedRows: [Row] = [["name": "c", "id": 3], ["name": "d", "id": 4]]
                    XCTAssertEqual(rowsFromSQLChangesRecorder.elementsAfterChanges, expectedRows)
                    XCTAssertEqual(rowsFromRequestChangesRecorder.elementsAfterChanges, expectedRows)
                    XCTAssertEqual(recordsFromSQLChangesRecorder.elementsAfterChanges, expectedRows.map { AnyRowConvertible(row: $0) })
                    XCTAssertEqual(recordsFromRequestChangesRecorder.elementsAfterChanges, expectedRows.map { AnyRowConvertible(row: $0) })
                }
                do {
                    XCTAssertTrue(rowsFromSQLChangesRecorder.changes == [
                        RecordedChange(change: .deletion(indexPath: IndexPath(row: 0, section: 0)), value: ["name": "a", "id": 1]),
                        RecordedChange(change: .insertion(indexPath: IndexPath(row: 0, section: 0)), value: ["name": "c", "id": 3]),
                        RecordedChange(change: .deletion(indexPath: IndexPath(row: 1, section: 0)), value: ["name": "b", "id": 2]),
                        RecordedChange(change: .insertion(indexPath: IndexPath(row: 1, section: 0)), value: ["name": "d", "id": 4])])
                    XCTAssertTrue(rowsFromRequestChangesRecorder.changes == [
                        RecordedChange(change: .deletion(indexPath: IndexPath(row: 0, section: 0)), value: ["name": "a", "id": 1]),
                        RecordedChange(change: .insertion(indexPath: IndexPath(row: 0, section: 0)), value: ["name": "c", "id": 3]),
                        RecordedChange(change: .deletion(indexPath: IndexPath(row: 1, section: 0)), value: ["name": "b", "id": 2]),
                        RecordedChange(change: .insertion(indexPath: IndexPath(row: 1, section: 0)), value: ["name": "d", "id": 4])])
                    XCTAssertTrue(recordsFromSQLChangesRecorder.changes == [
                        RecordedChange(change: .deletion(indexPath: IndexPath(row: 0, section: 0)), value: AnyRowConvertible(row: ["name": "a", "id": 1])),
                        RecordedChange(change: .insertion(indexPath: IndexPath(row: 0, section: 0)), value: AnyRowConvertible(row: ["name": "c", "id": 3])),
                        RecordedChange(change: .deletion(indexPath: IndexPath(row: 1, section: 0)), value: AnyRowConvertible(row: ["name": "b", "id": 2])),
                        RecordedChange(change: .insertion(indexPath: IndexPath(row: 1, section: 0)), value: AnyRowConvertible(row: ["name": "d", "id": 4]))])
                    XCTAssertTrue(recordsFromRequestChangesRecorder.changes == [
                        RecordedChange(change: .deletion(indexPath: IndexPath(row: 0, section: 0)), value: AnyRowConvertible(row: ["name": "a", "id": 1])),
                        RecordedChange(change: .insertion(indexPath: IndexPath(row: 0, section: 0)), value: AnyRowConvertible(row: ["name": "c", "id": 3])),
                        RecordedChange(change: .deletion(indexPath: IndexPath(row: 1, section: 0)), value: AnyRowConvertible(row: ["name": "b", "id": 2])),
                        RecordedChange(change: .insertion(indexPath: IndexPath(row: 1, section: 0)), value: AnyRowConvertible(row: ["name": "d", "id": 4]))])
                }
            }
        }
        
        func testTransactionChanges() {
            // Here we test delete, insert, update, and *also* that several
            // transactions can be chained and individually observed.
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
                
                let rowComparator = { (row1: Row, row2: Row) in
                    (row1.value(named: "id") as DatabaseValue) == (row2.value(named: "id") as DatabaseValue)
                }
                let rowsFromSQL = try FetchedCollection<Row>(dbPool, sql: sql)
                let rowsFromRequest = try FetchedCollection(dbPool, request: sqlRequest.bound(to: Row.self))
                let identifiedRowsFromSQL = try FetchedCollection<Row>(dbPool, sql: sql, isSameElement: rowComparator)
                let identifiedRowsFromRequest = try FetchedCollection(dbPool, request: sqlRequest.bound(to: Row.self), isSameElement: rowComparator)
                let recordsFromSQL = try FetchedCollection<AnyRowConvertible>(dbPool, sql: sql)
                let recordsFromRequest = try FetchedCollection(dbPool, request: sqlRequest.bound(to: AnyRowConvertible.self))
                let identifiedRecordsFromSQL = try FetchedCollection<AnyRowConvertible>(dbPool, sql: sql, isSameElement: { (record1, record2) in rowComparator(record1.row, record2.row) })
                let identifiedRecordsFromRequest = try FetchedCollection(dbPool, request: sqlRequest.bound(to: AnyRowConvertible.self), isSameElement: { (record1, record2) in rowComparator(record1.row, record2.row) })
                
                let rowsFromSQLChangesRecorder = ChangesRecorder<Row, Void>()
                let rowsFromRequestChangesRecorder = ChangesRecorder<Row, Void>()
                let identifiedRowsFromSQLChangesRecorder = ChangesRecorder<Row, Void>()
                let identifiedRowsFromRequestChangesRecorder = ChangesRecorder<Row, Void>()
                let recordsFromSQLChangesRecorder = ChangesRecorder<AnyRowConvertible, Void>()
                let recordsFromRequestChangesRecorder = ChangesRecorder<AnyRowConvertible, Void>()
                let identifiedRecordsFromSQLChangesRecorder = ChangesRecorder<AnyRowConvertible, Void>()
                let identifiedRecordsFromRequestChangesRecorder = ChangesRecorder<AnyRowConvertible, Void>()
                
                rowsFromSQLChangesRecorder.trackChanges(in: rowsFromSQL)
                rowsFromRequestChangesRecorder.trackChanges(in: rowsFromRequest)
                identifiedRowsFromSQLChangesRecorder.trackChanges(in: identifiedRowsFromSQL)
                identifiedRowsFromRequestChangesRecorder.trackChanges(in: identifiedRowsFromRequest)
                recordsFromSQLChangesRecorder.trackChanges(in: recordsFromSQL)
                recordsFromRequestChangesRecorder.trackChanges(in: recordsFromRequest)
                identifiedRecordsFromSQLChangesRecorder.trackChanges(in: identifiedRecordsFromSQL)
                identifiedRecordsFromRequestChangesRecorder.trackChanges(in: identifiedRecordsFromRequest)
                
                try rowsFromSQL.fetch()
                try rowsFromRequest.fetch()
                try identifiedRowsFromSQL.fetch()
                try identifiedRowsFromRequest.fetch()
                try recordsFromSQL.fetch()
                try recordsFromRequest.fetch()
                try identifiedRecordsFromSQL.fetch()
                try identifiedRecordsFromRequest.fetch()
                
                // transaction: delete
                try dbPool.writeInTransaction { db in
                    try db.execute("DELETE FROM table1")  // here we are also testing that truncate optimization doesn't break FetchedCollection
                    return .commit
                }
                
                // collection still contains initial values
                do {
                    let expectedRows: [Row] = [["name": "a", "id": 1], ["name": "b", "id": 2]]
                    XCTAssertEqual(Array(rowsFromSQL), expectedRows)
                    XCTAssertEqual(Array(rowsFromRequest), expectedRows)
                    XCTAssertEqual(Array(identifiedRowsFromSQL), expectedRows)
                    XCTAssertEqual(Array(identifiedRowsFromRequest), expectedRows)
                    XCTAssertEqual(Array(recordsFromSQL), expectedRows.map { AnyRowConvertible(row: $0) })
                    XCTAssertEqual(Array(recordsFromRequest), expectedRows.map { AnyRowConvertible(row: $0) })
                    XCTAssertEqual(Array(identifiedRecordsFromSQL), expectedRows.map { AnyRowConvertible(row: $0) })
                    XCTAssertEqual(Array(identifiedRecordsFromRequest), expectedRows.map { AnyRowConvertible(row: $0) })
                }
                
                rowsFromSQLChangesRecorder.expectation = expectation(description: "rowsFromSQL")
                rowsFromRequestChangesRecorder.expectation = expectation(description: "rowsFromRequest")
                identifiedRowsFromSQLChangesRecorder.expectation = expectation(description: "identifiedRowsFromSQL")
                identifiedRowsFromRequestChangesRecorder.expectation = expectation(description: "identifiedRowsFromRequest")
                recordsFromSQLChangesRecorder.expectation = expectation(description: "recordsFromSQL")
                recordsFromRequestChangesRecorder.expectation = expectation(description: "recordsFromRequest")
                identifiedRecordsFromSQLChangesRecorder.expectation = expectation(description: "identifiedRecordsFromSQL")
                identifiedRecordsFromRequestChangesRecorder.expectation = expectation(description: "identifiedRecordsFromRequest")
                waitForExpectations(timeout: 1, handler: nil)
                
                // collection now contains new values
                do {
                    let expectedRows: [Row] = []
                    XCTAssertEqual(Array(rowsFromSQL), expectedRows)
                    XCTAssertEqual(Array(rowsFromRequest), expectedRows)
                    XCTAssertEqual(Array(identifiedRowsFromSQL), expectedRows)
                    XCTAssertEqual(Array(identifiedRowsFromRequest), expectedRows)
                    XCTAssertEqual(Array(recordsFromSQL), expectedRows.map { AnyRowConvertible(row: $0) })
                    XCTAssertEqual(Array(recordsFromRequest), expectedRows.map { AnyRowConvertible(row: $0) })
                    XCTAssertEqual(Array(identifiedRecordsFromSQL), expectedRows.map { AnyRowConvertible(row: $0) })
                    XCTAssertEqual(Array(identifiedRecordsFromRequest), expectedRows.map { AnyRowConvertible(row: $0) })
                }
                do {
                    let expectedRows: [Row] = [["name": "a", "id": 1], ["name": "b", "id": 2]]
                    XCTAssertEqual(rowsFromSQLChangesRecorder.elementsBeforeChanges, expectedRows)
                    XCTAssertEqual(rowsFromRequestChangesRecorder.elementsBeforeChanges, expectedRows)
                    XCTAssertEqual(identifiedRowsFromSQLChangesRecorder.elementsBeforeChanges, expectedRows)
                    XCTAssertEqual(identifiedRowsFromRequestChangesRecorder.elementsBeforeChanges, expectedRows)
                    XCTAssertEqual(recordsFromSQLChangesRecorder.elementsBeforeChanges, expectedRows.map { AnyRowConvertible(row: $0) })
                    XCTAssertEqual(recordsFromRequestChangesRecorder.elementsBeforeChanges, expectedRows.map { AnyRowConvertible(row: $0) })
                    XCTAssertEqual(identifiedRecordsFromSQLChangesRecorder.elementsBeforeChanges, expectedRows.map { AnyRowConvertible(row: $0) })
                    XCTAssertEqual(identifiedRecordsFromRequestChangesRecorder.elementsBeforeChanges, expectedRows.map { AnyRowConvertible(row: $0) })
                }
                do {
                    let expectedRows: [Row] = []
                    XCTAssertEqual(rowsFromSQLChangesRecorder.elementsAfterChanges, expectedRows)
                    XCTAssertEqual(rowsFromRequestChangesRecorder.elementsAfterChanges, expectedRows)
                    XCTAssertEqual(identifiedRowsFromSQLChangesRecorder.elementsAfterChanges, expectedRows)
                    XCTAssertEqual(identifiedRowsFromRequestChangesRecorder.elementsAfterChanges, expectedRows)
                    XCTAssertEqual(recordsFromSQLChangesRecorder.elementsAfterChanges, expectedRows.map { AnyRowConvertible(row: $0) })
                    XCTAssertEqual(recordsFromRequestChangesRecorder.elementsAfterChanges, expectedRows.map { AnyRowConvertible(row: $0) })
                    XCTAssertEqual(identifiedRecordsFromSQLChangesRecorder.elementsAfterChanges, expectedRows.map { AnyRowConvertible(row: $0) })
                    XCTAssertEqual(identifiedRecordsFromRequestChangesRecorder.elementsAfterChanges, expectedRows.map { AnyRowConvertible(row: $0) })
                }
                do {
                    XCTAssertTrue(rowsFromSQLChangesRecorder.changes == [
                        RecordedChange(change: .deletion(indexPath: IndexPath(row: 0, section: 0)), value: ["name": "a", "id": 1]),
                        RecordedChange(change: .deletion(indexPath: IndexPath(row: 1, section: 0)), value: ["name": "b", "id": 2])])
                    XCTAssertTrue(rowsFromRequestChangesRecorder.changes == [
                        RecordedChange(change: .deletion(indexPath: IndexPath(row: 0, section: 0)), value: ["name": "a", "id": 1]),
                        RecordedChange(change: .deletion(indexPath: IndexPath(row: 1, section: 0)), value: ["name": "b", "id": 2])])
                    XCTAssertTrue(identifiedRowsFromSQLChangesRecorder.changes == [
                        RecordedChange(change: .deletion(indexPath: IndexPath(row: 0, section: 0)), value: ["name": "a", "id": 1]),
                        RecordedChange(change: .deletion(indexPath: IndexPath(row: 1, section: 0)), value: ["name": "b", "id": 2])])
                    XCTAssertTrue(identifiedRowsFromRequestChangesRecorder.changes == [
                        RecordedChange(change: .deletion(indexPath: IndexPath(row: 0, section: 0)), value: ["name": "a", "id": 1]),
                        RecordedChange(change: .deletion(indexPath: IndexPath(row: 1, section: 0)), value: ["name": "b", "id": 2])])
                    XCTAssertTrue(recordsFromSQLChangesRecorder.changes == [
                        RecordedChange(change: .deletion(indexPath: IndexPath(row: 0, section: 0)), value: AnyRowConvertible(row: ["name": "a", "id": 1])),
                        RecordedChange(change: .deletion(indexPath: IndexPath(row: 1, section: 0)), value: AnyRowConvertible(row: ["name": "b", "id": 2]))])
                    XCTAssertTrue(recordsFromRequestChangesRecorder.changes == [
                        RecordedChange(change: .deletion(indexPath: IndexPath(row: 0, section: 0)), value: AnyRowConvertible(row: ["name": "a", "id": 1])),
                        RecordedChange(change: .deletion(indexPath: IndexPath(row: 1, section: 0)), value: AnyRowConvertible(row: ["name": "b", "id": 2]))])
                    XCTAssertTrue(identifiedRecordsFromSQLChangesRecorder.changes == [
                        RecordedChange(change: .deletion(indexPath: IndexPath(row: 0, section: 0)), value: AnyRowConvertible(row: ["name": "a", "id": 1])),
                        RecordedChange(change: .deletion(indexPath: IndexPath(row: 1, section: 0)), value: AnyRowConvertible(row: ["name": "b", "id": 2]))])
                    XCTAssertTrue(identifiedRecordsFromRequestChangesRecorder.changes == [
                        RecordedChange(change: .deletion(indexPath: IndexPath(row: 0, section: 0)), value: AnyRowConvertible(row: ["name": "a", "id": 1])),
                        RecordedChange(change: .deletion(indexPath: IndexPath(row: 1, section: 0)), value: AnyRowConvertible(row: ["name": "b", "id": 2]))])
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
                    XCTAssertEqual(Array(rowsFromSQL), expectedRows)
                    XCTAssertEqual(Array(rowsFromRequest), expectedRows)
                    XCTAssertEqual(Array(identifiedRowsFromSQL), expectedRows)
                    XCTAssertEqual(Array(identifiedRowsFromRequest), expectedRows)
                    XCTAssertEqual(Array(recordsFromSQL), expectedRows.map { AnyRowConvertible(row: $0) })
                    XCTAssertEqual(Array(recordsFromRequest), expectedRows.map { AnyRowConvertible(row: $0) })
                    XCTAssertEqual(Array(identifiedRecordsFromSQL), expectedRows.map { AnyRowConvertible(row: $0) })
                    XCTAssertEqual(Array(identifiedRecordsFromRequest), expectedRows.map { AnyRowConvertible(row: $0) })
                }
                
                rowsFromSQLChangesRecorder.expectation = expectation(description: "rowsFromSQL")
                rowsFromRequestChangesRecorder.expectation = expectation(description: "rowsFromRequest")
                identifiedRowsFromSQLChangesRecorder.expectation = expectation(description: "identifiedRowsFromSQL")
                identifiedRowsFromRequestChangesRecorder.expectation = expectation(description: "identifiedRowsFromRequest")
                recordsFromSQLChangesRecorder.expectation = expectation(description: "recordsFromSQL")
                recordsFromRequestChangesRecorder.expectation = expectation(description: "recordsFromRequest")
                identifiedRecordsFromSQLChangesRecorder.expectation = expectation(description: "identifiedRecordsFromSQL")
                identifiedRecordsFromRequestChangesRecorder.expectation = expectation(description: "identifiedRecordsFromRequest")
                waitForExpectations(timeout: 1, handler: nil)
                
                // collection now contains new values
                do {
                    let expectedRows: [Row] = [["name": "c", "id": 3], ["name": "d", "id": 4]]
                    XCTAssertEqual(Array(rowsFromSQL), expectedRows)
                    XCTAssertEqual(Array(rowsFromRequest), expectedRows)
                    XCTAssertEqual(Array(identifiedRowsFromSQL), expectedRows)
                    XCTAssertEqual(Array(identifiedRowsFromRequest), expectedRows)
                    XCTAssertEqual(Array(recordsFromSQL), expectedRows.map { AnyRowConvertible(row: $0) })
                    XCTAssertEqual(Array(recordsFromRequest), expectedRows.map { AnyRowConvertible(row: $0) })
                    XCTAssertEqual(Array(identifiedRecordsFromSQL), expectedRows.map { AnyRowConvertible(row: $0) })
                    XCTAssertEqual(Array(identifiedRecordsFromRequest), expectedRows.map { AnyRowConvertible(row: $0) })
                }
                do {
                    let expectedRows: [Row] = []
                    XCTAssertEqual(rowsFromSQLChangesRecorder.elementsBeforeChanges, expectedRows)
                    XCTAssertEqual(rowsFromRequestChangesRecorder.elementsBeforeChanges, expectedRows)
                    XCTAssertEqual(identifiedRowsFromSQLChangesRecorder.elementsBeforeChanges, expectedRows)
                    XCTAssertEqual(identifiedRowsFromRequestChangesRecorder.elementsBeforeChanges, expectedRows)
                    XCTAssertEqual(recordsFromSQLChangesRecorder.elementsBeforeChanges, expectedRows.map { AnyRowConvertible(row: $0) })
                    XCTAssertEqual(recordsFromRequestChangesRecorder.elementsBeforeChanges, expectedRows.map { AnyRowConvertible(row: $0) })
                    XCTAssertEqual(identifiedRecordsFromSQLChangesRecorder.elementsBeforeChanges, expectedRows.map { AnyRowConvertible(row: $0) })
                    XCTAssertEqual(identifiedRecordsFromRequestChangesRecorder.elementsBeforeChanges, expectedRows.map { AnyRowConvertible(row: $0) })
                }
                do {
                    let expectedRows: [Row] = [["name": "c", "id": 3], ["name": "d", "id": 4]]
                    XCTAssertEqual(rowsFromSQLChangesRecorder.elementsAfterChanges, expectedRows)
                    XCTAssertEqual(rowsFromRequestChangesRecorder.elementsAfterChanges, expectedRows)
                    XCTAssertEqual(identifiedRowsFromSQLChangesRecorder.elementsAfterChanges, expectedRows)
                    XCTAssertEqual(identifiedRowsFromRequestChangesRecorder.elementsAfterChanges, expectedRows)
                    XCTAssertEqual(recordsFromSQLChangesRecorder.elementsAfterChanges, expectedRows.map { AnyRowConvertible(row: $0) })
                    XCTAssertEqual(recordsFromRequestChangesRecorder.elementsAfterChanges, expectedRows.map { AnyRowConvertible(row: $0) })
                    XCTAssertEqual(identifiedRecordsFromSQLChangesRecorder.elementsAfterChanges, expectedRows.map { AnyRowConvertible(row: $0) })
                    XCTAssertEqual(identifiedRecordsFromRequestChangesRecorder.elementsAfterChanges, expectedRows.map { AnyRowConvertible(row: $0) })
                }
                do {
                    XCTAssertTrue(rowsFromSQLChangesRecorder.changes == [
                        RecordedChange(change: .insertion(indexPath: IndexPath(row: 0, section: 0)), value: ["name": "c", "id": 3]),
                        RecordedChange(change: .insertion(indexPath: IndexPath(row: 1, section: 0)), value: ["name": "d", "id": 4])])
                    XCTAssertTrue(rowsFromRequestChangesRecorder.changes == [
                        RecordedChange(change: .insertion(indexPath: IndexPath(row: 0, section: 0)), value: ["name": "c", "id": 3]),
                        RecordedChange(change: .insertion(indexPath: IndexPath(row: 1, section: 0)), value: ["name": "d", "id": 4])])
                    XCTAssertTrue(identifiedRowsFromSQLChangesRecorder.changes == [
                        RecordedChange(change: .insertion(indexPath: IndexPath(row: 0, section: 0)), value: ["name": "c", "id": 3]),
                        RecordedChange(change: .insertion(indexPath: IndexPath(row: 1, section: 0)), value: ["name": "d", "id": 4])])
                    XCTAssertTrue(identifiedRowsFromRequestChangesRecorder.changes == [
                        RecordedChange(change: .insertion(indexPath: IndexPath(row: 0, section: 0)), value: ["name": "c", "id": 3]),
                        RecordedChange(change: .insertion(indexPath: IndexPath(row: 1, section: 0)), value: ["name": "d", "id": 4])])
                    XCTAssertTrue(recordsFromSQLChangesRecorder.changes == [
                        RecordedChange(change: .insertion(indexPath: IndexPath(row: 0, section: 0)), value: AnyRowConvertible(row: ["name": "c", "id": 3])),
                        RecordedChange(change: .insertion(indexPath: IndexPath(row: 1, section: 0)), value: AnyRowConvertible(row: ["name": "d", "id": 4]))])
                    XCTAssertTrue(recordsFromRequestChangesRecorder.changes == [
                        RecordedChange(change: .insertion(indexPath: IndexPath(row: 0, section: 0)), value: AnyRowConvertible(row: ["name": "c", "id": 3])),
                        RecordedChange(change: .insertion(indexPath: IndexPath(row: 1, section: 0)), value: AnyRowConvertible(row: ["name": "d", "id": 4]))])
                    XCTAssertTrue(identifiedRecordsFromSQLChangesRecorder.changes == [
                        RecordedChange(change: .insertion(indexPath: IndexPath(row: 0, section: 0)), value: AnyRowConvertible(row: ["name": "c", "id": 3])),
                        RecordedChange(change: .insertion(indexPath: IndexPath(row: 1, section: 0)), value: AnyRowConvertible(row: ["name": "d", "id": 4]))])
                    XCTAssertTrue(identifiedRecordsFromRequestChangesRecorder.changes == [
                        RecordedChange(change: .insertion(indexPath: IndexPath(row: 0, section: 0)), value: AnyRowConvertible(row: ["name": "c", "id": 3])),
                        RecordedChange(change: .insertion(indexPath: IndexPath(row: 1, section: 0)), value: AnyRowConvertible(row: ["name": "d", "id": 4]))])
                }
                
                // transaction: update
                try dbPool.writeInTransaction { db in
                    try db.execute("UPDATE table1 SET name = ? WHERE id = ?", arguments: ["e", 3])
                    return .commit
                }
                
                // collection still contains initial values
                do {
                    let expectedRows: [Row] = [["name": "c", "id": 3], ["name": "d", "id": 4]]
                    XCTAssertEqual(Array(rowsFromSQL), expectedRows)
                    XCTAssertEqual(Array(rowsFromRequest), expectedRows)
                    XCTAssertEqual(Array(identifiedRowsFromSQL), expectedRows)
                    XCTAssertEqual(Array(identifiedRowsFromRequest), expectedRows)
                    XCTAssertEqual(Array(recordsFromSQL), expectedRows.map { AnyRowConvertible(row: $0) })
                    XCTAssertEqual(Array(recordsFromRequest), expectedRows.map { AnyRowConvertible(row: $0) })
                    XCTAssertEqual(Array(identifiedRecordsFromSQL), expectedRows.map { AnyRowConvertible(row: $0) })
                    XCTAssertEqual(Array(identifiedRecordsFromRequest), expectedRows.map { AnyRowConvertible(row: $0) })
                }
                
                rowsFromSQLChangesRecorder.expectation = expectation(description: "rowsFromSQL")
                rowsFromRequestChangesRecorder.expectation = expectation(description: "rowsFromRequest")
                identifiedRowsFromSQLChangesRecorder.expectation = expectation(description: "identifiedRowsFromSQL")
                identifiedRowsFromRequestChangesRecorder.expectation = expectation(description: "identifiedRowsFromRequest")
                recordsFromSQLChangesRecorder.expectation = expectation(description: "recordsFromSQL")
                recordsFromRequestChangesRecorder.expectation = expectation(description: "recordsFromRequest")
                identifiedRecordsFromSQLChangesRecorder.expectation = expectation(description: "identifiedRecordsFromSQL")
                identifiedRecordsFromRequestChangesRecorder.expectation = expectation(description: "identifiedRecordsFromRequest")
                waitForExpectations(timeout: 1, handler: nil)
                
                // collection now contains new values
                do {
                    let expectedRows: [Row] = [["name": "e", "id": 3], ["name": "d", "id": 4]]
                    XCTAssertEqual(Array(rowsFromSQL), expectedRows)
                    XCTAssertEqual(Array(rowsFromRequest), expectedRows)
                    XCTAssertEqual(Array(identifiedRowsFromSQL), expectedRows)
                    XCTAssertEqual(Array(identifiedRowsFromRequest), expectedRows)
                    XCTAssertEqual(Array(recordsFromSQL), expectedRows.map { AnyRowConvertible(row: $0) })
                    XCTAssertEqual(Array(recordsFromRequest), expectedRows.map { AnyRowConvertible(row: $0) })
                    XCTAssertEqual(Array(identifiedRecordsFromSQL), expectedRows.map { AnyRowConvertible(row: $0) })
                    XCTAssertEqual(Array(identifiedRecordsFromRequest), expectedRows.map { AnyRowConvertible(row: $0) })
                }
                do {
                    let expectedRows: [Row] = [["name": "c", "id": 3], ["name": "d", "id": 4]]
                    XCTAssertEqual(rowsFromSQLChangesRecorder.elementsBeforeChanges, expectedRows)
                    XCTAssertEqual(rowsFromRequestChangesRecorder.elementsBeforeChanges, expectedRows)
                    XCTAssertEqual(identifiedRowsFromSQLChangesRecorder.elementsBeforeChanges, expectedRows)
                    XCTAssertEqual(identifiedRowsFromRequestChangesRecorder.elementsBeforeChanges, expectedRows)
                    XCTAssertEqual(recordsFromSQLChangesRecorder.elementsBeforeChanges, expectedRows.map { AnyRowConvertible(row: $0) })
                    XCTAssertEqual(recordsFromRequestChangesRecorder.elementsBeforeChanges, expectedRows.map { AnyRowConvertible(row: $0) })
                    XCTAssertEqual(identifiedRecordsFromSQLChangesRecorder.elementsBeforeChanges, expectedRows.map { AnyRowConvertible(row: $0) })
                    XCTAssertEqual(identifiedRecordsFromRequestChangesRecorder.elementsBeforeChanges, expectedRows.map { AnyRowConvertible(row: $0) })
                }
                do {
                    let expectedRows: [Row] = [["name": "e", "id": 3], ["name": "d", "id": 4]]
                    XCTAssertEqual(rowsFromSQLChangesRecorder.elementsAfterChanges, expectedRows)
                    XCTAssertEqual(rowsFromRequestChangesRecorder.elementsAfterChanges, expectedRows)
                    XCTAssertEqual(identifiedRowsFromSQLChangesRecorder.elementsAfterChanges, expectedRows)
                    XCTAssertEqual(identifiedRowsFromRequestChangesRecorder.elementsAfterChanges, expectedRows)
                    XCTAssertEqual(recordsFromSQLChangesRecorder.elementsAfterChanges, expectedRows.map { AnyRowConvertible(row: $0) })
                    XCTAssertEqual(recordsFromRequestChangesRecorder.elementsAfterChanges, expectedRows.map { AnyRowConvertible(row: $0) })
                    XCTAssertEqual(identifiedRecordsFromSQLChangesRecorder.elementsAfterChanges, expectedRows.map { AnyRowConvertible(row: $0) })
                    XCTAssertEqual(identifiedRecordsFromRequestChangesRecorder.elementsAfterChanges, expectedRows.map { AnyRowConvertible(row: $0) })
                }
                do {
                    XCTAssertTrue(rowsFromSQLChangesRecorder.changes == [
                        RecordedChange(change: .deletion(indexPath: IndexPath(row: 0, section: 0)), value: ["name": "c", "id": 3]),
                        RecordedChange(change: .insertion(indexPath: IndexPath(row: 0, section: 0)), value: ["name": "e", "id": 3])])
                    XCTAssertTrue(rowsFromRequestChangesRecorder.changes == [
                        RecordedChange(change: .deletion(indexPath: IndexPath(row: 0, section: 0)), value: ["name": "c", "id": 3]),
                        RecordedChange(change: .insertion(indexPath: IndexPath(row: 0, section: 0)), value: ["name": "e", "id": 3])])
                    XCTAssertTrue(identifiedRowsFromSQLChangesRecorder.changes == [
                        RecordedChange(change: .update(indexPath: IndexPath(row: 0, section: 0), changes: ["name": "c".databaseValue]), value: ["name": "e", "id": 3])])
                    XCTAssertTrue(identifiedRowsFromRequestChangesRecorder.changes == [
                        RecordedChange(change: .update(indexPath: IndexPath(row: 0, section: 0), changes: ["name": "c".databaseValue]), value: ["name": "e", "id": 3])])
                    XCTAssertTrue(recordsFromSQLChangesRecorder.changes == [
                        RecordedChange(change: .deletion(indexPath: IndexPath(row: 0, section: 0)), value: AnyRowConvertible(row: ["name": "c", "id": 3])),
                        RecordedChange(change: .insertion(indexPath: IndexPath(row: 0, section: 0)), value: AnyRowConvertible(row: ["name": "e", "id": 3]))])
                    XCTAssertTrue(recordsFromRequestChangesRecorder.changes == [
                        RecordedChange(change: .deletion(indexPath: IndexPath(row: 0, section: 0)), value: AnyRowConvertible(row: ["name": "c", "id": 3])),
                        RecordedChange(change: .insertion(indexPath: IndexPath(row: 0, section: 0)), value: AnyRowConvertible(row: ["name": "e", "id": 3]))])
                    XCTAssertTrue(identifiedRecordsFromSQLChangesRecorder.changes == [
                        RecordedChange(change: .update(indexPath: IndexPath(row: 0, section: 0), changes: ["name": "c".databaseValue]), value: AnyRowConvertible(row: ["name": "e", "id": 3]))])
                    XCTAssertTrue(identifiedRecordsFromRequestChangesRecorder.changes == [
                        RecordedChange(change: .update(indexPath: IndexPath(row: 0, section: 0), changes: ["name": "c".databaseValue]), value: AnyRowConvertible(row: ["name": "e", "id": 3]))])
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
                
                let rowsFromSQL = try FetchedCollection<Row>(dbPool, sql: sql)
                let rowsFromRequest = try FetchedCollection(dbPool, request: sqlRequest.bound(to: Row.self))
                let recordsFromSQL = try FetchedCollection<AnyRowConvertible>(dbPool, sql: sql)
                let recordsFromRequest = try FetchedCollection(dbPool, request: sqlRequest.bound(to: AnyRowConvertible.self))
                
                // fetch
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
                let rowsFromSQLChangesRecorder = ChangesRecorder<Row, Void>()
                let rowsFromRequestChangesRecorder = ChangesRecorder<Row, Void>()
                let recordsFromSQLChangesRecorder = ChangesRecorder<AnyRowConvertible, Void>()
                let recordsFromRequestChangesRecorder = ChangesRecorder<AnyRowConvertible, Void>()
                
                rowsFromSQLChangesRecorder.trackChanges(in: rowsFromSQL)
                rowsFromRequestChangesRecorder.trackChanges(in: rowsFromRequest)
                recordsFromSQLChangesRecorder.trackChanges(in: recordsFromSQL)
                recordsFromRequestChangesRecorder.trackChanges(in: recordsFromRequest)
                
                rowsFromSQLChangesRecorder.expectation = expectation(description: "rowsFromSQL")
                rowsFromRequestChangesRecorder.expectation = expectation(description: "rowsFromRequest")
                recordsFromSQLChangesRecorder.expectation = expectation(description: "recordsFromSQL")
                recordsFromRequestChangesRecorder.expectation = expectation(description: "recordsFromRequest")
                waitForExpectations(timeout: 1, handler: nil)
                
                // collection now contains new values
                do {
                    let expectedRows: [Row] = [["name": "c", "id": 3], ["name": "d", "id": 4]]
                    XCTAssertEqual(Array(rowsFromSQL), expectedRows)
                    XCTAssertEqual(Array(rowsFromRequest), expectedRows)
                    XCTAssertEqual(Array(recordsFromSQL), expectedRows.map { AnyRowConvertible(row: $0) })
                    XCTAssertEqual(Array(recordsFromRequest), expectedRows.map { AnyRowConvertible(row: $0) })
                }
                do {
                    let expectedRows: [Row] = [["name": "a", "id": 1], ["name": "b", "id": 2]]
                    XCTAssertEqual(rowsFromSQLChangesRecorder.elementsBeforeChanges, expectedRows)
                    XCTAssertEqual(rowsFromRequestChangesRecorder.elementsBeforeChanges, expectedRows)
                    XCTAssertEqual(recordsFromSQLChangesRecorder.elementsBeforeChanges, expectedRows.map { AnyRowConvertible(row: $0) })
                    XCTAssertEqual(recordsFromRequestChangesRecorder.elementsBeforeChanges, expectedRows.map { AnyRowConvertible(row: $0) })
                }
                do {
                    let expectedRows: [Row] = [["name": "c", "id": 3], ["name": "d", "id": 4]]
                    XCTAssertEqual(rowsFromSQLChangesRecorder.elementsAfterChanges, expectedRows)
                    XCTAssertEqual(rowsFromRequestChangesRecorder.elementsAfterChanges, expectedRows)
                    XCTAssertEqual(recordsFromSQLChangesRecorder.elementsAfterChanges, expectedRows.map { AnyRowConvertible(row: $0) })
                    XCTAssertEqual(recordsFromRequestChangesRecorder.elementsAfterChanges, expectedRows.map { AnyRowConvertible(row: $0) })
                }
                do {
                    XCTAssertTrue(rowsFromSQLChangesRecorder.changes == [
                        RecordedChange(change: .deletion(indexPath: IndexPath(row: 0, section: 0)), value: ["name": "a", "id": 1]),
                        RecordedChange(change: .insertion(indexPath: IndexPath(row: 0, section: 0)), value: ["name": "c", "id": 3]),
                        RecordedChange(change: .deletion(indexPath: IndexPath(row: 1, section: 0)), value: ["name": "b", "id": 2]),
                        RecordedChange(change: .insertion(indexPath: IndexPath(row: 1, section: 0)), value: ["name": "d", "id": 4])])
                    XCTAssertTrue(rowsFromRequestChangesRecorder.changes == [
                        RecordedChange(change: .deletion(indexPath: IndexPath(row: 0, section: 0)), value: ["name": "a", "id": 1]),
                        RecordedChange(change: .insertion(indexPath: IndexPath(row: 0, section: 0)), value: ["name": "c", "id": 3]),
                        RecordedChange(change: .deletion(indexPath: IndexPath(row: 1, section: 0)), value: ["name": "b", "id": 2]),
                        RecordedChange(change: .insertion(indexPath: IndexPath(row: 1, section: 0)), value: ["name": "d", "id": 4])])
                    XCTAssertTrue(recordsFromSQLChangesRecorder.changes == [
                        RecordedChange(change: .deletion(indexPath: IndexPath(row: 0, section: 0)), value: AnyRowConvertible(row: ["name": "a", "id": 1])),
                        RecordedChange(change: .insertion(indexPath: IndexPath(row: 0, section: 0)), value: AnyRowConvertible(row: ["name": "c", "id": 3])),
                        RecordedChange(change: .deletion(indexPath: IndexPath(row: 1, section: 0)), value: AnyRowConvertible(row: ["name": "b", "id": 2])),
                        RecordedChange(change: .insertion(indexPath: IndexPath(row: 1, section: 0)), value: AnyRowConvertible(row: ["name": "d", "id": 4]))])
                    XCTAssertTrue(recordsFromRequestChangesRecorder.changes == [
                        RecordedChange(change: .deletion(indexPath: IndexPath(row: 0, section: 0)), value: AnyRowConvertible(row: ["name": "a", "id": 1])),
                        RecordedChange(change: .insertion(indexPath: IndexPath(row: 0, section: 0)), value: AnyRowConvertible(row: ["name": "c", "id": 3])),
                        RecordedChange(change: .deletion(indexPath: IndexPath(row: 1, section: 0)), value: AnyRowConvertible(row: ["name": "b", "id": 2])),
                        RecordedChange(change: .insertion(indexPath: IndexPath(row: 1, section: 0)), value: AnyRowConvertible(row: ["name": "d", "id": 4]))])
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
                
                let rowsFromSQL = try FetchedCollection<Row>(dbPool, sql: sql)
                let rowsFromRequest = try FetchedCollection(dbPool, request: sqlRequest.bound(to: Row.self))
                let recordsFromSQL = try FetchedCollection<AnyRowConvertible>(dbPool, sql: sql)
                let recordsFromRequest = try FetchedCollection(dbPool, request: sqlRequest.bound(to: AnyRowConvertible.self))
                
                // fetch
                try rowsFromSQL.fetch()
                try rowsFromRequest.fetch()
                try recordsFromSQL.fetch()
                try recordsFromRequest.fetch()
                
                // track
                let rowsFromSQLChangesRecorder = ChangesRecorder<Row, Void>()
                let rowsFromRequestChangesRecorder = ChangesRecorder<Row, Void>()
                let recordsFromSQLChangesRecorder = ChangesRecorder<AnyRowConvertible, Void>()
                let recordsFromRequestChangesRecorder = ChangesRecorder<AnyRowConvertible, Void>()
                
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
                
                rowsFromSQLChangesRecorder.expectation = expectation(description: "rowsFromSQL")
                rowsFromRequestChangesRecorder.expectation = expectation(description: "rowsFromRequest")
                recordsFromSQLChangesRecorder.expectation = expectation(description: "recordsFromSQL")
                recordsFromRequestChangesRecorder.expectation = expectation(description: "recordsFromRequest")
                waitForExpectations(timeout: 1, handler: nil)
                
                // collection now contains new values
                do {
                    let expectedRows: [Row] = [["name": "c", "id": 3], ["name": "d", "id": 4]]
                    XCTAssertEqual(Array(rowsFromSQL), expectedRows)
                    XCTAssertEqual(Array(rowsFromRequest), expectedRows)
                    XCTAssertEqual(Array(recordsFromSQL), expectedRows.map { AnyRowConvertible(row: $0) })
                    XCTAssertEqual(Array(recordsFromRequest), expectedRows.map { AnyRowConvertible(row: $0) })
                }
                do {
                    let expectedRows: [Row] = [["name": "a", "id": 1], ["name": "b", "id": 2]]
                    XCTAssertEqual(rowsFromSQLChangesRecorder.elementsBeforeChanges, expectedRows)
                    XCTAssertEqual(rowsFromRequestChangesRecorder.elementsBeforeChanges, expectedRows)
                    XCTAssertEqual(recordsFromSQLChangesRecorder.elementsBeforeChanges, expectedRows.map { AnyRowConvertible(row: $0) })
                    XCTAssertEqual(recordsFromRequestChangesRecorder.elementsBeforeChanges, expectedRows.map { AnyRowConvertible(row: $0) })
                }
                do {
                    let expectedRows: [Row] = [["name": "c", "id": 3], ["name": "d", "id": 4]]
                    XCTAssertEqual(rowsFromSQLChangesRecorder.elementsAfterChanges, expectedRows)
                    XCTAssertEqual(rowsFromRequestChangesRecorder.elementsAfterChanges, expectedRows)
                    XCTAssertEqual(recordsFromSQLChangesRecorder.elementsAfterChanges, expectedRows.map { AnyRowConvertible(row: $0) })
                    XCTAssertEqual(recordsFromRequestChangesRecorder.elementsAfterChanges, expectedRows.map { AnyRowConvertible(row: $0) })
                }
                do {
                    XCTAssertTrue(rowsFromSQLChangesRecorder.changes == [
                        RecordedChange(change: .deletion(indexPath: IndexPath(row: 0, section: 0)), value: ["name": "a", "id": 1]),
                        RecordedChange(change: .insertion(indexPath: IndexPath(row: 0, section: 0)), value: ["name": "c", "id": 3]),
                        RecordedChange(change: .deletion(indexPath: IndexPath(row: 1, section: 0)), value: ["name": "b", "id": 2]),
                        RecordedChange(change: .insertion(indexPath: IndexPath(row: 1, section: 0)), value: ["name": "d", "id": 4])])
                    XCTAssertTrue(rowsFromRequestChangesRecorder.changes == [
                        RecordedChange(change: .deletion(indexPath: IndexPath(row: 0, section: 0)), value: ["name": "a", "id": 1]),
                        RecordedChange(change: .insertion(indexPath: IndexPath(row: 0, section: 0)), value: ["name": "c", "id": 3]),
                        RecordedChange(change: .deletion(indexPath: IndexPath(row: 1, section: 0)), value: ["name": "b", "id": 2]),
                        RecordedChange(change: .insertion(indexPath: IndexPath(row: 1, section: 0)), value: ["name": "d", "id": 4])])
                    XCTAssertTrue(recordsFromSQLChangesRecorder.changes == [
                        RecordedChange(change: .deletion(indexPath: IndexPath(row: 0, section: 0)), value: AnyRowConvertible(row: ["name": "a", "id": 1])),
                        RecordedChange(change: .insertion(indexPath: IndexPath(row: 0, section: 0)), value: AnyRowConvertible(row: ["name": "c", "id": 3])),
                        RecordedChange(change: .deletion(indexPath: IndexPath(row: 1, section: 0)), value: AnyRowConvertible(row: ["name": "b", "id": 2])),
                        RecordedChange(change: .insertion(indexPath: IndexPath(row: 1, section: 0)), value: AnyRowConvertible(row: ["name": "d", "id": 4]))])
                    XCTAssertTrue(recordsFromRequestChangesRecorder.changes == [
                        RecordedChange(change: .deletion(indexPath: IndexPath(row: 0, section: 0)), value: AnyRowConvertible(row: ["name": "a", "id": 1])),
                        RecordedChange(change: .insertion(indexPath: IndexPath(row: 0, section: 0)), value: AnyRowConvertible(row: ["name": "c", "id": 3])),
                        RecordedChange(change: .deletion(indexPath: IndexPath(row: 1, section: 0)), value: AnyRowConvertible(row: ["name": "b", "id": 2])),
                        RecordedChange(change: .insertion(indexPath: IndexPath(row: 1, section: 0)), value: AnyRowConvertible(row: ["name": "d", "id": 4]))])
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
                
                let rowsFromSQL = try FetchedCollection<Row>(dbPool, sql: sql)
                let rowsFromRequest = try FetchedCollection(dbPool, request: sqlRequest.bound(to: Row.self))
                let recordsFromSQL = try FetchedCollection<AnyRowConvertible>(dbPool, sql: sql)
                let recordsFromRequest = try FetchedCollection(dbPool, request: sqlRequest.bound(to: AnyRowConvertible.self))
                
                // track
                let rowsFromSQLChangesRecorder = ChangesRecorder<Row, Void>()
                let rowsFromRequestChangesRecorder = ChangesRecorder<Row, Void>()
                let recordsFromSQLChangesRecorder = ChangesRecorder<AnyRowConvertible, Void>()
                let recordsFromRequestChangesRecorder = ChangesRecorder<AnyRowConvertible, Void>()
                
                rowsFromSQLChangesRecorder.trackChanges(in: rowsFromSQL)
                rowsFromRequestChangesRecorder.trackChanges(in: rowsFromRequest)
                recordsFromSQLChangesRecorder.trackChanges(in: recordsFromSQL)
                recordsFromRequestChangesRecorder.trackChanges(in: recordsFromRequest)
                
                // fetch
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
                
                rowsFromSQLChangesRecorder.expectation = expectation(description: "rowsFromSQL")
                rowsFromRequestChangesRecorder.expectation = expectation(description: "rowsFromRequest")
                recordsFromSQLChangesRecorder.expectation = expectation(description: "recordsFromSQL")
                recordsFromRequestChangesRecorder.expectation = expectation(description: "recordsFromRequest")
                waitForExpectations(timeout: 1, handler: nil)
                
                // collection now contains new values
                do {
                    let expectedRows: [Row] = [["name": "c", "id": 3], ["name": "d", "id": 4]]
                    XCTAssertEqual(Array(rowsFromSQL), expectedRows)
                    XCTAssertEqual(Array(rowsFromRequest), expectedRows)
                    XCTAssertEqual(Array(recordsFromSQL), expectedRows.map { AnyRowConvertible(row: $0) })
                    XCTAssertEqual(Array(recordsFromRequest), expectedRows.map { AnyRowConvertible(row: $0) })
                }
                do {
                    let expectedRows: [Row] = [["name": "a", "id": 1], ["name": "b", "id": 2]]
                    XCTAssertEqual(rowsFromSQLChangesRecorder.elementsBeforeChanges, expectedRows)
                    XCTAssertEqual(rowsFromRequestChangesRecorder.elementsBeforeChanges, expectedRows)
                    XCTAssertEqual(recordsFromSQLChangesRecorder.elementsBeforeChanges, expectedRows.map { AnyRowConvertible(row: $0) })
                    XCTAssertEqual(recordsFromRequestChangesRecorder.elementsBeforeChanges, expectedRows.map { AnyRowConvertible(row: $0) })
                }
                do {
                    let expectedRows: [Row] = [["name": "c", "id": 3], ["name": "d", "id": 4]]
                    XCTAssertEqual(rowsFromSQLChangesRecorder.elementsAfterChanges, expectedRows)
                    XCTAssertEqual(rowsFromRequestChangesRecorder.elementsAfterChanges, expectedRows)
                    XCTAssertEqual(recordsFromSQLChangesRecorder.elementsAfterChanges, expectedRows.map { AnyRowConvertible(row: $0) })
                    XCTAssertEqual(recordsFromRequestChangesRecorder.elementsAfterChanges, expectedRows.map { AnyRowConvertible(row: $0) })
                }
                do {
                    XCTAssertTrue(rowsFromSQLChangesRecorder.changes == [
                        RecordedChange(change: .deletion(indexPath: IndexPath(row: 0, section: 0)), value: ["name": "a", "id": 1]),
                        RecordedChange(change: .insertion(indexPath: IndexPath(row: 0, section: 0)), value: ["name": "c", "id": 3]),
                        RecordedChange(change: .deletion(indexPath: IndexPath(row: 1, section: 0)), value: ["name": "b", "id": 2]),
                        RecordedChange(change: .insertion(indexPath: IndexPath(row: 1, section: 0)), value: ["name": "d", "id": 4])])
                    XCTAssertTrue(rowsFromRequestChangesRecorder.changes == [
                        RecordedChange(change: .deletion(indexPath: IndexPath(row: 0, section: 0)), value: ["name": "a", "id": 1]),
                        RecordedChange(change: .insertion(indexPath: IndexPath(row: 0, section: 0)), value: ["name": "c", "id": 3]),
                        RecordedChange(change: .deletion(indexPath: IndexPath(row: 1, section: 0)), value: ["name": "b", "id": 2]),
                        RecordedChange(change: .insertion(indexPath: IndexPath(row: 1, section: 0)), value: ["name": "d", "id": 4])])
                    XCTAssertTrue(recordsFromSQLChangesRecorder.changes == [
                        RecordedChange(change: .deletion(indexPath: IndexPath(row: 0, section: 0)), value: AnyRowConvertible(row: ["name": "a", "id": 1])),
                        RecordedChange(change: .insertion(indexPath: IndexPath(row: 0, section: 0)), value: AnyRowConvertible(row: ["name": "c", "id": 3])),
                        RecordedChange(change: .deletion(indexPath: IndexPath(row: 1, section: 0)), value: AnyRowConvertible(row: ["name": "b", "id": 2])),
                        RecordedChange(change: .insertion(indexPath: IndexPath(row: 1, section: 0)), value: AnyRowConvertible(row: ["name": "d", "id": 4]))])
                    XCTAssertTrue(recordsFromRequestChangesRecorder.changes == [
                        RecordedChange(change: .deletion(indexPath: IndexPath(row: 0, section: 0)), value: AnyRowConvertible(row: ["name": "a", "id": 1])),
                        RecordedChange(change: .insertion(indexPath: IndexPath(row: 0, section: 0)), value: AnyRowConvertible(row: ["name": "c", "id": 3])),
                        RecordedChange(change: .deletion(indexPath: IndexPath(row: 1, section: 0)), value: AnyRowConvertible(row: ["name": "b", "id": 2])),
                        RecordedChange(change: .insertion(indexPath: IndexPath(row: 1, section: 0)), value: AnyRowConvertible(row: ["name": "d", "id": 4]))])
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
                
                let rowsFromSQL = try FetchedCollection<Row>(dbPool, sql: sql)
                let rowsFromRequest = try FetchedCollection(dbPool, request: sqlRequest.bound(to: Row.self))
                let recordsFromSQL = try FetchedCollection<AnyRowConvertible>(dbPool, sql: sql)
                let recordsFromRequest = try FetchedCollection(dbPool, request: sqlRequest.bound(to: AnyRowConvertible.self))
                
                let rowsFromSQLChangesRecorder = ChangesRecorder<Row, Void>()
                let rowsFromRequestChangesRecorder = ChangesRecorder<Row, Void>()
                let recordsFromSQLChangesRecorder = ChangesRecorder<AnyRowConvertible, Void>()
                let recordsFromRequestChangesRecorder = ChangesRecorder<AnyRowConvertible, Void>()
                
                rowsFromSQLChangesRecorder.trackChanges(in: rowsFromSQL)
                rowsFromRequestChangesRecorder.trackChanges(in: rowsFromRequest)
                recordsFromSQLChangesRecorder.trackChanges(in: recordsFromSQL)
                recordsFromRequestChangesRecorder.trackChanges(in: recordsFromRequest)
                
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
                    XCTAssertEqual(Array(rowsFromSQL), expectedRows)
                    XCTAssertEqual(Array(rowsFromRequest), expectedRows)
                    XCTAssertEqual(Array(recordsFromSQL), expectedRows.map { AnyRowConvertible(row: $0) })
                    XCTAssertEqual(Array(recordsFromRequest), expectedRows.map { AnyRowConvertible(row: $0) })
                }
                
                rowsFromSQLChangesRecorder.expectation = expectation(description: "rowsFromSQL")
                rowsFromRequestChangesRecorder.expectation = expectation(description: "rowsFromRequest")
                recordsFromSQLChangesRecorder.expectation = expectation(description: "recordsFromSQL")
                recordsFromRequestChangesRecorder.expectation = expectation(description: "recordsFromRequest")
                waitForExpectations(timeout: 1, handler: nil)
                
                // collection now contains new values
                do {
                    let expectedRows: [Row] = [["name": "b", "id": 2], ["name": "c", "id": 3]]
                    XCTAssertEqual(Array(rowsFromSQL), expectedRows)
                    XCTAssertEqual(Array(rowsFromRequest), expectedRows)
                    XCTAssertEqual(Array(recordsFromSQL), expectedRows.map { AnyRowConvertible(row: $0) })
                    XCTAssertEqual(Array(recordsFromRequest), expectedRows.map { AnyRowConvertible(row: $0) })
                }
                do {
                    let expectedRows: [Row] = [["name": "a", "id": 1], ["name": "b", "id": 2]]
                    XCTAssertEqual(rowsFromSQLChangesRecorder.elementsBeforeChanges, expectedRows)
                    XCTAssertEqual(rowsFromRequestChangesRecorder.elementsBeforeChanges, expectedRows)
                    XCTAssertEqual(recordsFromSQLChangesRecorder.elementsBeforeChanges, expectedRows.map { AnyRowConvertible(row: $0) })
                    XCTAssertEqual(recordsFromRequestChangesRecorder.elementsBeforeChanges, expectedRows.map { AnyRowConvertible(row: $0) })
                }
                do {
                    let expectedRows: [Row] = [["name": "b", "id": 2], ["name": "c", "id": 3]]
                    XCTAssertEqual(rowsFromSQLChangesRecorder.elementsAfterChanges, expectedRows)
                    XCTAssertEqual(rowsFromRequestChangesRecorder.elementsAfterChanges, expectedRows)
                    XCTAssertEqual(recordsFromSQLChangesRecorder.elementsAfterChanges, expectedRows.map { AnyRowConvertible(row: $0) })
                    XCTAssertEqual(recordsFromRequestChangesRecorder.elementsAfterChanges, expectedRows.map { AnyRowConvertible(row: $0) })
                }
                do {
                    XCTAssertTrue(rowsFromSQLChangesRecorder.changes == [
                        RecordedChange(change: .deletion(indexPath: IndexPath(row: 0, section: 0)), value: ["name": "a", "id": 1]),
                        RecordedChange(change: .insertion(indexPath: IndexPath(row: 1, section: 0)), value: ["name": "c", "id": 3])])
                    XCTAssertTrue(rowsFromRequestChangesRecorder.changes == [
                        RecordedChange(change: .deletion(indexPath: IndexPath(row: 0, section: 0)), value: ["name": "a", "id": 1]),
                        RecordedChange(change: .insertion(indexPath: IndexPath(row: 1, section: 0)), value: ["name": "c", "id": 3])])
                    XCTAssertTrue(recordsFromSQLChangesRecorder.changes == [
                        RecordedChange(change: .deletion(indexPath: IndexPath(row: 0, section: 0)), value: AnyRowConvertible(row: ["name": "a", "id": 1])),
                        RecordedChange(change: .insertion(indexPath: IndexPath(row: 1, section: 0)), value: AnyRowConvertible(row: ["name": "c", "id": 3]))])
                    XCTAssertTrue(recordsFromRequestChangesRecorder.changes == [
                        RecordedChange(change: .deletion(indexPath: IndexPath(row: 0, section: 0)), value: AnyRowConvertible(row: ["name": "a", "id": 1])),
                        RecordedChange(change: .insertion(indexPath: IndexPath(row: 1, section: 0)), value: AnyRowConvertible(row: ["name": "c", "id": 3]))])
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
                    XCTAssertEqual(Array(rowsFromSQL), expectedRows)
                    XCTAssertEqual(Array(rowsFromRequest), expectedRows)
                    XCTAssertEqual(Array(recordsFromSQL), expectedRows.map { AnyRowConvertible(row: $0) })
                    XCTAssertEqual(Array(recordsFromRequest), expectedRows.map { AnyRowConvertible(row: $0) })
                }
                
                rowsFromSQLChangesRecorder.expectation = expectation(description: "rowsFromSQL")
                rowsFromRequestChangesRecorder.expectation = expectation(description: "rowsFromRequest")
                recordsFromSQLChangesRecorder.expectation = expectation(description: "recordsFromSQL")
                recordsFromRequestChangesRecorder.expectation = expectation(description: "recordsFromRequest")
                waitForExpectations(timeout: 1, handler: nil)
                
                // collection now contains new values
                do {
                    let expectedRows: [Row] = [["name": "c", "id": 3], ["name": "d", "id": 4]]
                    XCTAssertEqual(Array(rowsFromSQL), expectedRows)
                    XCTAssertEqual(Array(rowsFromRequest), expectedRows)
                    XCTAssertEqual(Array(recordsFromSQL), expectedRows.map { AnyRowConvertible(row: $0) })
                    XCTAssertEqual(Array(recordsFromRequest), expectedRows.map { AnyRowConvertible(row: $0) })
                }
                do {
                    let expectedRows: [Row] = [["name": "b", "id": 2], ["name": "c", "id": 3]]
                    XCTAssertEqual(rowsFromSQLChangesRecorder.elementsBeforeChanges, expectedRows)
                    XCTAssertEqual(rowsFromRequestChangesRecorder.elementsBeforeChanges, expectedRows)
                    XCTAssertEqual(recordsFromSQLChangesRecorder.elementsBeforeChanges, expectedRows.map { AnyRowConvertible(row: $0) })
                    XCTAssertEqual(recordsFromRequestChangesRecorder.elementsBeforeChanges, expectedRows.map { AnyRowConvertible(row: $0) })
                }
                do {
                    let expectedRows: [Row] = [["name": "c", "id": 3], ["name": "d", "id": 4]]
                    XCTAssertEqual(rowsFromSQLChangesRecorder.elementsAfterChanges, expectedRows)
                    XCTAssertEqual(rowsFromRequestChangesRecorder.elementsAfterChanges, expectedRows)
                    XCTAssertEqual(recordsFromSQLChangesRecorder.elementsAfterChanges, expectedRows.map { AnyRowConvertible(row: $0) })
                    XCTAssertEqual(recordsFromRequestChangesRecorder.elementsAfterChanges, expectedRows.map { AnyRowConvertible(row: $0) })
                }
                do {
                    XCTAssertTrue(rowsFromSQLChangesRecorder.changes == [
                        RecordedChange(change: .deletion(indexPath: IndexPath(row: 0, section: 0)), value: ["name": "b", "id": 2]),
                        RecordedChange(change: .insertion(indexPath: IndexPath(row: 1, section: 0)), value: ["name": "d", "id": 4])])
                    XCTAssertTrue(rowsFromRequestChangesRecorder.changes == [
                        RecordedChange(change: .deletion(indexPath: IndexPath(row: 0, section: 0)), value: ["name": "b", "id": 2]),
                        RecordedChange(change: .insertion(indexPath: IndexPath(row: 1, section: 0)), value: ["name": "d", "id": 4])])
                    XCTAssertTrue(recordsFromSQLChangesRecorder.changes == [
                        RecordedChange(change: .deletion(indexPath: IndexPath(row: 0, section: 0)), value: AnyRowConvertible(row: ["name": "b", "id": 2])),
                        RecordedChange(change: .insertion(indexPath: IndexPath(row: 1, section: 0)), value: AnyRowConvertible(row: ["name": "d", "id": 4]))])
                    XCTAssertTrue(recordsFromRequestChangesRecorder.changes == [
                        RecordedChange(change: .deletion(indexPath: IndexPath(row: 0, section: 0)), value: AnyRowConvertible(row: ["name": "b", "id": 2])),
                        RecordedChange(change: .insertion(indexPath: IndexPath(row: 1, section: 0)), value: AnyRowConvertible(row: ["name": "d", "id": 4]))])
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
                
                let rowsFromSQL = try FetchedCollection<Row>(dbPool, sql: sql1)
                let rowsFromRequest = try FetchedCollection(dbPool, request: sqlRequest1.bound(to: Row.self))
                let recordsFromSQL = try FetchedCollection<AnyRowConvertible>(dbPool, sql: sql1)
                let recordsFromRequest = try FetchedCollection(dbPool, request: sqlRequest1.bound(to: AnyRowConvertible.self))
                
                let rowsFromSQLChangesRecorder = ChangesRecorder<Row, Void>()
                let rowsFromRequestChangesRecorder = ChangesRecorder<Row, Void>()
                let recordsFromSQLChangesRecorder = ChangesRecorder<AnyRowConvertible, Void>()
                let recordsFromRequestChangesRecorder = ChangesRecorder<AnyRowConvertible, Void>()
                
                rowsFromSQLChangesRecorder.trackChanges(in: rowsFromSQL)
                rowsFromRequestChangesRecorder.trackChanges(in: rowsFromRequest)
                recordsFromSQLChangesRecorder.trackChanges(in: recordsFromSQL)
                recordsFromRequestChangesRecorder.trackChanges(in: recordsFromRequest)
                
                try rowsFromSQL.fetch()
                try rowsFromRequest.fetch()
                try recordsFromSQL.fetch()
                try recordsFromRequest.fetch()
                
                // change request
                let sql2 = "SELECT name, id FROM table2 ORDER BY id"
                let sqlRequest2 = SQLRequest(sql2)
                
                try rowsFromSQL.setRequest(sql: sql2)
                try rowsFromRequest.setRequest(sqlRequest2.bound(to: Row.self))
                try recordsFromSQL.setRequest(sql: sql2)
                try recordsFromRequest.setRequest(sqlRequest2.bound(to: AnyRowConvertible.self))
                
                rowsFromSQLChangesRecorder.expectation = expectation(description: "rowsFromSQL")
                rowsFromRequestChangesRecorder.expectation = expectation(description: "rowsFromRequest")
                recordsFromSQLChangesRecorder.expectation = expectation(description: "recordsFromSQL")
                recordsFromRequestChangesRecorder.expectation = expectation(description: "recordsFromRequest")
                waitForExpectations(timeout: 1, handler: nil)
                
                // collection now contains new values
                do {
                    let expectedRows: [Row] = [["name": "b", "id": 2]]
                    XCTAssertEqual(Array(rowsFromSQL), expectedRows)
                    XCTAssertEqual(Array(rowsFromRequest), expectedRows)
                    XCTAssertEqual(Array(recordsFromSQL), expectedRows.map { AnyRowConvertible(row: $0) })
                    XCTAssertEqual(Array(recordsFromRequest), expectedRows.map { AnyRowConvertible(row: $0) })
                }
                do {
                    XCTAssertTrue(rowsFromSQLChangesRecorder.changes == [
                        RecordedChange(change: .deletion(indexPath: IndexPath(row: 0, section: 0)), value: ["name": "a", "id": 1]),
                        RecordedChange(change: .insertion(indexPath: IndexPath(row: 0, section: 0)), value: ["name": "b", "id": 2])])
                    XCTAssertTrue(rowsFromRequestChangesRecorder.changes == [
                        RecordedChange(change: .deletion(indexPath: IndexPath(row: 0, section: 0)), value: ["name": "a", "id": 1]),
                        RecordedChange(change: .insertion(indexPath: IndexPath(row: 0, section: 0)), value: ["name": "b", "id": 2])])
                    XCTAssertTrue(recordsFromSQLChangesRecorder.changes == [
                        RecordedChange(change: .deletion(indexPath: IndexPath(row: 0, section: 0)), value: AnyRowConvertible(row: ["name": "a", "id": 1])),
                        RecordedChange(change: .insertion(indexPath: IndexPath(row: 0, section: 0)), value: AnyRowConvertible(row: ["name": "b", "id": 2]))])
                    XCTAssertTrue(recordsFromRequestChangesRecorder.changes == [
                        RecordedChange(change: .deletion(indexPath: IndexPath(row: 0, section: 0)), value: AnyRowConvertible(row: ["name": "a", "id": 1])),
                        RecordedChange(change: .insertion(indexPath: IndexPath(row: 0, section: 0)), value: AnyRowConvertible(row: ["name": "b", "id": 2]))])
                }
                
                // modify table2
                try dbPool.writeInTransaction { db in
                    try db.execute("INSERT INTO table2 (id, name) VALUES (?, ?)", arguments: [3, "c"])
                    return .commit
                }
                
                rowsFromSQLChangesRecorder.expectation = expectation(description: "rowsFromSQL")
                rowsFromRequestChangesRecorder.expectation = expectation(description: "rowsFromRequest")
                recordsFromSQLChangesRecorder.expectation = expectation(description: "recordsFromSQL")
                recordsFromRequestChangesRecorder.expectation = expectation(description: "recordsFromRequest")
                waitForExpectations(timeout: 1, handler: nil)
                
                // collection now contains new values
                do {
                    let expectedRows: [Row] = [["name": "b", "id": 2], ["name": "c", "id": 3]]
                    XCTAssertEqual(Array(rowsFromSQL), expectedRows)
                    XCTAssertEqual(Array(rowsFromRequest), expectedRows)
                    XCTAssertEqual(Array(recordsFromSQL), expectedRows.map { AnyRowConvertible(row: $0) })
                    XCTAssertEqual(Array(recordsFromRequest), expectedRows.map { AnyRowConvertible(row: $0) })
                }
                do {
                    XCTAssertTrue(rowsFromSQLChangesRecorder.changes == [
                        RecordedChange(change: .insertion(indexPath: IndexPath(row: 1, section: 0)), value: ["name": "c", "id": 3])])
                    XCTAssertTrue(rowsFromRequestChangesRecorder.changes == [
                        RecordedChange(change: .insertion(indexPath: IndexPath(row: 1, section: 0)), value: ["name": "c", "id": 3])])
                    XCTAssertTrue(recordsFromSQLChangesRecorder.changes == [
                        RecordedChange(change: .insertion(indexPath: IndexPath(row: 1, section: 0)), value: AnyRowConvertible(row: ["name": "c", "id": 3]))])
                    XCTAssertTrue(recordsFromRequestChangesRecorder.changes == [
                        RecordedChange(change: .insertion(indexPath: IndexPath(row: 1, section: 0)), value: AnyRowConvertible(row: ["name": "c", "id": 3]))])
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
                
                let rowsFromSQL = try FetchedCollection<Row>(dbPool, sql: sql)
                let rowsFromRequest = try FetchedCollection(dbPool, request: sqlRequest.bound(to: Row.self))
                let recordsFromSQL = try FetchedCollection<AnyRowConvertible>(dbPool, sql: sql)
                let recordsFromRequest = try FetchedCollection(dbPool, request: sqlRequest.bound(to: AnyRowConvertible.self))
                
                let rowsFromSQLChangesRecorder = ChangesRecorder<Row, Int>()
                let rowsFromRequestChangesRecorder = ChangesRecorder<Row, Int>()
                let recordsFromSQLChangesRecorder = ChangesRecorder<AnyRowConvertible, Int>()
                let recordsFromRequestChangesRecorder = ChangesRecorder<AnyRowConvertible, Int>()
                
                let fetchAlongside = { (db: Database) in try Int.fetchOne(db, "SELECT COUNT(*) FROM table1")! }
                rowsFromSQLChangesRecorder.trackChanges(in: rowsFromSQL, fetchAlongside: fetchAlongside)
                rowsFromRequestChangesRecorder.trackChanges(in: rowsFromRequest, fetchAlongside: fetchAlongside)
                recordsFromSQLChangesRecorder.trackChanges(in: recordsFromSQL, fetchAlongside: fetchAlongside)
                recordsFromRequestChangesRecorder.trackChanges(in: recordsFromRequest, fetchAlongside: fetchAlongside)
                
                try rowsFromSQL.fetch()
                try rowsFromRequest.fetch()
                try recordsFromSQL.fetch()
                try recordsFromRequest.fetch()
                
                // change the value that is fetched alongside
                try dbPool.writeInTransaction { db in
                    try db.execute("INSERT INTO table1 (id, name) VALUES (?, ?)", arguments: [1, "a"])
                    return .commit
                }
                
                rowsFromSQLChangesRecorder.expectation = expectation(description: "rowsFromSQL")
                rowsFromRequestChangesRecorder.expectation = expectation(description: "rowsFromRequest")
                recordsFromSQLChangesRecorder.expectation = expectation(description: "recordsFromSQL")
                recordsFromRequestChangesRecorder.expectation = expectation(description: "recordsFromRequest")
                waitForExpectations(timeout: 1, handler: nil)
                
                XCTAssertEqual(rowsFromSQLChangesRecorder.fetchedAlongsideAfterChanges, 1)
                XCTAssertEqual(rowsFromRequestChangesRecorder.fetchedAlongsideAfterChanges, 1)
                XCTAssertEqual(recordsFromSQLChangesRecorder.fetchedAlongsideAfterChanges, 1)
                XCTAssertEqual(recordsFromRequestChangesRecorder.fetchedAlongsideAfterChanges, 1)
                
                // change the value that is fetched alongside
                try dbPool.writeInTransaction { db in
                    try db.execute("INSERT INTO table1 (id, name) VALUES (?, ?)", arguments: [2, "b"])
                    return .commit
                }
                
                rowsFromSQLChangesRecorder.expectation = expectation(description: "rowsFromSQL")
                rowsFromRequestChangesRecorder.expectation = expectation(description: "rowsFromRequest")
                recordsFromSQLChangesRecorder.expectation = expectation(description: "recordsFromSQL")
                recordsFromRequestChangesRecorder.expectation = expectation(description: "recordsFromRequest")
                waitForExpectations(timeout: 1, handler: nil)
                
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
                
                let rowsFromSQL = try FetchedCollection<Row>(dbPool, sql: sql)
                let rowsFromRequest = try FetchedCollection(dbPool, request: sqlRequest.bound(to: Row.self))
                let recordsFromSQL = try FetchedCollection<AnyRowConvertible>(dbPool, sql: sql)
                let recordsFromRequest = try FetchedCollection(dbPool, request: sqlRequest.bound(to: AnyRowConvertible.self))
                
                let rowsFromSQLChangesRecorder = ChangesRecorder<Row, Void>()
                let rowsFromRequestChangesRecorder = ChangesRecorder<Row, Void>()
                let recordsFromSQLChangesRecorder = ChangesRecorder<AnyRowConvertible, Void>()
                let recordsFromRequestChangesRecorder = ChangesRecorder<AnyRowConvertible, Void>()
                
                func trackChangesWithTrailingClosure<Fetched>(in collection: FetchedCollection<Fetched>, with recorder: ChangesRecorder<Fetched, Void>) {
                    collection.trackChanges { collection in recorder.collectionDidChange(collection) }
                }
                trackChangesWithTrailingClosure(in: rowsFromSQL, with: rowsFromSQLChangesRecorder)
                trackChangesWithTrailingClosure(in: rowsFromRequest, with: rowsFromRequestChangesRecorder)
                trackChangesWithTrailingClosure(in: recordsFromSQL, with: recordsFromSQLChangesRecorder)
                trackChangesWithTrailingClosure(in: recordsFromRequest, with: recordsFromRequestChangesRecorder)
                
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
                
                rowsFromSQLChangesRecorder.expectation = expectation(description: "rowsFromSQL")
                rowsFromRequestChangesRecorder.expectation = expectation(description: "rowsFromRequest")
                recordsFromSQLChangesRecorder.expectation = expectation(description: "recordsFromSQL")
                recordsFromRequestChangesRecorder.expectation = expectation(description: "recordsFromRequest")
                waitForExpectations(timeout: 1, handler: nil)
                
                do {
                    let expectedRows: [Row] = [["name": "c", "id": 3], ["name": "d", "id": 4]]
                    XCTAssertEqual(rowsFromSQLChangesRecorder.elementsAfterChanges, expectedRows)
                    XCTAssertEqual(rowsFromRequestChangesRecorder.elementsAfterChanges, expectedRows)
                    XCTAssertEqual(recordsFromSQLChangesRecorder.elementsAfterChanges, expectedRows.map { AnyRowConvertible(row: $0) })
                    XCTAssertEqual(recordsFromRequestChangesRecorder.elementsAfterChanges, expectedRows.map { AnyRowConvertible(row: $0) })
                }
            }
        }
        
        func testChangesAreNotReReflectedUntilFetchAndTrackingIsSet() {
            // TODO: test that FetchedCollection contents do not eventually change
            // after a database change. The difficulty of this test lies in the
            // "eventually" word.
        }
        
        func testExternalChange() {
            // TODO: test that callbacks are not called after a change in some
            // external table or some unused column.
        }
    }
    
#endif
