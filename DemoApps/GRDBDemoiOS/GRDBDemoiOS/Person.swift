import GRDB

class Person: Record {
    var id: Int64?
    var name: String
    var score: Int
    var createdAt: Date
    var sortingDate: Date
    var externalCreator: String
    var externalLink: String
    var externalName: String
    var imageUrl: String
    var invitationCode: String
    var serviceNr: String
    var imageId: Int64
    var ownerId: Int64
    var inviteType: Int
    var replyType: Int
    var isArchived: Bool
    var isDirty: Bool
    var isGroup: Bool
    var isExternal: Bool
    var needsSync: Bool
    var usesGlobalUserName: Bool

    
    init(name: String, score: Int) {
        self.name = name
        self.score = score
        super.init()
    }
    
    // MARK: Record overrides
    
    override class var databaseTableName: String {
        return "persons"
    }
    
    required init(row: Row) {
        id = row.value(named: "id")
        name = row.value(named: "name")
        score = row.value(named: "score")
        super.init(row: row)
    }
    
    override var persistentDictionary: [String : DatabaseValueConvertible?] {
        return [
            "id": id,
            "name": name.databaseValue.value(),
            "score": score.databaseValue.value(),
            "createdAt": createdAt.databaseValue.value(),
            "sortingDate": sortingDate.databaseValue.value(),
            "externalCreator": externalCreator.databaseValue.value(),
            "externalLink": externalLink.databaseValue.value(),
            "externalName": externalName.databaseValue.value(),
            "imageUrl": imageUrl.databaseValue.value(),
            "invitationCode": invitationCode.databaseValue.value(),
            "serviceNr": serviceNr.databaseValue.value(),
            "imageId": imageId.databaseValue.value(),
            "ownerId": ownerId.databaseValue.value(),
            "inviteType": inviteType.databaseValue.value(),
            "replyType": replyType.databaseValue.value(),
            "isArchived": isArchived.databaseValue.value(),
            "isDirty": isDirty.databaseValue.value(),
            "isGroup": isGroup.databaseValue.value(),
            "isExternal": isExternal.databaseValue.value(),
            "needsSync": needsSync.databaseValue.value(),
            "usesGlobalUserName": usesGlobalUserName.databaseValue.value()

        ]
    }
    
    override func didInsert(with rowID: Int64, for column: String?) {
        id = rowID
    }
    
    // MARK: Random
    
    private static let names = ["Arthur", "Anita", "Barbara", "Bernard", "Craig", "Chiara", "David", "Dean", "Éric", "Elena", "Fatima", "Frederik", "Gilbert", "Georgette", "Henriette", "Hassan", "Ignacio", "Irene", "Julie", "Jack", "Karl", "Kristel", "Louis", "Liz", "Masashi", "Mary", "Noam", "Nicole", "Ophelie", "Oleg", "Pascal", "Patricia", "Quentin", "Quinn", "Raoul", "Rachel", "Stephan", "Susie", "Tristan", "Tatiana", "Ursule", "Urbain", "Victor", "Violette", "Wilfried", "Wilhelmina", "Yvon", "Yann", "Zazie", "Zoé"]
    
    class func randomName() -> String {
        return names[Int(arc4random_uniform(UInt32(names.count)))]
    }
    
    class func randomScore() -> Int {
        return 10 * Int(arc4random_uniform(101))
    }

}
