import Foundation
import SQLite3

/// A SQLite database another app keeps open, read from a private copy: the file and its
/// write-ahead log (where the newest rows may still be) are copied, opened read-write (a
/// WAL database refuses a read-only open when its shared-memory file is missing, and the
/// copy is ours to touch), queried, and deleted.
struct SQLiteCopy {
    private let copy: URL
    private let db: OpaquePointer

    init?(of database: URL) {
        let copy = FileManager.default.temporaryDirectory.appendingPathComponent("agentbar-\(UUID().uuidString).sqlite")
        guard (try? FileManager.default.copyItem(at: database, to: copy)) != nil else { return nil }
        try? FileManager.default.copyItem(at: URL(fileURLWithPath: database.path + "-wal"),
                                          to: URL(fileURLWithPath: copy.path + "-wal"))
        var handle: OpaquePointer?
        guard sqlite3_open_v2(copy.path, &handle, SQLITE_OPEN_READWRITE, nil) == SQLITE_OK, let db = handle else {
            Self.remove(copy)
            return nil
        }
        self.copy = copy
        self.db = db
    }

    func close() {
        sqlite3_close(db)
        Self.remove(copy)
    }

    private static func remove(_ copy: URL) {
        for leftover in [copy, URL(fileURLWithPath: copy.path + "-wal"), URL(fileURLWithPath: copy.path + "-shm")] {
            try? FileManager.default.removeItem(at: leftover)
        }
    }

    /// One text value from a key/value table.
    func value(in table: String, key: String) -> String? {
        rows(in: table, keyLike: key).first?.value
    }

    /// Every (key, value) in a key/value table whose key matches a `LIKE` pattern.
    func rows(in table: String, keyLike pattern: String) -> [(key: String, value: String)] {
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, "select key, value from \(table) where key like ?", -1, &statement, nil) == SQLITE_OK,
              let query = statement else { return [] }
        defer { sqlite3_finalize(query) }
        sqlite3_bind_text(query, 1, pattern, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))
        var rows: [(String, String)] = []
        while sqlite3_step(query) == SQLITE_ROW {
            guard let key = sqlite3_column_text(query, 0), let value = sqlite3_column_text(query, 1) else { continue }
            rows.append((String(cString: key), String(cString: value)))
        }
        return rows
    }
}
