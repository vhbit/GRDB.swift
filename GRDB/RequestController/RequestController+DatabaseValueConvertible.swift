extension RequestController where Fetched: DatabaseValueConvertible {
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

extension RequestController where Fetched: _OptionalFetchable, Fetched._Wrapped: DatabaseValueConvertible {
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
    extension RequestController where Fetched: DatabaseValueConvertible {
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
    
    extension RequestController where Fetched: _OptionalFetchable, Fetched._Wrapped: DatabaseValueConvertible {
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
    
    // TODO: make it a collection
    extension FetchedRecordsSectionInfo where Fetched: DatabaseValueConvertible {
        /// The array of records in the section.
        public var values: [Fetched] {
            guard let items = controller.fetchedItems else {
                // Programmer error
                fatalError("the performFetch() method must be called before accessing section contents")
            }
            return items.map { $0.value }
        }
    }
    
    extension FetchedRecordsSectionInfo where Fetched: _OptionalFetchable, Fetched._Wrapped: DatabaseValueConvertible {
        /// The array of records in the section.
        public var values: [Fetched] {
            guard let items = controller.fetchedItems else {
                // Programmer error
                fatalError("the performFetch() method must be called before accessing section contents")
            }
            return items.map { $0.value }
        }
    }
    
    extension TableViewChange where Fetched: DatabaseValueConvertible {
        var value: Fetched { return item.value }
    }
    
    extension TableViewChange where Fetched: _OptionalFetchable, Fetched._Wrapped: DatabaseValueConvertible {
        var value: Fetched { return item.value }
    }
#endif
