import Foundation
import SwiftData

/// A show groups episodes (e.g. "Attack on Titan").
@Model
final class Show {
    @Attribute(.unique) var name: String
    /// Index into `Theme.tileHues`; picked when the show is created.
    var colorIndex: Int
    var createdAt: Date
    @Relationship(deleteRule: .cascade, inverse: \Episode.show)
    var episodes: [Episode] = []

    init(name: String, colorIndex: Int, createdAt: Date = .now) {
        self.name = name
        self.colorIndex = colorIndex
        self.createdAt = createdAt
    }

    /// Episodes in watching order: numbered ones first (ascending), then by title.
    var sortedEpisodes: [Episode] {
        episodes.sorted { lhs, rhs in
            switch (lhs.number, rhs.number) {
            case let (l?, r?) where l != r: return l < r
            case (.some, .none): return true
            case (.none, .some): return false
            default: return lhs.title.localizedStandardCompare(rhs.title) == .orderedAscending
            }
        }
    }
}

/// One video file plus its chosen subtitle file and offset.
/// Paths are stored relative to the app's Documents folder, because the absolute container
/// path changes when the app is re-installed (e.g. every 7 days with a free Apple ID).
@Model
final class Episode {
    var title: String
    var number: Int?
    var videoPath: String
    var subtitlePath: String?
    /// Added to every subtitle time. Positive values show subtitles later.
    var offsetMs: Int
    var lastPositionMs: Int
    var createdAt: Date
    var show: Show?

    init(title: String, number: Int?, videoPath: String, subtitlePath: String? = nil, show: Show?) {
        self.title = title
        self.number = number
        self.videoPath = videoPath
        self.subtitlePath = subtitlePath
        self.offsetMs = 0
        self.lastPositionMs = 0
        self.createdAt = .now
        self.show = show
    }
}

enum CardStatus: String, Codable, CaseIterable {
    case pending, synced, failed, duplicate

    var needsSync: Bool { self == .pending || self == .failed }
}

/// The parts of a mined card. Mapped to the user's Anki note fields in Anki settings.
enum CardField: String, CaseIterable, Codable, Identifiable {
    case sentence, word, definition, translation, notes, audio, image, source

    var id: String { rawValue }

    var label: String {
        switch self {
        case .sentence: "Sentence"
        case .word: "Word"
        case .definition: "Definition"
        case .translation: "Translation"
        case .notes: "Notes"
        case .audio: "Sentence audio"
        case .image: "Screenshot"
        case .source: "Source"
        }
    }

    /// Fields the user types into in the card editor.
    static let editable: [CardField] = [.sentence, .word, .definition, .translation, .notes]
}

/// A card made in the app, waiting for (or done with) sync to desktop Anki.
@Model
final class PendingCard {
    var id: UUID
    var createdAt: Date
    var showName: String
    var episodeTitle: String
    var startMs: Int
    var endMs: Int
    var fieldsData: Data
    var audioFileName: String?
    var imageFileName: String?
    var statusRaw: String
    var ankiNoteId: Int64?
    var lastError: String?

    init(
        id: UUID,
        showName: String,
        episodeTitle: String,
        startMs: Int,
        endMs: Int,
        fields: [String: String],
        audioFileName: String?,
        imageFileName: String?
    ) {
        self.id = id
        self.createdAt = .now
        self.showName = showName
        self.episodeTitle = episodeTitle
        self.startMs = startMs
        self.endMs = endMs
        self.fieldsData = (try? JSONEncoder().encode(fields)) ?? Data()
        self.audioFileName = audioFileName
        self.imageFileName = imageFileName
        self.statusRaw = CardStatus.pending.rawValue
    }

    /// Text field values keyed by `CardField.rawValue`.
    var fields: [String: String] {
        get { (try? JSONDecoder().decode([String: String].self, from: fieldsData)) ?? [:] }
        set { fieldsData = (try? JSONEncoder().encode(newValue)) ?? Data() }
    }

    var status: CardStatus {
        get { CardStatus(rawValue: statusRaw) ?? .pending }
        set { statusRaw = newValue.rawValue }
    }
}
