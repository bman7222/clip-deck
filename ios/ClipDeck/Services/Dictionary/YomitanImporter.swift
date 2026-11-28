import Foundation
import ZIPFoundation

nonisolated enum DictionaryImportError: LocalizedError, Equatable {
    case alreadyInstalled(title: String, revision: String)
    case missingIndex
    case unsupportedFormat(Int?)
    case corrupt(String)
    case nothingToImport(title: String)

    var errorDescription: String? {
        switch self {
        case .alreadyInstalled(let title, let revision): "\(title) (\(revision)) is already installed."
        case .missingIndex: "This isn't a Yomitan dictionary: the zip has no index.json."
        case .unsupportedFormat(let format):
            "Dictionary format \(format.map(String.init) ?? "unknown") isn't supported. Clip Deck reads formats 1 to 3."
        case .corrupt(let what): "Can't read \(what): it is corrupt or incomplete."
        case .nothingToImport(let title): "\(title) has no words or frequency data that Clip Deck can use."
        }
    }
}

/// Reads a Yomitan dictionary .zip (formats 1 to 3) into a `DictionaryStore` database, written from the format
/// description only. Term banks, frequency rows of term-meta banks and tag banks are kept; kanji banks and the
/// pitch and IPA rows are ignored. Synchronous: the store's actor runs it inside its transaction, one bank file at a
/// time, and a cancelled task stops it at the next bank or after 1,000 rows (the transaction then rolls back).
nonisolated enum YomitanImporter {
    private static let cancelCheckInterval = 1_000

    /// Returns the new dictionary's id. Throws `DictionaryImportError`, or `CancellationError`.
    static func importZip(_ zip: URL, into db: SQLiteDatabase, progress: @Sendable (Double) -> Void) throws -> Int {
        let archive: Archive
        do { archive = try Archive(url: zip, accessMode: .read) } catch { throw DictionaryImportError.corrupt("the zip") }
        var files: [String: Entry] = [:]
        for entry in archive where entry.type == .file { files[entry.path] = entry }

        guard let indexEntry = files["index.json"] else { throw DictionaryImportError.missingIndex }
        guard let index = try json(indexEntry, in: archive) as? [String: Any] else {
            throw DictionaryImportError.corrupt("index.json")
        }
        let declared = (index["format"] as? Int) ?? (index["version"] as? Int)
        guard let format = declared, (1...3).contains(format) else { throw DictionaryImportError.unsupportedFormat(declared) }
        guard let title = index["title"] as? String, !title.isEmpty else { throw DictionaryImportError.corrupt("index.json") }
        let revision = index["revision"] as? String ?? ""
        let attribution = ["attribution", "author", "url"].compactMap { index[$0] as? String }
            .filter { !$0.isEmpty }.joined(separator: "\n")

        let duplicate = try db.query("SELECT 1 FROM dictionaries WHERE title = ? AND revision = ?",
                                     [.text(title), .text(revision)]) { $0.int(0) }
        guard duplicate.isEmpty else { throw DictionaryImportError.alreadyInstalled(title: title, revision: revision) }

        let prefixes = ["term_bank_", "term_meta_bank_", "tag_bank_"]
        let banks = files.keys.sorted().filter { name in name.hasSuffix(".json") && prefixes.contains { name.hasPrefix($0) } }
        let totalBytes = banks.reduce(0) { $0 + Int(files[$1]?.uncompressedSize ?? 0) }

        try db.run("INSERT INTO dictionaries(title, revision, format, kind, priority, attribution, frequency_mode, bytes)"
                   + " VALUES (?, ?, ?, 'words', (SELECT COALESCE(MAX(priority), -1) + 1 FROM dictionaries), ?, ?, ?)",
                   [.text(title), .text(revision), .int(format), .text(attribution),
                    .text(index["frequencyMode"] as? String ?? ""), .int(totalBytes)])
        let dict = db.lastInsertRowID

        let insertTerm = try db.prepare("INSERT INTO terms VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)")
        let insertMeta = try db.prepare("INSERT INTO term_meta VALUES (?, ?, ?, ?)")
        let insertTag = try db.prepare("INSERT INTO tags VALUES (?, ?, ?, ?, ?, ?)")
        var counts = (terms: 0, meta: 0, tags: 0)
        var doneBytes = 0
        progress(0)
        for name in banks {
            try Task.checkCancellation()
            guard let entry = files[name], let rows = try json(entry, in: archive) as? [Any] else {
                throw DictionaryImportError.corrupt(name)
            }
            for (number, raw) in rows.enumerated() {
                if number % cancelCheckInterval == 0 { try Task.checkCancellation() }
                guard let row = raw as? [Any] else { throw DictionaryImportError.corrupt(name) }
                if name.hasPrefix("term_meta_bank_") {
                    guard row.count >= 3, let term = row[0] as? String, let mode = row[1] as? String else {
                        throw DictionaryImportError.corrupt(name)
                    }
                    guard mode == "freq" else { continue }
                    let data = try JSONSerialization.data(withJSONObject: row[2], options: .fragmentsAllowed)
                    try insertMeta.run([.int(dict), .text(term), .text(mode), .text(String(decoding: data, as: UTF8.self))])
                    counts.meta += 1
                } else if name.hasPrefix("term_bank_") {
                    try insertTerm.run(termValues(row, format: format, dict: dict, file: name))
                    counts.terms += 1
                } else {
                    guard row.count >= 1, let tag = row[0] as? String else { throw DictionaryImportError.corrupt(name) }
                    try insertTag.run([.int(dict), .text(tag), .text(field(row, 1, "")), .int(field(row, 2, 0)),
                                       .text(field(row, 3, "")), .int(field(row, 4, 0))])
                    counts.tags += 1
                }
            }
            doneBytes += Int(entry.uncompressedSize)
            progress(Double(doneBytes) / Double(max(totalBytes, 1)))
        }

        guard counts.terms > 0 || counts.meta > 0 else { throw DictionaryImportError.nothingToImport(title: title) }
        try db.run("UPDATE dictionaries SET kind = ?, term_count = ?, meta_count = ?, tag_count = ? WHERE id = ?",
                   [.text(counts.terms > 0 ? "words" : "frequency"), .int(counts.terms), .int(counts.meta),
                    .int(counts.tags), .int(dict)])
        progress(1)
        return dict
    }

    /// v1 rows are [expression, reading, tags, rules, score, glossary...]; v2 and v3 put the glossary in one array
    /// at index 5, followed by [sequence, term tags].
    private static func termValues(_ row: [Any], format: Int, dict: Int, file: String) throws -> [SQLiteValue] {
        guard row.count >= 5, let expression = row[0] as? String, let reading = row[1] as? String else {
            throw DictionaryImportError.corrupt(file)
        }
        let glossary: [Any]
        if format == 1 {
            glossary = Array(row.dropFirst(5))
        } else if row.count > 5, let array = row[5] as? [Any] {
            glossary = array
        } else {
            throw DictionaryImportError.corrupt(file)
        }
        let packed = try (JSONSerialization.data(withJSONObject: glossary) as NSData).compressed(using: .zlib) as Data
        return [.int(dict), .text(expression), .text(reading), .text(field(row, 2, "")), .text(field(row, 3, "")),
                .int(field(row, 4, 0)), .int(format == 1 ? 0 : field(row, 6, 0)),
                .text(format == 1 ? "" : field(row, 7, "")), .blob(packed)]
    }

    private static func field<T>(_ row: [Any], _ index: Int, _ fallback: T) -> T {
        index < row.count ? (row[index] as? T ?? fallback) : fallback
    }

    private static func json(_ entry: Entry, in archive: Archive) throws -> Any {
        var data = Data()
        do {
            _ = try archive.extract(entry) { data.append($0) }
            return try JSONSerialization.jsonObject(with: data)
        } catch {
            throw DictionaryImportError.corrupt(entry.path)
        }
    }
}
