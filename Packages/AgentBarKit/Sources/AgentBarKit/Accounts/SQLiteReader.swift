import Foundation
import SQLite3

/// A SQLite database another app keeps open, read in place and read-only.
///
/// Nothing is copied: Cursor's state database runs to gigabytes, and copying it for
/// every read was the app's single largest cost. A read-only connection beside the
/// running writer is what SQLite is built for; with the writer gone, its shared-memory
/// file may be gone too, and the database is then opened as immutable, which reads
/// without it (and without a write-ahead log, which a writer that closed cleanly has
/// already folded in).
struct SQLiteReader {
    private let db: OpaquePointer

    init?(reading database: URL) {
        var handle: OpaquePointer?
        if sqlite3_open_v2(database.path, &handle, SQLITE_OPEN_READONLY, nil) == SQLITE_OK,
           let db = handle, Self.canRead(db) {
            self.db = db
            return
        }
        if let handle { sqlite3_close(handle) }
        handle = nil
        guard let path = database.path.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed),
              sqlite3_open_v2("file:\(path)?immutable=1", &handle, SQLITE_OPEN_READONLY | SQLITE_OPEN_URI, nil) == SQLITE_OK,
              let db = handle else {
            if let handle { sqlite3_close(handle) }
            return nil
        }
        self.db = db
    }

    /// Opening succeeds before the file is touched; the first read is where a WAL
    /// database with no shared-memory file says no.
    private static func canRead(_ db: OpaquePointer) -> Bool {
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, "select 1 from sqlite_master limit 1", -1, &statement, nil) == SQLITE_OK,
              let query = statement else { return false }
        defer { sqlite3_finalize(query) }
        let step = sqlite3_step(query)
        return step == SQLITE_ROW || step == SQLITE_DONE
    }

    func close() {
        sqlite3_close(db)
    }

    /// One text value from a key/value table, found through the key's index.
    func value(in table: String, key: String) -> String? {
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, "select value from \(table) where key = ?", -1, &statement, nil) == SQLITE_OK,
              let query = statement else { return nil }
        defer { sqlite3_finalize(query) }
        sqlite3_bind_text(query, 1, key, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))
        guard sqlite3_step(query) == SQLITE_ROW, let value = sqlite3_column_text(query, 0) else { return nil }
        return String(cString: value)
    }
}
