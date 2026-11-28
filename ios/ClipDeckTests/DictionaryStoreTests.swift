import Foundation
import Testing
@testable import ClipDeck

/// `DictionaryStore` and `YomitanImporter` against the tiny zips in scripts/fixtures/dictionaries
/// (rebuilt by scripts/make-dictionary-fixtures.py). Each test gets its own database file.
struct DictionaryStoreTests {
    final class ProgressLog: @unchecked Sendable {
        private let lock = NSLock()
        private var values: [Double] = []
        var all: [Double] { lock.withLock { values } }
        @discardableResult func add(_ value: Double) -> Int { lock.withLock { values.append(value); return values.count } }
    }

    let databaseURL = FileManager.default.temporaryDirectory
        .appending(path: "DictionaryStoreTests-\(UUID().uuidString)", directoryHint: .isDirectory)
        .appending(path: "dictionaries.sqlite")

    func makeStore() throws -> DictionaryStore { try DictionaryStore(url: databaseURL) }

    func fixture(_ name: String) throws -> URL {
        // This file is <repo>/ios/ClipDeckTests/DictionaryStoreTests.swift.
        let url = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
            .deletingLastPathComponent().appending(path: "scripts/fixtures/dictionaries/\(name).zip")
        try #require(FileManager.default.fileExists(atPath: url.path), "Missing fixture \(name).zip")
        return url
    }

    /// Row counts read through a second connection, so they show what is really committed.
    func rowCounts() throws -> [Int] {
        let db = try SQLiteDatabase(url: databaseURL)
        return try ["dictionaries", "terms", "term_meta", "tags"].map { table in
            try db.query("SELECT count(*) FROM \(table)") { $0.int(0) }[0]
        }
    }

    @Test func importsWordsFrequencyAndLegacyDictionariesInPriorityOrder() async throws {
        let store = try makeStore()
        let log = ProgressLog()
        let words = try await store.importDictionary(from: fixture("words-v3")) { log.add($0) }
        _ = try await store.importDictionary(from: fixture("words-second"))
        _ = try await store.importDictionary(from: fixture("frequency"))
        _ = try await store.importDictionary(from: fixture("legacy-v1"))

        let all = try await store.dictionaries()
        #expect(all.map(\.title) == ["Clip Test Words", "Second Test Words", "Test Frequency", "Legacy Words"])
        #expect(all.map(\.priority) == [0, 1, 2, 3])
        #expect(all.map(\.kind) == [.words, .words, .frequency, .words])
        #expect(all.map(\.format) == [3, 3, 3, 1])
        #expect(all.map(\.termCount) == [9, 2, 0, 2])
        #expect(all.map(\.metaCount) == [0, 0, 4, 0])
        #expect(all.map(\.tagCount) == [3, 0, 0, 0])
        #expect(all.allSatisfy { $0.enabled && $0.bytes > 0 })
        #expect(all[0] == words)
        #expect(all[0].revision == "2026.1")
        #expect(all[0].attribution == "Test data written for Clip Deck\nClip Deck\nhttps://example.com/test")
        #expect(all[0].frequencyMode == nil)
        #expect(all[2].frequencyMode == "rank-based")
        #expect(try rowCounts() == [4, 13, 4, 3])

        let steps = log.all
        #expect(steps.first == 0 && steps.last == 1)
        #expect(steps == steps.sorted())
    }

    @Test func termsMatchExpressionsAndReadingsInPriorityOrder() async throws {
        let store = try makeStore()
        _ = try await store.importDictionary(from: fixture("words-v3"))
        let second = try await store.importDictionary(from: fixture("words-second"))
        let legacy = try await store.importDictionary(from: fixture("legacy-v1"))

        #expect(try await store.terms(matching: []).isEmpty)
        #expect(try await store.terms(matching: ["nothing"]).isEmpty)

        let eat = try await store.terms(matching: ["食べる"])
        #expect(eat.count == 2 && eat[0].dictionaryID != second.id && eat[1].dictionaryID == second.id)
        #expect(eat[0].reading == "たべる" && eat[0].rules == "v1" && eat[0].definitionTags == "v1")
        #expect(eat[0].score == 9 && eat[0].sequence == 5 && eat[0].termTags == "P")
        let glossary = try #require(try JSONSerialization.jsonObject(with: eat[0].glossaryJSON) as? [[String: Any]])
        #expect(glossary.first?["type"] as? String == "structured-content")

        // The reading ゆく finds 行く, and both readings of 行く come back for the expression.
        #expect(try await store.terms(matching: ["ゆく"]).map(\.expression) == ["行く"])
        #expect(try await store.terms(matching: ["行く"]).map(\.reading) == ["いく", "ゆく"])

        // A v1 glossary is the flat list after the score.
        let dog = try #require(try await store.terms(matching: ["犬"]).first)
        #expect(dog.dictionaryID == legacy.id && dog.sequence == 0 && dog.termTags == "")
        #expect(try JSONSerialization.jsonObject(with: dog.glossaryJSON) as? [String] == ["dog", "hound"])

        try await store.setPriorityOrder([second.id])
        #expect(try await store.terms(matching: ["食べる"]).map(\.dictionaryID).first == second.id)
        try await store.setEnabled(second.id, false)
        #expect(try await store.terms(matching: ["食べる"]).count == 1)
    }

    @Test func aDuplicateTitleAndRevisionIsRejected() async throws {
        let store = try makeStore()
        _ = try await store.importDictionary(from: fixture("words-v3"))
        let before = try rowCounts()
        let message = "Clip Test Words (2026.1) is already installed."
        await #expect {
            try await store.importDictionary(from: fixture("words-v3"))
        } throws: { error in
            (error as? DictionaryImportError) == .alreadyInstalled(title: "Clip Test Words", revision: "2026.1")
                && error.localizedDescription == message
        }
        #expect(try rowCounts() == before)
    }

    @Test func badZipsAreRejectedAndLeaveNothing() async throws {
        let store = try makeStore()
        let cases: [(String, DictionaryImportError)] = [
            ("no-index", .missingIndex),
            ("format-9", .unsupportedFormat(9)),
            ("corrupt", .corrupt("the zip")),
            ("bad-bank", .corrupt("term_bank_2.json")),
        ]
        for (name, expected) in cases {
            await #expect(throws: expected) { try await store.importDictionary(from: fixture(name)) }
            #expect(try rowCounts() == [0, 0, 0, 0], "\(name) left rows behind")
        }
        #expect(try await store.dictionaries().isEmpty)
    }

    @Test func aCancelledImportRollsBack() async throws {
        let store = try makeStore()
        let zip = try fixture("words-v3")
        let log = ProgressLog()
        let task = Task {
            // Calls: 0 at the start, then one per bank (tag bank, term bank 1, ...). Cancel once term bank 1 is in.
            try await store.importDictionary(from: zip) { value in
                if log.add(value) == 3 { withUnsafeCurrentTask { $0?.cancel() } }
            }
        }
        await #expect(throws: CancellationError.self) { try await task.value }
        #expect(log.all.count == 3)
        #expect(try rowCounts() == [0, 0, 0, 0])
        _ = try await store.importDictionary(from: zip)
        #expect(try rowCounts()[1] == 9)
    }

    @Test func deletingRemovesEveryRowOfThatDictionary() async throws {
        let store = try makeStore()
        let words = try await store.importDictionary(from: fixture("words-v3"))
        let frequency = try await store.importDictionary(from: fixture("frequency"))

        try await store.delete(words.id)
        #expect(try rowCounts() == [1, 0, 4, 0])
        #expect(try await store.dictionaries().map(\.id) == [frequency.id])
        try await store.delete(frequency.id)
        #expect(try rowCounts() == [0, 0, 0, 0])
    }

    @Test func enabledAndPriorityAreKeptWhenTheStoreIsReopened() async throws {
        let store = try makeStore()
        let first = try await store.importDictionary(from: fixture("words-v3"))
        let second = try await store.importDictionary(from: fixture("words-second"))
        try await store.setPriorityOrder([second.id, first.id])
        try await store.setEnabled(first.id, false)
        let third = try await store.importDictionary(from: fixture("frequency"))

        let reopened = try makeStore()
        let all = try await reopened.dictionaries()
        #expect(all.map(\.id) == [second.id, first.id, third.id])
        #expect(all.map(\.enabled) == [true, false, true])
        #expect(all.map(\.priority) == [0, 1, 2])
    }

    @Test @MainActor func schemaVersionIndexesAndDefaultLocation() throws {
        #expect(DictionaryStore.defaultURL.path(percentEncoded: false)
            .hasSuffix("Library/Application Support/Dictionaries/dictionaries.sqlite"))
        _ = try makeStore()
        let db = try SQLiteDatabase(url: databaseURL)
        #expect(try db.query("PRAGMA user_version") { $0.int(0) } == [DictionaryStore.schemaVersion])
        #expect(try db.query("PRAGMA journal_mode") { $0.text(0) } == ["wal"])
        let indexes = try db.query("SELECT tbl_name || '.' || sql FROM sqlite_master WHERE type = 'index' AND sql IS NOT NULL") {
            $0.text(0)
        }
        #expect(indexes.contains { $0.hasPrefix("terms.") && $0.contains("(expression)") })
        #expect(indexes.contains { $0.hasPrefix("terms.") && $0.contains("(reading)") })
        #expect(indexes.contains { $0.hasPrefix("term_meta.") && $0.contains("(term)") })
        let tables = try db.query("SELECT name FROM sqlite_master WHERE type = 'table'") { $0.text(0) }
        #expect(Set(["dictionaries", "terms", "term_meta", "tags"]).isSubset(of: Set(tables)))

        let licence = LicenceText.load("ZIPFoundation-LICENSE", bundle: Bundle(for: SQLiteDatabase.self))
        #expect(licence.contains("MIT License") && licence.contains("Thomas Zoechling"))
    }

    @Test func priorityOrderIgnoresUnknownAndRepeatedIDsAndKeepsTheRest() async throws {
        let store = try makeStore()
        let first = try await store.importDictionary(from: fixture("words-v3"))
        let second = try await store.importDictionary(from: fixture("words-second"))
        let third = try await store.importDictionary(from: fixture("frequency"))
        try await store.setPriorityOrder([third.id, 999, third.id])
        #expect(try await store.dictionaries().map(\.id) == [third.id, first.id, second.id])
    }
}
