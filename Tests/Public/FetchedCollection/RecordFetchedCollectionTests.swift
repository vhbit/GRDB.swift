import XCTest
#if USING_SQLCIPHER
    import GRDBCipher
#elseif USING_CUSTOMSQLITE
    import GRDBCustomSQLite
#else
    import GRDB
#endif

private class ChangesRecorder<Record: RowConvertible> {
    var recordsBeforeChanges: [Record]!
    var recordsAfterChanges: [Record]!
    var countAfterChanges: Int?
    var transactionExpectation: XCTestExpectation? {
        didSet {
            recordsBeforeChanges = nil
            recordsAfterChanges = nil
            countAfterChanges = nil
        }
    }
    
    func collectionWillChange(_ collection: FetchedCollection<Record>) {
        recordsBeforeChanges = Array(collection)
    }
    
    /// The default implementation does nothing.
    func collectionDidChange(_ collection: FetchedCollection<Record>, count: Int? = nil) {
        recordsAfterChanges = Array(collection)
        countAfterChanges = count
        if let transactionExpectation = transactionExpectation {
            transactionExpectation.fulfill()
        }
    }
}

private class Person : Record {
    var id: Int64?
    let name: String
    let email: String?
    let bookCount: Int?
    
    init(id: Int64? = nil, name: String, email: String? = nil) {
        self.id = id
        self.name = name
        self.email = email
        self.bookCount = nil
        super.init()
    }
    
    required init(row: Row) {
        id = row.value(named: "id")
        name = row.value(named: "name")
        email = row.value(named: "email")
        bookCount = row.value(named: "bookCount")
        super.init(row: row)
    }
    
    override class var databaseTableName: String {
        return "persons"
    }
    
    override var persistentDictionary: [String : DatabaseValueConvertible?] {
        return ["id": id, "name": name, "email": email]
    }
    
    override func didInsert(with rowID: Int64, for column: String?) {
        id = rowID
    }
}

private struct Book : RowConvertible {
    var id: Int64
    var authorID: Int64
    var title: String
    
    init(row: Row) {
        id = row.value(named: "id")
        authorID = row.value(named: "authorID")
        title = row.value(named: "title")
    }
}

class RecordFetchedCollectionTests: GRDBTestCase {

    override func setup(_ dbWriter: DatabaseWriter) throws {
        try dbWriter.write { db in
            try db.create(table: "persons") { t in
                t.column("id", .integer).primaryKey()
                t.column("name", .text)
                t.column("email", .text)
            }
            try db.create(table: "books") { t in
                t.column("id", .integer).primaryKey()
                t.column("authorId", .integer).notNull().references("persons", onDelete: .cascade, onUpdate: .cascade)
                t.column("title", .text)
            }
            try db.create(table: "flowers") { t in
                t.column("id", .integer).primaryKey()
                t.column("name", .text)
            }
        }
    }
    
    func testCollectionFromSQL() {
        assertNoError {
            let dbQueue = try makeDatabaseQueue()
            let authorId: Int64 = try dbQueue.inDatabase { db in
                let plato = Person(name: "Plato")
                try plato.insert(db)
                try db.execute("INSERT INTO books (authorID, title) VALUES (?, ?)", arguments: [plato.id, "Symposium"])
                let cervantes = Person(name: "Cervantes")
                try cervantes.insert(db)
                try db.execute("INSERT INTO books (authorID, title) VALUES (?, ?)", arguments: [cervantes.id, "Don Quixote"])
                return cervantes.id!
            }
            
            let books = try FetchedCollection<Book>(dbQueue, sql: "SELECT * FROM books WHERE authorID = ?", arguments: [authorId])
            try books.fetch()
            XCTAssertEqual(books.count, 1)
            XCTAssertEqual(books[0].title, "Don Quixote")
        }
    }
    
    func testCollectionFromSQLWithAdapter() {
        assertNoError {
            let dbQueue = try makeDatabaseQueue()
            let authorId: Int64 = try dbQueue.inDatabase { db in
                let plato = Person(name: "Plato")
                try plato.insert(db)
                try db.execute("INSERT INTO books (authorID, title) VALUES (?, ?)", arguments: [plato.id, "Symposium"])
                let cervantes = Person(name: "Cervantes")
                try cervantes.insert(db)
                try db.execute("INSERT INTO books (authorID, title) VALUES (?, ?)", arguments: [cervantes.id, "Don Quixote"])
                return cervantes.id!
            }
            
            let adapter = ColumnMapping(["id": "_id", "authorId": "_authorId", "title": "_title"])
            let books = try FetchedCollection<Book>(dbQueue, sql: "SELECT id AS _id, authorId AS _authorId, title AS _title FROM books WHERE authorID = ?", arguments: [authorId], adapter: adapter)
            try books.fetch()
            XCTAssertEqual(books.count, 1)
            XCTAssertEqual(books[0].title, "Don Quixote")
        }
    }
    
    func testCollectionFromRequest() {
        assertNoError {
            let dbQueue = try makeDatabaseQueue()
            try dbQueue.inDatabase { db in
                try Person(name: "Plato").insert(db)
                try Person(name: "Cervantes").insert(db)
            }
            
            let request = Person.order(Column("name"))
            let persons = try FetchedCollection(dbQueue, request: request)
            try persons.fetch()
            XCTAssertEqual(persons.count, 2)
            XCTAssertEqual(persons[0].name, "Cervantes")
            XCTAssertEqual(persons[1].name, "Plato")
        }
    }
    
    // TODO: obsolete test
    func testRecordsAreNotLoadedUntilPerformFetch() {
        assertNoError {
            let dbQueue = try makeDatabaseQueue()
            let arthur = Person(name: "Arthur")
            try dbQueue.inDatabase { db in
                try arthur.insert(db)
            }
            
            let request = Person.all()
            let persons = try FetchedCollection(dbQueue, request: request)
            try persons.fetch()
            XCTAssertEqual(persons.count, 1)
            XCTAssertEqual(persons[0].name, "Arthur")
        }
    }
    
    func testDatabaseChangesAreNotReReflectedUntilFetchAndTrackingIsSet() {
        // TODO: test that FetchedCollection contents do not eventually change
        // after a database change. The difficulty of this test lies in the
        // "eventually" word.
    }

    func testSimpleInsert() {
        assertNoError {
            let dbQueue = try makeDatabaseQueue()
            let persons = try FetchedCollection(dbQueue, request: Person.order(Column("id")))
            let recorder = ChangesRecorder<Person>()
            persons.trackChanges(
                willChange: { recorder.collectionWillChange($0) },
                didChange: { recorder.collectionDidChange($0) })
            try persons.fetch()
            
            // First insert
            recorder.transactionExpectation = expectation(description: "expectation")
            try dbQueue.inTransaction { db in
                try synchronizePersons(db, [
                    Person(id: 1, name: "Arthur")])
                return .commit
            }
            waitForExpectations(timeout: 1, handler: nil)
            
            XCTAssertEqual(recorder.recordsBeforeChanges.count, 0)
            XCTAssertEqual(recorder.recordsAfterChanges.count, 1)
            XCTAssertEqual(recorder.recordsAfterChanges.map { $0.name }, ["Arthur"])
            
            // Second insert
            recorder.transactionExpectation = expectation(description: "expectation")
            try dbQueue.inTransaction { db in
                try synchronizePersons(db, [
                    Person(id: 1, name: "Arthur"),
                    Person(id: 2, name: "Barbara")])
                return .commit
            }
            waitForExpectations(timeout: 1, handler: nil)
            
            XCTAssertEqual(recorder.recordsBeforeChanges.count, 1)
            XCTAssertEqual(recorder.recordsBeforeChanges.map { $0.name }, ["Arthur"])
            XCTAssertEqual(recorder.recordsAfterChanges.count, 2)
            XCTAssertEqual(recorder.recordsAfterChanges.map { $0.name }, ["Arthur", "Barbara"])
        }
    }
    
    func testExternalTableChange() {
        // TODO: test that delegate is not notified after a database change in a
        // table not involved in the fetch request. The difficulty of this test
        // lies in the "not" word.
    }
    
    func testCustomRecordIdentity() {
        // TODO: test record comparison not based on primary key but based on
        // custom function
    }
}


// Synchronizes the persons table with a JSON payload
private func synchronizePersons(_ db: Database, _ newPersons: [Person]) throws {
    // Sort new persons and database persons by id:
    let newPersons = newPersons.sorted { $0.id! < $1.id! }
    let databasePersons = try Person.fetchAll(db, "SELECT * FROM persons ORDER BY id")
    
    // Now that both lists are sorted by id, we can compare them with
    // the sortedMerge() function.
    //
    // We'll delete, insert or update persons, depending on their presence
    // in either lists.
    let steps = sortedMerge(
        left: databasePersons,
        right: newPersons,
        leftKey: { $0.id! },
        rightKey: { $0.id! })
    for mergeStep in steps {
        switch mergeStep {
        case .left(let databasePerson):
            try databasePerson.delete(db)
        case .right(let newPerson):
            try newPerson.insert(db)
        case .common(_, let newPerson):
            try newPerson.update(db)
        }
    }
}


/// Given two sorted sequences (left and right), this function emits "merge steps"
/// which tell whether elements are only found on the left, on the right, or on
/// both sides.
///
/// Both sequences do not have to share the same element type. Yet elements must
/// share a common comparable *key*.
///
/// Both sequences must be sorted by this key.
///
/// Keys must be unique in both sequences.
///
/// The example below compare two sequences sorted by integer representation,
/// and prints:
///
/// - Left: 1
/// - Common: 2, 2
/// - Common: 3, 3
/// - Right: 4
///
///     for mergeStep in sortedMerge(
///         left: [1,2,3],
///         right: ["2", "3", "4"],
///         leftKey: { $0 },
///         rightKey: { Int($0)! })
///     {
///         switch mergeStep {
///         case .left(let left):
///             print("- Left: \(left)")
///         case .right(let right):
///             print("- Right: \(right)")
///         case .common(let left, let right):
///             print("- Common: \(left), \(right)")
///         }
///     }
///
/// - parameters:
///     - left: The left sequence.
///     - right: The right sequence.
///     - leftKey: A function that returns the key of a left element.
///     - rightKey: A function that returns the key of a right element.
/// - returns: A sequence of MergeStep
private func sortedMerge<LeftSequence: Sequence, RightSequence: Sequence, Key: Comparable>(
    left lSeq: LeftSequence,
    right rSeq: RightSequence,
    leftKey: @escaping (LeftSequence.Iterator.Element) -> Key,
    rightKey: @escaping (RightSequence.Iterator.Element) -> Key) -> AnySequence<MergeStep<LeftSequence.Iterator.Element, RightSequence.Iterator.Element>>
{
    return AnySequence { () -> AnyIterator<MergeStep<LeftSequence.Iterator.Element, RightSequence.Iterator.Element>> in
        var (lGen, rGen) = (lSeq.makeIterator(), rSeq.makeIterator())
        var (lOpt, rOpt) = (lGen.next(), rGen.next())
        return AnyIterator {
            switch (lOpt, rOpt) {
            case (let lElem?, let rElem?):
                let (lKey, rKey) = (leftKey(lElem), rightKey(rElem))
                if lKey > rKey {
                    rOpt = rGen.next()
                    return .right(rElem)
                } else if lKey == rKey {
                    (lOpt, rOpt) = (lGen.next(), rGen.next())
                    return .common(lElem, rElem)
                } else {
                    lOpt = lGen.next()
                    return .left(lElem)
                }
            case (nil, let rElem?):
                rOpt = rGen.next()
                return .right(rElem)
            case (let lElem?, nil):
                lOpt = lGen.next()
                return .left(lElem)
            case (nil, nil):
                return nil
            }
        }
    }
}

/**
 Support for sortedMerge()
 */
private enum MergeStep<LeftElement, RightElement> {
    /// An element only found in the left sequence:
    case left(LeftElement)
    /// An element only found in the right sequence:
    case right(RightElement)
    /// Left and right elements share a common key:
    case common(LeftElement, RightElement)
}
