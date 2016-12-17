#if os(iOS)
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
        public convenience init(
            _ databaseWriter: DatabaseWriter,
            sql: String,
            arguments: StatementArguments? = nil,
            adapter: RowAdapter? = nil,
            queue: DispatchQueue = .main,
            compareRecordsByPrimaryKey: Bool) throws
        {
            try self.init(
                databaseWriter,
                request: SQLRequest(sql, arguments: arguments, adapter: adapter).bound(to: Fetched.self),
                queue: queue,
                compareRecordsByPrimaryKey: compareRecordsByPrimaryKey)
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
        public convenience init<Request>(
            _ databaseWriter: DatabaseWriter,
            request: Request,
            queue: DispatchQueue = .main,
            compareRecordsByPrimaryKey: Bool) throws
            where Request: TypedRequest, Request.Fetched == Fetched
        {
            if compareRecordsByPrimaryKey {
                let rowComparator = try databaseWriter.read { db in try Fetched.primaryKeyRowComparator(db) }
                try self.init(
                    databaseWriter,
                    request: request,
                    queue: queue,
                    elementsAreTheSame: { rowComparator($0.row, $1.row) })
            } else {
                try self.init(
                    databaseWriter,
                    request: request,
                    queue: queue,
                    elementsAreTheSame: { _ in false })
            }
        }
    }
#endif
