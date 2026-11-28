import Foundation
import Testing
@testable import ClipDeck

/// What the stub session answers to the JMdict request.
nonisolated enum DictionaryStubBehaviour {
    case body(Data)
    case status(Int)
    /// Sends the headers and `sent` of `total` bytes, then never finishes (until the request is cancelled).
    case hang(sent: Int, total: Int)
}

nonisolated final class DictionaryStubProtocol: URLProtocol, @unchecked Sendable {
    nonisolated(unsafe) static var behaviour = DictionaryStubBehaviour.status(500)
    nonisolated(unsafe) static var requested: [URL] = []

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func stopLoading() {}

    override func startLoading() {
        guard let url = request.url else { return }
        Self.requested.append(url)
        switch Self.behaviour {
        case .body(let data):
            respond(url, status: 200, length: data.count)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        case .status(let status):
            respond(url, status: status, length: 0)
            client?.urlProtocolDidFinishLoading(self)
        case .hang(let sent, let total):
            respond(url, status: 200, length: total)
            client?.urlProtocol(self, didLoad: Data(count: sent))
        }
    }

    private func respond(_ url: URL, status: Int, length: Int) {
        let response = HTTPURLResponse(url: url, statusCode: status, httpVersion: "HTTP/1.1",
                                       headerFields: ["Content-Length": "\(length)"])!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
    }
}

/// `DictionaryManagerModel` against the tiny zips in scripts/fixtures/dictionaries and a stub URLSession (no network).
@MainActor
@Suite(.serialized)
struct DictionaryManagerModelTests {
    let databaseURL: URL
    let temporaryFolder: URL

    init() throws {
        let root = FileManager.default.temporaryDirectory
            .appending(path: "DictionaryManagerModelTests-\(UUID().uuidString)", directoryHint: .isDirectory)
        databaseURL = root.appending(path: "db/dictionaries.sqlite")
        temporaryFolder = root.appending(path: "tmp", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: temporaryFolder, withIntermediateDirectories: true)
        DictionaryStubProtocol.behaviour = .status(500)
        DictionaryStubProtocol.requested = []
    }

    func makeModel() -> DictionaryManagerModel {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [DictionaryStubProtocol.self]
        return DictionaryManagerModel(url: databaseURL, session: URLSession(configuration: configuration),
                                      temporaryFolder: temporaryFolder)
    }

    func fixtureURL(_ name: String) throws -> URL {
        // This file is <repo>/ios/ClipDeckTests/DictionaryManagerModelTests.swift.
        let url = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
            .deletingLastPathComponent().appending(path: "scripts/fixtures/dictionaries/\(name).zip")
        try #require(FileManager.default.fileExists(atPath: url.path), "Missing fixture \(name).zip")
        return url
    }

    var temporaryEntries: [String] {
        (try? FileManager.default.contentsOfDirectory(atPath: temporaryFolder.path(percentEncoded: false))) ?? []
    }

    func waitUntil(seconds: Double = 20, _ condition: () -> Bool) async throws {
        let deadline = ContinuousClock.now + .seconds(seconds)
        while !condition(), ContinuousClock.now < deadline {
            try await Task.sleep(for: .milliseconds(10))
        }
    }

    func installAllThree(_ model: DictionaryManagerModel) async throws {
        for name in ["words-v3", "words-second", "frequency"] {
            let file = try fixtureURL(name)
            await model.importFile(file)
        }
    }

    // MARK: Download

    @Test func aSuccessfulDownloadIsImportedAndTheTempFileIsGone() async throws {
        DictionaryStubProtocol.behaviour = .body(try Data(contentsOf: fixtureURL("words-v3")))
        let model = makeModel()
        await model.downloadJMdict()

        #expect(DictionaryStubProtocol.requested == [DictionaryManagerModel.jmdictURL])
        #expect(model.errorMessage == nil)
        #expect(model.phase == .idle)
        #expect(model.dictionaries.map(\.title) == ["Clip Test Words"])
        #expect(temporaryEntries.isEmpty)
    }

    @Test func aFailedDownloadImportsNothingAndSaysWhy() async throws {
        DictionaryStubProtocol.behaviour = .status(404)
        let model = makeModel()
        await model.downloadJMdict()

        #expect(model.errorMessage == "The download failed (HTTP 404).")
        #expect(model.phase == .idle)
        #expect(model.dictionaries.isEmpty)
        #expect(temporaryEntries.isEmpty)
    }

    @Test func aBrokenZipImportsNothingAndTheTempFileIsGone() async throws {
        DictionaryStubProtocol.behaviour = .body(Data("not a zip".utf8))
        let model = makeModel()
        await model.downloadJMdict()

        #expect(model.errorMessage == DictionaryImportError.corrupt("the zip").localizedDescription)
        #expect(model.dictionaries.isEmpty)
        #expect(temporaryEntries.isEmpty)
    }

    @Test func anInstalledRevisionSaysSo() async throws {
        DictionaryStubProtocol.behaviour = .body(try Data(contentsOf: fixtureURL("words-v3")))
        let model = makeModel()
        await model.downloadJMdict()
        await model.downloadJMdict()

        #expect(model.errorMessage == "Clip Test Words (2026.1) is already installed.")
        #expect(model.dictionaries.count == 1)
        #expect(temporaryEntries.isEmpty)
    }

    @Test func progressShowsWhileDownloadingAndACancelDeletesTheTempFile() async throws {
        DictionaryStubProtocol.behaviour = .hang(sent: 131_072, total: 262_144)
        let model = makeModel()
        let run = Task { await model.downloadJMdict() }

        try await waitUntil { model.phase == .downloading && (model.progress ?? 0) >= 0.5 }
        #expect(model.progress == 0.5)
        #expect(model.progressText == "Downloading… 50%")
        #expect(temporaryEntries.count == 1)

        model.cancel()
        await run.value
        #expect(model.phase == .idle)
        #expect(model.errorMessage == nil)
        #expect(model.dictionaries.isEmpty)
        #expect(temporaryEntries.isEmpty)
    }

    // MARK: Import from Files

    @Test func importingAFileAddsItLastAndABadFileShowsAnError() async throws {
        let model = makeModel()
        try await installAllThree(model)
        #expect(model.errorMessage == nil)
        #expect(model.dictionaries.map(\.title) == ["Clip Test Words", "Second Test Words", "Test Frequency"])

        let corrupt = try fixtureURL("corrupt")
        await model.importFile(corrupt)
        #expect(model.errorMessage != nil)
        #expect(model.dictionaries.count == 3)
    }

    @Test func rowsSayTheirKindEntryCountAndSize() async throws {
        let model = makeModel()
        try await installAllThree(model)
        let summaries = model.dictionaries.map(\.summary)
        #expect(summaries[0].hasPrefix("Words · 9 entries · "))
        #expect(summaries[1].hasPrefix("Words · 2 entries · "))
        #expect(summaries[2].hasPrefix("Frequency · 4 entries · "))
    }

    // MARK: Order, switch, delete

    @Test func reorderEnableAndDeleteAreSavedInOrder() async throws {
        let model = makeModel()
        try await installAllThree(model)
        func id(_ title: String) throws -> Int { try #require(model.dictionaries.first { $0.title == title }).id }

        model.move(fromOffsets: [2], toOffset: 0)
        #expect(model.dictionaries.map(\.title) == ["Test Frequency", "Clip Test Words", "Second Test Words"])
        model.move(try id("Test Frequency"), by: 1)
        #expect(model.dictionaries.map(\.title) == ["Clip Test Words", "Test Frequency", "Second Test Words"])
        model.move(try id("Second Test Words"), by: 1)
        #expect(model.dictionaries.map(\.title) == ["Clip Test Words", "Test Frequency", "Second Test Words"])
        model.setEnabled(try id("Second Test Words"), false)
        await model.finishWrites()

        let reopened = makeModel()
        await reopened.reload()
        #expect(reopened.dictionaries.map(\.title) == ["Clip Test Words", "Test Frequency", "Second Test Words"])
        #expect(reopened.dictionaries.map(\.enabled) == [true, true, false])

        model.delete(try id("Test Frequency"))
        #expect(model.dictionaries.map(\.title) == ["Clip Test Words", "Second Test Words"])
        await model.finishWrites()
        await reopened.reload()
        #expect(reopened.dictionaries.map(\.title) == ["Clip Test Words", "Second Test Words"])
    }
}
