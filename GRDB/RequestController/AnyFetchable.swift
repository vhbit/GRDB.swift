final class AnyFetchable<Fetched> : RowConvertible {
    let row: Row
    fileprivate var _value: Fetched? // cache only used when Fetched adopts RowConvertible
    
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

typealias AnyFetchableComparator<Fetched> = (AnyFetchable<Fetched>, AnyFetchable<Fetched>) -> Bool
