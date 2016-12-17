import Foundation

/// RequestObserver adopts TransactionObserverType so that it can
/// monitor changes to its fetched records.
final class RequestObserver<Fetched> : TransactionObserver {
    var isValid: Bool
    var needsComputeChanges: Bool
    var items: [AnyFetchable<Fetched>]!  // ought to be not nil when observer has started tracking transactions
    let queue: DispatchQueue // protects items
    let selectionInfo: SelectStatement.SelectionInfo
    var fetchAndNotifyChanges: (RequestObserver<Fetched>) -> ()
    
    init(selectionInfo: SelectStatement.SelectionInfo, fetchAndNotifyChanges: @escaping (RequestObserver<Fetched>) -> ()) {
        self.isValid = true
        self.items = nil
        self.needsComputeChanges = false
        self.queue = DispatchQueue(label: "GRDB.RequestObserver")
        self.selectionInfo = selectionInfo
        self.fetchAndNotifyChanges = fetchAndNotifyChanges
    }
    
    func invalidate() {
        isValid = false
    }
    
    func observes(eventsOfKind eventKind: DatabaseEventKind) -> Bool {
        switch eventKind {
        case .delete(let tableName):
            return selectionInfo.contains(anyColumnFrom: tableName)
        case .insert(let tableName):
            return selectionInfo.contains(anyColumnFrom: tableName)
        case .update(let tableName, let updatedColumnNames):
            return selectionInfo.contains(anyColumnIn: updatedColumnNames, from: tableName)
        }
    }
    
    #if SQLITE_ENABLE_PREUPDATE_HOOK
    /// Part of the TransactionObserverType protocol
    func databaseWillChange(with event: DatabasePreUpdateEvent) { }
    #endif
    
    /// Part of the TransactionObserverType protocol
    func databaseDidChange(with event: DatabaseEvent) {
        needsComputeChanges = true
    }
    
    /// Part of the TransactionObserverType protocol
    func databaseWillCommit() throws { }
    
    /// Part of the TransactionObserverType protocol
    func databaseDidRollback(_ db: Database) {
        needsComputeChanges = false
    }
    
    /// Part of the TransactionObserverType protocol
    func databaseDidCommit(_ db: Database) {
        // The databaseDidCommit callback is called in the database writer
        // dispatch queue, which is serialized: it is guaranteed to process the
        // last database transaction.
        
        // Were observed tables modified?
        guard needsComputeChanges else { return }
        needsComputeChanges = false
        
        fetchAndNotifyChanges(self)
    }
}
