import Foundation
import SwiftData
import Testing
@testable import ClipDeck

// MARK: - AnkiConnect client

@MainActor
@Suite(.serialized)
struct AnkiConnectClientTests {
    let base = URL(string: "http://192.168.1.20:8765")!

    @Test func buildsVersion6RequestWithKey() throws {
        let client = AnkiConnectClient(baseURL: base, apiKey: "secret")
        let request = try client.makeRequest(action: "modelFieldNames", params: ["modelName": "Lapis"])
        #expect(request.httpMethod == "POST")
        #expect(request.url == base)
        let httpBody = try #require(request.httpBody)
        let body = try #require(JSONSerialization.jsonObject(with: httpBody) as? [String: Any])
        #expect(body["action"] as? String == "modelFieldNames")
        #expect(body["version"] as? Int == 6)
        #expect(body["key"] as? String == "secret")
        #expect((body["params"] as? [String: Any])?["modelName"] as? String == "Lapis")
    }

    @Test func omitsEmptyKeyAndParams() throws {
        let request = try AnkiConnectClient(baseURL: base).makeRequest(action: "version")
        let httpBody = try #require(request.httpBody)
        let body = try #require(JSONSerialization.jsonObject(with: httpBody) as? [String: Any])
        #expect(body["key"] == nil)
        #expect(body["params"] == nil)
    }

    @Test(arguments: [
        ("192.168.1.20:8765", "http://192.168.1.20:8765"),
        ("  http://pc.local:8765 ", "http://pc.local:8765"),
    ])
    func acceptsAddressesFromSettings(input: String, expected: String) throws {
        var settings = AnkiSettings()
        settings.url = input
        let client = try #require(AnkiConnectClient(settings: settings))
        #expect(client.baseURL.absoluteString == expected)
    }

    @Test(arguments: ["", "ftp://pc:8765", "http://"])
    func rejectsUnusableAddresses(input: String) {
        var settings = AnkiSettings()
        settings.url = input
        #expect(AnkiConnectClient(settings: settings) == nil)
    }

    @Test func decodesResultsAndErrors() throws {
        let ok: Int = try AnkiConnectClient.decode(Data(#"{"result": 6, "error": null}"#.utf8))
        #expect(ok == 6)
        #expect(throws: AnkiError.anki("cannot create note because it is a duplicate")) {
            let _: Int64 = try AnkiConnectClient.decode(Data(#"{"result": null, "error": "cannot create note because it is a duplicate"}"#.utf8))
        }
        #expect(throws: AnkiError.invalidResponse) {
            let _: Int = try AnkiConnectClient.decode(Data("<html>".utf8))
        }
        #expect(AnkiError.anki("cannot create note because it is a duplicate").isDuplicate)
    }

    @Test func networkFailureIsReportedAsUnreachable() async {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [FailingURLProtocol.self]
        let client = AnkiConnectClient(baseURL: base, session: URLSession(configuration: config))
        await #expect(throws: AnkiError.unreachable(base.absoluteString)) {
            _ = try await client.version()
        }
    }
}

/// Fails every request, like an unreachable computer.
final class FailingURLProtocol: URLProtocol {
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() { client?.urlProtocol(self, didFailWithError: URLError(.cannotConnectToHost)) }
    override func stopLoading() {}
}

// MARK: - Sync

@MainActor
final class FakeAnki: AnkiTransport {
    var storedMedia: [String] = []
    var addedNotes: [[String: String]] = []
    /// Errors to throw from addNote, in order (nil = succeed).
    var addNoteErrors: [AnkiError?] = []

    func version() async throws -> Int { 6 }
    func deckNames() async throws -> [String] { ["Mining"] }
    func modelNames() async throws -> [String] { ["Lapis"] }
    func modelFieldNames(_ modelName: String) async throws -> [String] { ["Sentence", "SentenceAudio", "Picture"] }
    func storeMediaFile(name: String, data: Data) async throws { storedMedia.append(name) }
    func addNote(deck: String, model: String, fields: [String: String], tags: [String]) async throws -> Int64 {
        if !addNoteErrors.isEmpty, let error = addNoteErrors.removeFirst() { throw error }
        addedNotes.append(fields)
        return Int64(1_000 + addedNotes.count)
    }
}

@MainActor
struct CardSyncerTests {
    let container: ModelContainer
    let mediaFolder: URL
    var settings: AnkiSettings

    init() throws {
        container = try ModelContainer(for: PendingCard.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        mediaFolder = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        try FileManager.default.createDirectory(at: mediaFolder, withIntermediateDirectories: true)
        settings = AnkiSettings()
        settings.url = "http://192.168.1.20:8765"
        settings.deckName = "Mining"
        settings.noteType = "Lapis"
    }

    func makeCard(sentence: String, withAudio: Bool = true) throws -> PendingCard {
        let id = UUID()
        let audio = CardMediaNames.audio(for: id)
        if withAudio { try Data([1, 2, 3]).write(to: mediaFolder.appending(path: audio)) }
        let card = PendingCard(
            id: id, showName: "Show", episodeTitle: "Ep 1", startMs: 0, endMs: 1_000,
            fields: [CardField.sentence.rawValue: sentence, CardField.source.rawValue: "Show Ep 1 (0:00.0)"],
            audioFileName: audio, imageFileName: nil
        )
        container.mainContext.insert(card)
        return card
    }

    @Test func syncsPendingCardsWithMediaAndMapping() async throws {
        let anki = FakeAnki()
        let card = try makeCard(sentence: "A < B\n二行目")
        let summary = await CardSyncer(transport: anki, settings: settings, mediaFolder: mediaFolder).sync([card])

        #expect(summary == SyncSummary(added: 1))
        #expect(card.status == .synced)
        #expect(card.ankiNoteId == 1_001)
        #expect(anki.storedMedia == [card.audioFileName!])
        let fields = try #require(anki.addedNotes.first)
        #expect(fields["Sentence"] == "A &lt; B<br>二行目")
        #expect(fields["SentenceAudio"] == "[sound:\(card.audioFileName!)]")
        #expect(fields["MiscInfo"] == "Show Ep 1 (0:00.0)")
        #expect(fields["Picture"] == nil) // no screenshot on this card
    }

    @Test func rerunSkipsSyncedAndMarksDuplicates() async throws {
        let anki = FakeAnki()
        let first = try makeCard(sentence: "one")
        let second = try makeCard(sentence: "two")
        let syncer = CardSyncer(transport: anki, settings: settings, mediaFolder: mediaFolder)

        anki.addNoteErrors = [nil, .anki("cannot create note because it is a duplicate")]
        let summary = await syncer.sync([first, second])
        #expect(summary.added == 1)
        #expect(summary.duplicates == 1)
        #expect(second.status == .duplicate)

        let again = await syncer.sync([first, second])
        #expect(again == SyncSummary())
        #expect(anki.addedNotes.count == 1)
    }

    @Test func unreachableStopsAndKeepsCardsQueued() async throws {
        let anki = FakeAnki()
        let cards = [try makeCard(sentence: "one"), try makeCard(sentence: "two")]
        anki.addNoteErrors = [.unreachable("http://192.168.1.20:8765")]
        let summary = await CardSyncer(transport: anki, settings: settings, mediaFolder: mediaFolder).sync(cards)
        #expect(summary.stoppedReason != nil)
        #expect(cards.allSatisfy { $0.status == .pending })
    }

    @Test func otherErrorsMarkCardFailedAndContinue() async throws {
        let anki = FakeAnki()
        let cards = [try makeCard(sentence: "bad"), try makeCard(sentence: "good")]
        anki.addNoteErrors = [.anki("model was not found: Lapis"), nil]
        let summary = await CardSyncer(transport: anki, settings: settings, mediaFolder: mediaFolder).sync(cards)
        #expect(summary.failed == 1)
        #expect(summary.added == 1)
        let failed = try #require(cards.first { $0.status == .failed })
        #expect(failed.lastError?.contains("model was not found") == true)
    }

    @Test func incompleteSettingsStopBeforeContactingAnki() async throws {
        let anki = FakeAnki()
        var incomplete = settings
        incomplete.deckName = ""
        let summary = await CardSyncer(transport: anki, settings: incomplete, mediaFolder: mediaFolder).sync([try makeCard(sentence: "x")])
        #expect(summary.stoppedReason == "Choose a deck in Anki settings.")
        #expect(anki.storedMedia.isEmpty)
    }

    @Test func missingMediaFileStillAddsTheNote() async throws {
        let anki = FakeAnki()
        let card = try makeCard(sentence: "no audio on disk", withAudio: false)
        _ = await CardSyncer(transport: anki, settings: settings, mediaFolder: mediaFolder).sync([card])
        #expect(card.status == .synced)
        #expect(anki.addedNotes.first?["SentenceAudio"] == nil)
    }

    @Test func settingsPersistAcrossStores() throws {
        let suite = "test.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let first = SettingsStore(defaults: defaults)
        first.anki.deckName = "Mining"
        first.anki.fieldMap[CardField.word.rawValue] = "Word"
        let second = SettingsStore(defaults: defaults)
        #expect(second.anki.deckName == "Mining")
        #expect(second.anki.target(for: .word) == "Word")
    }
}
