import Foundation

/// Typed access to public build-time configuration.
///
/// Values flow: ios/Config/*.xcconfig -> Info.plist (see project.yml `info.properties`) -> here.
/// Only values that are safe inside the app binary belong here. Server secrets never ship in the app.
enum AppConfig {
    /// Returns a non-empty Info.plist string value, or nil when the key is missing or blank.
    static func value(for key: String, in bundle: Bundle = .main) -> String? {
        guard let raw = bundle.object(forInfoDictionaryKey: key) as? String else { return nil }
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    /// Parses a configured URL value. Nil when missing, blank, or not an absolute http(s) URL.
    static func url(for key: String, in bundle: Bundle = .main) -> URL? {
        guard let string = value(for: key, in: bundle),
              let url = URL(string: string),
              let scheme = url.scheme?.lowercased(),
              scheme == "http" || scheme == "https",
              url.host != nil
        else { return nil }
        return url
    }
}
