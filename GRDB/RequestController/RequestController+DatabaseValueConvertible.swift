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
        ///     - willChange: Invoked before records are updated.
        ///     - onChange: Invoked for each record that has been added,
        ///       removed, moved, or updated.
        ///     - didChange: Invoked after records have been updated.
        public func trackChanges(
            willChange: ((RequestController<Fetched>) -> ())? = nil,
            onChange: ((RequestController<Fetched>, Fetched, RequestChange) -> ())? = nil,
            didChange: ((RequestController<Fetched>) -> ())? = nil)
        {
            trackChanges(
                fetchAlongside: { _ in },
                willChange: willChange.map { willChange in { (controller, _) in willChange(controller) } },
                onChange: onChange,
                didChange: didChange.map { didChange in { (controller, _) in didChange(controller) } })
        }
        
        /// Registers changes notification callbacks (iOS only).
        ///
        /// - parameters:
        ///     - fetchAlongside: The value returned from this closure is given to
        ///       willChange and didChange callbacks, as their
        ///       `fetchedAlongside` argument. The closure is guaranteed to see the
        ///       database in the state it has just after eventual changes to the
        ///       fetched records have been performed. Use it in order to fetch
        ///       values that must be consistent with the fetched records.
        ///     - willChange: Invoked before records are updated.
        ///     - onChange: Invoked for each record that has been added,
        ///       removed, moved, or updated.
        ///     - didChange: Invoked after records have been updated.
        public func trackChanges<T>(
            fetchAlongside: @escaping (Database) throws -> T,
            willChange: ((RequestController<Fetched>, _ fetchedAlongside: T) -> ())? = nil,
            onChange: ((RequestController<Fetched>, Fetched, RequestChange) -> ())? = nil,
            didChange: ((RequestController<Fetched>, _ fetchedAlongside: T) -> ())? = nil)
        {
            // If some changes are currently processed, make sure they are
            // discarded because they would trigger previously set callbacks.
            observer?.invalidate()
            observer = nil
            
            guard (willChange != nil) || (onChange != nil) || (didChange != nil) else {
                // Stop tracking
                return
            }
            
            let initialItems = fetchedItems
            databaseWriter.write { db in
                let fetchAndNotifyChanges = makeFetchAndNotifyChangesFunction(
                    controller: self,
                    fetchAlongside: fetchAlongside,
                    elementsAreTheSame: elementsAreTheSame,
                    willChange: willChange,
                    handleChanges: onChange.map { onChange in
                        { (controller, changes) in
                            for change in changes {
                                onChange(controller, change.value, change.change)
                            }
                        }
                }, didChange: didChange)
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
        ///     - willChange: Invoked before records are updated.
        ///     - onChange: Invoked for each record that has been added,
        ///       removed, moved, or updated.
        ///     - didChange: Invoked after records have been updated.
        public func trackChanges(
            willChange: ((RequestController<Fetched>) -> ())? = nil,
            onChange: ((RequestController<Fetched>, Fetched, RequestChange) -> ())? = nil,
            didChange: ((RequestController<Fetched>) -> ())? = nil)
        {
            trackChanges(
                fetchAlongside: { _ in },
                willChange: willChange.map { willChange in { (controller, _) in willChange(controller) } },
                onChange: onChange,
                didChange: didChange.map { didChange in { (controller, _) in didChange(controller) } })
        }
        
        /// Registers changes notification callbacks (iOS only).
        ///
        /// - parameters:
        ///     - fetchAlongside: The value returned from this closure is given to
        ///       willChange and didChange callbacks, as their
        ///       `fetchedAlongside` argument. The closure is guaranteed to see the
        ///       database in the state it has just after eventual changes to the
        ///       fetched records have been performed. Use it in order to fetch
        ///       values that must be consistent with the fetched records.
        ///     - willChange: Invoked before records are updated.
        ///     - onChange: Invoked for each record that has been added,
        ///       removed, moved, or updated.
        ///     - didChange: Invoked after records have been updated.
        public func trackChanges<T>(
            fetchAlongside: @escaping (Database) throws -> T,
            willChange: ((RequestController<Fetched>, _ fetchedAlongside: T) -> ())? = nil,
            onChange: ((RequestController<Fetched>, Fetched, RequestChange) -> ())? = nil,
            didChange: ((RequestController<Fetched>, _ fetchedAlongside: T) -> ())? = nil)
        {
            // If some changes are currently processed, make sure they are
            // discarded because they would trigger previously set callbacks.
            observer?.invalidate()
            observer = nil
            
            guard (willChange != nil) || (onChange != nil) || (didChange != nil) else {
                // Stop tracking
                return
            }
            
            let initialItems = fetchedItems
            databaseWriter.write { db in
                let fetchAndNotifyChanges = makeFetchAndNotifyChangesFunction(
                    controller: self,
                    fetchAlongside: fetchAlongside,
                    elementsAreTheSame: elementsAreTheSame,
                    willChange: willChange,
                    handleChanges: onChange.map { onChange in
                        { (controller, changes) in
                            for change in changes {
                                onChange(controller, change.value, change.change)
                            }
                        }
                }, didChange: didChange)
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
    
    extension RequestController where Fetched: DatabaseValueConvertible {
        // MARK: - Querying Sections Information
        
        /// The sections for the fetched records (iOS only).
        ///
        /// You typically use the sections array when implementing
        /// UITableViewDataSource methods, such as `numberOfSectionsInTableView`.
        ///
        /// The sections array is never empty, even when there are no fetched
        /// records. In this case, there is a single empty section.
        public var sections: [RequestSection<Fetched>] {
            // We only support a single section so far.
            // We also return a single section when there are no fetched
            // records, just like NSFetchedResultsController.
            return [RequestSection(controller: self, unwrap: { $0.value })]
        }
    }
    
    extension RequestController where Fetched: _OptionalFetchable, Fetched._Wrapped: DatabaseValueConvertible {
        // MARK: - Querying Sections Information
        
        /// The sections for the fetched records (iOS only).
        ///
        /// You typically use the sections array when implementing
        /// UITableViewDataSource methods, such as `numberOfSectionsInTableView`.
        ///
        /// The sections array is never empty, even when there are no fetched
        /// records. In this case, there is a single empty section.
        public var sections: [RequestSection<Fetched>] {
            // We only support a single section so far.
            // We also return a single section when there are no fetched
            // records, just like NSFetchedResultsController.
            return [RequestSection(controller: self, unwrap: { $0.value })]
        }
    }
    
    extension AnyFetchableChange where Fetched: DatabaseValueConvertible {
        var value: Fetched { return item.value }
    }
    
    extension AnyFetchableChange where Fetched: _OptionalFetchable, Fetched._Wrapped: DatabaseValueConvertible {
        var value: Fetched { return item.value }
    }
#endif
