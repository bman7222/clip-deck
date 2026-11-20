import CoreMedia
import Foundation
import SwiftData
import VideoToolbox

/// Adds an episode, or re-links a missing video, from a file the user picked (spec › Import, files and lifecycle).
///
/// Two steps:
/// 1. `prepare(_:)`: checks the extension, waits for iCloud (coordinated read), checks free space and, for MKV,
///    probes the file and builds the conversion plan. Nothing is written.
/// 2. `importEpisode(_:as:options:into:progress:)` or `relink(_:to:options:in:progress:)`: converts (MKV) or copies
///    (MP4/MOV/M4V) into `tmp/Converting/<uuid>/`, moves the results into Documents with `FileStore.uniquePath`, then
///    inserts or updates the Episode and saves. If anything fails, including the SwiftData save, the moved files
///    are deleted again, so the library never holds half an import. `sweepStaging()` at launch removes what a
///    killed import left in `tmp/Converting/`.
///
/// Runs on the main actor (the app's default isolation); the slow parts (probe, conversion, copy) run detached, so
/// the UI stays responsive. Progress reaches the caller on the main actor.
struct EpisodeImporter {
    /// Video files the upload and relink pickers accept (checked after picking).
    static let videoExtensions: Set<String> = ["mp4", "mov", "m4v", "mkv"]
    /// Of those, the ones converted to MP4 on import. The rest are copied as they are.
    static let convertedExtensions: Set<String> = ["mkv"]

    var store: FileStore
    /// Holds `Converting/`. The app's temporary folder, which is on the same volume as Documents, so the final
    /// move is a rename.
    var temporaryFolder: URL
    var supportsAV1: Bool
    /// Free bytes on the volume holding the given URL; nil when unknown (the space check is then skipped).
    var availableCapacity: (URL) -> Int64?
    /// Saves the library. Tests replace it to force a failure.
    var save: (ModelContext) throws -> Void
    /// Called on the conversion thread with every raw progress value, before it is relayed to the main actor.
    /// nil in the app; tests use it to hold a conversion midway.
    var onConversionProgress: (@Sendable (Double) -> Void)?

    init(store: FileStore = .live,
         temporaryFolder: URL = FileManager.default.temporaryDirectory,
         supportsAV1: Bool = EpisodeImporter.deviceSupportsAV1,
         availableCapacity: @escaping (URL) -> Int64? = EpisodeImporter.volumeAvailableCapacity,
         save: @escaping (ModelContext) throws -> Void = { context in try context.save() },
         onConversionProgress: (@Sendable (Double) -> Void)? = nil) {
        self.store = store
        self.temporaryFolder = temporaryFolder
        self.supportsAV1 = supportsAV1
        self.availableCapacity = availableCapacity
        self.save = save
        self.onConversionProgress = onConversionProgress
    }

    /// Whether this iPhone decodes AV1 in hardware (the plan only accepts AV1 then).
    nonisolated static var deviceSupportsAV1: Bool {
        VTIsHardwareDecodeSupported(kCMVideoCodecType_AV1)
    }

    /// `volumeAvailableCapacityForImportantUsage` of the volume holding `url`.
    nonisolated static func volumeAvailableCapacity(_ url: URL) -> Int64? {
        try? url.resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey]).volumeAvailableCapacityForImportantUsage
    }

    /// True for a file the pickers accept (by extension).
    static func isSupportedVideo(_ url: URL) -> Bool {
        videoExtensions.contains(url.pathExtension.lowercased())
    }

    /// True for a file that is converted to MP4 on import (MKV).
    static func needsConversion(_ url: URL) -> Bool {
        convertedExtensions.contains(url.pathExtension.lowercased())
    }

    // MARK: Launch sweep

    /// `tmp/Converting/`, where imports stage their files.
    nonisolated static func stagingRoot(in temporaryFolder: URL) -> URL {
        temporaryFolder.appending(path: "Converting", directoryHint: .isDirectory)
    }

    /// Removes everything an interrupted import left in `tmp/Converting/` (spec › Staging). Call it once at launch,
    /// before any import starts.
    nonisolated static func sweepStaging(in temporaryFolder: URL = FileManager.default.temporaryDirectory) {
        let root = stagingRoot(in: temporaryFolder)
        guard FileManager.default.fileExists(atPath: root.path(percentEncoded: false)) else { return }
        do {
            try FileManager.default.removeItem(at: root)
        } catch {
            print("EpisodeImporter: couldn't sweep \(root.path(percentEncoded: false)): \(error)")
        }
    }

    // MARK: Step 1: prepare

    /// Checks a picked video and gets it ready to import. Writes nothing.
    /// - Order: extension; iCloud (if the file isn't downloaded: `startDownloadingUbiquitousItem`, then
    ///   `onStage(.downloadingFromICloud)`); a coordinated read, held open until the import ends; free space
    ///   (source size + max(10 %, 200 MB)); for MKV `onStage(.probing)`, the probe and the default plan.
    /// - Throws `EpisodeImportError` with a message for the `ErrorBanner`, or `CancellationError` when the calling
    ///   task is cancelled.
    /// - The result keeps the file open. Pass it to `importEpisode`/`relink` (which close it on success), or call
    ///   `close()` on it when the user picks another file or leaves.
    func prepare(_ url: URL, onStage: (PrepareStage) -> Void = { _ in }) async throws -> PreparedVideo {
        let fileExtension = url.pathExtension.lowercased()
        guard Self.videoExtensions.contains(fileExtension) else {
            throw EpisodeImportError.unsupportedVideoType(fileExtension)
        }

        let access = SourceAccess(url: url)
        do {
            if SourceAccess.needsDownload(url) {
                do {
                    try FileManager.default.startDownloadingUbiquitousItem(at: url)
                } catch {
                    throw EpisodeImportError.iCloudDownloadFailed(error.localizedDescription)
                }
                onStage(.downloadingFromICloud)
            }
            do {
                try await access.acquire()
            } catch is CancellationError {
                throw CancellationError()
            } catch {
                throw EpisodeImportError.unreadable(error.localizedDescription)
            }
            try await access.waitUntilDownloaded()

            let sourceBytes = access.fileSize
            try StorageSpaceRule.check(sourceBytes: sourceBytes, availableBytes: availableCapacity(store.documentsURL))

            guard Self.convertedExtensions.contains(fileExtension) else {
                return PreparedVideo(source: url, fileExtension: fileExtension, sourceBytes: sourceBytes,
                                     probe: nil, defaultPlan: nil, supportsAV1: supportsAV1, access: access)
            }

            onStage(.probing)
            let probe: MediaProbe
            do {
                probe = try await MediaProber.load(url: access.readURL)
            } catch is CancellationError {
                throw CancellationError()
            } catch let error as FFmpegError {
                throw EpisodeImportError.unreadable(error.message)
            } catch {
                throw EpisodeImportError.unreadable(error.localizedDescription)
            }
            let plan = try Self.defaultPlan(for: probe, supportsAV1: supportsAV1)
            return PreparedVideo(source: url, fileExtension: fileExtension, sourceBytes: sourceBytes,
                                 probe: probe, defaultPlan: plan, supportsAV1: supportsAV1, access: access)
        } catch {
            access.close()
            throw error
        }
    }

    /// The plan for the file's default audio track (spec: the default-flagged one, else the first). If that track
    /// can't be decoded, the first track that can is used instead; video problems are thrown as they are.
    static func defaultPlan(for probe: MediaProbe, supportsAV1: Bool) throws -> ConversionPlan {
        let firstError: UnsupportedMediaError
        switch makePlan(probe, audioStreamIndex: nil, supportsAV1: supportsAV1) {
        case .success(let plan):
            return plan
        case .failure(let error):
            firstError = error
        }
        if case .audioCodec = firstError {
            for track in probe.audioTracks {
                if case .success(let plan) = makePlan(probe, audioStreamIndex: track.streamIndex, supportsAV1: supportsAV1) {
                    return plan
                }
            }
        }
        throw EpisodeImportError.unsupported(firstError)
    }

    nonisolated static func makePlan(_ probe: MediaProbe, audioStreamIndex: Int?, supportsAV1: Bool,
                                     subtitleStreams: [Int] = [],
                                     requiredSubtitleStream: Int? = nil) -> Result<ConversionPlan, UnsupportedMediaError> {
        do {
            let plan = try ConversionPlan.make(probe: probe, audioStreamIndex: audioStreamIndex, supportsAV1: supportsAV1,
                                               extractingSubtitleStreams: subtitleStreams,
                                               requiredSubtitleStream: requiredSubtitleStream)
            return .success(plan)
        } catch {
            return .failure(error)
        }
    }

    // MARK: Step 2: import

    /// Imports a prepared video as a new episode of `details.showName` (created if needed), with the optional
    /// subtitle file.
    /// - `progress` gets 0 at the start, rising values while an MKV converts, and 1 once the files are staged.
    ///   It is called on the main actor.
    /// - To stop, cancel the calling task: it throws `CancellationError`, and nothing is added or left behind
    ///   (an MP4 copy finishes copying into the temporary folder first, then is deleted).
    /// - Other failures throw `EpisodeImportError` or `MediaConversionError`, both with a user message.
    /// - On success the prepared file is closed; on failure it stays open, so the user can try again.
    func importEpisode(_ prepared: PreparedVideo,
                       as details: NewEpisodeDetails,
                       options: EpisodeImportOptions = EpisodeImportOptions(),
                       into context: ModelContext,
                       progress: @escaping @MainActor (Double) -> Void = { _ in }) async throws -> EpisodeImportResult {
        let showName = details.showName.trimmingCharacters(in: .whitespacesAndNewlines)
        let title = details.title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !showName.isEmpty else { throw EpisodeImportError.missingShowName }
        guard !title.isEmpty else { throw EpisodeImportError.missingTitle }
        if let subtitleFile = details.subtitleFile, SubtitleFormat(fileExtension: subtitleFile.pathExtension) == nil {
            throw EpisodeImportError.unsupportedSubtitleType(subtitleFile.pathExtension.lowercased())
        }

        let shows: [Show]
        do {
            shows = try context.fetch(FetchDescriptor<Show>())
        } catch {
            throw EpisodeImportError.saveFailed(error.localizedDescription)
        }
        let existingShow = shows.first { $0.name.caseInsensitiveCompare(showName) == .orderedSame }
        let folderShowName = existingShow?.name ?? showName

        let staging = try makeStagingFolder()
        defer { try? FileManager.default.removeItem(at: staging) }
        let staged = try await stage(prepared, options: options, subtitleFile: details.subtitleFile,
                                     in: staging, relay: ProgressRelay(progress))
        try Task.checkCancellation()

        // Commit: move into Documents, then insert and save. Undo the moves if anything after them fails.
        var moves = [(from: staged.video, to: store.uniquePath(folder: store.videoFolderPath(show: folderShowName),
                                                              baseName: title, fileExtension: staged.videoExtension))]
        let subtitleFolder = store.subtitleFolderPath(show: folderShowName, episode: title)
        var takenSubtitlePaths: Set<String> = []
        var subtitlePath: String?
        if let subtitle = staged.subtitle {
            let path = reserveSubtitlePath(folder: subtitleFolder, file: subtitle, taken: &takenSubtitlePaths)
            moves.append((from: subtitle, to: path))
            subtitlePath = path
        }
        // Extracted built-in tracks: all of them are saved. The user's own file wins as the episode's subtitle;
        // without one, the chosen track is.
        var embeddedPaths: [Int: String] = [:]
        for embedded in staged.embeddedSubtitles {
            let path = reserveSubtitlePath(folder: subtitleFolder, file: embedded.url, taken: &takenSubtitlePaths)
            moves.append((from: embedded.url, to: path))
            embeddedPaths[embedded.streamIndex] = path
        }
        if subtitlePath == nil, let chosen = options.chosenSubtitleStream {
            subtitlePath = embeddedPaths[chosen]
        }
        let moved = try move(moves)

        let show = existingShow ?? Show(name: showName, colorIndex: shows.count)
        if existingShow == nil { context.insert(show) }
        let episode = Episode(title: title, number: details.number, videoPath: moves[0].to,
                              subtitlePath: subtitlePath, show: show)
        context.insert(episode)
        do {
            try save(context)
        } catch {
            context.delete(episode)
            if existingShow == nil { context.delete(show) }
            moved.undo()
            throw EpisodeImportError.saveFailed(error.localizedDescription)
        }
        prepared.close()
        return EpisodeImportResult(episode: episode, warnings: staged.warnings)
    }

    /// Re-links an episode whose video is missing (spec › J-6): the new video goes next to where the old one was
    /// (same folder and name; `.mp4` for an MKV), and `videoPath` points at it. Same staging, progress,
    /// cancellation, errors and rollback as `importEpisode` (a failed save restores the old `videoPath`).
    func relink(_ episode: Episode,
                to prepared: PreparedVideo,
                options: EpisodeImportOptions = EpisodeImportOptions(),
                in context: ModelContext,
                progress: @escaping @MainActor (Double) -> Void = { _ in }) async throws -> EpisodeImportResult {
        let staging = try makeStagingFolder()
        defer { try? FileManager.default.removeItem(at: staging) }
        // A relink only replaces the video: the episode keeps its subtitle files, so none are extracted.
        var videoOnly = options
        videoOnly.embeddedSubtitleStreams = []
        videoOnly.chosenSubtitleStream = nil
        let staged = try await stage(prepared, options: videoOnly, subtitleFile: nil, in: staging, relay: ProgressRelay(progress))
        try Task.checkCancellation()

        let oldPath = episode.videoPath
        let oldFolder = (oldPath as NSString).deletingLastPathComponent
        let oldName = ((oldPath as NSString).lastPathComponent as NSString).deletingPathExtension
        let folder = oldFolder.isEmpty ? store.videoFolderPath(show: episode.show?.name ?? episode.title) : oldFolder
        let path = store.uniquePath(folder: folder, baseName: oldName.isEmpty ? episode.title : oldName,
                                    fileExtension: staged.videoExtension)
        let moved = try move([(from: staged.video, to: path)])

        episode.videoPath = path
        do {
            try save(context)
        } catch {
            episode.videoPath = oldPath
            moved.undo()
            throw EpisodeImportError.saveFailed(error.localizedDescription)
        }
        prepared.close()
        return EpisodeImportResult(episode: episode, warnings: staged.warnings)
    }

    // MARK: Staging

    private struct Staged {
        var video: URL
        var videoExtension: String
        var subtitle: URL?
        /// Built-in text tracks written during the conversion (MKV only), in `staging/Embedded/`.
        var embeddedSubtitles: [MediaConverter.SubtitleFile] = []
        var warnings: [String]
    }

    /// A free path in the episode's subtitle folder for `file`: not on disk and not already given to another
    /// file of this import (the user's file and an extracted track can have the same name).
    private func reserveSubtitlePath(folder: String, file: URL, taken: inout Set<String>) -> String {
        let base = file.deletingPathExtension().lastPathComponent
        var name = base
        var counter = 2
        while true {
            let path = store.uniquePath(folder: folder, baseName: name, fileExtension: file.pathExtension)
            if !taken.contains(path) {
                taken.insert(path)
                return path
            }
            name = "\(base) (\(counter))"
            counter += 1
        }
    }

    private func makeStagingFolder() throws -> URL {
        do {
            return try MediaConverter.makeStagingFolder(in: temporaryFolder)
        } catch {
            throw EpisodeImportError.copyFailed(error.localizedDescription)
        }
    }

    /// Writes the video (and subtitle file) into `staging`. Nothing outside `staging` is touched.
    private func stage(_ prepared: PreparedVideo, options: EpisodeImportOptions, subtitleFile: URL?,
                       in staging: URL, relay: ProgressRelay) async throws -> Staged {
        guard prepared.access.isOpen else { throw EpisodeImportError.sourceClosed }
        try StorageSpaceRule.check(sourceBytes: prepared.sourceBytes, availableBytes: availableCapacity(store.documentsURL))
        try Task.checkCancellation()
        relay.send(0)

        var warnings: [String] = []
        var embedded: [MediaConverter.SubtitleFile] = []
        let video: URL
        let videoExtension: String
        let readURL = prepared.access.readURL
        if let plan = try prepared.plan(for: options, userPickedSubtitleFile: subtitleFile != nil) {
            warnings += plan.warnings.map { $0.message }
            videoExtension = "mp4"
            video = staging.appending(path: "Episode.mp4")
            let embeddedFolder = staging.appending(path: "Embedded", directoryHint: .isDirectory)
            if !plan.subtitles.isEmpty {
                do {
                    try FileManager.default.createDirectory(at: embeddedFolder, withIntermediateDirectories: true)
                } catch {
                    throw EpisodeImportError.copyFailed(error.localizedDescription)
                }
            }
            let tap = onConversionProgress
            let report = try await MediaConverter.convert(source: readURL, plan: plan, to: video,
                                                          subtitlesFolder: plan.subtitles.isEmpty ? nil : embeddedFolder,
                                                          progress: { value in
                tap?(value)
                Task { @MainActor in relay.send(value) }
            })
            warnings += report.warnings.map { $0.message }
            embedded = report.subtitleFiles
        } else {
            videoExtension = prepared.fileExtension
            video = staging.appending(path: "Episode.\(videoExtension)")
            do {
                try await Task.detached(priority: .userInitiated) {
                    try FileStore.copySecurityScoped(from: readURL, to: video)
                }.value
            } catch {
                throw EpisodeImportError.copyFailed(error.localizedDescription)
            }
        }
        try Task.checkCancellation()

        var subtitle: URL?
        if let subtitleFile {
            let target = staging.appending(path: "Subtitles", directoryHint: .isDirectory)
                .appending(path: FileStore.safeName(subtitleFile.lastPathComponent))
            do {
                try await Task.detached(priority: .userInitiated) {
                    try SourceAccess.coordinatedCopy(from: subtitleFile, to: target)
                }.value
            } catch {
                throw EpisodeImportError.subtitleCopyFailed(error.localizedDescription)
            }
            subtitle = target
        }
        try Task.checkCancellation()
        relay.send(1)
        return Staged(video: video, videoExtension: videoExtension, subtitle: subtitle,
                      embeddedSubtitles: embedded, warnings: warnings)
    }

    // MARK: Commit and rollback

    /// Files moved into Documents by one import, and the folders it created for them.
    private struct MovedFiles {
        var files: [URL] = []
        var createdFolders: [URL] = []

        /// Deletes the moved files, then the folders this import created if they are empty again.
        func undo() {
            let fileManager = FileManager.default
            for file in files {
                try? fileManager.removeItem(at: file)
            }
            for folder in createdFolders.sorted(by: { $0.path(percentEncoded: false).count > $1.path(percentEncoded: false).count }) {
                let contents = (try? fileManager.contentsOfDirectory(atPath: folder.path(percentEncoded: false))) ?? []
                if contents.isEmpty { try? fileManager.removeItem(at: folder) }
            }
        }
    }

    /// Moves staged files to their Documents-relative paths (a rename: tmp and Documents share a volume).
    /// On failure, undoes the moves already made and throws.
    private func move(_ items: [(from: URL, to: String)]) throws -> MovedFiles {
        let fileManager = FileManager.default
        var moved = MovedFiles()
        do {
            for item in items {
                let destination = store.absoluteURL(item.to)
                let folder = destination.deletingLastPathComponent()
                moved.createdFolders += missingFolders(upTo: folder)
                try fileManager.createDirectory(at: folder, withIntermediateDirectories: true)
                try fileManager.moveItem(at: item.from, to: destination)
                moved.files.append(destination)
            }
        } catch {
            moved.undo()
            throw EpisodeImportError.copyFailed(error.localizedDescription)
        }
        return moved
    }

    /// `folder` and its ancestors (below Documents) that don't exist yet, deepest first.
    private func missingFolders(upTo folder: URL) -> [URL] {
        let fileManager = FileManager.default
        let documentsPath = store.documentsURL.standardizedFileURL.path(percentEncoded: false)
        var missing: [URL] = []
        var current = folder.standardizedFileURL
        while !fileManager.fileExists(atPath: current.path(percentEncoded: false)),
              current.path(percentEncoded: false).count > documentsPath.count {
            missing.append(current)
            current = current.deletingLastPathComponent()
        }
        return missing
    }
}

// MARK: - Values the UI uses

/// What `prepare` is doing, for the sheet's status line.
nonisolated enum PrepareStage: Sendable, Equatable {
    /// The file is in iCloud Drive and not on the phone yet: show "Downloading from iCloud…".
    case downloadingFromICloud
    /// Reading the MKV's tracks: show a short spinner.
    case probing
}

/// Choices made between prepare and import. The default is "no built-in subtitles", so callers that don't set
/// the subtitle fields keep the T-006 behaviour. All fields are ignored for MP4/MOV/M4V.
nonisolated struct EpisodeImportOptions: Sendable, Equatable {
    /// MKV only: the audio track to keep (a `MediaProbe.Audio.streamIndex` from `PreparedVideo.audioTracks`);
    /// nil keeps the prepared default (`PreparedVideo.defaultAudioStreamIndex`).
    var audioStreamIndex: Int?
    /// MKV only: the built-in text subtitle tracks (`EmbeddedSubtitleTrack.streamIndex`) to save as files in the
    /// episode's subtitle folder. Pass `PreparedVideo.usableSubtitleStreamIndices` to save them all, so the other
    /// tracks show up under "Load different subtitles".
    var embeddedSubtitleStreams: [Int]
    /// MKV only: which built-in track becomes the episode's subtitle (it is extracted even if it isn't listed in
    /// `embeddedSubtitleStreams`). nil = none. A subtitle file the user picked (`NewEpisodeDetails.subtitleFile`)
    /// wins over it. Start from `PreparedVideo.defaultSubtitleStreamIndex`.
    var chosenSubtitleStream: Int?

    init(audioStreamIndex: Int? = nil, embeddedSubtitleStreams: [Int] = [], chosenSubtitleStream: Int? = nil) {
        self.audioStreamIndex = audioStreamIndex
        self.embeddedSubtitleStreams = embeddedSubtitleStreams
        self.chosenSubtitleStream = chosenSubtitleStream
    }

    /// Every stream to extract: the listed ones plus the chosen one.
    var subtitleStreamsToExtract: [Int] {
        var streams = embeddedSubtitleStreams
        if let chosenSubtitleStream, !streams.contains(chosenSubtitleStream) { streams.append(chosenSubtitleStream) }
        return streams
    }
}

/// One subtitle track of an MKV, for the upload sheet's "Embedded subtitles" row.
nonisolated struct EmbeddedSubtitleTrack: Sendable, Equatable, Identifiable {
    /// The value to use in `EpisodeImportOptions` (also the picker tag).
    var streamIndex: Int
    /// "jpn · Full · ASS", "eng · PGS", or "Track 2 · ASS" when the file names neither language nor title.
    var label: String
    var language: String?
    var title: String?
    /// "SRT", "ASS", "WebVTT" for text; "PGS", "VobSub", "DVB" or the codec name otherwise.
    var formatName: String
    /// A picture format (PGS, VobSub, DVB): the UI says "image-based, can't be used". When `isUsable` and this are
    /// both false it is a text format Clip Deck can't write: say "format not supported".
    var isImageBased: Bool
    /// Flagged default in the file.
    var isDefault: Bool
    /// False for picture tracks (PGS, VobSub, DVB) and text formats Clip Deck can't write: show them greyed out
    /// (picture tracks: "image-based, can't be used"; other text formats: "format not supported"; see `isImageBased`),
    /// and never pass them in the options.
    var isUsable: Bool

    var id: Int { streamIndex }
}

/// The new episode's details from the upload sheet.
nonisolated struct NewEpisodeDetails: Sendable, Equatable {
    /// An existing show's name (matched ignoring case) or a new one. Trimmed; must not be empty.
    var showName: String
    /// Trimmed; must not be empty.
    var title: String
    var number: Int?
    /// An `.srt`/`.ass`/`.ssa` the user picked, copied next to the episode. nil for none.
    var subtitleFile: URL?

    init(showName: String, title: String, number: Int? = nil, subtitleFile: URL? = nil) {
        self.showName = showName
        self.title = title
        self.number = number
        self.subtitleFile = subtitleFile
    }
}

/// The result of `EpisodeImporter.prepare`. Holds the picked file open (security scope + coordinated read)
/// until the import succeeds or `close()` is called (or the last copy of it goes away).
nonisolated struct PreparedVideo: Sendable {
    /// The URL the picker returned.
    let source: URL
    /// Lower-cased: mp4, mov, m4v or mkv.
    let fileExtension: String
    /// 0 when the file system couldn't tell.
    let sourceBytes: Int64
    /// MKV only: what the file contains. nil for MP4/MOV/M4V, which are copied as they are.
    let probe: MediaProbe?
    /// MKV only: the plan for the default audio track.
    let defaultPlan: ConversionPlan?
    let supportsAV1: Bool
    let access: SourceAccess

    /// True for an MKV (converted on import, so show "Converting… n%"); false for a plain copy.
    var needsConversion: Bool { probe != nil }

    /// The audio tracks to choose from (MKV only; empty for MP4/MOV/M4V). Show a picker when there are 2 or more.
    var audioTracks: [MediaProbe.Audio] { probe?.audioTracks ?? [] }

    /// The preselected audio track's stream index (the file's default-flagged track, else the first usable one).
    var defaultAudioStreamIndex: Int? { defaultPlan?.audio?.streamIndex }

    /// All subtitle tracks of the MKV (empty for MP4/MOV/M4V), usable or not, in file order.
    var subtitleTracks: [EmbeddedSubtitleTrack] {
        guard let probe else { return [] }
        return probe.subtitleTracks.enumerated().map { position, track in
            EmbeddedSubtitleTrack(
                streamIndex: track.streamIndex,
                label: label(for: track, position: position),
                language: track.language,
                title: track.title,
                formatName: ConversionPlan.displayName(ofCodec: track.codec),
                isImageBased: !track.isText,
                isDefault: track.isDefault,
                isUsable: ConversionPlan.isUsableSubtitle(track))
        }
    }

    /// The tracks that can be saved as files (text SRT, ASS/SSA, WebVTT). Hide the "Embedded subtitles" row when
    /// this is empty (no subtitles, or pictures only), and say nothing.
    var usableSubtitleTracks: [EmbeddedSubtitleTrack] { subtitleTracks.filter(\.isUsable) }

    /// Stream indices of `usableSubtitleTracks`: pass them as `EpisodeImportOptions.embeddedSubtitleStreams`.
    var usableSubtitleStreamIndices: [Int] { usableSubtitleTracks.map(\.streamIndex) }

    /// The preselected episode subtitle: the default-flagged text track, else the first text track, else nil ("None").
    var defaultSubtitleStreamIndex: Int? {
        probe.flatMap { ConversionPlan.defaultSubtitleTrack(in: $0)?.streamIndex }
    }

    /// Notes for the user about the default plan (e.g. the file has no sound). Empty for a normal file.
    var warnings: [String] { defaultPlan?.warnings.map { $0.message } ?? [] }

    /// The picker label for an audio track: "language · title · codec", leaving out what the file doesn't say
    /// ("und" counts as unknown). With neither language nor title it starts with "Track n" (n from 1).
    func label(for track: MediaProbe.Audio) -> String {
        var parts: [String] = []
        if let language = track.language?.trimmingCharacters(in: .whitespacesAndNewlines),
           !language.isEmpty, language.lowercased() != "und" {
            parts.append(language)
        }
        if let title = track.title?.trimmingCharacters(in: .whitespacesAndNewlines), !title.isEmpty {
            parts.append(title)
        }
        if parts.isEmpty {
            let position = (audioTracks.firstIndex { $0.streamIndex == track.streamIndex } ?? 0) + 1
            parts.append("Track \(position)")
        }
        parts.append(ConversionPlan.displayName(ofCodec: track.codec))
        return parts.joined(separator: " · ")
    }

    /// "language · title · format", leaving out what the file doesn't say ("und" counts as unknown). With neither
    /// language nor title it starts with "Track n" (n = position among the file's subtitle tracks, from 1).
    private func label(for track: MediaProbe.Subtitle, position: Int) -> String {
        var parts: [String] = []
        if let language = track.language?.trimmingCharacters(in: .whitespacesAndNewlines),
           !language.isEmpty, language.lowercased() != "und" {
            parts.append(language)
        }
        if let title = track.title?.trimmingCharacters(in: .whitespacesAndNewlines), !title.isEmpty {
            parts.append(title)
        }
        if parts.isEmpty { parts.append("Track \(position + 1)") }
        parts.append(ConversionPlan.displayName(ofCodec: track.codec))
        return parts.joined(separator: " · ")
    }

    /// The conversion plan for these options, or nil for a file that is copied. Throws
    /// `EpisodeImportError.unsupported` when the chosen audio track can't be used; show its message and keep
    /// Add episode disabled.
    /// `userPickedSubtitleFile`: the user picked their own subtitle file, which wins over the chosen built-in track,
    /// so that track is still extracted but failing to write it only adds a warning.
    func plan(for options: EpisodeImportOptions, userPickedSubtitleFile: Bool = false) throws -> ConversionPlan? {
        guard let probe else { return nil }
        let subtitleStreams = options.subtitleStreamsToExtract
        let requiredStream = userPickedSubtitleFile ? nil : options.chosenSubtitleStream
        guard let audioStreamIndex = options.audioStreamIndex, audioStreamIndex != defaultAudioStreamIndex else {
            guard var plan = defaultPlan else { return nil }
            if !subtitleStreams.isEmpty {
                do {
                    plan.subtitles = try ConversionPlan.subtitleExtractions(
                        in: probe, streams: subtitleStreams, required: requiredStream)
                } catch {
                    throw EpisodeImportError.unsupported(error)
                }
            }
            return plan
        }
        switch EpisodeImporter.makePlan(probe, audioStreamIndex: audioStreamIndex, supportsAV1: supportsAV1,
                                        subtitleStreams: subtitleStreams,
                                        requiredSubtitleStream: requiredStream) {
        case .success(let plan): return plan
        case .failure(let error): throw EpisodeImportError.unsupported(error)
        }
    }

    /// Ends the coordinated read and security-scoped access. Call it when the user picks another file or leaves
    /// without importing. Safe to call more than once.
    func close() {
        access.close()
    }
}

/// What an import made.
struct EpisodeImportResult {
    let episode: Episode
    /// Things worth telling the user after a successful import (no sound track; damaged audio skipped).
    /// Empty for a normal file.
    let warnings: [String]
}

/// Why an import can't go ahead. Every message is a full sentence for the `ErrorBanner`.
nonisolated enum EpisodeImportError: Error, Equatable, Sendable, LocalizedError {
    /// Not mp4, mov, m4v or mkv (the lower-cased extension, possibly empty).
    case unsupportedVideoType(String)
    case unsupportedSubtitleType(String)
    case missingShowName
    case missingTitle
    case iCloudDownloadFailed(String)
    /// The file couldn't be opened or read.
    case unreadable(String)
    case notEnoughSpace(neededBytes: Int64, availableBytes: Int64)
    /// The video (or the chosen audio track) can't be used on iPhone.
    case unsupported(UnsupportedMediaError)
    /// `import` was called with a prepared video that was already closed.
    case sourceClosed
    case copyFailed(String)
    case subtitleCopyFailed(String)
    /// The library couldn't save the episode; its files were removed again.
    case saveFailed(String)

    var errorDescription: String? { message }

    var message: String {
        switch self {
        case .unsupportedVideoType(let fileExtension):
            fileExtension.isEmpty
                ? "Files without an extension aren't supported. Use MP4, MOV, M4V or MKV."
                : "“.\(fileExtension)” videos aren't supported. Use MP4, MOV, M4V or MKV."
        case .unsupportedSubtitleType(let fileExtension):
            "“.\(fileExtension)” files aren't supported. Use an .srt or .ass subtitle file."
        case .missingShowName:
            "Enter a show name."
        case .missingTitle:
            "Enter an episode name."
        case .iCloudDownloadFailed(let detail):
            "The file couldn't be downloaded from iCloud (\(detail)). Check your connection and try again."
        case .unreadable(let detail):
            "Clip Deck couldn't read this file (\(detail)). Choose it again, or try another copy."
        case .notEnoughSpace(let needed, let available):
            "This needs about \(StorageSpaceRule.gigabytes(roundingUp: needed)) free; you have \(StorageSpaceRule.gigabytes(roundingDown: available))."
        case .unsupported(let error):
            error.message
        case .sourceClosed:
            "The video is no longer open. Choose it again."
        case .copyFailed(let detail):
            "The video couldn't be copied: \(detail)"
        case .subtitleCopyFailed(let detail):
            "The subtitle file couldn't be copied: \(detail)"
        case .saveFailed(let detail):
            "The episode couldn't be saved, so nothing was added: \(detail)"
        }
    }
}

/// The free-space rule (spec › Free space): the volume needs the source size plus the larger of 10 % and 200 MB.
/// Sizes are decimal (1 GB = 1,000,000,000 bytes), as iOS shows them in Settings › General › iPhone Storage.
nonisolated enum StorageSpaceRule {
    static let minimumMargin: Int64 = 200_000_000

    static func requiredBytes(forSourceBytes sourceBytes: Int64) -> Int64 {
        let size = max(sourceBytes, 0)
        let margin = max(size / 10, minimumMargin)
        let (sum, overflow) = size.addingReportingOverflow(margin)
        return overflow ? .max : sum
    }

    /// Throws `EpisodeImportError.notEnoughSpace` when `availableBytes` is below the requirement. Unknown free
    /// space (nil) passes: refusing every import because iOS didn't answer would be worse.
    static func check(sourceBytes: Int64, availableBytes: Int64?) throws {
        guard let availableBytes else { return }
        let needed = requiredBytes(forSourceBytes: sourceBytes)
        guard availableBytes >= needed else {
            throw EpisodeImportError.notEnoughSpace(neededBytes: needed, availableBytes: availableBytes)
        }
    }

    /// "1.6 GB": tenths of a GB, rounded up (for what is needed).
    static func gigabytes(roundingUp bytes: Int64) -> String {
        let clamped = max(bytes, 0)
        let tenths = clamped / 100_000_000 + (clamped % 100_000_000 == 0 ? 0 : 1)
        return "\(tenths / 10).\(tenths % 10) GB"
    }

    /// "0.9 GB": tenths of a GB, rounded down (for what is free).
    static func gigabytes(roundingDown bytes: Int64) -> String {
        let tenths = max(bytes, 0) / 100_000_000
        return "\(tenths / 10).\(tenths % 10) GB"
    }
}

extension ConversionPlan.Warning {
    /// A note for the user after preparing or importing.
    nonisolated var message: String {
        switch self {
        case .noAudioTrack: "This video has no sound track, so its cards will have no audio."
        }
    }
}

/// Delivers progress to the caller on the main actor, never going backwards (reports hop to the main actor
/// in separate tasks, so a late one must not undo a newer value).
@MainActor
final class ProgressRelay {
    private let handler: @MainActor (Double) -> Void
    private var last = -Double.infinity

    init(_ handler: @escaping @MainActor (Double) -> Void) {
        self.handler = handler
    }

    func send(_ value: Double) {
        guard value.isFinite, value > last else { return }
        last = value
        handler(value)
    }
}
