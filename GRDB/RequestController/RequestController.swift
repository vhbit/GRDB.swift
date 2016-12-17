/// You use RequestController to track changes in the results of an
/// SQLite request.
///
/// On iOS, RequestController can feed a UITableView, and animate rows
/// when the results of the request change.
///
/// See https://github.com/groue/GRDB.swift#fetchedrecordscontroller for
/// more information.
public final class RequestController<Fetched> {
    // The items
    fileprivate var fetchedItems: [AnyFetchable<Fetched>]?
    
    #if os(iOS)
    // The record comparator
    fileprivate var elementsAreTheSame: ItemComparator<Fetched>
    #endif
    
    // The request
    fileprivate var request: ObservedRequest<Fetched>
    
    // The eventual current database observer
    fileprivate var observer: FetchedRecordsObserver<Fetched>?
    
    // The eventual error handler
    fileprivate var errorHandler: ((RequestController<Fetched>, Error) -> ())?
    
    // MARK: - Initialization
    
    #if os(iOS)
    /// Creates a fetched records controller initialized from a SQL query and
    /// its eventual arguments.
    ///
    ///     let controller = RequestController<Wine>(
    ///         dbQueue,
    ///         sql: "SELECT * FROM wines WHERE color = ? ORDER BY name",
    ///         arguments: [Color.red],
    ///         isSameElement: { (wine1, wine2) in wine1.id == wine2.id })
    ///
    /// - parameters:
    ///     - databaseWriter: A DatabaseWriter (DatabaseQueue, or DatabasePool)
    ///     - sql: An SQL query.
    ///     - arguments: Optional statement arguments.
    ///     - adapter: Optional RowAdapter
    ///     - queue: Optional dispatch queue (defaults to the main queue)
    ///
    ///         The fetched records controller delegate will be notified of
    ///         record changes in this queue. The controller itself must be used
    ///         from this queue.
    ///
    ///         This dispatch queue must be serial.
    ///
    ///     - isSameElement: Optional function that compares two records.
    ///
    ///         This function should return true if the two records have the
    ///         same identity. For example, they have the same id.
    public convenience init(_ databaseWriter: DatabaseWriter, sql: String, arguments: StatementArguments? = nil, adapter: RowAdapter? = nil, queue: DispatchQueue = .main) throws {
        try self.init(databaseWriter, request: SQLRequest(sql, arguments: arguments, adapter: adapter).bound(to: Fetched.self), queue: queue, elementsAreTheSame: { _ in false })
    }
    
    fileprivate init<Request>(_ databaseWriter: DatabaseWriter, request: Request, queue: DispatchQueue, elementsAreTheSame: @escaping ItemComparator<Fetched>) throws where Request: TypedRequest, Request.Fetched == Fetched {
        self.request = try databaseWriter.read { db in try ObservedRequest(db, request: request) }
        self.databaseWriter = databaseWriter
        self.elementsAreTheSame = elementsAreTheSame
        self.queue = queue
    }
    #else
    /// Creates a fetched records controller initialized from a SQL query and
    /// its eventual arguments.
    ///
    ///     let controller = RequestController<Wine>(
    ///         dbQueue,
    ///         sql: "SELECT * FROM wines WHERE color = ? ORDER BY name",
    ///         arguments: [Color.red])
    ///
    /// - parameters:
    ///     - databaseWriter: A DatabaseWriter (DatabaseQueue, or DatabasePool)
    ///     - sql: An SQL query.
    ///     - arguments: Optional statement arguments.
    ///     - adapter: Optional RowAdapter
    ///     - queue: Optional dispatch queue (defaults to the main queue)
    ///
    ///         The fetched records controller delegate will be notified of
    ///         record changes in this queue. The controller itself must be used
    ///         from this queue.
    ///
    ///         This dispatch queue must be serial.
    public convenience init(_ databaseWriter: DatabaseWriter, sql: String, arguments: StatementArguments? = nil, adapter: RowAdapter? = nil, queue: DispatchQueue = .main) throws {
        try self.init(databaseWriter, request: SQLRequest(sql, arguments: arguments, adapter: adapter).bound(to: Fetched.self), queue: queue)
    }
    
    /// Creates a fetched records controller initialized from a fetch request
    /// from the [Query Interface](https://github.com/groue/GRDB.swift#the-query-interface).
    ///
    ///     let request = Wine.order(Column("name"))
    ///     let controller = RequestController<Wine>(
    ///         dbQueue,
    ///         request: request)
    ///
    /// - parameters:
    ///     - databaseWriter: A DatabaseWriter (DatabaseQueue, or DatabasePool)
    ///     - request: A fetch request.
    ///     - queue: Optional dispatch queue (defaults to the main queue)
    ///
    ///         The fetched records controller delegate will be notified of
    ///         record changes in this queue. The controller itself must be used
    ///         from this queue.
    ///
    ///         This dispatch queue must be serial.
    public init<Request>(_ databaseWriter: DatabaseWriter, request: Request, queue: DispatchQueue = .main) throws where Request: TypedRequest, Request.Fetched == Fetched {
        self.request = try databaseWriter.read { db in try ObservedRequest(db, request: request) }
        self.databaseWriter = databaseWriter
        self.queue = queue
    }
    #endif
    
    /// Executes the controller's fetch request.
    ///
    /// After executing this method, you can access the the fetched objects with
    /// the property fetchedRecords.
    public func performFetch() throws {
        // If some changes are currently processed, make sure they are
        // discarded. But preserve eventual changes processing for future
        // changes.
        let fetchAndNotifyChanges = observer?.fetchAndNotifyChanges
        observer?.invalidate()
        observer = nil
        
        // Fetch items on the writing dispatch queue, so that the transaction
        // observer is added on the same serialized queue as transaction
        // callbacks.
        try databaseWriter.write { db in
            let initialItems = try request.fetchAll(db)
            fetchedItems = initialItems
            if let fetchAndNotifyChanges = fetchAndNotifyChanges {
                let observer = FetchedRecordsObserver(selectionInfo: request.selectionInfo, fetchAndNotifyChanges: fetchAndNotifyChanges)
                self.observer = observer
                observer.items = initialItems
                db.add(transactionObserver: observer)
            }
        }
    }
    
    
    // MARK: - Configuration
    
    /// The database writer used to fetch records.
    ///
    /// The controller registers as a transaction observer in order to respond
    /// to changes.
    public let databaseWriter: DatabaseWriter
    
    /// The dispatch queue on which the controller must be used.
    ///
    /// Unless specified otherwise at initialization time, it is the main queue.
    public let queue: DispatchQueue
    
    /// Updates the fetch request, and notifies the delegate of changes in the
    /// fetched records if delegate is not nil, and performFetch() has been
    /// called.
    public func setRequest<Request>(_ request: Request) throws where Request: TypedRequest, Request.Fetched == Fetched {
        self.request = try databaseWriter.read { db in try ObservedRequest(db, request: request) }
        
        // No observer: don't look for changes
        guard let observer = observer else { return }
        
        // If some changes are currently processed, make sure they are
        // discarded. But preserve eventual changes processing.
        let fetchAndNotifyChanges = observer.fetchAndNotifyChanges
        observer.invalidate()
        self.observer = nil
        
        // Replace observer so that it tracks a new set of columns,
        // and notify eventual changes
        let initialItems = fetchedItems
        databaseWriter.write { db in
            let observer = FetchedRecordsObserver(selectionInfo: self.request.selectionInfo, fetchAndNotifyChanges: fetchAndNotifyChanges)
            self.observer = observer
            observer.items = initialItems
            db.add(transactionObserver: observer)
            observer.fetchAndNotifyChanges(observer)
        }
    }
    
    /// Updates the fetch request, and notifies the delegate of changes in the
    /// fetched records if delegate is not nil, and performFetch() has been
    /// called.
    public func setRequest(sql: String, arguments: StatementArguments? = nil, adapter: RowAdapter? = nil) throws {
        try setRequest(SQLRequest(sql, arguments: arguments, adapter: adapter).bound(to: Fetched.self))
    }
    
    #if os(iOS)
    #else
    /// Registers changes notification callbacks.
    ///
    /// - parameters:
    ///     - recordsWillChange: Invoked before records are updated.
    ///     - recordsDidChange: Invoked after records have been updated.
    public func trackChanges(
        recordsWillChange: ((RequestController<Fetched>) -> ())? = nil,
        recordsDidChange: ((RequestController<Fetched>) -> ())? = nil)
    {
        trackChanges(
            fetchAlongside: { _ in },
            recordsWillChange: recordsWillChange.flatMap { callback in { (controller, _) in callback(controller) } },
            recordsDidChange: recordsDidChange.flatMap { callback in { (controller, _) in callback(controller) } })
    }
    #endif
    
    /// Registers a callback for changes tracking errors.
    ///
    /// Whenever the controller could not look for changes after a transaction
    /// has potentially modified the tracked request, this error handler is
    /// called.
    ///
    /// The request observation is not stopped, though: future transactions may
    /// successfully be handled, and the notified changes will then be based on
    /// the last successful fetch.
    public func trackErrors(_ errorHandler: @escaping (RequestController<Fetched>, Error) -> ()) {
        self.errorHandler = errorHandler
    }
}

#if os(iOS)
    extension RequestController where Fetched: Row {
        /// Registers changes notification callbacks (iOS only).
        ///
        /// - parameters:
        ///     - recordsWillChange: Invoked before records are updated.
        ///     - tableViewEvent: Invoked for each record that has been added,
        ///       removed, moved, or updated.
        ///     - recordsDidChange: Invoked after records have been updated.
        public func trackChanges(
            recordsWillChange: ((RequestController<Fetched>) -> ())? = nil,
            tableViewEvent: ((RequestController<Fetched>, Fetched, TableViewEvent) -> ())? = nil,
            recordsDidChange: ((RequestController<Fetched>) -> ())? = nil)
        {
            trackChanges(
                fetchAlongside: { _ in },
                recordsWillChange: recordsWillChange.map { recordsWillChange in { (controller, _) in recordsWillChange(controller) } },
                tableViewEvent: tableViewEvent,
                recordsDidChange: recordsDidChange.map { recordsDidChange in { (controller, _) in recordsDidChange(controller) } })
        }
        
        /// Registers changes notification callbacks (iOS only).
        ///
        /// - parameters:
        ///     - fetchAlongside: The value returned from this closure is given to
        ///       recordsWillChange and recordsDidChange callbacks, as their
        ///       `fetchedAlongside` argument. The closure is guaranteed to see the
        ///       database in the state it has just after eventual changes to the
        ///       fetched records have been performed. Use it in order to fetch
        ///       values that must be consistent with the fetched records.
        ///     - recordsWillChange: Invoked before records are updated.
        ///     - tableViewEvent: Invoked for each record that has been added,
        ///       removed, moved, or updated.
        ///     - recordsDidChange: Invoked after records have been updated.
        public func trackChanges<T>(
            fetchAlongside: @escaping (Database) throws -> T,
            recordsWillChange: ((RequestController<Fetched>, _ fetchedAlongside: T) -> ())? = nil,
            tableViewEvent: ((RequestController<Fetched>, Fetched, TableViewEvent) -> ())? = nil,
            recordsDidChange: ((RequestController<Fetched>, _ fetchedAlongside: T) -> ())? = nil)
        {
            // If some changes are currently processed, make sure they are
            // discarded because they would trigger previously set callbacks.
            observer?.invalidate()
            observer = nil
            
            guard (recordsWillChange != nil) || (tableViewEvent != nil) || (recordsDidChange != nil) else {
                // Stop tracking
                return
            }
            
            let initialItems = fetchedItems
            databaseWriter.write { db in
                let fetchAndNotifyChanges = makeFetchAndNotifyChangesFunction(
                    controller: self,
                    fetchAlongside: fetchAlongside,
                    elementsAreTheSame: elementsAreTheSame,
                    recordsWillChange: recordsWillChange,
                    handleChanges: tableViewEvent.map { tableViewEvent in
                        { (controller, changes) in
                            for change in changes {
                                tableViewEvent(controller, change.value, change.event)
                            }
                        }
                }, recordsDidChange: recordsDidChange)
                let observer = FetchedRecordsObserver(selectionInfo: request.selectionInfo, fetchAndNotifyChanges: fetchAndNotifyChanges)
                self.observer = observer
                if let initialItems = initialItems {
                    observer.items = initialItems
                    db.add(transactionObserver: observer)
                    observer.fetchAndNotifyChanges(observer)
                }
            }
        }
    }
    
    extension RequestController where Fetched: RowConvertible {
        /// Registers changes notification callbacks (iOS only).
        ///
        /// - parameters:
        ///     - recordsWillChange: Invoked before records are updated.
        ///     - tableViewEvent: Invoked for each record that has been added,
        ///       removed, moved, or updated.
        ///     - recordsDidChange: Invoked after records have been updated.
        public func trackChanges(
            recordsWillChange: ((RequestController<Fetched>) -> ())? = nil,
            tableViewEvent: ((RequestController<Fetched>, Fetched, TableViewEvent) -> ())? = nil,
            recordsDidChange: ((RequestController<Fetched>) -> ())? = nil)
        {
            trackChanges(
                fetchAlongside: { _ in },
                recordsWillChange: recordsWillChange.map { recordsWillChange in { (controller, _) in recordsWillChange(controller) } },
                tableViewEvent: tableViewEvent,
                recordsDidChange: recordsDidChange.map { recordsDidChange in { (controller, _) in recordsDidChange(controller) } })
        }
        
        /// Registers changes notification callbacks (iOS only).
        ///
        /// - parameters:
        ///     - fetchAlongside: The value returned from this closure is given to
        ///       recordsWillChange and recordsDidChange callbacks, as their
        ///       `fetchedAlongside` argument. The closure is guaranteed to see the
        ///       database in the state it has just after eventual changes to the
        ///       fetched records have been performed. Use it in order to fetch
        ///       values that must be consistent with the fetched records.
        ///     - recordsWillChange: Invoked before records are updated.
        ///     - tableViewEvent: Invoked for each record that has been added,
        ///       removed, moved, or updated.
        ///     - recordsDidChange: Invoked after records have been updated.
        public func trackChanges<T>(
            fetchAlongside: @escaping (Database) throws -> T,
            recordsWillChange: ((RequestController<Fetched>, _ fetchedAlongside: T) -> ())? = nil,
            tableViewEvent: ((RequestController<Fetched>, Fetched, TableViewEvent) -> ())? = nil,
            recordsDidChange: ((RequestController<Fetched>, _ fetchedAlongside: T) -> ())? = nil)
        {
            // If some changes are currently processed, make sure they are
            // discarded because they would trigger previously set callbacks.
            observer?.invalidate()
            observer = nil
            
            guard (recordsWillChange != nil) || (tableViewEvent != nil) || (recordsDidChange != nil) else {
                // Stop tracking
                return
            }
            
            let initialItems = fetchedItems
            databaseWriter.write { db in
                let fetchAndNotifyChanges = makeFetchAndNotifyChangesFunction(
                    controller: self,
                    fetchAlongside: fetchAlongside,
                    elementsAreTheSame: elementsAreTheSame,
                    recordsWillChange: recordsWillChange,
                    handleChanges: tableViewEvent.map { tableViewEvent in
                        { (controller, changes) in
                            for change in changes {
                                tableViewEvent(controller, change.value, change.event)
                            }
                        }
                }, recordsDidChange: recordsDidChange)
                let observer = FetchedRecordsObserver(selectionInfo: request.selectionInfo, fetchAndNotifyChanges: fetchAndNotifyChanges)
                self.observer = observer
                if let initialItems = initialItems {
                    observer.items = initialItems
                    db.add(transactionObserver: observer)
                    observer.fetchAndNotifyChanges(observer)
                }
            }
        }
    }
    
    extension RequestController where Fetched: DatabaseValueConvertible {
        /// Registers changes notification callbacks (iOS only).
        ///
        /// - parameters:
        ///     - recordsWillChange: Invoked before records are updated.
        ///     - tableViewEvent: Invoked for each record that has been added,
        ///       removed, moved, or updated.
        ///     - recordsDidChange: Invoked after records have been updated.
        public func trackChanges(
            recordsWillChange: ((RequestController<Fetched>) -> ())? = nil,
            tableViewEvent: ((RequestController<Fetched>, Fetched, TableViewEvent) -> ())? = nil,
            recordsDidChange: ((RequestController<Fetched>) -> ())? = nil)
        {
            trackChanges(
                fetchAlongside: { _ in },
                recordsWillChange: recordsWillChange.map { recordsWillChange in { (controller, _) in recordsWillChange(controller) } },
                tableViewEvent: tableViewEvent,
                recordsDidChange: recordsDidChange.map { recordsDidChange in { (controller, _) in recordsDidChange(controller) } })
        }
        
        /// Registers changes notification callbacks (iOS only).
        ///
        /// - parameters:
        ///     - fetchAlongside: The value returned from this closure is given to
        ///       recordsWillChange and recordsDidChange callbacks, as their
        ///       `fetchedAlongside` argument. The closure is guaranteed to see the
        ///       database in the state it has just after eventual changes to the
        ///       fetched records have been performed. Use it in order to fetch
        ///       values that must be consistent with the fetched records.
        ///     - recordsWillChange: Invoked before records are updated.
        ///     - tableViewEvent: Invoked for each record that has been added,
        ///       removed, moved, or updated.
        ///     - recordsDidChange: Invoked after records have been updated.
        public func trackChanges<T>(
            fetchAlongside: @escaping (Database) throws -> T,
            recordsWillChange: ((RequestController<Fetched>, _ fetchedAlongside: T) -> ())? = nil,
            tableViewEvent: ((RequestController<Fetched>, Fetched, TableViewEvent) -> ())? = nil,
            recordsDidChange: ((RequestController<Fetched>, _ fetchedAlongside: T) -> ())? = nil)
        {
            // If some changes are currently processed, make sure they are
            // discarded because they would trigger previously set callbacks.
            observer?.invalidate()
            observer = nil
            
            guard (recordsWillChange != nil) || (tableViewEvent != nil) || (recordsDidChange != nil) else {
                // Stop tracking
                return
            }
            
            let initialItems = fetchedItems
            databaseWriter.write { db in
                let fetchAndNotifyChanges = makeFetchAndNotifyChangesFunction(
                    controller: self,
                    fetchAlongside: fetchAlongside,
                    elementsAreTheSame: elementsAreTheSame,
                    recordsWillChange: recordsWillChange,
                    handleChanges: tableViewEvent.map { tableViewEvent in
                        { (controller, changes) in
                            for change in changes {
                                tableViewEvent(controller, change.value, change.event)
                            }
                        }
                }, recordsDidChange: recordsDidChange)
                let observer = FetchedRecordsObserver(selectionInfo: request.selectionInfo, fetchAndNotifyChanges: fetchAndNotifyChanges)
                self.observer = observer
                if let initialItems = initialItems {
                    observer.items = initialItems
                    db.add(transactionObserver: observer)
                    observer.fetchAndNotifyChanges(observer)
                }
            }
        }
    }
    
    extension RequestController where Fetched: _OptionalFetchable, Fetched._Wrapped: DatabaseValueConvertible {
        /// Registers changes notification callbacks (iOS only).
        ///
        /// - parameters:
        ///     - recordsWillChange: Invoked before records are updated.
        ///     - tableViewEvent: Invoked for each record that has been added,
        ///       removed, moved, or updated.
        ///     - recordsDidChange: Invoked after records have been updated.
        public func trackChanges(
            recordsWillChange: ((RequestController<Fetched>) -> ())? = nil,
            tableViewEvent: ((RequestController<Fetched>, Fetched, TableViewEvent) -> ())? = nil,
            recordsDidChange: ((RequestController<Fetched>) -> ())? = nil)
        {
            trackChanges(
                fetchAlongside: { _ in },
                recordsWillChange: recordsWillChange.map { recordsWillChange in { (controller, _) in recordsWillChange(controller) } },
                tableViewEvent: tableViewEvent,
                recordsDidChange: recordsDidChange.map { recordsDidChange in { (controller, _) in recordsDidChange(controller) } })
        }
        
        /// Registers changes notification callbacks (iOS only).
        ///
        /// - parameters:
        ///     - fetchAlongside: The value returned from this closure is given to
        ///       recordsWillChange and recordsDidChange callbacks, as their
        ///       `fetchedAlongside` argument. The closure is guaranteed to see the
        ///       database in the state it has just after eventual changes to the
        ///       fetched records have been performed. Use it in order to fetch
        ///       values that must be consistent with the fetched records.
        ///     - recordsWillChange: Invoked before records are updated.
        ///     - tableViewEvent: Invoked for each record that has been added,
        ///       removed, moved, or updated.
        ///     - recordsDidChange: Invoked after records have been updated.
        public func trackChanges<T>(
            fetchAlongside: @escaping (Database) throws -> T,
            recordsWillChange: ((RequestController<Fetched>, _ fetchedAlongside: T) -> ())? = nil,
            tableViewEvent: ((RequestController<Fetched>, Fetched, TableViewEvent) -> ())? = nil,
            recordsDidChange: ((RequestController<Fetched>, _ fetchedAlongside: T) -> ())? = nil)
        {
            // If some changes are currently processed, make sure they are
            // discarded because they would trigger previously set callbacks.
            observer?.invalidate()
            observer = nil
            
            guard (recordsWillChange != nil) || (tableViewEvent != nil) || (recordsDidChange != nil) else {
                // Stop tracking
                return
            }
            
            let initialItems = fetchedItems
            databaseWriter.write { db in
                let fetchAndNotifyChanges = makeFetchAndNotifyChangesFunction(
                    controller: self,
                    fetchAlongside: fetchAlongside,
                    elementsAreTheSame: elementsAreTheSame,
                    recordsWillChange: recordsWillChange,
                    handleChanges: tableViewEvent.map { tableViewEvent in
                        { (controller, changes) in
                            for change in changes {
                                tableViewEvent(controller, change.value, change.event)
                            }
                        }
                }, recordsDidChange: recordsDidChange)
                let observer = FetchedRecordsObserver(selectionInfo: request.selectionInfo, fetchAndNotifyChanges: fetchAndNotifyChanges)
                self.observer = observer
                if let initialItems = initialItems {
                    observer.items = initialItems
                    db.add(transactionObserver: observer)
                    observer.fetchAndNotifyChanges(observer)
                }
            }
        }
    }
#else
    extension RequestController {
        /// Registers changes notification callbacks.
        ///
        /// - parameters:
        ///     - fetchAlongside: The value returned from this closure is given to
        ///       recordsWillChange and recordsDidChange callbacks, as their
        ///       `fetchedAlongside` argument. The closure is guaranteed to see the
        ///       database in the state it has just after eventual changes to the
        ///       fetched records have been performed. Use it in order to fetch
        ///       values that must be consistent with the fetched records.
        ///     - recordsWillChange: Invoked before records are updated.
        ///     - recordsDidChange: Invoked after records have been updated.
        public func trackChanges<T>(
            fetchAlongside: @escaping (Database) throws -> T,
            recordsWillChange: ((RequestController<Fetched>, _ fetchedAlongside: T) -> ())? = nil,
            recordsDidChange: ((RequestController<Fetched>, _ fetchedAlongside: T) -> ())? = nil)
        {
            // If some changes are currently processed, make sure they are
            // discarded because they would trigger previously set callbacks.
            observer?.invalidate()
            observer = nil
            
            guard (recordsWillChange != nil) || (recordsDidChange != nil) else {
                // Stop tracking
                return
            }
            
            let initialItems = fetchedItems
            databaseWriter.write { db in
                let fetchAndNotifyChanges = makeFetchAndNotifyChangesFunction(controller: self, fetchAlongside: fetchAlongside, recordsWillChange: recordsWillChange, recordsDidChange: recordsDidChange)
                let observer = FetchedRecordsObserver(selectionInfo: request.selectionInfo, fetchAndNotifyChanges: fetchAndNotifyChanges)
                self.observer = observer
                if let initialItems = initialItems {
                    observer.items = initialItems
                    db.add(transactionObserver: observer)
                    observer.fetchAndNotifyChanges(observer)
                }
            }
        }
    }
#endif

#if os(iOS)
    extension RequestController where Fetched: Row {
        
        // MARK: - Initialization
        
        /// Creates a fetched records controller initialized from a SQL query and
        /// its eventual arguments.
        ///
        ///     let controller = RequestController<Wine>(
        ///         dbQueue,
        ///         sql: "SELECT * FROM wines WHERE color = ? ORDER BY name",
        ///         arguments: [Color.red],
        ///         isSameElement: { (wine1, wine2) in wine1.id == wine2.id })
        ///
        /// - parameters:
        ///     - databaseWriter: A DatabaseWriter (DatabaseQueue, or DatabasePool)
        ///     - sql: An SQL query.
        ///     - arguments: Optional statement arguments.
        ///     - adapter: Optional RowAdapter
        ///     - queue: Optional dispatch queue (defaults to the main queue)
        ///
        ///         The fetched records controller delegate will be notified of
        ///         record changes in this queue. The controller itself must be used
        ///         from this queue.
        ///
        ///         This dispatch queue must be serial.
        ///
        ///     - isSameElement: Optional function that compares two records.
        ///
        ///         This function should return true if the two records have the
        ///         same identity. For example, they have the same id.
        public convenience init(_ databaseWriter: DatabaseWriter, sql: String, arguments: StatementArguments? = nil, adapter: RowAdapter? = nil, queue: DispatchQueue = .main, isSameElement: @escaping (Fetched, Fetched) -> Bool) throws {
            try self.init(databaseWriter, request: SQLRequest(sql, arguments: arguments, adapter: adapter).bound(to: Fetched.self), queue: queue, elementsAreTheSame: { isSameElement($0.value, $1.value) })
        }
        
        /// Creates a fetched records controller initialized from a fetch request
        /// from the [Query Interface](https://github.com/groue/GRDB.swift#the-query-interface).
        ///
        ///     let request = Wine.order(Column("name"))
        ///     let controller = RequestController<Wine>(
        ///         dbQueue,
        ///         request: request,
        ///         isSameElement: { (wine1, wine2) in wine1.id == wine2.id })
        ///
        /// - parameters:
        ///     - databaseWriter: A DatabaseWriter (DatabaseQueue, or DatabasePool)
        ///     - request: A fetch request.
        ///     - queue: Optional dispatch queue (defaults to the main queue)
        ///
        ///         The fetched records controller delegate will be notified of
        ///         record changes in this queue. The controller itself must be used
        ///         from this queue.
        ///
        ///         This dispatch queue must be serial.
        ///
        ///     - isSameElement: Optional function that compares two records.
        ///
        ///         This function should return true if the two records have the
        ///         same identity. For example, they have the same id.
        public convenience init<Request>(_ databaseWriter: DatabaseWriter, request: Request, queue: DispatchQueue = .main, isSameElement: @escaping (Row, Row) -> Bool) throws where Request: TypedRequest, Request.Fetched == Fetched {
            try self.init(databaseWriter, request: request, queue: queue, elementsAreTheSame: { isSameElement($0.value, $1.value) })
        }
    }
    
    extension RequestController where Fetched: RowConvertible {
        
        // MARK: - Initialization
        
        /// Creates a fetched records controller initialized from a SQL query and
        /// its eventual arguments.
        ///
        ///     let controller = RequestController<Wine>(
        ///         dbQueue,
        ///         sql: "SELECT * FROM wines WHERE color = ? ORDER BY name",
        ///         arguments: [Color.red],
        ///         isSameElement: { (wine1, wine2) in wine1.id == wine2.id })
        ///
        /// - parameters:
        ///     - databaseWriter: A DatabaseWriter (DatabaseQueue, or DatabasePool)
        ///     - sql: An SQL query.
        ///     - arguments: Optional statement arguments.
        ///     - adapter: Optional RowAdapter
        ///     - queue: Optional dispatch queue (defaults to the main queue)
        ///
        ///         The fetched records controller delegate will be notified of
        ///         record changes in this queue. The controller itself must be used
        ///         from this queue.
        ///
        ///         This dispatch queue must be serial.
        ///
        ///     - isSameElement: Optional function that compares two records.
        ///
        ///         This function should return true if the two records have the
        ///         same identity. For example, they have the same id.
        public convenience init(_ databaseWriter: DatabaseWriter, sql: String, arguments: StatementArguments? = nil, adapter: RowAdapter? = nil, queue: DispatchQueue = .main, isSameElement: @escaping (Fetched, Fetched) -> Bool) throws {
            try self.init(databaseWriter, request: SQLRequest(sql, arguments: arguments, adapter: adapter).bound(to: Fetched.self), queue: queue, elementsAreTheSame: { isSameElement($0.value, $1.value) })
        }
        
        /// Creates a fetched records controller initialized from a fetch request
        /// from the [Query Interface](https://github.com/groue/GRDB.swift#the-query-interface).
        ///
        ///     let request = Wine.order(Column("name"))
        ///     let controller = RequestController<Wine>(
        ///         dbQueue,
        ///         request: request,
        ///         isSameElement: { (wine1, wine2) in wine1.id == wine2.id })
        ///
        /// - parameters:
        ///     - databaseWriter: A DatabaseWriter (DatabaseQueue, or DatabasePool)
        ///     - request: A fetch request.
        ///     - queue: Optional dispatch queue (defaults to the main queue)
        ///
        ///         The fetched records controller delegate will be notified of
        ///         record changes in this queue. The controller itself must be used
        ///         from this queue.
        ///
        ///         This dispatch queue must be serial.
        ///
        ///     - isSameElement: Optional function that compares two records.
        ///
        ///         This function should return true if the two records have the
        ///         same identity. For example, they have the same id.
        public convenience init<Request>(_ databaseWriter: DatabaseWriter, request: Request, queue: DispatchQueue = .main, isSameElement: @escaping (Fetched, Fetched) -> Bool) throws where Request: TypedRequest, Request.Fetched == Fetched {
            try self.init(databaseWriter, request: request, queue: queue, elementsAreTheSame: { isSameElement($0.value, $1.value) })
        }
    }
    
    extension RequestController where Fetched: TableMapping {
        
        // MARK: - Initialization
        
        /// Creates a fetched records controller initialized from a SQL query and
        /// its eventual arguments.
        ///
        ///     let controller = RequestController<Wine>(
        ///         dbQueue,
        ///         sql: "SELECT * FROM wines WHERE color = ? ORDER BY name",
        ///         arguments: [Color.red],
        ///         compareRecordsByPrimaryKey: true)
        ///
        /// - parameters:
        ///     - databaseWriter: A DatabaseWriter (DatabaseQueue, or DatabasePool)
        ///     - sql: An SQL query.
        ///     - arguments: Optional statement arguments.
        ///     - adapter: Optional RowAdapter
        ///     - queue: Optional dispatch queue (defaults to the main queue)
        ///
        ///         The fetched records controller delegate will be notified of
        ///         record changes in this queue. The controller itself must be used
        ///         from this queue.
        ///
        ///         This dispatch queue must be serial.
        ///
        ///     - compareRecordsByPrimaryKey: A boolean that tells if two records
        ///         share the same identity if they share the same primay key.
        public convenience init(_ databaseWriter: DatabaseWriter, sql: String, arguments: StatementArguments? = nil, adapter: RowAdapter? = nil, queue: DispatchQueue = .main, compareRecordsByPrimaryKey: Bool) throws {
            try self.init(databaseWriter, request: SQLRequest(sql, arguments: arguments, adapter: adapter).bound(to: Fetched.self), queue: queue, compareRecordsByPrimaryKey: compareRecordsByPrimaryKey)
        }
        
        /// Creates a fetched records controller initialized from a fetch request.
        /// from the [Query Interface](https://github.com/groue/GRDB.swift#the-query-interface).
        ///
        ///     let request = Wine.order(Column("name"))
        ///     let controller = RequestController<Wine>(
        ///         dbQueue,
        ///         request: request,
        ///         compareRecordsByPrimaryKey: true)
        ///
        /// - parameters:
        ///     - databaseWriter: A DatabaseWriter (DatabaseQueue, or DatabasePool)
        ///     - request: A fetch request.
        ///     - queue: Optional dispatch queue (defaults to the main queue)
        ///
        ///         The fetched records controller delegate will be notified of
        ///         record changes in this queue. The controller itself must be used
        ///         from this queue.
        ///
        ///         This dispatch queue must be serial.
        ///
        ///     - compareRecordsByPrimaryKey: A boolean that tells if two records
        ///         share the same identity if they share the same primay key.
        public convenience init<Request>(_ databaseWriter: DatabaseWriter, request: Request, queue: DispatchQueue = .main, compareRecordsByPrimaryKey: Bool) throws where Request: TypedRequest, Request.Fetched == Fetched {
            if compareRecordsByPrimaryKey {
                let rowComparator = try databaseWriter.read { db in try Fetched.primaryKeyRowComparator(db) }
                try self.init(databaseWriter, request: request, queue: queue, elementsAreTheSame: { rowComparator($0.row, $1.row) })
            } else {
                try self.init(databaseWriter, request: request, queue: queue, elementsAreTheSame: { _ in false })
            }
        }
    }
#endif

extension RequestController where Fetched: Row {
    // MARK: - Accessing Records
    
    /// The fetched records.
    ///
    /// The value of this property is nil if performFetch() hasn't been called.
    ///
    /// The records reflect the state of the database after the initial
    /// call to performFetch, and after each database transaction that affects
    /// the results of the fetch request.
    public var fetchedRecords: [Fetched]? {
        guard let fetchedItems = fetchedItems else {
            return nil
        }
        return fetchedItems.map { $0.value }
    }
}

extension RequestController where Fetched: RowConvertible {
    // MARK: - Accessing Records
    
    /// The fetched records.
    ///
    /// The value of this property is nil if performFetch() hasn't been called.
    ///
    /// The records reflect the state of the database after the initial
    /// call to performFetch, and after each database transaction that affects
    /// the results of the fetch request.
    public var fetchedRecords: [Fetched]? {
        guard let fetchedItems = fetchedItems else {
            return nil
        }
        return fetchedItems.map { $0.value }
    }
}

extension RequestController where Fetched: DatabaseValueConvertible {
    // MARK: - Accessing Records
    
    /// The fetched records.
    ///
    /// The value of this property is nil if performFetch() hasn't been called.
    ///
    /// The records reflect the state of the database after the initial
    /// call to performFetch, and after each database transaction that affects
    /// the results of the fetch request.
    public var fetchedRecords: [Fetched]? {
        guard let fetchedItems = fetchedItems else {
            return nil
        }
        return fetchedItems.map { $0.value }
    }
}

extension RequestController where Fetched: _OptionalFetchable, Fetched._Wrapped: DatabaseValueConvertible {
    // MARK: - Accessing Records
    
    /// The fetched records.
    ///
    /// The value of this property is nil if performFetch() hasn't been called.
    ///
    /// The records reflect the state of the database after the initial
    /// call to performFetch, and after each database transaction that affects
    /// the results of the fetch request.
    public var fetchedRecords: [Fetched]? {
        guard let fetchedItems = fetchedItems else {
            return nil
        }
        return fetchedItems.map { $0.value }
    }
}

fileprivate struct ObservedRequest<T> : TypedRequest {
    typealias Fetched = AnyFetchable<T>
    let request: AnyRequest
    let selectionInfo: SelectStatement.SelectionInfo
    
    init<Request>(_ db: Database, request: Request) throws where Request: TypedRequest, Request.Fetched == T {
        self.request = AnyRequest(request)
        let (statement, _) = try request.prepare(db)
        self.selectionInfo = statement.selectionInfo
    }
    
    func prepare(_ db: Database) throws -> (SelectStatement, RowAdapter?) {
        return try request.prepare(db)
    }
}


// MARK: - FetchedRecordsObserver

/// RequestController adopts TransactionObserverType so that it can
/// monitor changes to its fetched records.
private final class FetchedRecordsObserver<Fetched> : TransactionObserver {
    var isValid: Bool
    var needsComputeChanges: Bool
    var items: [AnyFetchable<Fetched>]!  // ought to be not nil when observer has started tracking transactions
    let queue: DispatchQueue // protects items
    let selectionInfo: SelectStatement.SelectionInfo
    var fetchAndNotifyChanges: (FetchedRecordsObserver<Fetched>) -> ()
    
    init(selectionInfo: SelectStatement.SelectionInfo, fetchAndNotifyChanges: @escaping (FetchedRecordsObserver<Fetched>) -> ()) {
        self.isValid = true
        self.items = nil
        self.needsComputeChanges = false
        self.queue = DispatchQueue(label: "GRDB.FetchedRecordsObserver")
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


// MARK: - Changes

fileprivate func makeFetchFunction<Fetched, T>(
    controller: RequestController<Fetched>,
    fetchAlongside: @escaping (Database) throws -> T,
    completion: @escaping (Result<(fetchedItems: [AnyFetchable<Fetched>], fetchedAlongside: T, observer: FetchedRecordsObserver<Fetched>)>) -> ()
    ) -> (FetchedRecordsObserver<Fetched>) -> ()
{
    // Make sure we keep a weak reference to the fetched records controller,
    // so that the user can use unowned references in callbacks:
    //
    //      controller.trackChanges { [unowned self] ... }
    //
    // Should controller become strong at any point before callbacks are
    // called, such unowned reference would have an opportunity to crash.
    return { [weak controller] observer in
        // Return if observer has been invalidated
        guard observer.isValid else { return }
        
        // Return if fetched records controller has been deallocated
        guard let request = controller?.request, let databaseWriter = controller?.databaseWriter else { return }
        
        // Fetch items.
        //
        // This method is called from the database writer's serialized
        // queue, so that we can fetch items before other writes have the
        // opportunity to modify the database.
        //
        // However, we don't have to block the writer queue for all the
        // duration of the fetch. We just need to block the writer queue
        // until we can perform a fetch in isolation. This is the role of
        // the readFromCurrentState method (see below).
        //
        // However, our fetch will last for an unknown duration. And since
        // we release the writer queue early, the next database modification
        // will triggers this callback while our fetch is, maybe, still
        // running. This next callback will also perform its own fetch, that
        // will maybe end before our own fetch.
        //
        // We have to make sure that our fetch is processed *before* the
        // next fetch: let's immediately dispatch the processing task in our
        // serialized FIFO queue, but have it wait for our fetch to
        // complete, with a semaphore:
        let semaphore = DispatchSemaphore(value: 0)
        var result: Result<(fetchedItems: [AnyFetchable<Fetched>], fetchedAlongside: T)>? = nil
        do {
            try databaseWriter.readFromCurrentState { db in
                result = Result.wrap { try (
                    fetchedItems: request.fetchAll(db),
                    fetchedAlongside: fetchAlongside(db)) }
                semaphore.signal()
            }
        } catch {
            result = .failure(error)
            semaphore.signal()
        }
        
        // Process the fetched items
        
        observer.queue.async { [weak observer] in
            // Wait for the fetch to complete:
            _ = semaphore.wait(timeout: .distantFuture)
            
            // Return if observer has been invalidated
            guard let strongObserver = observer else { return }
            guard strongObserver.isValid else { return }
            
            completion(result!.map { (fetchedItems, fetchedAlongside) in
                (fetchedItems: fetchedItems, fetchedAlongside: fetchedAlongside, observer: strongObserver)
            })
        }
    }
}

#if os(iOS)
    fileprivate func makeFetchAndNotifyChangesFunction<Fetched, T>(
        controller: RequestController<Fetched>,
        fetchAlongside: @escaping (Database) throws -> T,
        elementsAreTheSame: @escaping ItemComparator<Fetched>,
        recordsWillChange: ((_ controller: RequestController<Fetched>, _ fetchedAlongside: T) -> ())?,
        handleChanges: ((_ controller: RequestController<Fetched>, _ changes: [TableViewChange<Fetched>]) -> ())?,
        recordsDidChange: ((_ controller: RequestController<Fetched>, _ fetchedAlongside: T) -> ())?
        ) -> (FetchedRecordsObserver<Fetched>) -> ()
    {
        // Make sure we keep a weak reference to the fetched records controller,
        // so that the user can use unowned references in callbacks:
        //
        //      controller.trackChanges { [unowned self] ... }
        //
        // Should controller become strong at any point before callbacks are
        // called, such unowned reference would have an opportunity to crash.
        return makeFetchFunction(controller: controller, fetchAlongside: fetchAlongside) { [weak controller] result in
            // Return if fetched records controller has been deallocated
            guard let callbackQueue = controller?.queue else { return }
            
            switch result {
            case .failure(let error):
                callbackQueue.async {
                    // Now we can retain controller
                    guard let strongController = controller else { return }
                    strongController.errorHandler?(strongController, error)
                }
                
            case .success((fetchedItems: let fetchedItems, fetchedAlongside: let fetchedAlongside, observer: let observer)):
                // Return if there is no change
                let tableViewChanges: [TableViewChange<Fetched>]
                if handleChanges != nil {
                    // Compute table view changes
                    tableViewChanges = computeTableViewChanges(from: observer.items, to: fetchedItems, elementsAreTheSame: elementsAreTheSame)
                    if tableViewChanges.isEmpty { return }
                } else {
                    // Don't compute changes: just look for a row difference:
                    if identicalItemArrays(fetchedItems, observer.items) { return }
                    tableViewChanges = []
                }
                
                // Ready for next check
                observer.items = fetchedItems
                
                callbackQueue.async { [weak observer] in
                    // Return if observer has been invalidated
                    guard let strongObserver = observer else { return }
                    guard strongObserver.isValid else { return }
                    
                    // Now we can retain controller
                    guard let strongController = controller else { return }
                    
                    // Notify changes
                    recordsWillChange?(strongController, fetchedAlongside)
                    strongController.fetchedItems = fetchedItems
                    handleChanges?(strongController, tableViewChanges)
                    recordsDidChange?(strongController, fetchedAlongside)
                }
            }
        }
    }
    
    fileprivate func computeTableViewChanges<Fetched>(from s: [AnyFetchable<Fetched>], to t: [AnyFetchable<Fetched>], elementsAreTheSame: ItemComparator<Fetched>) -> [TableViewChange<Fetched>] {
        let m = s.count
        let n = t.count
        
        // Fill first row and column of insertions and deletions.
        
        var d: [[[TableViewChange<Fetched>]]] = Array(repeating: Array(repeating: [], count: n + 1), count: m + 1)
        
        var changes = [TableViewChange<Fetched>]()
        for (row, item) in s.enumerated() {
            let deletion = TableViewChange.deletion(item: item, indexPath: IndexPath(row: row, section: 0))
            changes.append(deletion)
            d[row + 1][0] = changes
        }
        
        changes.removeAll()
        for (col, item) in t.enumerated() {
            let insertion = TableViewChange.insertion(item: item, indexPath: IndexPath(row: col, section: 0))
            changes.append(insertion)
            d[0][col + 1] = changes
        }
        
        if m == 0 || n == 0 {
            // Pure deletions or insertions
            return d[m][n]
        }
        
        // Fill body of matrix.
        for tx in 0..<n {
            for sx in 0..<m {
                if s[sx] == t[tx] {
                    d[sx+1][tx+1] = d[sx][tx] // no operation
                } else {
                    var del = d[sx][tx+1]     // a deletion
                    var ins = d[sx+1][tx]     // an insertion
                    var sub = d[sx][tx]       // a substitution
                    
                    // Record operation.
                    let minimumCount = min(del.count, ins.count, sub.count)
                    if del.count == minimumCount {
                        let deletion = TableViewChange.deletion(item: s[sx], indexPath: IndexPath(row: sx, section: 0))
                        del.append(deletion)
                        d[sx+1][tx+1] = del
                    } else if ins.count == minimumCount {
                        let insertion = TableViewChange.insertion(item: t[tx], indexPath: IndexPath(row: tx, section: 0))
                        ins.append(insertion)
                        d[sx+1][tx+1] = ins
                    } else {
                        let deletion = TableViewChange.deletion(item: s[sx], indexPath: IndexPath(row: sx, section: 0))
                        let insertion = TableViewChange.insertion(item: t[tx], indexPath: IndexPath(row: tx, section: 0))
                        sub.append(deletion)
                        sub.append(insertion)
                        d[sx+1][tx+1] = sub
                    }
                }
            }
        }
        
        /// Returns an array where deletion/insertion pairs of the same element are replaced by `.move` change.
        func standardize(changes: [TableViewChange<Fetched>], elementsAreTheSame: ItemComparator<Fetched>) -> [TableViewChange<Fetched>] {
            
            /// Returns a potential .move or .update if *change* has a matching change in *changes*:
            /// If *change* is a deletion or an insertion, and there is a matching inverse
            /// insertion/deletion with the same value in *changes*, a corresponding .move or .update is returned.
            /// As a convenience, the index of the matched change is returned as well.
            func merge(change: TableViewChange<Fetched>, in changes: [TableViewChange<Fetched>], elementsAreTheSame: ItemComparator<Fetched>) -> (mergedChange: TableViewChange<Fetched>, mergedIndex: Int)? {
                
                /// Returns the changes between two rows: a dictionary [key: oldValue]
                /// Precondition: both rows have the same columns
                func changedValues(from oldRow: Row, to newRow: Row) -> [String: DatabaseValue] {
                    var changedValues: [String: DatabaseValue] = [:]
                    for (column, newValue) in newRow {
                        let oldValue: DatabaseValue? = oldRow.value(named: column)
                        if newValue != oldValue {
                            changedValues[column] = oldValue
                        }
                    }
                    return changedValues
                }
                
                switch change {
                case .insertion(let newItem, let newIndexPath):
                    // Look for a matching deletion
                    for (index, otherChange) in changes.enumerated() {
                        guard case .deletion(let oldItem, let oldIndexPath) = otherChange else { continue }
                        guard elementsAreTheSame(oldItem, newItem) else { continue }
                        let rowChanges = changedValues(from: oldItem.row, to: newItem.row)
                        if oldIndexPath == newIndexPath {
                            return (TableViewChange.update(item: newItem, indexPath: oldIndexPath, changes: rowChanges), index)
                        } else {
                            return (TableViewChange.move(item: newItem, indexPath: oldIndexPath, newIndexPath: newIndexPath, changes: rowChanges), index)
                        }
                    }
                    return nil
                    
                case .deletion(let oldItem, let oldIndexPath):
                    // Look for a matching insertion
                    for (index, otherChange) in changes.enumerated() {
                        guard case .insertion(let newItem, let newIndexPath) = otherChange else { continue }
                        guard elementsAreTheSame(oldItem, newItem) else { continue }
                        let rowChanges = changedValues(from: oldItem.row, to: newItem.row)
                        if oldIndexPath == newIndexPath {
                            return (TableViewChange.update(item: newItem, indexPath: oldIndexPath, changes: rowChanges), index)
                        } else {
                            return (TableViewChange.move(item: newItem, indexPath: oldIndexPath, newIndexPath: newIndexPath, changes: rowChanges), index)
                        }
                    }
                    return nil
                    
                default:
                    return nil
                }
            }
            
            // Updates must be pushed at the end
            var mergedChanges: [TableViewChange<Fetched>] = []
            var updateChanges: [TableViewChange<Fetched>] = []
            for change in changes {
                if let (mergedChange, mergedIndex) = merge(change: change, in: mergedChanges, elementsAreTheSame: elementsAreTheSame) {
                    mergedChanges.remove(at: mergedIndex)
                    switch mergedChange {
                    case .update:
                        updateChanges.append(mergedChange)
                    default:
                        mergedChanges.append(mergedChange)
                    }
                } else {
                    mergedChanges.append(change)
                }
            }
            return mergedChanges + updateChanges
        }
        
        return standardize(changes: d[m][n], elementsAreTheSame: elementsAreTheSame)
    }

#else
    /// Returns a function that fetches and notify changes, and erases the type
    /// of values that are fetched alongside tracked records.
    fileprivate func makeFetchAndNotifyChangesFunction<Fetched, T>(
        controller: RequestController<Fetched>,
        fetchAlongside: @escaping (Database) throws -> T,
        recordsWillChange: ((RequestController<Fetched>, _ fetchedAlongside: T) -> ())?,
        recordsDidChange: ((RequestController<Fetched>, _ fetchedAlongside: T) -> ())?
        ) -> (FetchedRecordsObserver<Fetched>) -> ()
    {
        // Make sure we keep a weak reference to the fetched records controller,
        // so that the user can use unowned references in callbacks:
        //
        //      controller.trackChanges { [unowned self] ... }
        //
        // Should controller become strong at any point before callbacks are
        // called, such unowned reference would have an opportunity to crash.
        return makeFetchFunction(controller: controller, fetchAlongside: fetchAlongside) { [weak controller] result in
            // Return if fetched records controller has been deallocated
            guard let callbackQueue = controller?.queue else { return }
            
            switch result {
            case .failure(let error):
                callbackQueue.async {
                    // Now we can retain controller
                    guard let strongController = controller else { return }
                    strongController.errorHandler?(strongController, error)
                }
                
            case .success((fetchedItems: let fetchedItems, fetchedAlongside: let fetchedAlongside, observer: let observer)):
                // Return if there is no change
                if identicalItemArrays(fetchedItems, observer.items) { return }
                
                // Ready for next check
                observer.items = fetchedItems
                
                callbackQueue.async { [weak observer] in
                    // Return if observer has been invalidated
                    guard let strongObserver = observer else { return }
                    guard strongObserver.isValid else { return }
                    
                    // Now we can retain controller
                    guard let strongController = controller else { return }
                    
                    // Notify changes
                    recordsWillChange?(strongController, fetchedAlongside)
                    strongController.fetchedItems = fetchedItems
                    recordsDidChange?(strongController, fetchedAlongside)
                }
            }
        }
    }
#endif

fileprivate func identicalItemArrays<Fetched>(_ lhs: [AnyFetchable<Fetched>], _ rhs: [AnyFetchable<Fetched>]) -> Bool {
    guard lhs.count == rhs.count else {
        return false
    }
    for (lhs, rhs) in zip(lhs, rhs) {
        if lhs.row != rhs.row {
            return false
        }
    }
    return true
}


// MARK: - UITableView Support

#if os(iOS)
    fileprivate typealias ItemComparator<Fetched> = (AnyFetchable<Fetched>, AnyFetchable<Fetched>) -> Bool
    
    extension RequestController where Fetched: Row {
        // MARK: - Accessing Records
        
        /// Returns the object at the given index path (iOS only).
        ///
        /// - parameter indexPath: An index path in the fetched records.
        ///
        ///     If indexPath does not describe a valid index path in the fetched
        ///     records, a fatal error is raised.
        public subscript(_ indexPath: IndexPath) -> Fetched {
            guard let fetchedItems = fetchedItems else {
                // Programmer error
                fatalError("performFetch() has not been called.")
            }
            return fetchedItems[indexPath.row].value
        }
    }
    
    extension RequestController where Fetched: RowConvertible {
        // MARK: - Accessing Records
        
        /// Returns the object at the given index path (iOS only).
        ///
        /// - parameter indexPath: An index path in the fetched records.
        ///
        ///     If indexPath does not describe a valid index path in the fetched
        ///     records, a fatal error is raised.
        public subscript(_ indexPath: IndexPath) -> Fetched {
            guard let fetchedItems = fetchedItems else {
                // Programmer error
                fatalError("performFetch() has not been called.")
            }
            return fetchedItems[indexPath.row].value
        }
    }
    
    extension RequestController where Fetched: DatabaseValueConvertible {
        // MARK: - Accessing Records
        
        /// Returns the object at the given index path (iOS only).
        ///
        /// - parameter indexPath: An index path in the fetched records.
        ///
        ///     If indexPath does not describe a valid index path in the fetched
        ///     records, a fatal error is raised.
        public subscript(_ indexPath: IndexPath) -> Fetched {
            guard let fetchedItems = fetchedItems else {
                // Programmer error
                fatalError("performFetch() has not been called.")
            }
            return fetchedItems[indexPath.row].value
        }
    }
    
    extension RequestController where Fetched: _OptionalFetchable, Fetched._Wrapped: DatabaseValueConvertible {
        // MARK: - Accessing Records
        
        /// Returns the object at the given index path (iOS only).
        ///
        /// - parameter indexPath: An index path in the fetched records.
        ///
        ///     If indexPath does not describe a valid index path in the fetched
        ///     records, a fatal error is raised.
        public subscript(_ indexPath: IndexPath) -> Fetched {
            guard let fetchedItems = fetchedItems else {
                // Programmer error
                fatalError("performFetch() has not been called.")
            }
            return fetchedItems[indexPath.row].value
        }
    }
    
    extension RequestController {
        // MARK: - Querying Sections Information
        
        /// The sections for the fetched records (iOS only).
        ///
        /// You typically use the sections array when implementing
        /// UITableViewDataSource methods, such as `numberOfSectionsInTableView`.
        ///
        /// The sections array is never empty, even when there are no fetched
        /// records. In this case, there is a single empty section.
        public var sections: [FetchedRecordsSectionInfo<Fetched>] {
            // We only support a single section so far.
            // We also return a single section when there are no fetched
            // records, just like NSFetchedResultsController.
            return [FetchedRecordsSectionInfo(controller: self)]
        }
    }
    
    extension RequestController where Fetched: MutablePersistable {
        
        /// Returns the indexPath of a given record (iOS only).
        ///
        /// - returns: The index path of *record* in the fetched records, or nil
        ///   if record could not be found.
        public func indexPath(for element: Fetched) -> IndexPath? {
            let item = AnyFetchable<Fetched>(row: Row(element.persistentDictionary))
            guard let fetchedItems = fetchedItems, let index = fetchedItems.index(where: { elementsAreTheSame($0, item) }) else {
                return nil
            }
            return IndexPath(row: index, section: 0)
        }
    }
    
    private enum TableViewChange<Fetched> {
        case insertion(item: AnyFetchable<Fetched>, indexPath: IndexPath)
        case deletion(item: AnyFetchable<Fetched>, indexPath: IndexPath)
        case move(item: AnyFetchable<Fetched>, indexPath: IndexPath, newIndexPath: IndexPath, changes: [String: DatabaseValue])
        case update(item: AnyFetchable<Fetched>, indexPath: IndexPath, changes: [String: DatabaseValue])
    }
    
    extension TableViewChange where Fetched: Row {
        var value: Fetched {
            return item.value
        }
    }
    
    extension TableViewChange where Fetched: RowConvertible {
        var value: Fetched {
            return item.value
        }
    }
    
    extension TableViewChange where Fetched: DatabaseValueConvertible {
        var value: Fetched {
            return item.value
        }
    }
    
    extension TableViewChange where Fetched: _OptionalFetchable, Fetched._Wrapped: DatabaseValueConvertible {
        var value: Fetched {
            return item.value
        }
    }
    
    extension TableViewChange {
        var item: AnyFetchable<Fetched> {
            switch self {
            case .insertion(item: let item, indexPath: _):
                return item
            case .deletion(item: let item, indexPath: _):
                return item
            case .move(item: let item, indexPath: _, newIndexPath: _, changes: _):
                return item
            case .update(item: let item, indexPath: _, changes: _):
                return item
            }
        }
        
        var event: TableViewEvent {
            switch self {
            case .insertion(item: _, indexPath: let indexPath):
                return .insertion(indexPath: indexPath)
            case .deletion(item: _, indexPath: let indexPath):
                return .deletion(indexPath: indexPath)
            case .move(item: _, indexPath: let indexPath, newIndexPath: let newIndexPath, changes: let changes):
                return .move(indexPath: indexPath, newIndexPath: newIndexPath, changes: changes)
            case .update(item: _, indexPath: let indexPath, changes: let changes):
                return .update(indexPath: indexPath, changes: changes)
            }
        }
    }
    
    extension TableViewChange: CustomStringConvertible {
        var description: String {
            switch self {
            case .insertion(let item, let indexPath):
                return "Insert \(item) at \(indexPath)"
                
            case .deletion(let item, let indexPath):
                return "Delete \(item) from \(indexPath)"
                
            case .move(let item, let indexPath, let newIndexPath, changes: let changes):
                return "Move \(item) from \(indexPath) to \(newIndexPath) with changes: \(changes)"
                
            case .update(let item, let indexPath, let changes):
                return "Update \(item) at \(indexPath) with changes: \(changes)"
            }
        }
    }
    
    /// A change event given by a RequestController to its delegate.
    ///
    /// The move and update events hold a *changes* dictionary. Its keys are column
    /// names, and values the old values that have been changed.
    public enum TableViewEvent {
        
        /// An insertion event, at given indexPath.
        case insertion(indexPath: IndexPath)
        
        /// A deletion event, at given indexPath.
        case deletion(indexPath: IndexPath)
        
        /// A move event, from indexPath to newIndexPath. The *changes* are a
        /// dictionary whose keys are column names, and values the old values that
        /// have been changed.
        case move(indexPath: IndexPath, newIndexPath: IndexPath, changes: [String: DatabaseValue])
        
        /// An update event, at given indexPath. The *changes* are a dictionary
        /// whose keys are column names, and values the old values that have
        /// been changed.
        case update(indexPath: IndexPath, changes: [String: DatabaseValue])
    }
    
    extension TableViewEvent: CustomStringConvertible {
        
        /// A textual representation of `self`.
        public var description: String {
            switch self {
            case .insertion(let indexPath):
                return "Insertion at \(indexPath)"
                
            case .deletion(let indexPath):
                return "Deletion from \(indexPath)"
                
            case .move(let indexPath, let newIndexPath, changes: let changes):
                return "Move from \(indexPath) to \(newIndexPath) with changes: \(changes)"
                
            case .update(let indexPath, let changes):
                return "Update at \(indexPath) with changes: \(changes)"
            }
        }
    }
    
    /// A section given by a RequestController.
    public struct FetchedRecordsSectionInfo<Fetched> {
        fileprivate let controller: RequestController<Fetched>
        
        /// The number of records (rows) in the section.
        public var count: Int {
            guard let items = controller.fetchedItems else {
                // Programmer error
                fatalError("the performFetch() method must be called before accessing section contents")
            }
            return items.count
        }
    }
    
    extension FetchedRecordsSectionInfo where Fetched: Row {
        /// The array of records in the section.
        public var elements: [Fetched] {
            guard let items = controller.fetchedItems else {
                // Programmer error
                fatalError("the performFetch() method must be called before accessing section contents")
            }
            return items.map { $0.value }
        }
    }
    
    extension FetchedRecordsSectionInfo where Fetched: RowConvertible {
        /// The array of records in the section.
        public var elements: [Fetched] {
            guard let items = controller.fetchedItems else {
                // Programmer error
                fatalError("the performFetch() method must be called before accessing section contents")
            }
            return items.map { $0.value }
        }
    }
    
    extension FetchedRecordsSectionInfo where Fetched: DatabaseValueConvertible {
        /// The array of records in the section.
        public var elements: [Fetched] {
            guard let items = controller.fetchedItems else {
                // Programmer error
                fatalError("the performFetch() method must be called before accessing section contents")
            }
            return items.map { $0.value }
        }
    }
    
    extension FetchedRecordsSectionInfo where Fetched: _OptionalFetchable, Fetched._Wrapped: DatabaseValueConvertible {
        /// The array of records in the section.
        public var elements: [Fetched] {
            guard let items = controller.fetchedItems else {
                // Programmer error
                fatalError("the performFetch() method must be called before accessing section contents")
            }
            return items.map { $0.value }
        }
    }

#endif


// MARK: - AnyFetchable

final class AnyFetchable<Fetched> : RowConvertible {
    let row: Row
    var _value: Fetched?
    
    init(row: Row) {
        self.row = row.copy()
    }
}

extension AnyFetchable : Equatable {
    static func ==<T>(lhs: AnyFetchable<T>, rhs: AnyFetchable<T>) -> Bool {
        return lhs.row == rhs.row
    }
}

extension AnyFetchable : Hashable {
    var hashValue: Int {
        return row.hashValue
    }
}

extension AnyFetchable where Fetched: Row {
    var value: Fetched {
        return row as! Fetched // Row is final: this can't fail even though Swift compiler doesn't see it.
    }
}

extension AnyFetchable where Fetched: RowConvertible {
    var value: Fetched {
        if let value = _value {
            return value
        } else {
            let value = Fetched(row: row)
            value.awakeFromFetch(row: row)
            _value = value
            return value
        }
    }
}

extension AnyFetchable where Fetched: DatabaseValueConvertible {
    var value: Fetched {
        return row.value(atIndex: 0)
    }
}

extension AnyFetchable where Fetched: _OptionalFetchable, Fetched._Wrapped: DatabaseValueConvertible {
    var value: Fetched {
        return (row.value(atIndex: 0) as Fetched._Wrapped?) as! Fetched // Fetched is Fetched._Wrapped?: this can't fail even though Swift compiler doesn't see it.
    }
}

