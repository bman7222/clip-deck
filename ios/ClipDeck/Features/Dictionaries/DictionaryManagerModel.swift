import SwiftUI

nonisolated enum DictionaryDownloadError: LocalizedError, Equatable {
    case badStatus(Int)

    var errorDescription: String? {
        switch self {
        case .badStatus(let status): "The download failed (HTTP \(status))."
        }
    }
}

extension DictionaryInfo {
    /// "Words · 9 entries · 2 KB": the kind, how many entries it counts, and the size of its bank files.
    var summary: String {
        let count = kind == .words ? termCount : metaCount
        let size = ByteCountFormatter.string(fromByteCount: Int64(bytes), countStyle: .file)
        return "\(kind == .words ? "Words" : "Frequency") · \(count) \(count == 1 ? "entry" : "entries") · \(size)"
    }
}

/// The Dictionaries sheet and Settings › About › Dictionary sources: the installed list, its order, import from
/// Files and the JMdict download. The one `DictionaryStore` does the work; this model only holds what the screens show.
/// List edits (order, switch, delete) show at once and are written in order; `finishWrites()` waits for them.
@Observable
final class DictionaryManagerModel {
    enum Phase: Equatable {
        case idle, downloading, importing
    }

    static let jmdictURL = URL(string: "https://github.com/yomidevs/jmdict-yomitan/releases/latest/download/JMdict_english.zip")!
    private static let chunkSize = 65_536

    @ObservationIgnored private let store: DictionaryStore?
    @ObservationIgnored private let session: URLSession
    @ObservationIgnored private let temporaryFolder: URL
    @ObservationIgnored private var runTask: Task<Void, any Error>?
    @ObservationIgnored private var lastWrite: Task<Void, Never>?

    private(set) var dictionaries: [DictionaryInfo] = []
    private(set) var phase = Phase.idle
    /// 0...1, or nil while the size is unknown.
    private(set) var progress: Double?
    var errorMessage: String?

    init(url: URL = DictionaryStore.defaultURL, session: URLSession = .shared,
         temporaryFolder: URL = FileManager.default.temporaryDirectory) {
        self.session = session
        self.temporaryFolder = temporaryFolder
        do {
            store = try DictionaryStore(url: url)
        } catch {
            store = nil
            errorMessage = error.localizedDescription
        }
    }

    var progressText: String {
        let percent = progress.map { " \(Int(($0 * 100).rounded(.down)))%" } ?? ""
        return (phase == .downloading ? "Downloading…" : "Importing…") + percent
    }

    func reload() async {
        guard let store else { return }
        do { dictionaries = try await store.dictionaries() } catch { errorMessage = error.localizedDescription }
    }

    // MARK: Order, switch, delete

    func move(fromOffsets: IndexSet, toOffset: Int) {
        let before = dictionaries.map(\.id)
        dictionaries.move(fromOffsets: fromOffsets, toOffset: toOffset)
        let ids = dictionaries.map(\.id)
        if LaunchFlags.isUITesting { print("T-028 diag onMove from \(Array(fromOffsets)) to \(toOffset): \(before) -> \(ids)") }
        write { try await $0.setPriorityOrder(ids) }
    }

    /// The VoiceOver "Move up" and "Move down" actions.
    func move(_ id: Int, by step: Int) {
        guard let from = dictionaries.firstIndex(where: { $0.id == id }),
              dictionaries.indices.contains(from + step)
        else { return }
        move(fromOffsets: [from], toOffset: step < 0 ? from + step : from + step + 1)
    }

    func setEnabled(_ id: Int, _ enabled: Bool) {
        guard let index = dictionaries.firstIndex(where: { $0.id == id }) else { return }
        dictionaries[index].enabled = enabled
        write { try await $0.setEnabled(id, enabled) }
    }

    func delete(_ id: Int) {
        dictionaries.removeAll { $0.id == id }
        write { try await $0.delete(id) }
    }

    /// Waits until every list edit so far is stored.
    func finishWrites() async {
        await lastWrite?.value
    }

    private func write(_ work: @escaping @Sendable (DictionaryStore) async throws -> Void) {
        guard let store else { return }
        let previous = lastWrite
        lastWrite = Task {
            await previous?.value
            do {
                try await work(store)
            } catch {
                errorMessage = error.localizedDescription
                await reload()
            }
        }
    }

    // MARK: Import and download

    /// Imports a picked .zip: a security-scoped, coordinated read (so an iCloud file is downloaded first), then the importer.
    func importFile(_ url: URL) async {
        await run(.importing) { [self] store in
            let access = SourceAccess(url: url)
            defer { access.close() }
            try await access.acquire()
            try await importZip(access.readURL, into: store)
        }
    }

    /// The app's only dictionary network call: JMdict English to a temp file, then the same import. The file is deleted
    /// whatever happens.
    func downloadJMdict() async {
        await run(.downloading) { [self] store in
            let file = temporaryFolder.appending(path: "JMdict-\(UUID().uuidString).zip")
            defer { try? FileManager.default.removeItem(at: file) }
            try await download(to: file)
            phase = .importing
            progress = 0
            try await importZip(file, into: store)
        }
    }

    func cancel() {
        runTask?.cancel()
    }

    private func run(_ phase: Phase, _ work: @escaping @MainActor (DictionaryStore) async throws -> Void) async {
        guard self.phase == .idle, let store else { return }
        errorMessage = nil
        self.phase = phase
        progress = phase == .importing ? 0 : nil
        let task = Task { try await work(store) }
        runTask = task
        do {
            try await task.value
        } catch {
            if !task.isCancelled { errorMessage = error.localizedDescription }
        }
        runTask = nil
        self.phase = .idle
        progress = nil
        await reload()
    }

    private func importZip(_ file: URL, into store: DictionaryStore) async throws {
        _ = try await store.importDictionary(from: file) { value in
            Task { @MainActor in self.progress = max(self.progress ?? 0, value) }
        }
    }

    private func download(to file: URL) async throws {
        let (bytes, response) = try await session.bytes(from: Self.jmdictURL)
        if let status = (response as? HTTPURLResponse)?.statusCode, status != 200 {
            throw DictionaryDownloadError.badStatus(status)
        }
        try Data().write(to: file)
        let handle = try FileHandle(forWritingTo: file)
        defer { try? handle.close() }
        let expected = response.expectedContentLength
        var buffer = Data()
        var received: Int64 = 0
        for try await byte in bytes {
            buffer.append(byte)
            guard buffer.count == Self.chunkSize else { continue }
            try handle.write(contentsOf: buffer)
            received += Int64(buffer.count)
            buffer.removeAll(keepingCapacity: true)
            if expected > 0 { progress = min(Double(received) / Double(expected), 1) }
            try Task.checkCancellation()
        }
        try handle.write(contentsOf: buffer)
    }
}
