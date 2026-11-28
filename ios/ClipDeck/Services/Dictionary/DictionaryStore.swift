import Foundation

nonisolated enum DictionaryKind: String, Sendable {
    case words, frequency
}

nonisolated struct DictionaryInfo: Equatable, Identifiable, Sendable {
    let id: Int
    let title: String
    let revision: String
    let format: Int
    let kind: DictionaryKind
    let priority: Int
    var enabled: Bool
    let attribution: String
    let frequencyMode: String?
    let termCount: Int
    let metaCount: Int
    let tagCount: Int
    /// The uncompressed size of the imported bank files, not the size on disk.
    let bytes: Int

    static let columns = "id, title, revision, format, kind, priority, enabled, attribution, frequency_mode, "
        + "term_count, meta_count, tag_count, bytes"

    init(row: SQLiteStatement) {
        id = row.int(0)
        title = row.text(1)
        revision = row.text(2)
        format = row.int(3)
        kind = DictionaryKind(rawValue: row.text(4)) ?? .words
        priority = row.int(5)
        enabled = row.int(6) != 0
        attribution = row.text(7)
        frequencyMode = row.text(8).isEmpty ? nil : row.text(8)
        termCount = row.int(9)
        metaCount = row.int(10)
        tagCount = row.int(11)
        bytes = row.int(12)
    }
}

nonisolated struct TermRow: Equatable, Sendable {
    let dictionaryID: Int
    let expression: String
    let reading: String
    let definitionTags: String
    let rules: String
    let score: Int
    let sequence: Int
    let termTags: String
    /// The glossary as JSON text bytes (an array of strings and structured-content objects), decompressed.
    let glossaryJSON: Data

    static let columns = "t.dict, t.expression, t.reading, t.def_tags, t.rules, t.score, t.sequence, t.term_tags, t.glossary"

    init(row: SQLiteStatement) throws {
        dictionaryID = row.int(0)
        expression = row.text(1)
        reading = row.text(2)
        definitionTags = row.text(3)
        rules = row.text(4)
        score = row.int(5)
        sequence = row.int(6)
        termTags = row.text(7)
        glossaryJSON = try (row.blob(8) as NSData).decompressed(using: .zlib) as Data
    }
}

/// The offline dictionary database (`Library/Application Support/Dictionaries/dictionaries.sqlite`), reached through the
/// system SQLite3 C API. The actor owns the connection, so every call is serialised; an import holds it until it ends.
actor DictionaryStore {
    static let schemaVersion = 1

    private let db: SQLiteDatabase

    nonisolated static var defaultURL: URL {
        URL.applicationSupportDirectory.appending(path: "Dictionaries/dictionaries.sqlite")
    }

    init(url: URL = DictionaryStore.defaultURL) throws {
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        let db = try SQLiteDatabase(url: url)
        try Self.prepareSchema(db)
        self.db = db
    }

    private static let schema = [
        "CREATE TABLE IF NOT EXISTS dictionaries(id INTEGER PRIMARY KEY AUTOINCREMENT, title TEXT NOT NULL, revision TEXT NOT NULL,",
        " format INTEGER NOT NULL, kind TEXT NOT NULL, priority INTEGER NOT NULL, enabled INTEGER NOT NULL DEFAULT 1,",
        " attribution TEXT NOT NULL DEFAULT '', frequency_mode TEXT NOT NULL DEFAULT '', term_count INTEGER NOT NULL DEFAULT 0,",
        " meta_count INTEGER NOT NULL DEFAULT 0, tag_count INTEGER NOT NULL DEFAULT 0, bytes INTEGER NOT NULL DEFAULT 0,",
        " UNIQUE(title, revision));",
        "CREATE TABLE IF NOT EXISTS terms(dict INTEGER NOT NULL, expression TEXT NOT NULL, reading TEXT NOT NULL,",
        " def_tags TEXT NOT NULL, rules TEXT NOT NULL, score INTEGER NOT NULL, sequence INTEGER NOT NULL,",
        " term_tags TEXT NOT NULL, glossary BLOB NOT NULL);",
        "CREATE INDEX IF NOT EXISTS terms_expression ON terms(expression);",
        "CREATE INDEX IF NOT EXISTS terms_reading ON terms(reading);",
        "CREATE TABLE IF NOT EXISTS term_meta(dict INTEGER NOT NULL, term TEXT NOT NULL, mode TEXT NOT NULL, data TEXT NOT NULL);",
        "CREATE INDEX IF NOT EXISTS term_meta_term ON term_meta(term);",
        "CREATE TABLE IF NOT EXISTS tags(dict INTEGER NOT NULL, name TEXT NOT NULL, category TEXT NOT NULL,",
        " ord INTEGER NOT NULL, notes TEXT NOT NULL, score INTEGER NOT NULL);",
        "PRAGMA user_version = \(schemaVersion);",
    ].joined()

    nonisolated private static func prepareSchema(_ db: SQLiteDatabase) throws {
        let version = try db.query("PRAGMA user_version") { $0.int(0) }.first ?? 0
        guard version <= schemaVersion else {
            throw SQLiteError(message: "The dictionary database was made by a newer version of Clip Deck.")
        }
        try db.exec("PRAGMA journal_mode=WAL; PRAGMA synchronous=NORMAL;")
        if version < schemaVersion { try db.transaction { try db.exec(schema) } }
    }

    // MARK: Import

    /// Imports a Yomitan .zip in one transaction: it completes, or it throws (cancellation: `CancellationError`)
    /// and leaves nothing behind. The new dictionary goes last in priority. `progress` runs on the store's executor.
    func importDictionary(from zip: URL, progress: @Sendable (Double) -> Void = { _ in }) throws -> DictionaryInfo {
        let id = try db.transaction { try YomitanImporter.importZip(zip, into: db, progress: progress) }
        return try info(id)
    }

    // MARK: Dictionaries

    func dictionaries() throws -> [DictionaryInfo] {
        try db.query("SELECT \(DictionaryInfo.columns) FROM dictionaries ORDER BY priority, id", map: DictionaryInfo.init(row:))
    }

    private func info(_ id: Int) throws -> DictionaryInfo {
        guard let info = try db.query("SELECT \(DictionaryInfo.columns) FROM dictionaries WHERE id = ?", [.int(id)],
                                      map: DictionaryInfo.init(row:)).first
        else { throw SQLiteError(message: "Dictionary \(id) isn't installed.") }
        return info
    }

    /// Dictionaries named in `ids` take priority 0, 1, 2 ... in that order; any not named follow, in their old order.
    func setPriorityOrder(_ ids: [Int]) throws {
        try db.transaction {
            let installed = try db.query("SELECT id FROM dictionaries ORDER BY priority, id") { $0.int(0) }
            var seen = Set<Int>()
            let order = (ids + installed).filter { installed.contains($0) && seen.insert($0).inserted }
            let update = try db.prepare("UPDATE dictionaries SET priority = ? WHERE id = ?")
            for (priority, id) in order.enumerated() { try update.run([.int(priority), .int(id)]) }
        }
    }

    func setEnabled(_ id: Int, _ enabled: Bool) throws {
        try db.run("UPDATE dictionaries SET enabled = ? WHERE id = ?", [.int(enabled ? 1 : 0), .int(id)])
    }

    func delete(_ id: Int) throws {
        try db.transaction {
            for table in ["terms", "term_meta", "tags"] { try db.run("DELETE FROM \(table) WHERE dict = ?", [.int(id)]) }
            try db.run("DELETE FROM dictionaries WHERE id = ?", [.int(id)])
        }
    }

    // MARK: Lookup

    /// Term rows of the enabled dictionaries whose expression or reading is one of `words`, in dictionary priority
    /// order, then score (highest first). One bound variable per word, twice, so keep batches to a few hundred.
    func terms(matching words: [String]) throws -> [TermRow] {
        guard !words.isEmpty else { return [] }
        let marks = Array(repeating: "?", count: words.count).joined(separator: ",")
        let sql = "SELECT \(TermRow.columns) FROM terms t JOIN dictionaries d ON d.id = t.dict WHERE d.enabled = 1"
            + " AND (t.expression IN (\(marks)) OR t.reading IN (\(marks))) ORDER BY d.priority, t.score DESC, t.rowid"
        return try db.query(sql, (words + words).map(SQLiteValue.text), map: TermRow.init(row:))
    }
}
