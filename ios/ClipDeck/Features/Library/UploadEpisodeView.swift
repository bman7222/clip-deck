import SwiftData
import SwiftUI
import UniformTypeIdentifiers

/// Upload an episode: choose (or create) a show, pick the video, name it, optionally add subtitles.
/// Every video goes through `EpisodeImporter` (via `VideoImportModel`): MKV is converted to MP4 with an audio-track
/// choice, progress and Cancel; MP4/MOV/M4V are copied.
struct UploadEpisodeView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Show.name) private var shows: [Show]

    @State private var selectedShowName = ""
    @State private var newShowName = ""
    @State private var title = ""
    @State private var numberText = ""
    @State private var video = VideoImportModel()
    @State private var subtitleURL: URL?
    @State private var pickingKind: Picking = .video
    @State private var isPicking = false
    @State private var errorMessage: String?
    /// Notes from a finished import (e.g. damaged audio skipped); shown before the sheet closes.
    @State private var importWarnings: [String] = []

    private static let newShowTag = "__new__"

    enum Picking {
        case video, subtitle
    }

    var body: some View {
        NavigationStack {
            Form {
                if video.isRunning {
                    Section {
                        ImportProgressView(model: video, identifierPrefix: "upload")
                    }
                }

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
                .disabled(video.isRunning)

                Section {
                    TextField("Episode name, e.g. Episode 3", text: $title)
                        .accessibilityIdentifier("upload.title")
                    TextField("Episode number (optional)", text: $numberText)
                        .keyboardType(.numberPad)
                        .accessibilityIdentifier("upload.number")
                    fileRow(
                        label: "Video",
                        fileName: video.fileName,
                        placeholder: "Choose MP4, MOV, M4V or MKV",
                        identifier: "upload.video"
                    ) { pickingKind = .video; isPicking = true }
                    if video.isPreparing {
                        VideoPreparingRow(text: video.preparingText, identifier: "upload.preparing")
                    }
                    if video.audioTracks.count > 1 {
                        Picker("Audio", selection: audioSelection) {
                            ForEach(video.audioTracks, id: \.streamIndex) { track in
                                Text(video.audioLabel(for: track)).tag(track.streamIndex)
                            }
                        }
                        .accessibilityIdentifier("upload.audioTrack")
                    }
                } header: {
                    Text("Episode")
                } footer: {
                    if video.prepared?.needsConversion == true {
                        Text("MKV videos are converted to MP4 when you add them. Keep Clip Deck open until it finishes.")
                    }
                }
                .disabled(video.isRunning)

                if let videoError = video.videoError {
                    Section {
                        ErrorBanner(message: videoError)
                            .accessibilityIdentifier("upload.videoError")
                    }
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets())
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
                .disabled(video.isRunning)

                if let errorMessage {
                    Section {
                        ErrorBanner(message: errorMessage)
                            .accessibilityIdentifier("upload.error")
                    }
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets())
                }
            }
            .navigationTitle("Upload episode")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .disabled(video.isRunning)
                }
                ToolbarItem(placement: .confirmationAction) {
                    if video.isRunning {
                        ProgressView()
                    } else {
                        Button("Add episode") { startImport() }
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
            .alert("Episode added", isPresented: showWarnings) {
                Button("OK") { dismiss() }
                    .accessibilityIdentifier("upload.warningsOK")
            } message: {
                Text(importWarnings.joined(separator: "\n\n"))
            }
            .onAppear {
                if selectedShowName.isEmpty { selectedShowName = shows.first?.name ?? Self.newShowTag }
            }
            // Leaving the sheet (Cancel, swipe, or after adding) stops a running prepare and closes the picked file.
            .onDisappear { video.leave() }
            .interactiveDismissDisabled(video.isRunning)
        }
    }

    private var isNewShow: Bool { selectedShowName == Self.newShowTag }

    private var showName: String {
        (isNewShow ? newShowName : selectedShowName).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var canSave: Bool {
        !showName.isEmpty && !title.trimmingCharacters(in: .whitespaces).isEmpty && video.canImport
    }

    private var audioSelection: Binding<Int> {
        Binding(
            get: { video.selectedAudio ?? video.audioTracks.first?.streamIndex ?? 0 },
            set: { video.selectAudio($0) }
        )
    }

    private var showWarnings: Binding<Bool> {
        Binding(
            get: { !importWarnings.isEmpty },
            set: { if !$0 { importWarnings = [] } }
        )
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
            errorMessage = nil
            if pickingKind == .subtitle {
                guard SubtitleFormat(fileExtension: url.pathExtension) != nil else {
                    errorMessage = SubtitleError.unsupportedFormat(url.pathExtension).localizedDescription
                    return
                }
                subtitleURL = url
            } else {
                // Closes the previous file; the extension check, iCloud download, space check and (MKV) probe
                // all happen in the importer. A refused file shows its message and keeps Add episode disabled.
                video.pick(url)
                if EpisodeImporter.isSupportedVideo(url), title.isEmpty {
                    title = url.deletingPathExtension().lastPathComponent
                }
            }
        case .failure(let error):
            errorMessage = "The file couldn't be opened: \(error.localizedDescription)"
        }
    }

    private func startImport() {
        errorMessage = nil
        let details = NewEpisodeDetails(
            showName: showName,
            title: title,
            number: Int(numberText.trimmingCharacters(in: .whitespaces)),
            subtitleFile: subtitleURL
        )
        let context = self.context
        video.run({ importer, prepared, options, progress in
            try await importer.importEpisode(prepared, as: details, options: options, into: context, progress: progress)
        }, completion: { outcome in
            switch outcome {
            case .added(let result):
                if result.warnings.isEmpty {
                    dismiss()
                } else {
                    importWarnings = result.warnings
                }
            case .cancelled:
                // Nothing was added; the file stays prepared, so Add episode can be tapped again.
                break
            case .failed(let message):
                errorMessage = message
            }
        })
    }
}

enum FileTypes {
    /// MKV has no system-declared type, so allow movies and any file, and check the extension after picking
    /// (`EpisodeImporter.isSupportedVideo`, then `prepare`).
    static let videos: [UTType] = [.movie, .item]
    /// .srt/.ass have no system-declared types, so allow any file and check the extension after picking.
    static let subtitles: [UTType] = [.item]
}
