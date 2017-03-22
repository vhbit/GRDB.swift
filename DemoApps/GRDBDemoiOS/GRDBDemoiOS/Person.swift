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
            "name": name,
            "score": score,
            "createdAt": createdAt,
            "sortingDate": sortingDate,
            "externalCreator": externalCreator,
            "externalLink": externalLink,
            "externalName": externalName,
            "imageUrl": imageUrl,
            "invitationCode": invitationCode,
            "serviceNr": serviceNr,
            "imageId": imageId,
            "ownerId": ownerId,
            "inviteType": inviteType,
            "replyType": replyType,
            "isArchived": isArchived,
            "isDirty": isDirty,
            "isGroup": isGroup,
            "isExternal": isExternal,
            "needsSync": needsSync,
            "usesGlobalUserName": usesGlobalUserName

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
