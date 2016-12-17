extension RequestController where Fetched: RowConvertible {
    // MARK: - Accessing Records
    
    /// The fetched records.
    ///
    /// The value of this property is nil if performFetch() hasn't been called.
    ///
    /// The records reflect the state of the database after the initial
    /// call to performFetch, and after each database transaction that affects
    /// the results of the fetch request.
    public var fetchedValues: [Fetched]? {
        return fetchedItems.map { $0.map { $0.value } }
    }
}

#if os(iOS)
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
        
        
        // MARK: - Tracking Changes
        
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
                let observer = RequestObserver(selectionInfo: request.selectionInfo, fetchAndNotifyChanges: fetchAndNotifyChanges)
                self.observer = observer
                if let initialItems = initialItems {
                    observer.items = initialItems
                    db.add(transactionObserver: observer)
                    observer.fetchAndNotifyChanges(observer)
                }
            }
        }
        
        
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
    
    extension FetchedRecordsSectionInfo where Fetched: RowConvertible {
        /// The array of records in the section.
        public var values: [Fetched] {
            guard let items = controller.fetchedItems else {
                // Programmer error
                fatalError("the performFetch() method must be called before accessing section contents")
            }
            return items.map { $0.value }
        }
    }
    
    extension TableViewChange where Fetched: RowConvertible {
        var value: Fetched { return item.value }
    }
#endif
