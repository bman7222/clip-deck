import Foundation

nonisolated struct DeconjugationError: LocalizedError, Equatable {
    let message: String
    var errorDescription: String? { message }
}

/// One way a conjugated word can be read as a dictionary form: `text` is that form, `rule` its Yomitan rule id
/// (v1, v5, vk, vs, vz, adj-i, cop), `reasons` the conjugations undone, outermost first (`["past", "negative"]`).
nonisolated struct Deconjugation: Equatable, Sendable {
    let text: String
    let rule: String
    let reasons: [String]
}

/// Undoes Japanese verb and adjective conjugation with the rule table in `Resources/Dictionary/deconjugation_rules.json`
/// (JL's table, Apache-2.0, derived from Nazeka's; see `Deconjugation-LICENSE.txt`). Rules are applied right to left
/// from the end of the word, each one trading a conjugated ending for a plainer one, until a dictionary word class is reached.
nonisolated struct Deconjugator: Sendable {
    nonisolated enum Kind: String, Decodable, Sendable {
        case std = "stdrule", neverFinal = "neverfinalrule", onlyFinal = "onlyfinalrule", rewrite = "rewriterule"
    }

    nonisolated struct RawRule: Decodable {
        let type: Kind
        let decEnd: [String]
        let conEnd: [String]
        let decTag: [String]
        let conTag: [String]
        let detail: String

        enum CodingKeys: String, CodingKey {
            case type, detail
            case decEnd = "dec_end", conEnd = "con_end", decTag = "dec_tag", conTag = "con_tag"
        }
    }

    nonisolated struct Rule: Sendable {
        let kind: Kind
        let decEnd: String
        let conEnd: String
        let decTag: String
        let conTag: String
        let reason: String?
    }

    nonisolated struct Form: Sendable {
        let text: String
        let tag: String
        let reasons: [String]
    }

    /// Rules grouped by the last character of their conjugated ending, so most are skipped without a string compare.
    nonisolated struct RuleIndex: Sendable {
        var byEnd: [Character: [Rule]] = [:]
        var anyEnd: [Rule] = []

        mutating func add(_ rule: Rule) {
            if let last = rule.conEnd.last { byEnd[last, default: []].append(rule) } else { anyEnd.append(rule) }
        }

        func candidates(for text: String) -> [Rule] {
            (text.last.flatMap { byEnd[$0] } ?? []) + anyEnd
        }
    }

    private static let wordClasses: Set<String> = [
        "adj-i", "adj-ix", "cop", "v1", "v1-s", "v4r", "v5aru", "v5b", "v5g", "v5k", "v5k-s", "v5m", "v5n", "v5r", "v5r-i",
        "v5s", "v5t", "v5u", "v5u-s", "vk", "vs-c", "vs-i", "vs-s", "vz",
    ]
    private static let maxReasons = 7
    private static let maxGrowth = 10

    private let initial: RuleIndex
    private let byTag: [String: RuleIndex]

    init(rulesJSON: Data) throws {
        let raw: [RawRule]
        do { raw = try JSONDecoder().decode([RawRule].self, from: rulesJSON) } catch {
            throw DeconjugationError(message: "The deconjugation rules can't be read: \(error.localizedDescription)")
        }
        var initial = RuleIndex()
        var byTag: [String: RuleIndex] = [:]
        for rule in raw {
            let count = rule.conEnd.count
            guard rule.decEnd.count == count, rule.conTag.count == 1 || rule.conTag.count == count,
                  rule.decTag.count == 1 || rule.decTag.count == count
            else { throw DeconjugationError(message: "A deconjugation rule has lists of different lengths: \(rule.detail)") }
            let proper = !rule.detail.isEmpty && !rule.detail.hasPrefix("(")
            for i in 0..<count {
                let built = Rule(kind: rule.type, decEnd: rule.decEnd[i], conEnd: rule.conEnd[i],
                                 decTag: rule.decTag.count == 1 ? rule.decTag[0] : rule.decTag[i],
                                 conTag: rule.conTag.count == 1 ? rule.conTag[0] : rule.conTag[i],
                                 reason: proper ? rule.detail : nil)
                if built.kind != .neverFinal { initial.add(built) }
                if built.kind != .onlyFinal { byTag[built.conTag, default: RuleIndex()].add(built) }
            }
        }
        self.initial = initial
        self.byTag = byTag
    }

    static func bundled(_ bundle: Bundle = .main) throws -> Deconjugator {
        guard let url = bundle.url(forResource: "deconjugation_rules", withExtension: "json"),
              let data = try? Data(contentsOf: url)
        else { throw DeconjugationError(message: "The deconjugation rules are missing from the app.") }
        return try Deconjugator(rulesJSON: data)
    }

    /// Yomitan's rule id for a word class; classes Yomitan has no id for (cop) keep their own name.
    static func yomitanRule(_ wordClass: String) -> String {
        switch wordClass {
        case "v1", "v1-s": return "v1"
        case "vs-i", "vs-s", "vs-c": return "vs"
        case "adj-i", "adj-ix": return "adj-i"
        case _ where wordClass.hasPrefix("v5") || wordClass == "v4r": return "v5"
        default: return wordClass
        }
    }

    /// Every dictionary form `text` can be read as, nearest first. `text` itself is not included.
    func deconjugate(_ text: String) -> [Deconjugation] {
        guard !text.isEmpty else { return [] }
        let limit = text.count + Self.maxGrowth
        var seen: Set<String> = [text + "\n"]
        var found: Set<String> = []
        var results: [Deconjugation] = []
        var frontier = [Form(text: text, tag: "", reasons: [])]
        while !frontier.isEmpty {
            var next: [Form] = []
            for form in frontier {
                if !form.reasons.isEmpty, Self.wordClasses.contains(form.tag) {
                    let rule = Self.yomitanRule(form.tag)
                    if found.insert(form.text + "\n" + rule).inserted {
                        results.append(Deconjugation(text: form.text, rule: rule, reasons: form.reasons))
                    }
                }
                guard form.reasons.count <= Self.maxReasons, form.text.count <= limit else { continue }
                let rules = form.tag.isEmpty ? initial.candidates(for: form.text) : (byTag[form.tag]?.candidates(for: form.text) ?? [])
                for rule in rules {
                    guard form.text.hasSuffix(rule.conEnd), rule.kind != .rewrite || form.text == rule.conEnd,
                          !(rule.decEnd.isEmpty && form.text == rule.conEnd)
                    else { continue }
                    let text = String(form.text.dropLast(rule.conEnd.count)) + rule.decEnd
                    guard seen.insert(text + "\n" + rule.decTag).inserted else { continue }
                    next.append(Form(text: text, tag: rule.decTag, reasons: form.reasons + (rule.reason.map { [$0] } ?? [])))
                }
            }
            frontier = next
        }
        return results
    }
}
