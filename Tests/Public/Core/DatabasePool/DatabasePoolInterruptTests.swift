import XCTest
#if USING_SQLCIPHER
    import GRDBCipher
#elseif USING_CUSTOMSQLITE
    import GRDBCustomSQLite
#else
    import GRDB
#endif

class DatabasePoolInterruptTests: GRDBTestCase {
    
    func testInterruptSelectStatementStep() {
        assertNoError {
            let dbPool = try makeDatabasePool()
            try dbPool.write { db in
                try db.execute("CREATE TABLE items (id INTEGER PRIMARY KEY)")
                for _ in 0..<3 {
                    try db.execute("INSERT INTO items (id) VALUES (NULL)")
                }
            }
            
            // Block 1                      Block 2
            // BEGIN DEFERRED TRANSACTION
            // SELECT * FROM items
            // step
            // >
            let s1 = DispatchSemaphore(value: 0)
            //                              interrupt
            //                              <
            let s2 = DispatchSemaphore(value: 0)
            // step (SQLITE_INTERRUPT)
            // step (SQLITE_MISUSE)
            // COMMIT
            
            let block1 = { () in
                dbPool.read { db in
                    let iterator = Row.fetch(db, "SELECT * FROM items").makeIterator()
                    do {
                        _ = try iterator.step()
                    } catch {
                        XCTFail("Unexpected error \(error)")
                    }
                    s1.signal()
                    _ = s2.wait(timeout: .distantFuture)
                    do {
                        _ = try iterator.step()
                        XCTFail("Expected error")
                    } catch let error as DatabaseError {
                        XCTAssertEqual(error.code, 9) // SQLITE_INTERRUPT
                        XCTAssertEqual(error.message!, "interrupted")
                        XCTAssertEqual(error.sql!, "SELECT * FROM items")
                        XCTAssertEqual(error.description, "SQLite error 9 with statement `SELECT * FROM items`: interrupted")
                    } catch {
                        XCTFail("Unexpected error \(error)")
                    }
                    do {
                        _ = try iterator.step()
                        XCTFail("Expected error")
                    } catch let error as DatabaseError {
                        XCTAssertEqual(error.code, 21) // SQLITE_MISUSE
                        XCTAssertEqual(error.message!, "interrupted")
                        XCTAssertEqual(error.sql!, "SELECT * FROM items")
                        XCTAssertEqual(error.description, "SQLite error 21 with statement `SELECT * FROM items`: interrupted")
                    } catch {
                        XCTFail("Unexpected error \(error)")
                    }
                }
            }
            let block2 = { () in
                _ = s1.wait(timeout: .distantFuture)
                dbPool.interrupt()
                s2.signal()
            }
            let blocks = [block1, block2]
            DispatchQueue.concurrentPerform(iterations: blocks.count) { index in
                blocks[index]()
            }
        }
    }
    
    func testInterruptUpdateStatement() {
        assertNoError {
            let dbPool = try makeDatabasePool()
            try dbPool.write { db in
                try db.execute("CREATE TABLE items (id INTEGER PRIMARY KEY)")
            }
            
            // We execute a statement that calls a function which waits for the interrupt
            
            // Block 1                      Block 2
            // INSERT INTO items (id) VALUES (1)
            // INSERT INTO items (id) VALUES (2)
            // DELETE FROM items WHERE 1
            // The deletion of first row triggers interrupt, before second row can be deleted
            // >
            let s1 = DispatchSemaphore(value: 0)
            //                              interrupt
            //                              <
            let s2 = DispatchSemaphore(value: 0)
            // error SQLITE_INTERRUPT
            
            let interrupt = DatabaseFunction("interrupt", argumentCount: 0) { _ in
                s1.signal()
                _ = s2.wait(timeout: .distantFuture)
                return nil
            }
            dbPool.add(function: interrupt)
            try dbPool.write { db in
                try db.execute("CREATE TRIGGER interrupt AFTER DELETE ON items BEGIN SELECT interrupt(); END")
            }
            
            let block1 = { () in
                try! dbPool.write { db in
                    try db.execute("INSERT INTO items (id) VALUES (1)")
                    try db.execute("INSERT INTO items (id) VALUES (2)")
                    do {
                        try db.execute("DELETE FROM items WHERE 1") // Avoid truncate optimization
                        XCTFail("Expected error")
                    } catch let error as DatabaseError {
                        XCTAssertEqual(error.code, 9) // SQLITE_INTERRUPT
                        XCTAssertEqual(error.message!, "interrupted")
                        XCTAssertEqual(error.sql!, "DELETE FROM items WHERE 1")
                        XCTAssertEqual(error.description, "SQLite error 9 with statement `DELETE FROM items WHERE 1`: interrupted")
                    } catch {
                        XCTFail("Unexpected error \(error)")
                    }
                    let count = Int.fetchOne(db, "SELECT COUNT(*) from items")!
                    XCTAssertEqual(count, 2)
                }
            }
            let block2 = { () in
                _ = s1.wait(timeout: .distantFuture)
                dbPool.interrupt()
                s2.signal()
            }
            let blocks = [block1, block2]
            DispatchQueue.concurrentPerform(iterations: blocks.count) { index in
                blocks[index]()
            }
        }
    }
    
    func testInterruptTransaction() {
        assertNoError {
            let dbPool = try makeDatabasePool()
            try dbPool.write { db in
                try db.execute("CREATE TABLE items (id INTEGER PRIMARY KEY)")
            }
            
            let s1 = DispatchSemaphore(value: 0)
            let s2 = DispatchSemaphore(value: 0)
            
            let interrupt = DatabaseFunction("interrupt", argumentCount: 0) { _ in
                s1.signal()
                _ = s2.wait(timeout: .distantFuture)
                return nil
            }
            dbPool.add(function: interrupt)
            try dbPool.write { db in
                try db.execute("CREATE TRIGGER interrupt AFTER DELETE ON items BEGIN SELECT interrupt(); END")
            }
            
            let block1 = { () in
                try! dbPool.write { db in
                    try db.execute("INSERT INTO items (id) VALUES (1)")
                    try db.execute("INSERT INTO items (id) VALUES (2)")
                    try db.inTransaction {
                        do {
                            try db.execute("DELETE FROM items WHERE 1") // Avoid truncate optimization
                            XCTFail("Expected error")
                        } catch let error as DatabaseError {
                            XCTAssertEqual(error.code, 9) // SQLITE_INTERRUPT
                            XCTAssertEqual(error.message!, "interrupted")
                            XCTAssertEqual(error.sql!, "DELETE FROM items WHERE 1")
                            XCTAssertEqual(error.description, "SQLite error 9 with statement `DELETE FROM items WHERE 1`: interrupted")
                        } catch {
                            XCTFail("Unexpected error \(error)")
                        }
                        
                        do {
                            try db.execute("INSERT INTO items (id) VALUES (3)")
                            XCTFail("Expected error")
                        } catch let error as DatabaseError {
                            XCTAssertEqual(error.code, 21) // SQLITE_MISUSE
                            XCTAssertEqual(error.message!, "transaction has been rollbacked due to a call to sqlite3_interrupt()")
                            XCTAssertEqual(error.sql!, "INSERT INTO items (id) VALUES (3)")
                            XCTAssertEqual(error.description, "SQLite error 21 with statement `INSERT INTO items (id) VALUES (3)`: transaction has been rollbacked due to a call to sqlite3_interrupt()")
                        } catch {
                            XCTFail("Unexpected error \(error)")
                        }
                        
                        return .commit
                    }
                }
            }
            let block2 = { () in
                _ = s1.wait(timeout: .distantFuture)
                dbPool.interrupt()
                s2.signal()
            }
            let blocks = [block1, block2]
            DispatchQueue.concurrentPerform(iterations: blocks.count) { index in
                blocks[index]()
            }
        }
    }
    
    // TODO: test nested transactions and savepoints
    // TODO: test transaction observers
}
