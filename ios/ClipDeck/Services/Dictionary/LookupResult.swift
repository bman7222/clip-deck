import Foundation

/// What `LookupEngine` returns. T-029 (popup), T-030 and T-031 read only these types.
nonisolated struct LookupResult: Equatable, Sendable {
    /// The longest matched text, as a range of the text that was searched.
    let range: Range<String.Index>
    /// Longest match first, then dictionary priority, frequency and score.
    let entries: [LookupEntry]
}

/// One word, grouped by expression and reading across every enabled dictionary.
nonisolated struct LookupEntry: Equatable, Sendable {
    let expression: String
    let reading: String
    /// The conjugations undone to reach this word, outermost first (`["past", "negative"]`); empty when none were.
    let reasons: [String]
    /// How many characters of the searched text this entry matched.
    let matchLength: Int
    let frequencies: [LookupFrequency]
    /// One per dictionary that has the word, in dictionary priority order.
    let sections: [LookupSection]
}

nonisolated struct LookupFrequency: Equatable, Sendable {
    let dictionaryTitle: String
    let value: Int
    let displayText: String
}

nonisolated struct LookupSection: Equatable, Sendable {
    let dictionaryID: Int
    let dictionaryTitle: String
    let definitions: [LookupDefinition]
}

nonisolated struct LookupDefinition: Equatable, Sendable {
    let tags: [String]
    let termTags: [String]
    let glossary: [GlossaryItem]
}

nonisolated enum GlossaryItem: Equatable, Sendable {
    case text(String)
    /// The JSON of a structured-content or image object, for the renderer in T-029.
    case structured(Data)
}
