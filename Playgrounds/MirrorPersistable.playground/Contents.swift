//: Playground - noun: a place where people can play

import GRDB

struct Foo : Persistable, MirrorPersistable {
    let id: Int64?
    let name: String
    
    static var databaseTableName: String { return "foos" }
}

class Bar: Record, MirrorPersistable {
    let id: Int64?
    let name: String
    
    init(id: Int64?, name: String) {
        self.id = id
        self.name = name
        super.init()
    }
    
    override class var databaseTableName: String { return "foos" }
    
    required init(row: Row) {
        self.id = row.value(named: "id")
        self.name = row.value(named: "name")
        super.init(row: row)
    }
}

Foo(id: nil, name: "foo").persistentDictionary
Foo(id: 1, name: "foo").persistentDictionary
Bar(id: nil, name: "bar").persistentDictionary
Bar(id: 1, name: "bar").persistentDictionary

var config = Configuration()
config.trace = { print($0) }
let dbQueue = DatabaseQueue(configuration: config)
try! dbQueue.inDatabase { db in
    try db.create(table: "foos") { t in
        t.column("id", .integer).primaryKey()
        t.column("name", .text)
    }
    try Foo(id: nil, name: "foo").insert(db)
    try Bar(id: nil, name: "bar").insert(db)
}


struct T { }
struct U : MirrorPersistable {
    let t: T?
}
U(t: nil).persistentDictionary // ["t": nil]
U(t: T()).persistentDictionary // [:]
