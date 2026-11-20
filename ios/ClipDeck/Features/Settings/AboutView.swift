import SwiftUI

/// Settings › About and licences: app version, the Clip Deck licence, and the FFmpeg notices
/// that the LGPL requires us to ship, with source links.
struct AboutView: View {
    private static let ffmpegSource = URL(string: "https://github.com/FFmpeg/FFmpeg/tree/n8.1.3")!
    private static let ffmpegBuildSource = URL(string: "https://github.com/superuser404notfound/FFmpegBuild/tree/3.16.0")!

    private let appLicense = LicenceText.load("ClipDeck-LICENSE")
    private let ffmpegNotice = LicenceText.load("FFmpeg-NOTICE")
    private let lgpl = LicenceText.load("FFmpeg-LGPL-2.1")
    private let otherComponents = LicenceText.load("Other-Components")

    private var appVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "unknown"
    }

    var body: some View {
        List {
            Section {
                LabeledContent("Clip Deck", value: appVersion)
                LabeledContent("FFmpeg", value: "n8.1.3")
                LabeledContent("FFmpegBuild", value: "3.16.0")
            } header: {
                Text("Versions")
            }

            Section("Clip Deck licence") {
                licenceBlock(appLicense, identifier: "about.appLicense")
            }

            Section("FFmpeg notice") {
                licenceBlock(ffmpegNotice, identifier: "about.ffmpegNotice")
                Link(destination: Self.ffmpegSource) {
                    Label("FFmpeg n8.1.3 source", systemImage: "link")
                }
                .accessibilityIdentifier("about.ffmpegSource")
                Link(destination: Self.ffmpegBuildSource) {
                    Label("FFmpegBuild 3.16.0 source", systemImage: "link")
                }
                .accessibilityIdentifier("about.ffmpegBuildSource")
            }

            Section("GNU Lesser General Public License 2.1") {
                licenceBlock(lgpl, identifier: "about.lgpl")
            }

            Section("Other components") {
                licenceBlock(otherComponents, identifier: "about.otherComponents")
            }
        }
        .navigationTitle("About and licences")
        .navigationBarTitleDisplayMode(.inline)
        .background(Theme.shell)
    }

    /// Long text as one wrapping, selectable element. The enclosing List scrolls and Dynamic Type applies.
    private func licenceBlock(_ text: String, identifier: String) -> some View {
        Text(text)
            .font(.system(.footnote, design: .monospaced))
            .foregroundStyle(Theme.ink)
            .textSelection(.enabled)
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityIdentifier(identifier)
    }
}
