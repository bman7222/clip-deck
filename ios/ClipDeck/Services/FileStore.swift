import Foundation

/// Where the app keeps files, and how imports land there.
///
/// Layout (Documents is visible in the Files app under On My iPhone > Clip Deck):
///   Documents/Videos/<Show>/<Episode>.mp4
///   Documents/Subtitles/<Show>/<Episode>/<file>.srt|.ass
///   Library/CardMedia/clipdeck_<card-id>.m4a|.jpg   (not user-visible)
struct FileStore {
    let documentsURL: URL
    let libraryURL: URL

    static let live = FileStore(documentsURL: URL.documentsDirectory, libraryURL: URL.libraryDirectory)

    static let appFolderLabel = "On My iPhone › Clip Deck"

    var videosFolder: URL { documentsURL.appending(path: "Videos", directoryHint: .isDirectory) }
    var subtitlesFolder: URL { documentsURL.appending(path: "Subtitles", directoryHint: .isDirectory) }
    var cardMediaFolder: URL { libraryURL.appending(path: "CardMedia", directoryHint: .isDirectory) }

    func ensureFolders() {
        for folder in [videosFolder, subtitlesFolder, cardMediaFolder] {
            try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        }
    }

    // MARK: Paths

    func absoluteURL(_ relativePath: String) -> URL {
        documentsURL.appending(path: relativePath)
    }

    func exists(_ relativePath: String) -> Bool {
        FileManager.default.fileExists(atPath: absoluteURL(relativePath).path(percentEncoded: false))
    }

    func cardMediaURL(_ fileName: String) -> URL {
        cardMediaFolder.appending(path: fileName)
    }

    /// A file/folder name that is safe on disk: no slashes or colons, never empty.
    nonisolated static func safeName(_ name: String) -> String {
        // Newlines and other control characters would make odd names in the Files app and the subtitle picker.
        var scalars = String.UnicodeScalarView()
        for scalar in name.unicodeScalars {
            scalars.append(CharacterSet.controlCharacters.contains(scalar) ? " " : scalar)
        }
        let cleaned = String(scalars)
            .replacingOccurrences(of: "/", with: "-")
            .replacingOccurrences(of: ":", with: "-")
            .replacingOccurrences(of: "\\", with: "-")
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: "."))
        return cleaned.isEmpty ? "Untitled" : cleaned
    }

    func subtitleFolderPath(show: String, episode: String) -> String {
        "Subtitles/\(Self.safeName(show))/\(Self.safeName(episode))"
    }

    func videoFolderPath(show: String) -> String {
        "Videos/\(Self.safeName(show))"
    }

    /// `folder/name.ext`, or `folder/name (2).ext` etc. if that file already exists.
    func uniquePath(folder: String, baseName: String, fileExtension: String) -> String {
        let base = Self.safeName(baseName)
        let ext = fileExtension.lowercased()
        var candidate = "\(folder)/\(base).\(ext)"
        var counter = 2
        while exists(candidate) {
            candidate = "\(folder)/\(base) (\(counter)).\(ext)"
            counter += 1
        }
        return candidate
    }

    /// Human-readable location of a stored file's folder, as the Files app shows it.
    func locationDescription(ofRelativePath relativePath: String) -> String {
        let folders = relativePath.split(separator: "/").dropLast()
        return ([Self.appFolderLabel] + folders.map(String.init)).joined(separator: " › ")
    }

    // MARK: Importing

    /// Copies a user-picked file into the app at `relativePath` (creating folders).
    /// Runs the copy off the main thread because videos can be gigabytes.
    func importFile(from source: URL, toRelativePath relativePath: String) async throws {
        let destination = absoluteURL(relativePath)
        try await Task.detached(priority: .userInitiated) {
            try FileStore.copySecurityScoped(from: source, to: destination)
        }.value
    }

    nonisolated static func copySecurityScoped(from source: URL, to destination: URL) throws {
        let scoped = source.startAccessingSecurityScopedResource()
        defer { if scoped { source.stopAccessingSecurityScopedResource() } }
        let fm = FileManager.default
        try fm.createDirectory(at: destination.deletingLastPathComponent(), withIntermediateDirectories: true)
        if fm.fileExists(atPath: destination.path(percentEncoded: false)) {
            try fm.removeItem(at: destination)
        }
        try fm.copyItem(at: source, to: destination)
    }

    func deleteFile(_ relativePath: String) {
        try? FileManager.default.removeItem(at: absoluteURL(relativePath))
    }

    // MARK: Browsing

    struct Entry: Identifiable, Hashable {
        let name: String
        let relativePath: String
        let isFolder: Bool
        var id: String { relativePath }
    }

    /// Folders first, then files; hidden files skipped.
    func contents(ofRelativeFolder folder: String) -> [Entry] {
        let url = absoluteURL(folder)
        let items = (try? FileManager.default.contentsOfDirectory(
            at: url, includingPropertiesForKeys: [.isDirectoryKey], options: [.skipsHiddenFiles]
        )) ?? []
        return items.map { item in
            let isFolder = (try? item.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false
            return Entry(name: item.lastPathComponent, relativePath: "\(folder)/\(item.lastPathComponent)", isFolder: isFolder)
        }
        .sorted { lhs, rhs in
            if lhs.isFolder != rhs.isFolder { return lhs.isFolder }
            return lhs.name.localizedStandardCompare(rhs.name) == .orderedAscending
        }
    }

    /// Subtitle files stored for an episode.
    func subtitleFiles(show: String, episode: String) -> [Entry] {
        contents(ofRelativeFolder: subtitleFolderPath(show: show, episode: episode))
            .filter { !$0.isFolder && SubtitleFormat(fileExtension: ($0.name as NSString).pathExtension) != nil }
    }
}
