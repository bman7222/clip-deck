import Foundation
import Testing
@testable import ClipDeck

@MainActor
struct InstallExpiryTests {
    // MARK: helpers

    private func date(_ iso: String) -> Date { ISO8601DateFormatter().date(from: iso)! }

    private func calendar(_ zone: String) -> Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: zone)!
        return c
    }

    private var utc: Calendar { calendar("UTC") }

    /// A fake provisioning profile: junk bytes, the XML plist, junk bytes (like the CMS envelope).
    private func profile(expiry: Date?, extra: [String: Any] = [:], junkBefore: [UInt8] = [0x30, 0x82, 0xFF, 0xFE, 0x00, 0x80]) throws -> Data {
        var dict: [String: Any] = ["Name": "iOS Team Provisioning Profile", "TeamName": "Test"]
        if let expiry { dict["ExpirationDate"] = expiry }
        for (k, v) in extra { dict[k] = v }
        let xml = try PropertyListSerialization.data(fromPropertyList: dict, format: .xml, options: 0)
        return Data(junkBefore) + xml + Data([0x00, 0xA0, 0x82, 0x01, 0xFF, 0xFE])
    }

    private func tempFile(_ data: Data) throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("expiry-\(UUID().uuidString).mobileprovision")
        try data.write(to: url)
        return url
    }

    // MARK: parser (AC-1)

    @Test func parsesExpirationDateFromWrappedPlist() throws {
        let expiry = date("2026-11-21T14:02:00Z")
        #expect(InstallExpiry.expirationDate(fromProfile: try profile(expiry: expiry)) == expiry)
    }

    @Test func parsesWithNoJunkAtAll() throws {
        let expiry = date("2026-11-21T14:02:00Z")
        #expect(InstallExpiry.expirationDate(fromProfile: try profile(expiry: expiry, junkBefore: [])) == expiry)
    }

    @Test func ignoresOtherKeysAndNestedData() throws {
        let expiry = date("2027-01-02T03:04:05Z")
        let data = try profile(expiry: expiry, extra: ["DeveloperCertificates": [Data([1, 2, 3])], "Entitlements": ["get-task-allow": true]])
        #expect(InstallExpiry.expirationDate(fromProfile: data) == expiry)
    }

    @Test func emptyAndGarbageDataGiveNil() {
        #expect(InstallExpiry.expirationDate(fromProfile: Data()) == nil)
        #expect(InstallExpiry.expirationDate(fromProfile: Data([0x30, 0x82, 0xFF, 0x00, 0x11])) == nil)
        #expect(InstallExpiry.expirationDate(fromProfile: Data("just some text".utf8)) == nil)
    }

    @Test func truncatedXMLGivesNil() throws {
        let full = try profile(expiry: date("2026-11-21T14:02:00Z"))
        let end = full.range(of: Data("</plist>".utf8))!.lowerBound
        #expect(InstallExpiry.expirationDate(fromProfile: full.subdata(in: 0..<end)) == nil)
        // Cut mid-document, after "<?xml".
        let start = full.range(of: Data("<?xml".utf8))!.lowerBound
        #expect(InstallExpiry.expirationDate(fromProfile: full.subdata(in: 0..<(start + 40))) == nil)
    }

    @Test func malformedXMLBetweenMarkersGivesNil() {
        let data = Data("junk<?xml version=\"1.0\"?><plist><dict><key>ExpirationDate</key></plist>junk".utf8)
        #expect(InstallExpiry.expirationDate(fromProfile: data) == nil)
    }

    @Test func missingKeyOrWrongTypeGivesNil() throws {
        #expect(InstallExpiry.expirationDate(fromProfile: try profile(expiry: nil)) == nil)
        #expect(InstallExpiry.expirationDate(fromProfile: try profile(expiry: nil, extra: ["ExpirationDate": "tomorrow"])) == nil)
    }

    @Test func plistThatIsNotADictionaryGivesNil() {
        let data = Data("x<?xml version=\"1.0\"?><plist version=\"1.0\"><array><string>a</string></array></plist>x".utf8)
        #expect(InstallExpiry.expirationDate(fromProfile: data) == nil)
    }

    @Test func readsFromFile() throws {
        let expiry = date("2026-11-21T14:02:00Z")
        let url = try tempFile(try profile(expiry: expiry))
        defer { try? FileManager.default.removeItem(at: url) }
        #expect(InstallExpiry.expirationDate(profileAt: url) == expiry)
    }

    @Test func missingNilAndCorruptFilesGiveNil() throws {
        #expect(InstallExpiry.expirationDate(profileAt: nil) == nil)
        #expect(InstallExpiry.expirationDate(profileAt: URL(fileURLWithPath: "/nonexistent/embedded.mobileprovision")) == nil)
        let empty = try tempFile(Data())
        let corrupt = try tempFile(Data((0..<512).map { UInt8($0 % 251) }))
        defer {
            try? FileManager.default.removeItem(at: empty)
            try? FileManager.default.removeItem(at: corrupt)
        }
        #expect(InstallExpiry.expirationDate(profileAt: empty) == nil)
        #expect(InstallExpiry.expirationDate(profileAt: corrupt) == nil)
    }

    @Test func bundleWithoutProfileGivesNil() {
        // Like the simulator, TestFlight and the App Store: no embedded.mobileprovision.
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("noprofile-\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        let bundle = Bundle(url: dir) ?? .main
        if bundle != .main { #expect(InstallExpiry.profileExpiry(in: bundle) == nil) }
    }

    // MARK: decision (AC-2)

    @Test func threeDaysLeftIsHidden() {
        let now = date("2026-11-18T12:00:00Z")
        #expect(!InstallExpiry.shouldShowBanner(now: now, expiry: now.addingTimeInterval(72 * 3600), lastDismissedDay: nil, calendar: utc))
    }

    @Test func boundaryAt48Hours() {
        let now = date("2026-11-19T12:00:00Z")
        #expect(InstallExpiry.shouldShowBanner(now: now, expiry: now.addingTimeInterval(48 * 3600), lastDismissedDay: nil, calendar: utc))
        #expect(!InstallExpiry.shouldShowBanner(now: now, expiry: now.addingTimeInterval(48 * 3600 + 1), lastDismissedDay: nil, calendar: utc))
        #expect(InstallExpiry.shouldShowBanner(now: now, expiry: now.addingTimeInterval(47 * 3600), lastDismissedDay: nil, calendar: utc))
    }

    @Test func lastDayAndExpiredAreShown() {
        let now = date("2026-11-19T12:00:00Z")
        #expect(InstallExpiry.shouldShowBanner(now: now, expiry: now.addingTimeInterval(3600), lastDismissedDay: nil, calendar: utc))
        #expect(InstallExpiry.shouldShowBanner(now: now, expiry: now, lastDismissedDay: nil, calendar: utc))
        #expect(InstallExpiry.shouldShowBanner(now: now, expiry: now.addingTimeInterval(-5 * 86400), lastDismissedDay: nil, calendar: utc))
    }

    @Test func unknownExpiryIsHidden() {
        #expect(!InstallExpiry.shouldShowBanner(now: Date(), expiry: nil, lastDismissedDay: nil, calendar: utc))
    }

    @Test func dismissedTodayHiddenYesterdayShown() {
        let now = date("2026-11-19T12:00:00Z")
        let expiry = now.addingTimeInterval(3600)
        #expect(!InstallExpiry.shouldShowBanner(now: now, expiry: expiry, lastDismissedDay: "2026-11-19", calendar: utc))
        #expect(InstallExpiry.shouldShowBanner(now: now, expiry: expiry, lastDismissedDay: "2026-11-18", calendar: utc))
        // Still daily after expiry.
        let later = date("2026-11-22T09:00:00Z")
        #expect(!InstallExpiry.shouldShowBanner(now: later, expiry: expiry, lastDismissedDay: "2026-11-22", calendar: utc))
        #expect(InstallExpiry.shouldShowBanner(now: later, expiry: expiry, lastDismissedDay: "2026-11-21", calendar: utc))
    }

    @Test func midnightInLocalTimeZoneRollsTheDay() {
        let tokyo = calendar("Asia/Tokyo")
        let expiry = date("2026-11-20T00:00:00Z")
        // 23:30 Tokyo on the 19th = 14:30Z; 00:30 Tokyo on the 20th = 15:30Z (still the 19th in UTC).
        let before = date("2026-11-19T14:30:00Z")
        let after = date("2026-11-19T15:30:00Z")
        let stamp = InstallExpiry.dayStamp(for: before, calendar: tokyo)
        #expect(stamp == "2026-11-19")
        #expect(!InstallExpiry.shouldShowBanner(now: before, expiry: expiry, lastDismissedDay: stamp, calendar: tokyo))
        #expect(InstallExpiry.shouldShowBanner(now: after, expiry: expiry, lastDismissedDay: stamp, calendar: tokyo))
    }

    @Test func dstFallBackRepeatedHourIsStillOneDay() {
        let ny = calendar("America/New_York")
        let expiry = date("2026-11-01T00:00:00Z")
        let first = date("2026-11-01T05:30:00Z")   // 01:30 EDT
        let second = date("2026-11-01T06:30:00Z")  // 01:30 EST, same local day
        let nextDay = date("2026-11-02T05:00:00Z") // 00:00 EST on the 2nd
        let stamp = InstallExpiry.dayStamp(for: first, calendar: ny)
        #expect(stamp == "2026-11-01")
        #expect(!InstallExpiry.shouldShowBanner(now: second, expiry: expiry, lastDismissedDay: stamp, calendar: ny))
        #expect(InstallExpiry.shouldShowBanner(now: nextDay, expiry: expiry, lastDismissedDay: stamp, calendar: ny))
    }

    @Test func the48HourWindowIsAbsoluteAcrossDST() {
        // Spring forward 2026-03-08 in New York: 48 real hours, not 2 calendar days.
        let ny = calendar("America/New_York")
        let expiry = date("2026-03-09T20:00:00Z")
        let edge = expiry.addingTimeInterval(-48 * 3600)
        #expect(InstallExpiry.shouldShowBanner(now: edge, expiry: expiry, lastDismissedDay: nil, calendar: ny))
        #expect(!InstallExpiry.shouldShowBanner(now: edge.addingTimeInterval(-1), expiry: expiry, lastDismissedDay: nil, calendar: ny))
    }

    // MARK: store

    private func freshDefaults() -> UserDefaults {
        let name = "InstallExpiryTests-\(UUID().uuidString)"
        let d = UserDefaults(suiteName: name)!
        d.removePersistentDomain(forName: name)
        return d
    }

    @Test func storeRecordsDismissalAndPersists() {
        let defaults = freshDefaults()
        let now = date("2026-11-19T12:00:00Z")
        let expiry = now.addingTimeInterval(3600)
        let store = ExpiryReminderStore(defaults: defaults)
        #expect(store.lastDismissedDay == nil)
        #expect(store.shouldShowBanner(now: now, expiry: expiry, calendar: utc))
        store.recordDismissal(now: now, calendar: utc)
        #expect(!store.shouldShowBanner(now: now, expiry: expiry, calendar: utc))
        // A new store on the same defaults (a relaunch) still remembers.
        #expect(!ExpiryReminderStore(defaults: defaults).shouldShowBanner(now: now, expiry: expiry, calendar: utc))
        #expect(ExpiryReminderStore(defaults: defaults).shouldShowBanner(now: now.addingTimeInterval(86400), expiry: expiry, calendar: utc))
        store.recordDismissal(now: now, calendar: utc)   // a repeated call is harmless
        #expect(store.lastDismissedDay == "2026-11-19")
    }

    // MARK: override

    @Test func overrideArgumentParsing() {
        let expected = date("2026-11-20T10:00:00Z")
        #expect(InstallExpiry.overrideDate(in: ["app", "-uiTesting", "-uiTestingExpiry", "2026-11-20T10:00:00Z"]) == expected)
        #expect(InstallExpiry.overrideDate(in: ["-uiTestingExpiry", "2026-11-20T10:00:00.000Z"]) == expected)
        #expect(InstallExpiry.overrideDate(in: ["-uiTesting"]) == nil)
        #expect(InstallExpiry.overrideDate(in: ["-uiTestingExpiry"]) == nil)
        #expect(InstallExpiry.overrideDate(in: ["-uiTestingExpiry", "tomorrow"]) == nil)
    }

    #if DEBUG
    @Test func currentExpiryUsesOverrideInDebug() {
        let args = ["-uiTestingExpiry", "2026-11-20T10:00:00Z"]
        #expect(InstallExpiry.currentExpiry(arguments: args) == date("2026-11-20T10:00:00Z"))
    }
    #endif

    // MARK: strings

    @Test func bannerAndSettingsText() {
        let zone = TimeZone(identifier: "Europe/London")!
        let expiry = date("2026-11-21T14:02:00Z")
        let now = date("2026-11-20T14:02:00Z")
        #expect(InstallExpiry.bannerText(expiry: expiry, now: now, timeZone: zone)
                == "Clip Deck stops opening on Sat 21 Nov at 14:02. Open SideStore and tap Refresh All.")
        #expect(InstallExpiry.bannerText(expiry: expiry, now: expiry.addingTimeInterval(60), timeZone: zone)
                == "Clip Deck's signing ran out on Sat 21 Nov at 14:02. Open SideStore and tap Refresh All.")
        #expect(InstallExpiry.settingsText(expiry: expiry, timeZone: zone) == "This install expires: Sat 21 Nov 2026 at 14:02")
    }

    @Test func sideStoreURL() {
        #expect(InstallExpiry.sideStoreURL.absoluteString == "sidestore://")
    }
}
