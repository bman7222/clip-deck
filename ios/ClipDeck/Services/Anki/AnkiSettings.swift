import Foundation
import Observation

/// Anki + card settings. Stored on device; lists fetched from AnkiConnect are cached so the
/// pickers still work offline.
struct AnkiSettings: Codable, Equatable {
    /// AnkiConnect address on the computer running Anki, e.g. http://192.168.1.20:8765
    var url: String = ""
    /// Only needed if `apiKey` is set in AnkiConnect's config.
    var apiKey: String = ""
    var deckName: String = ""
    var noteType: String = ""
    /// `CardField.rawValue` → Anki note field name. Empty or missing means "not used".
    var fieldMap: [String: String] = AnkiSettings.defaultFieldMap
    var tags: String = "clipdeck"
    var audioPaddingStartMs: Int = 0
    var audioPaddingEndMs: Int = 500

    var cachedDecks: [String] = []
    var cachedNoteTypes: [String] = []
    /// Note type name → its field names.
    var cachedFields: [String: [String]] = [:]

    /// Field names used by the popular Lapis / Yomitan mining note types; edit in Settings to match yours.
    static let defaultFieldMap: [String: String] = [
        CardField.sentence.rawValue: "Sentence",
        CardField.word.rawValue: "Expression",
        CardField.definition.rawValue: "MainDefinition",
        CardField.audio.rawValue: "SentenceAudio",
        CardField.image.rawValue: "Picture",
        CardField.source.rawValue: "MiscInfo",
    ]

    var tagList: [String] {
        tags.split(whereSeparator: { $0 == " " || $0 == "," }).map(String.init)
    }

    func target(for field: CardField) -> String? {
        guard let name = fieldMap[field.rawValue]?.trimmingCharacters(in: .whitespaces), !name.isEmpty else { return nil }
        return name
    }

    /// What still has to be set before cards can sync, or nil when ready.
    var setupProblem: String? {
        if url.trimmingCharacters(in: .whitespaces).isEmpty { return "Add your computer's AnkiConnect address in Anki settings." }
        if deckName.isEmpty { return "Choose a deck in Anki settings." }
        if noteType.isEmpty { return "Choose a note type in Anki settings." }
        if target(for: .sentence) == nil { return "Choose which Anki field gets the sentence in Anki settings." }
        return nil
    }
}

/// Observable wrapper that saves settings to UserDefaults on every change.
@Observable
final class SettingsStore {
    var anki: AnkiSettings {
        didSet { save() }
    }

    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private let key: String

    init(defaults: UserDefaults = .standard, key: String = "ankiSettings.v1") {
        self.defaults = defaults
        self.key = key
        if let data = defaults.data(forKey: key), let saved = try? JSONDecoder().decode(AnkiSettings.self, from: data) {
            anki = saved
        } else {
            anki = AnkiSettings()
        }
    }

    private func save() {
        if let data = try? JSONEncoder().encode(anki) {
            defaults.set(data, forKey: key)
        }
    }
}
