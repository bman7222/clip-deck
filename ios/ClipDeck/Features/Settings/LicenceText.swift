import Foundation

/// Loads the licence and notice texts bundled under `Licenses/`.
enum LicenceText {
    static let missing = "Licence text missing"

    /// The text of `Licenses/<name>.txt`, or a visible fallback when it can't be read.
    static func load(_ name: String, bundle: Bundle = .main) -> String {
        guard let url = bundle.url(forResource: name, withExtension: "txt", subdirectory: "Licenses"),
              let text = try? String(contentsOf: url, encoding: .utf8),
              !text.isEmpty
        else { return "\(missing): \(name)" }
        return text
    }
}
