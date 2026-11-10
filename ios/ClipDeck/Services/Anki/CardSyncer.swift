import Foundation

struct SyncSummary: Equatable {
    var added = 0
    var duplicates = 0
    var failed = 0
    /// Set when sync stopped early (Anki unreachable or settings incomplete).
    var stoppedReason: String?

    var message: String {
        if let stoppedReason, added == 0, duplicates == 0, failed == 0 { return stoppedReason }
        var parts: [String] = []
        if added > 0 { parts.append("\(added) added to Anki") }
        if duplicates > 0 { parts.append("\(duplicates) already in Anki") }
        if failed > 0 { parts.append("\(failed) failed") }
        var text = parts.isEmpty ? "Nothing to sync." : parts.joined(separator: ", ") + "."
        if let stoppedReason { text += " " + stoppedReason }
        return text
    }
}

/// Sends queued cards to Anki one at a time. Safe to run repeatedly: synced and duplicate cards
/// are skipped, and media names are fixed per card, so a retry overwrites instead of duplicating.
struct CardSyncer {
    let transport: any AnkiTransport
    let settings: AnkiSettings
    let mediaFolder: URL

    func sync(_ cards: [PendingCard], progress: (Int, Int) -> Void = { _, _ in }) async -> SyncSummary {
        if let problem = settings.setupProblem { return SyncSummary(stoppedReason: problem) }

        let queue = cards.filter { $0.status.needsSync }.sorted { $0.createdAt < $1.createdAt }
        var summary = SyncSummary()

        cardLoop: for (index, card) in queue.enumerated() {
            progress(index, queue.count)
            do {
                let audioName = try await uploadMedia(named: card.audioFileName)
                let imageName = try await uploadMedia(named: card.imageFileName)
                let noteId = try await transport.addNote(
                    deck: settings.deckName,
                    model: settings.noteType,
                    fields: noteFields(for: card, audioName: audioName, imageName: imageName),
                    tags: settings.tagList
                )
                card.status = .synced
                card.ankiNoteId = noteId
                card.lastError = nil
                summary.added += 1
            } catch let error as AnkiError where error.isDuplicate {
                card.status = .duplicate
                card.lastError = nil
                summary.duplicates += 1
            } catch let error as AnkiError where error.isUnreachable {
                // Every remaining card would fail the same way; leave them queued.
                summary.stoppedReason = error.localizedDescription
                break cardLoop
            } catch {
                card.status = .failed
                card.lastError = error.localizedDescription
                summary.failed += 1
            }
        }
        progress(queue.count, queue.count)
        return summary
    }

    /// Uploads a card's media file if it is still on disk; returns the name to reference in the note.
    private func uploadMedia(named name: String?) async throws -> String? {
        guard let name else { return nil }
        let url = mediaFolder.appending(path: name)
        guard let data = try? Data(contentsOf: url) else { return nil }
        try await transport.storeMediaFile(name: name, data: data)
        return name
    }

    /// Anki field name → HTML value, following the user's field mapping.
    func noteFields(for card: PendingCard, audioName: String?, imageName: String?) -> [String: String] {
        let values = card.fields
        var result: [String: String] = [:]
        for field in CardField.allCases {
            guard let target = settings.target(for: field) else { continue }
            let value: String
            switch field {
            case .audio: value = audioName.map { "[sound:\($0)]" } ?? ""
            case .image: value = imageName.map { "<img src=\"\($0)\">" } ?? ""
            default: value = Self.html(values[field.rawValue] ?? "")
            }
            guard !value.isEmpty else { continue }
            if let existing = result[target] {
                result[target] = existing + "<br>" + value
            } else {
                result[target] = value
            }
        }
        return result
    }

    static func html(_ text: String) -> String {
        text.trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\n", with: "<br>")
    }
}
