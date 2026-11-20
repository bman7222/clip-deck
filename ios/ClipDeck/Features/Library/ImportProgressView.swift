import SwiftUI

/// "Converting… 42%" (or "Adding…" for a plain copy) with a bar and Cancel, shared by the upload sheet and
/// "Choose the video again", so both look and behave the same (spec J-1, J-6).
/// Identifiers: `<prefix>.progress` (the status text) and `<prefix>.cancelConvert`.
struct ImportProgressView: View {
    let model: VideoImportModel
    let identifierPrefix: String

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.m) {
            HStack(alignment: .firstTextBaseline, spacing: Spacing.m) {
                if !model.isConverting {
                    ProgressView()
                }
                Text(model.progressText)
                    .font(.deckHeadline)
                    .monospacedDigit()
                    .foregroundStyle(Theme.ink)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("\(identifierPrefix).progress")
                Spacer(minLength: Spacing.s)
                Button("Cancel", role: .destructive) { model.cancelRun() }
                    .font(.deckHeadline)
                    .foregroundStyle(Theme.danger)
                    .buttonStyle(.borderless)
                    .frame(minHeight: 44)
                    .accessibilityIdentifier("\(identifierPrefix).cancelConvert")
            }
            if model.isConverting {
                ProgressView(value: model.progress)
                    .tint(Theme.accent)
                    .accessibilityHidden(true)
                Text("Keep Clip Deck open until it finishes. The screen stays on meanwhile.")
                    .font(.deckCaption)
                    .foregroundStyle(Theme.inkSoft)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

/// The status line while a picked video is checked: "Downloading from iCloud…", "Reading the video…".
struct VideoPreparingRow: View {
    let text: String
    let identifier: String

    var body: some View {
        HStack(spacing: Spacing.m) {
            ProgressView()
            Text(text)
                .font(.deckCallout)
                .foregroundStyle(Theme.inkSoft)
                .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier(identifier)
    }
}
