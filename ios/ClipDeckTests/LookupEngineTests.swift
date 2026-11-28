import Foundation
import Testing
@testable import ClipDeck

/// `Deconjugator` and `LookupEngine` against the zips in scripts/fixtures/dictionaries and a generated 200k-term store.
struct LookupEngineTests {
    let databaseURL = FileManager.default.temporaryDirectory
        .appending(path: "LookupEngineTests-\(UUID().uuidString)", directoryHint: .isDirectory)
        .appending(path: "dictionaries.sqlite")

    func fixture(_ name: String) throws -> URL {
        // This file is <repo>/ios/ClipDeckTests/LookupEngineTests.swift.
        let url = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
            .deletingLastPathComponent().appending(path: "scripts/fixtures/dictionaries/\(name).zip")
        try #require(FileManager.default.fileExists(atPath: url.path), "Missing fixture \(name).zip")
        return url
    }

    func deconjugator() throws -> Deconjugator { try Deconjugator.bundled(Bundle(for: SQLiteDatabase.self)) }

    /// A store with the named fixtures imported in order, and an engine on it.
    func makeEngine(_ names: [String]) async throws -> (engine: LookupEngine, store: DictionaryStore, ids: [Int]) {
        let store = try DictionaryStore(url: databaseURL)
        var ids: [Int] = []
        for name in names { ids.append(try await store.importDictionary(from: fixture(name)).id) }
        let rules = try deconjugator()
        return (LookupEngine(store: store, deconjugator: rules), store, ids)
    }

    func at(_ text: String, _ offset: Int) -> String.Index { text.index(text.startIndex, offsetBy: offset) }

    // MARK: Deconjugation

    @Test func deconjugatesTheCommonForms() throws {
        let rules = try deconjugator()
        func found(_ word: String, _ base: String, _ rule: String, _ reasons: [String]) -> Bool {
            rules.deconjugate(word).contains(Deconjugation(text: base, rule: rule, reasons: reasons))
        }
        #expect(found("食べた", "食べる", "v1", ["past"]))
        #expect(found("行かなかった", "行く", "v5", ["past", "negative"]))
        #expect(found("高くない", "高い", "adj-i", ["negative"]))
        #expect(found("来なかった", "来る", "vk", ["past", "negative"]))
        #expect(rules.deconjugate("してしまった").contains { $0.text == "する" && $0.rule == "vs" && $0.reasons.first == "past" })
        #expect(rules.deconjugate("犬").isEmpty)
        #expect(rules.deconjugate("").isEmpty)
    }

    @Test func mapsWordClassesToYomitanRuleIds() {
        let pairs = [("v1", "v1"), ("v1-s", "v1"), ("v5k", "v5"), ("v5aru", "v5"), ("v4r", "v5"), ("vk", "vk"),
                     ("vs-i", "vs"), ("vs-s", "vs"), ("vz", "vz"), ("adj-i", "adj-i"), ("adj-ix", "adj-i"), ("cop", "cop")]
        for (wordClass, rule) in pairs { #expect(Deconjugator.yomitanRule(wordClass) == rule) }
    }

    @Test func badRuleDataIsRefused() {
        #expect(throws: DeconjugationError.self) { try Deconjugator(rulesJSON: Data("not json".utf8)) }
        let uneven = #"[{"type":"stdrule","dec_end":["a","b"],"con_end":["c"],"dec_tag":["v1"],"con_tag":["x"],"detail":"d"}]"#
        #expect(throws: DeconjugationError.self) { try Deconjugator(rulesJSON: Data(uneven.utf8)) }
    }

    // MARK: Scan

    @Test func aTapInTheMiddleOfAConjugatedWordFindsTheDictionaryForm() async throws {
        let (engine, _, _) = try await makeEngine(["words-v3"])
        let text = "食べた"
        let result = try #require(try await engine.scan(text: text, at: at(text, 1)))
        #expect(String(text[result.range]) == "食べた")
        let first = try #require(result.entries.first)
        #expect(first.expression == "食べる" && first.reading == "たべる")
        #expect(first.reasons == ["past"] && first.matchLength == 3)
        #expect(first.sections.map(\.dictionaryTitle) == ["Clip Test Words"])
    }

    @Test func scansNegativesAdjectivesAndSuruVerbs() async throws {
        let (engine, _, _) = try await makeEngine(["words-v3"])
        for (text, expression) in [("行かなかった", "行く"), ("高くない", "高い"), ("してしまった", "する")] {
            let result = try #require(try await engine.scan(text: text, at: text.startIndex))
            #expect(String(text[result.range]) == text)
            #expect(result.entries.first?.expression == expression)
        }
    }

    @Test func katakanaFindsTheWordThroughTheHiraganaCandidate() async throws {
        let (engine, _, _) = try await makeEngine(["words-v3"])
        let text = "タベタ"
        let result = try #require(try await engine.scan(text: text, at: text.startIndex))
        #expect(String(text[result.range]) == "タベタ")
        #expect(result.entries.first?.expression == "食べる")
    }

    @Test func theLongestMatchWins() async throws {
        let (engine, _, _) = try await makeEngine(["words-v3", "lookup-words"])
        let text = "元気です"
        let result = try #require(try await engine.scan(text: text, at: text.startIndex))
        #expect(String(text[result.range]) == "元気")
        #expect(result.entries.map(\.expression).prefix(2) == ["元気", "元"])
        #expect(result.entries.map(\.matchLength).prefix(2) == [2, 1])
    }

    @Test func nothingFoundAndBadIndexesReturnNil() async throws {
        let (engine, _, _) = try await makeEngine(["words-v3"])
        let text = "zzz"
        #expect(try await engine.scan(text: text, at: text.startIndex) == nil)
        #expect(try await engine.scan(text: text, at: text.endIndex) == nil)
        #expect(try await engine.scan(text: "", at: "".startIndex) == nil)
    }

    // MARK: Exact lookup

    @Test func anExactLookupDeconjugatesTheWholeSelectionWithoutScanning() async throws {
        let (engine, _, _) = try await makeEngine(["words-v3", "words-second"])
        let text = "食べた"
        let result = try #require(try await engine.lookup(exact: text))
        #expect(result.range == text.startIndex..<text.endIndex)
        #expect(result.entries.map(\.expression) == ["食べる"] && result.entries[0].reasons == ["past"])

        #expect(try await engine.lookup(exact: "食べるzz") == nil)
        #expect(try await engine.lookup(exact: "  \n") == nil)
        #expect(try await engine.lookup(exact: "ねこ")?.entries.map(\.expression) == ["猫"])
    }

    // MARK: Ranking and grouping

    @Test func definitionsFormOneSectionPerDictionaryInPriorityOrder() async throws {
        let (engine, store, ids) = try await makeEngine(["words-v3", "words-second"])
        let before = try #require(try await engine.lookup(exact: "食べる")).entries
        #expect(before.count == 1)
        #expect(before[0].sections.map(\.dictionaryID) == ids)
        #expect(before[0].sections.map(\.dictionaryTitle) == ["Clip Test Words", "Second Test Words"])
        #expect(before[0].sections[0].definitions[0].tags == ["v1"] && before[0].sections[0].definitions[0].termTags == ["P"])

        try await store.setPriorityOrder([ids[1]])
        let after = try #require(try await engine.lookup(exact: "食べる")).entries
        #expect(after[0].sections.map(\.dictionaryID) == [ids[1], ids[0]])

        try await store.setEnabled(ids[1], false)
        let disabled = try #require(try await engine.lookup(exact: "食べる")).entries
        #expect(disabled[0].sections.map(\.dictionaryID) == [ids[0]])
    }

    @Test func aDisabledDictionaryIsIgnoredCompletely() async throws {
        let (engine, store, ids) = try await makeEngine(["words-v3", "frequency"])
        try await store.setEnabled(ids[0], false)
        #expect(try await engine.lookup(exact: "食べる") == nil)
        try await store.setEnabled(ids[0], true)
        try await store.setEnabled(ids[1], false)
        let entry = try #require(try await engine.lookup(exact: "食べる")).entries[0]
        #expect(entry.frequencies.isEmpty)
    }

    @Test func entriesWithTheSameWordAndDifferentReadingsRankByScore() async throws {
        let (engine, _, _) = try await makeEngine(["words-v3"])
        let entries = try #require(try await engine.lookup(exact: "行く")).entries
        #expect(entries.map(\.reading) == ["いく", "ゆく"])
    }

    @Test func rankBasedFrequencyPutsTheLowerNumberFirst() async throws {
        let (engine, _, _) = try await makeEngine(["lookup-words", "frequency-rank"])
        let entries = try #require(try await engine.lookup(exact: "あし")).entries
        #expect(entries.map(\.expression) == ["足", "脚"])
        #expect(entries[0].frequencies == [LookupFrequency(dictionaryTitle: "Rank Frequency", value: 10, displayText: "10")])
        #expect(entries[1].frequencies == [LookupFrequency(dictionaryTitle: "Rank Frequency", value: 20, displayText: "20 (rare)")])
    }

    @Test func occurrenceBasedFrequencyPutsTheHigherNumberFirst() async throws {
        let (engine, _, _) = try await makeEngine(["lookup-words", "frequency-occurrence"])
        let entries = try #require(try await engine.lookup(exact: "あし")).entries
        #expect(entries.map(\.expression) == ["脚", "足"])
    }

    @Test func frequencyValuesComeFromNumbersObjectsAndReadingObjects() async throws {
        let (engine, _, _) = try await makeEngine(["words-v3", "frequency"])
        func frequencies(_ word: String) async throws -> [LookupFrequency] {
            try #require(try await engine.lookup(exact: word)).entries[0].frequencies
        }
        #expect(try await frequencies("食べる").map(\.value) == [120])
        #expect(try await frequencies("行く").map(\.displayText) == ["340"])
        #expect(try await frequencies("高い").map(\.value) == [55])
        #expect(try await frequencies("する").map(\.value) == [12])
    }

    @Test func frequencyDataAndGlossariesAreDecoded() {
        #expect(LookupEngine.frequency("12", reading: "")?.0 == 12)
        #expect(LookupEngine.frequency(#""1234㋕""#, reading: "")?.1 == "1234㋕")
        #expect(LookupEngine.frequency(#"{"reading":"あ","frequency":7}"#, reading: "い") == nil)
        #expect(LookupEngine.frequency(#"{"reading":"あ","frequency":{"value":7,"displayValue":"7x"}}"#, reading: "あ")?.1 == "7x")
        #expect(LookupEngine.frequency(#""abc""#, reading: "") == nil)
        #expect(LookupEngine.frequency("[1]", reading: "") == nil)

        let glossary = LookupEngine.glossary(Data(#"["a",{"type":"text","text":"b"},{"type":"structured-content","content":"c"}]"#.utf8))
        #expect(glossary.count == 3 && glossary[0] == .text("a") && glossary[1] == .text("b"))
        #expect(LookupEngine.glossary(Data("{}".utf8)).isEmpty)
    }

    // MARK: Normalising and rule matching (tester, T-027 round 2)

    @Test func halfWidthKatakanaIsWidenedBeforeTheLookup() async throws {
        let (engine, _, _) = try await makeEngine(["words-v3", "words-second"])
        let text = "ﾈｺ"
        let result = try #require(try await engine.scan(text: text, at: text.startIndex))
        #expect(String(text[result.range]) == "ﾈｺ")
        #expect(result.entries.first?.expression == "猫")
    }

    /// One dictionary holding one term, written straight into the database.
    func seedTerm(_ expression: String, reading: String, rules: String) throws {
        let db = try SQLiteDatabase(url: databaseURL)
        let glossary = try (Data(#"["definition"]"#.utf8) as NSData).compressed(using: .zlib) as Data
        try db.run("INSERT INTO dictionaries(title, revision, format, kind, priority, enabled, term_count)"
                   + " VALUES ('Seeded', '1', 3, 'words', 0, 1, 1)")
        let dict = db.lastInsertRowID
        try db.run("INSERT INTO terms VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)",
                   [.int(dict), .text(expression), .text(reading), .text(rules), .text(rules), .int(1), .int(1), .text(""), .blob(glossary)])
    }

    @Test func aDeconjugatedFormNeedsAnEntryWhoseRulesMatch() async throws {
        let store = try DictionaryStore(url: databaseURL)
        try seedTerm("食べる", reading: "たべる", rules: "v5")
        let engine = LookupEngine(store: store, deconjugator: try deconjugator())
        #expect(try await engine.lookup(exact: "食べた") == nil)
        #expect(try await engine.lookup(exact: "食べる")?.entries.map(\.expression) == ["食べる"])
    }

    // MARK: Performance

    /// Writes `count` generated three-kana terms and one real verb straight into the database, as dictionary 1.
    func seedSyntheticTerms(count: Int) throws {
        let db = try SQLiteDatabase(url: databaseURL)
        let glossary = try (Data(#"["definition"]"#.utf8) as NSData).compressed(using: .zlib) as Data
        let places = [1, 80, 6_400]
        try db.transaction {
            try db.run("INSERT INTO dictionaries(title, revision, format, kind, priority, enabled, term_count)"
                       + " VALUES ('Synthetic', '1', 3, 'words', 0, 1, \(count))")
            let dict = db.lastInsertRowID
            let insert = try db.prepare("INSERT INTO terms VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)")
            for i in 0..<count {
                let kana = places.map { Unicode.Scalar(UInt32(0x3042 + (i / $0) % 80)) ?? "あ" }
                let word = String(String.UnicodeScalarView(kana))
                try insert.run([.int(dict), .text(word), .text(word), .text(""), .text(""), .int(i % 10), .int(i), .text(""), .blob(glossary)])
            }
            try insert.run([.int(dict), .text("食べる"), .text("たべる"), .text("v1"), .text("v1"), .int(9), .int(count), .text(""), .blob(glossary)])
        }
    }

    @Test func medianScanOfA200kTermStoreIsUnder50ms() async throws {
        let store = try DictionaryStore(url: databaseURL)
        try seedSyntheticTerms(count: 200_000)
        let rules = try deconjugator()
        let engine = LookupEngine(store: store, deconjugator: rules)
        let text = "昨日友達と一緒においしい寿司を食べたけどやっぱり高くなかった"
        let taps = stride(from: 0, to: text.count, by: 3).map { at(text, $0) }
        _ = try await engine.scan(text: text, at: taps[0])

        let clock = ContinuousClock()
        var milliseconds: [Double] = []
        for _ in 0..<3 {
            for tap in taps {
                let started = clock.now
                _ = try await engine.scan(text: text, at: tap)
                let spent = clock.now - started
                milliseconds.append(Double(spent.components.seconds) * 1_000 + Double(spent.components.attoseconds) / 1e15)
            }
        }
        let sorted = milliseconds.sorted()
        let median = sorted[sorted.count / 2]
        let report = "scans: \(sorted.count), terms: 200000, median: \(median) ms, max: \(sorted[sorted.count - 1]) ms\n"
            + "all (ms): \(sorted.map { String(format: "%.1f", $0) }.joined(separator: " "))\n"
        print(report)
        Attachment.record(report, named: "scan-timings.txt")
        #expect(median < 50, "median scan \(median) ms")
    }
}
