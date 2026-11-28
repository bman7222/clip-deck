import Foundation
import NaturalLanguage

/// Finds dictionary entries for a tapped character (`scan`) or a selected piece of text (`lookup(exact:)`), offline.
/// It reads only the `DictionaryStore` and the bundled deconjugation rules.
nonisolated struct LookupEngine: Sendable {
    static let maxLength = 16

    /// One substring to look up: its surface forms (full-width, and with katakana turned into hiragana).
    nonisolated struct Probe: Sendable {
        let length: Int
        let surfaces: [String]
    }

    nonisolated struct Candidate: Sendable {
        let word: String
        let rule: String?
        let reasons: [String]
    }

    nonisolated struct Match {
        var matchLength: Int
        var reasons: [String]
        var rows: Set<Int> = []
    }

    nonisolated struct GroupKey: Hashable {
        let expression: String
        let reading: String
    }

    nonisolated struct Ranked {
        let entry: LookupEntry
        let priority: Int
        let frequencyKey: Double?
        let score: Int
        let order: Int
    }

    let store: DictionaryStore
    let deconjugator: Deconjugator

    init(store: DictionaryStore, deconjugator: Deconjugator) {
        self.store = store
        self.deconjugator = deconjugator
    }

    /// Looks up the word at `index` in `text`: the start moves back to the beginning of the word, then substrings of up
    /// to 16 characters that include the tapped one are tried, longest first. Nil when nothing matches.
    func scan(text: String, at index: String.Index) async throws -> LookupResult? {
        guard index >= text.startIndex, index < text.endIndex else { return nil }
        let tapped = text.distance(from: text.startIndex, to: index)
        var start = text.distance(from: text.startIndex, to: Self.wordStart(in: text, at: index))
        if tapped - start >= Self.maxLength { start = tapped }
        let wide = text.map(Self.widened)
        let plain = wide.map(Self.hiragana)
        let longest = min(Self.maxLength, wide.count - start)
        let probes = stride(from: longest, through: tapped - start + 1, by: -1).map { length in
            Probe(length: length, surfaces: [String(wide[start..<(start + length)]), String(plain[start..<(start + length)])])
        }
        let entries = try await resolve(probes)
        guard let best = entries.first else { return nil }
        let origin = text.index(text.startIndex, offsetBy: start)
        return LookupResult(range: origin..<text.index(origin, offsetBy: best.matchLength), entries: entries)
    }

    /// Looks up all of `text` (a selection), deconjugated but not scanned. Nil when nothing matches.
    func lookup(exact text: String) async throws -> LookupResult? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        let wide = trimmed.map(Self.widened)
        let probe = Probe(length: wide.count, surfaces: [String(wide), String(wide.map(Self.hiragana))])
        let entries = try await resolve([probe])
        guard !entries.isEmpty else { return nil }
        return LookupResult(range: text.startIndex..<text.endIndex, entries: entries)
    }

    // MARK: Pipeline

    /// Probes must run longest first. One batched term query, then the frequencies and dictionaries of what it found.
    private func resolve(_ probes: [Probe]) async throws -> [LookupEntry] {
        let candidates = probes.map { probe in
            var seen = Set<String>()
            let plain = probe.surfaces.filter { seen.insert($0).inserted }.map { Candidate(word: $0, rule: nil, reasons: []) }
            let deconjugated = plain.flatMap { surface in
                deconjugator.deconjugate(surface.word).map { Candidate(word: $0.text, rule: $0.rule, reasons: $0.reasons) }
            }
            return (probe.length, plain + deconjugated)
        }
        let words = Array(Set(candidates.flatMap { $0.1.map(\.word) }))
        let rows = try await store.terms(matching: words)

        var byWord: [String: [Int]] = [:]
        for (index, row) in rows.enumerated() {
            byWord[row.expression, default: []].append(index)
            if row.reading != row.expression { byWord[row.reading, default: []].append(index) }
        }
        var groups: [GroupKey: Match] = [:]
        var order: [GroupKey] = []
        for (length, forms) in candidates {
            for form in forms {
                for index in byWord[form.word] ?? [] {
                    let row = rows[index]
                    if let rule = form.rule, !row.rules.split(separator: " ").contains(Substring(rule)) { continue }
                    let key = GroupKey(expression: row.expression, reading: row.reading)
                    if groups[key] == nil {
                        groups[key] = Match(matchLength: length, reasons: form.reasons)
                        order.append(key)
                    }
                    groups[key]?.rows.insert(index)
                }
            }
        }
        guard !order.isEmpty else { return [] }

        let installed = try await store.dictionaries()
        let infos = Dictionary(uniqueKeysWithValues: installed.map { ($0.id, $0) })
        let frequencyRows = try await store.frequencies(matching: Array(Set(order.map(\.expression))))
        let ranked = order.enumerated().map { position, key in
            rank(key, groups[key]!, rows: rows, infos: infos, frequencyRows: frequencyRows, order: position)
        }
        return ranked.sorted { a, b in
            if a.entry.matchLength != b.entry.matchLength { return a.entry.matchLength > b.entry.matchLength }
            if a.priority != b.priority { return a.priority < b.priority }
            if (a.frequencyKey ?? .infinity) != (b.frequencyKey ?? .infinity) {
                return (a.frequencyKey ?? .infinity) < (b.frequencyKey ?? .infinity)
            }
            if a.score != b.score { return a.score > b.score }
            return a.order < b.order
        }.map(\.entry)
    }

    private func rank(_ key: GroupKey, _ group: Match, rows: [TermRow], infos: [Int: DictionaryInfo],
                      frequencyRows: [FrequencyRow], order: Int) -> Ranked {
        let members = group.rows.sorted().map { rows[$0] }
        let sections = Dictionary(grouping: members, by: \.dictionaryID).compactMap { id, members -> (Int, LookupSection)? in
            guard let info = infos[id] else { return nil }
            let definitions = members.map {
                LookupDefinition(tags: $0.definitionTags.split(separator: " ").map(String.init),
                                 termTags: $0.termTags.split(separator: " ").map(String.init),
                                 glossary: Self.glossary($0.glossaryJSON))
            }
            return (info.priority, LookupSection(dictionaryID: id, dictionaryTitle: info.title, definitions: definitions))
        }.sorted { $0.0 < $1.0 }

        var frequencies: [LookupFrequency] = []
        var frequencyKey: Double?
        for row in frequencyRows where row.term == key.expression {
            guard let info = infos[row.dictionaryID], let (value, shown) = Self.frequency(row.data, reading: key.reading) else { continue }
            frequencies.append(LookupFrequency(dictionaryTitle: info.title, value: value, displayText: shown))
            if frequencyKey == nil { frequencyKey = info.frequencyMode == "occurrence-based" ? -Double(value) : Double(value) }
        }
        let entry = LookupEntry(expression: key.expression, reading: key.reading, reasons: group.reasons,
                                matchLength: group.matchLength, frequencies: frequencies, sections: sections.map(\.1))
        return Ranked(entry: entry, priority: sections.first?.0 ?? Int.max, frequencyKey: frequencyKey,
                      score: members.map(\.score).max() ?? 0, order: order)
    }

    // MARK: Text

    /// NLTokenizer's start of the word holding `index`; `index` itself if the tokenizer has no earlier start.
    private static func wordStart(in text: String, at index: String.Index) -> String.Index {
        let tokenizer = NLTokenizer(unit: .word)
        tokenizer.string = text
        tokenizer.setLanguage(.japanese)
        let start = tokenizer.tokenRange(at: index).lowerBound
        return start <= index ? start : index
    }

    /// Half-width katakana and punctuation to full width (one character stays one character).
    private static func widened(_ character: Character) -> Character {
        guard let scalar = character.unicodeScalars.first, (0xFF61...0xFF9F).contains(scalar.value),
              let wide = String(character).applyingTransform(.fullwidthToHalfwidth, reverse: true), wide.count == 1
        else { return character }
        return wide.first ?? character
    }

    private static func hiragana(_ character: Character) -> Character {
        guard character.unicodeScalars.count == 1, let scalar = character.unicodeScalars.first,
              (0x30A1...0x30F6).contains(scalar.value), let converted = Unicode.Scalar(scalar.value - 0x60)
        else { return character }
        return Character(converted)
    }

    // MARK: Term data

    /// The glossary array of a term row: strings and text objects become text, anything else keeps its JSON.
    static func glossary(_ json: Data) -> [GlossaryItem] {
        guard let items = try? JSONSerialization.jsonObject(with: json) as? [Any] else { return [] }
        return items.compactMap { item in
            if let text = item as? String { return .text(text) }
            guard let object = item as? [String: Any] else { return nil }
            if object["type"] as? String == "text", let text = object["text"] as? String { return .text(text) }
            return (try? JSONSerialization.data(withJSONObject: object)).map(GlossaryItem.structured)
        }
    }

    /// A frequency value and its display text from a term-meta row: a number, a string ("1234" or "1234㋕"), or an
    /// object (`{value, displayValue}` or `{reading, frequency}`, which only applies to that reading). Nil if unusable.
    static func frequency(_ json: String, reading: String) -> (Int, String)? {
        guard let any = try? JSONSerialization.jsonObject(with: Data(json.utf8), options: .fragmentsAllowed) else { return nil }
        return frequencyValue(any, reading: reading)
    }

    private static func frequencyValue(_ any: Any, reading: String) -> (Int, String)? {
        if let object = any as? [String: Any] {
            if let wanted = object["reading"] as? String, wanted != reading { return nil }
            guard let inner = object["frequency"] ?? object["value"], let (value, shown) = frequencyValue(inner, reading: reading) else { return nil }
            return (value, object["displayValue"] as? String ?? shown)
        }
        if let text = any as? String {
            guard let value = Int(String(text.prefix { $0.isASCII && $0.isNumber })) else { return nil }
            return (value, text)
        }
        if let number = any as? NSNumber {
            let value = Int(number.doubleValue.rounded())
            return (value, String(value))
        }
        return nil
    }
}
