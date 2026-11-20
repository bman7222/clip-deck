import Foundation

/// When does this sideloaded install stop opening, and should we remind the user?
///
/// A free-Apple-ID install is signed for 7 days. The signing profile ships in the app bundle as
/// `embedded.mobileprovision` (a CMS envelope whose payload is a plain XML plist). Simulator, TestFlight and
/// App Store builds have no such file, so every function here returns nil / false for them.
nonisolated enum InstallExpiry {
    /// Show the reminder from this long before expiry (and on/after it).
    static let reminderLead: TimeInterval = 48 * 60 * 60
    /// Debug-only launch argument: `-uiTestingExpiry <ISO-8601 date>` replaces the real expiry date.
    static let overrideArgument = "-uiTestingExpiry"
    /// SideStore's URL scheme (CFBundleURLSchemes in SideStore@4f3d18d AltStore/Info.plist). Opening it only launches the app.
    static let sideStoreURL = URL(string: "sidestore://")!

    // MARK: Reading the profile

    /// Pulls `ExpirationDate` out of the bytes of an `embedded.mobileprovision`.
    /// Nil for anything that isn't a profile: empty or garbage data, truncated XML, no key, wrong value type.
    static func expirationDate(fromProfile data: Data) -> Date? {
        guard let start = data.range(of: Data("<?xml".utf8)),
              let end = data.range(of: Data("</plist>".utf8), in: start.lowerBound..<data.endIndex)
        else { return nil }
        let xml = data.subdata(in: start.lowerBound..<end.upperBound)
        guard let plist = try? PropertyListSerialization.propertyList(from: xml, options: [], format: nil),
              let dict = plist as? [String: Any]
        else { return nil }
        return dict["ExpirationDate"] as? Date
    }

    /// Reads and parses a profile file. Nil when the URL is nil, the file is missing or unreadable, or it doesn't parse.
    static func expirationDate(profileAt url: URL?) -> Date? {
        guard let url, let data = try? Data(contentsOf: url) else { return nil }
        return expirationDate(fromProfile: data)
    }

    /// The real expiry of this install, from the profile in `bundle`. Nil when there is no profile.
    static func profileExpiry(in bundle: Bundle = .main) -> Date? {
        expirationDate(profileAt: bundle.url(forResource: "embedded", withExtension: "mobileprovision"))
    }

    // MARK: Debug override

    /// Value of `-uiTestingExpiry <ISO-8601>` in `arguments`; nil when absent or not a valid date.
    static func overrideDate(in arguments: [String]) -> Date? {
        guard let i = arguments.firstIndex(of: overrideArgument), i + 1 < arguments.count else { return nil }
        let text = arguments[i + 1]
        let plain = ISO8601DateFormatter()
        if let date = plain.date(from: text) { return date }
        let fractional = ISO8601DateFormatter()
        fractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return fractional.date(from: text)
    }

    /// The expiry the app should use: the Debug override when given, otherwise the profile's date.
    /// Release builds ignore the override.
    static func currentExpiry(bundle: Bundle = .main, arguments: [String] = ProcessInfo.processInfo.arguments) -> Date? {
        #if DEBUG
        if let override = overrideDate(in: arguments) { return override }
        #endif
        return profileExpiry(in: bundle)
    }

    // MARK: Decision

    /// "yyyy-MM-dd" of `date` on `calendar` (its time zone). This is what a dismissal stores.
    static func dayStamp(for date: Date, calendar: Calendar = .current) -> String {
        let c = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", c.year ?? 0, c.month ?? 0, c.day ?? 0)
    }

    /// True when the banner should be on screen: an expiry is known, it is 48 h away or less (including after it),
    /// and the user hasn't dismissed it on today's local calendar day.
    static func shouldShowBanner(now: Date, expiry: Date?, lastDismissedDay: String?, calendar: Calendar = .current) -> Bool {
        guard let expiry else { return false }
        guard expiry.timeIntervalSince(now) <= reminderLead else { return false }
        return lastDismissedDay != dayStamp(for: now, calendar: calendar)
    }

    // MARK: Strings

    /// Banner text. Before expiry: "Clip Deck stops opening on Fri 21 Nov at 14:02. Open SideStore and tap Refresh All."
    static func bannerText(expiry: Date, now: Date, timeZone: TimeZone = .current) -> String {
        let when = "\(format("EEE d MMM", expiry, timeZone)) at \(format("HH:mm", expiry, timeZone))"
        let lead = expiry > now ? "Clip Deck stops opening on" : "Clip Deck's signing ran out on"
        return "\(lead) \(when). Open SideStore and tap Refresh All."
    }

    /// Anki settings row text, e.g. "This install expires: Fri 21 Nov 2026 at 14:02".
    static func settingsText(expiry: Date, timeZone: TimeZone = .current) -> String {
        "This install expires: \(format("EEE d MMM yyyy", expiry, timeZone)) at \(format("HH:mm", expiry, timeZone))"
    }

    private static func format(_ pattern: String, _ date: Date, _ timeZone: TimeZone) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = timeZone
        f.dateFormat = pattern
        return f.string(from: date)
    }
}

/// Remembers the local day on which the user last dismissed the reminder.
final class ExpiryReminderStore {
    static let key = "installExpiry.lastDismissedDay"
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) { self.defaults = defaults }

    var lastDismissedDay: String? { defaults.string(forKey: Self.key) }

    /// Hides the banner until the next local day.
    func recordDismissal(now: Date = Date(), calendar: Calendar = .current) {
        defaults.set(InstallExpiry.dayStamp(for: now, calendar: calendar), forKey: Self.key)
    }

    func shouldShowBanner(now: Date = Date(), expiry: Date?, calendar: Calendar = .current) -> Bool {
        InstallExpiry.shouldShowBanner(now: now, expiry: expiry, lastDismissedDay: lastDismissedDay, calendar: calendar)
    }
}
