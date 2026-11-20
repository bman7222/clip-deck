import Foundation
import os

/// Keeps a picked file open for an import, from `EpisodeImporter.prepare` to the end of the import
/// (spec › Import, files and lifecycle › iCloud files):
/// - security-scoped access, started when this is created;
/// - a coordinated read (`NSFileCoordinator`), started by `acquire()`. iCloud Drive or another file provider
///   downloads the file before the read is granted, and doesn't replace it while Clip Deck reads it.
///
/// `NSFileCoordinator` only grants access inside its accessor block, which is synchronous. So a dedicated thread
/// runs the coordinated read and waits inside the block until `close()`. Call `close()` when the import has
/// finished or the user picks another file; `deinit` closes it too.
nonisolated final class SourceAccess: Sendable {
    /// The URL the picker returned.
    let url: URL
    private let hold: CoordinatedHold

    init(url: URL) {
        self.url = url
        hold = CoordinatedHold(url: url)
    }

    deinit {
        hold.close()
    }

    /// The URL to read through: the one the coordinated read granted (normally the same as `url`).
    var readURL: URL { hold.readURL ?? url }

    /// True from a successful `acquire()` until `close()`.
    var isOpen: Bool { hold.isHolding }

    /// Starts the coordinated read and returns once it is granted (after any iCloud download). Cancelling the
    /// calling task stops the wait and throws `CancellationError`.
    func acquire() async throws {
        try await hold.acquire()
    }

    /// Ends the coordinated read and the security-scoped access. Safe to call more than once.
    func close() {
        hold.close()
    }

    /// The file's size in bytes, or 0 when the file system can't tell.
    var fileSize: Int64 {
        var fresh = readURL
        fresh.removeAllCachedResourceValues()
        guard let size = try? fresh.resourceValues(forKeys: [.fileSizeKey]).fileSize else { return 0 }
        return Int64(size)
    }

    // MARK: iCloud

    /// True for an iCloud Drive file whose latest version isn't on the phone yet.
    static func needsDownload(_ url: URL) -> Bool {
        var fresh = url
        fresh.removeAllCachedResourceValues()
        guard let values = try? fresh.resourceValues(forKeys: [.isUbiquitousItemKey, .ubiquitousItemDownloadingStatusKey]),
              values.isUbiquitousItem == true
        else { return false }
        return values.ubiquitousItemDownloadingStatus != .current
    }

    /// Waits while iCloud still reports the file as not downloaded (the coordinated read normally covers this).
    /// Throws `EpisodeImportError.iCloudDownloadFailed` when iCloud reports a download error, and
    /// `CancellationError` when the calling task is cancelled.
    func waitUntilDownloaded(pollInterval: Duration = .milliseconds(500)) async throws {
        while true {
            var fresh = url
            fresh.removeAllCachedResourceValues()
            guard let values = try? fresh.resourceValues(forKeys: [
                .isUbiquitousItemKey, .ubiquitousItemDownloadingStatusKey, .ubiquitousItemDownloadingErrorKey,
            ]), values.isUbiquitousItem == true else { return }
            if let error = values.ubiquitousItemDownloadingError {
                throw EpisodeImportError.iCloudDownloadFailed(error.localizedDescription)
            }
            guard values.ubiquitousItemDownloadingStatus == .notDownloaded else { return }
            try await Task.sleep(for: pollInterval)
        }
    }

    /// Copies a small picked file (a subtitle file) with security-scoped access and a coordinated read, so an
    /// iCloud file is downloaded first. Synchronous and blocking: call it off the main actor.
    static func coordinatedCopy(from source: URL, to destination: URL) throws {
        let scoped = source.startAccessingSecurityScopedResource()
        defer { if scoped { source.stopAccessingSecurityScopedResource() } }
        try FileManager.default.createDirectory(at: destination.deletingLastPathComponent(), withIntermediateDirectories: true)

        var coordinationError: NSError?
        var copyError: (any Error)?
        NSFileCoordinator(filePresenter: nil).coordinate(readingItemAt: source, options: [], error: &coordinationError) { readURL in
            do {
                try FileManager.default.copyItem(at: readURL, to: destination)
            } catch {
                copyError = error
            }
        }
        if let coordinationError { throw coordinationError }
        if let copyError { throw copyError }
    }
}

/// The thread-blocking half of `SourceAccess`. The thread that holds the coordinated read keeps this object
/// alive, never the `SourceAccess` itself, so dropping the last `SourceAccess` reference still closes it.
nonisolated private final class CoordinatedHold: @unchecked Sendable {
    private enum Phase: Sendable, Equatable {
        case idle, waiting, holding, closed
    }

    private struct State: Sendable {
        var phase: Phase = .idle
        var readURL: URL?
        var cancelRequested = false
        var scopeEnded = false
    }

    let url: URL
    private let scoped: Bool
    // NSFileCoordinator and DispatchSemaphore are used from several threads, which both allow (cancel() is
    // documented as callable from any thread). All other state is behind `state`.
    private let coordinator = NSFileCoordinator(filePresenter: nil)
    private let release = DispatchSemaphore(value: 0)
    private let state = OSAllocatedUnfairLock(initialState: State())

    init(url: URL) {
        self.url = url
        scoped = url.startAccessingSecurityScopedResource()
    }

    var readURL: URL? { state.withLock { value in value.readURL } }

    var isHolding: Bool { state.withLock { value in value.phase == .holding } }

    func acquire() async throws {
        let phase = state.withLock { value -> Phase in
            let current = value.phase
            if current == .idle { value.phase = .waiting }
            return current
        }
        switch phase {
        case .holding: return
        case .waiting, .closed: throw CancellationError()
        case .idle: break
        }

        try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, any Error>) in
                let thread = Thread { [self] in
                    self.holdRead(continuation)
                }
                thread.name = "ClipDeck.SourceAccess"
                thread.qualityOfService = .userInitiated
                thread.start()
            }
        } onCancel: {
            self.cancelWaiting()
        }

        if Task.isCancelled {
            close()
            throw CancellationError()
        }
    }

    /// Runs on the dedicated thread: blocks inside the coordinated read until `close()`.
    private func holdRead(_ continuation: CheckedContinuation<Void, any Error>) {
        var coordinationError: NSError?
        var resumed = false
        coordinator.coordinate(readingItemAt: url, options: [], error: &coordinationError) { grantedURL in
            let keep = self.state.withLock { value -> Bool in
                guard value.phase == .waiting, !value.cancelRequested else { return false }
                value.phase = .holding
                value.readURL = grantedURL
                return true
            }
            resumed = true
            if keep {
                continuation.resume()
                self.release.wait()   // until close()
            } else {
                continuation.resume(throwing: CancellationError())
            }
        }
        guard !resumed else { return }
        let cancelled = state.withLock { value -> Bool in
            if value.phase == .waiting { value.phase = .idle }
            return value.cancelRequested || value.phase == .closed
        }
        if cancelled {
            continuation.resume(throwing: CancellationError())
        } else if let coordinationError {
            continuation.resume(throwing: coordinationError)
        } else {
            continuation.resume(throwing: CocoaError(.fileReadUnknown))
        }
    }

    private func cancelWaiting() {
        let waiting = state.withLock { value -> Bool in
            value.cancelRequested = true
            return value.phase == .waiting
        }
        if waiting { coordinator.cancel() }
    }

    func close() {
        let (wasHolding, wasWaiting, endScope) = state.withLock { value -> (Bool, Bool, Bool) in
            let holding = value.phase == .holding
            let waiting = value.phase == .waiting
            value.phase = .closed
            let end = !value.scopeEnded
            value.scopeEnded = true
            return (holding, waiting, end)
        }
        if wasHolding { release.signal() }
        if wasWaiting { coordinator.cancel() }
        if endScope, scoped { url.stopAccessingSecurityScopedResource() }
    }
}
