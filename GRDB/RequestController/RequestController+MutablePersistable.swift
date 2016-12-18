#if os(iOS)
    extension RequestController where Fetched: MutablePersistable {
        
        /// Returns the indexPath of a given record (iOS only).
        ///
        /// - returns: The index path of *record* in the fetched records, or nil
        ///   if record could not be found.
        public func indexPath(for element: Fetched) -> IndexPath? {
            let item = AnyFetchable<Fetched>(row: Row(element.persistentDictionary))
            guard let fetchedItems = fetchedItems, let index = fetchedItems.index(where: { itemsAreIdentical($0, item) }) else {
                return nil
            }
            return IndexPath(row: index, section: 0)
        }
    }
#endif
