import Foundation
import SQLite3

nonisolated struct SQLiteError: LocalizedError, Equatable {
    let message: String
    var errorDescription: String? { message }
}

nonisolated enum SQLiteValue {
    case int(Int)
    case text(String)
    case blob(Data)
}

/// A prepared statement. Not thread-safe: use it only where its database is used.
nonisolated final class SQLiteStatement {
    private let handle: OpaquePointer

    init(_ db: OpaquePointer, _ sql: String) throws {
        var prepared: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &prepared, nil) == SQLITE_OK, let statement = prepared else {
            throw SQLiteError(message: String(cString: sqlite3_errmsg(db)))
        }
        handle = statement
    }

    deinit { sqlite3_finalize(handle) }

    private var failure: SQLiteError {
        SQLiteError(message: String(cString: sqlite3_errmsg(sqlite3_db_handle(handle))))
    }

    /// Binds `values`, runs the statement to completion (no rows expected) and resets it for reuse.
    func run(_ values: [SQLiteValue] = []) throws {
        try bind(values)
        defer { sqlite3_reset(handle) }
        guard sqlite3_step(handle) == SQLITE_DONE else { throw failure }
    }

    func query<T>(_ values: [SQLiteValue] = [], map: (SQLiteStatement) throws -> T) throws -> [T] {
        try bind(values)
        defer { sqlite3_reset(handle) }
        var rows: [T] = []
        while true {
            switch sqlite3_step(handle) {
            case SQLITE_ROW: rows.append(try map(self))
            case SQLITE_DONE: return rows
            default: throw failure
            }
        }
    }

    func int(_ column: Int) -> Int { Int(sqlite3_column_int64(handle, Int32(column))) }

    func text(_ column: Int) -> String {
        sqlite3_column_text(handle, Int32(column)).map { String(cString: $0) } ?? ""
    }

    func blob(_ column: Int) -> Data {
        guard let bytes = sqlite3_column_blob(handle, Int32(column)) else { return Data() }
        return Data(bytes: bytes, count: Int(sqlite3_column_bytes(handle, Int32(column))))
    }

    // SQLITE_TRANSIENT makes SQLite copy the bytes; the C macro doesn't import into Swift.
    private static var transient: sqlite3_destructor_type { unsafeBitCast(-1, to: sqlite3_destructor_type.self) }

    private func bind(_ values: [SQLiteValue]) throws {
        sqlite3_clear_bindings(handle)
        for (offset, value) in values.enumerated() {
            let index = Int32(offset + 1)
            let code: Int32
            switch value {
            case .int(let number): code = sqlite3_bind_int64(handle, index, Int64(number))
            case .text(let string): code = sqlite3_bind_text(handle, index, string, -1, Self.transient)
            case .blob(let data):
                code = data.withUnsafeBytes { sqlite3_bind_blob(handle, index, $0.baseAddress, Int32($0.count), Self.transient) }
            }
            guard code == SQLITE_OK else { throw failure }
        }
    }
}

/// One SQLite connection. Not thread-safe: `DictionaryStore` (an actor) owns it and nothing else touches it.
nonisolated final class SQLiteDatabase {
    private let handle: OpaquePointer

    init(url: URL) throws {
        var opened: OpaquePointer?
        let code = sqlite3_open_v2(url.path(percentEncoded: false), &opened,
                                   SQLITE_OPEN_READWRITE | SQLITE_OPEN_CREATE | SQLITE_OPEN_FULLMUTEX, nil)
        guard code == SQLITE_OK, let connection = opened else {
            let message = opened.map { String(cString: sqlite3_errmsg($0)) } ?? "out of memory"
            sqlite3_close_v2(opened)
            throw SQLiteError(message: "Can't open the dictionary database: \(message)")
        }
        handle = connection
    }

    deinit { sqlite3_close_v2(handle) }

    var lastInsertRowID: Int { Int(sqlite3_last_insert_rowid(handle)) }

    /// Runs one or more statements that return no rows we need (DDL, pragmas).
    func exec(_ sql: String) throws {
        guard sqlite3_exec(handle, sql, nil, nil, nil) == SQLITE_OK else {
            throw SQLiteError(message: String(cString: sqlite3_errmsg(handle)))
        }
    }

    func prepare(_ sql: String) throws -> SQLiteStatement { try SQLiteStatement(handle, sql) }

    func run(_ sql: String, _ values: [SQLiteValue] = []) throws { try prepare(sql).run(values) }

    func query<T>(_ sql: String, _ values: [SQLiteValue] = [], map: (SQLiteStatement) throws -> T) throws -> [T] {
        try prepare(sql).query(values, map: map)
    }

    /// Commits if `body` returns, rolls back if it throws.
    func transaction<T>(_ body: () throws -> T) throws -> T {
        try exec("BEGIN IMMEDIATE")
        do {
            let result = try body()
            try exec("COMMIT")
            return result
        } catch {
            try? exec("ROLLBACK")
            throw error
        }
    }
}
