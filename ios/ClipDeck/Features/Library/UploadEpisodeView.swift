import SwiftData
import SwiftUI
import UniformTypeIdentifiers

/// Upload an episode: choose (or create) a show, pick the video, name it, optionally add subtitles.
struct UploadEpisodeView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Show.name) private var shows: [Show]

    @State private var selectedShowName = ""
    @State private var newShowName = ""
    @State private var title = ""
    @State private var numberText = ""
    @State private var videoURL: URL?
    @State private var subtitleURL: URL?
    @State private var pickingKind: Picking = .video
    @State private var isPicking = false
    @State private var isSaving = false
    @State private var errorMessage: String?

    private let store = FileStore.live
    private static let newShowTag = "__new__"

    enum Picking {
        case video, subtitle
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Show") {
                    Picker("Show", selection: $selectedShowName) {
                        ForEach(shows) { Text($0.name).tag($0.name) }
                        Text("New show…").tag(Self.newShowTag)
                    }
                    .accessibilityIdentifier("upload.showPicker")
                    if isNewShow {
                        TextField("Show name, e.g. Attack on Titan", text: $newShowName)
                            .accessibilityIdentifier("upload.newShowName")
                    }
                }

                Section("Episode") {
                    TextField("Episode name, e.g. Episode 3", text: $title)
                        .accessibilityIdentifier("upload.title")
                    TextField("Episode number (optional)", text: $numberText)
                        .keyboardType(.numberPad)
                        .accessibilityIdentifier("upload.number")
                    fileRow(
                        label: "Video",
                        fileName: videoURL?.lastPathComponent,
                        placeholder: "Choose MP4, MOV or M4V",
                        identifier: "upload.video"
                    ) { pickingKind = .video; isPicking = true }
                }

                Section {
                    fileRow(
                        label: "Subtitles",
                        fileName: subtitleURL?.lastPathComponent,
                        placeholder: "Choose SRT or ASS (optional)",
                        identifier: "upload.subtitle"
                    ) { pickingKind = .subtitle; isPicking = true }
                } footer: {
                    Text("You can add subtitles later from the show's episode list.")
                }

                if let errorMessage {
                    Section { ErrorBanner(message: errorMessage) }
                        .listRowBackground(Color.clear)
                        .listRowInsets(EdgeInsets())
                }
            }
            .navigationTitle("Upload episode")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .disabled(isSaving)
                }
                ToolbarItem(placement: .confirmationAction) {
                    if isSaving {
                        ProgressView()
                    } else {
                        Button("Add episode") { Task { await save() } }
                            .disabled(!canSave)
                            .accessibilityIdentifier("upload.save")
                    }
                }
            }
            .fileImporter(
                isPresented: $isPicking,
                allowedContentTypes: pickingKind == .subtitle ? FileTypes.subtitles : FileTypes.videos
            ) { result in
                handlePick(result)
            }
            .onAppear {
                if selectedShowName.isEmpty { selectedShowName = shows.first?.name ?? Self.newShowTag }
            }
            .interactiveDismissDisabled(isSaving)
        }
    }

    private var isNewShow: Bool { selectedShowName == Self.newShowTag }

    private var showName: String {
        (isNewShow ? newShowName : selectedShowName).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var canSave: Bool {
        !showName.isEmpty && !title.trimmingCharacters(in: .whitespaces).isEmpty && videoURL != nil && !isSaving
    }

    private func fileRow(label: String, fileName: String?, placeholder: String, identifier: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                Text(label).foregroundStyle(Theme.ink)
                Spacer()
                Text(fileName ?? placeholder)
                    .foregroundStyle(fileName == nil ? Theme.inkSoft : Theme.accent)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
        }
        .accessibilityIdentifier(identifier)
    }

    private func handlePick(_ result: Result<URL, Error>) {
        switch result {
        case .success(let url):
            if pickingKind == .subtitle {
                guard SubtitleFormat(fileExtension: url.pathExtension) != nil else {
                    errorMessage = SubtitleError.unsupportedFormat(url.pathExtension).localizedDescription
                    return
                }
                subtitleURL = url
            } else {
                guard FileStore.videoExtensions.contains(url.pathExtension.lowercased()) else {
                    errorMessage = "“.\(url.pathExtension)” videos aren't supported. Use MP4, MOV or M4V."
                    return
                }
                videoURL = url
                if title.isEmpty { title = url.deletingPathExtension().lastPathComponent }
            }
            errorMessage = nil
        case .failure(let error):
            errorMessage = "The file couldn't be opened: \(error.localizedDescription)"
        }
    }

    private func save() async {
        guard let videoURL else { return }
        isSaving = true
        errorMessage = nil
        let episodeTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        do {
            let show = try findOrCreateShow(named: showName)
            let videoPath = store.uniquePath(
                folder: store.videoFolderPath(show: show.name),
                baseName: episodeTitle,
                fileExtension: videoURL.pathExtension
            )
            try await store.importFile(from: videoURL, toRelativePath: videoPath)

            var subtitlePath: String?
            if let subtitleURL {
                let folder = store.subtitleFolderPath(show: show.name, episode: episodeTitle)
                let path = "\(folder)/\(FileStore.safeName(subtitleURL.lastPathComponent))"
                try await store.importFile(from: subtitleURL, toRelativePath: path)
                subtitlePath = path
            }

            let episode = Episode(
                title: episodeTitle,
                number: Int(numberText.trimmingCharacters(in: .whitespaces)),
                videoPath: videoPath,
                subtitlePath: subtitlePath,
                show: show
            )
            context.insert(episode)
            try context.save()
            dismiss()
        } catch {
            errorMessage = "The episode couldn't be added: \(error.localizedDescription)"
            isSaving = false
        }
    }

    private func findOrCreateShow(named name: String) throws -> Show {
        if let existing = shows.first(where: { $0.name.caseInsensitiveCompare(name) == .orderedSame }) {
            return existing
        }
        let show = Show(name: name, colorIndex: shows.count)
        context.insert(show)
        return show
    }
}

enum FileTypes {
    static let videos: [UTType] = [.mpeg4Movie, .quickTimeMovie, UTType(filenameExtension: "m4v") ?? .movie]
    /// .srt/.ass have no system-declared types, so allow any file and check the extension after picking.
    static let subtitles: [UTType] = [.item]
}
