import XCTest

final class AboutUITests: XCTestCase {
    @MainActor
    func testAboutShowsLicences() throws {
        let app = XCUIApplication()
        app.launchArguments += ["-uiTesting", "-uiTestingNoSeed"]
        openAbout(app)

        let appLicense = app.staticTexts["about.appLicense"]
        scrollTo(appLicense, in: app)
        XCTAssertTrue(UITestSupport.wait(timeout: 10) { appLicense.exists })
        XCTAssertTrue(appLicense.label.contains("All rights reserved"), "Clip Deck licence text is shown")

        let lgpl = app.staticTexts["about.lgpl"]
        scrollTo(lgpl, in: app)
        XCTAssertTrue(UITestSupport.wait(timeout: 10) { lgpl.exists })
        XCTAssertTrue(lgpl.label.contains("GNU LESSER GENERAL PUBLIC LICENSE"), "LGPL text is shown")

        scrollTo(app.links["about.ffmpegSource"], in: app, upward: false)
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "about-01-licences"
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    /// AC-7 (added by loop-tester): both source links are on screen, carry their versions, and open Safari when tapped.
    /// Queried by identifier with any element type, so the test does not depend on whether a List row exposes a Link
    /// as a link or a button (the type is recorded in the about-02-links-tree attachment).
    @MainActor
    func testSourceLinksAreShownAndOpenInSafari() throws {
        let app = XCUIApplication()
        app.launchArguments += ["-uiTesting", "-uiTestingNoSeed"]
        openAbout(app)

        let ffmpeg = app.descendants(matching: .any).matching(identifier: "about.ffmpegSource").firstMatch
        let build = app.descendants(matching: .any).matching(identifier: "about.ffmpegBuildSource").firstMatch
        var tries = 0
        while !(ffmpeg.exists && ffmpeg.isHittable && build.exists && build.isHittable) && tries < 20 {
            app.swipeUp(velocity: .slow)
            tries += 1
        }
        attach(text: app.debugDescription, name: "about-02-links-tree")
        attach(screenshot: app.screenshot(), name: "about-02-links")
        XCTAssertTrue(ffmpeg.exists && ffmpeg.isHittable, "FFmpeg source link is on screen")
        XCTAssertTrue(build.exists && build.isHittable, "FFmpegBuild source link is on screen")
        XCTAssertTrue(ffmpeg.label.contains("n8.1.3"), "FFmpeg link label: \(ffmpeg.label)")
        XCTAssertTrue(build.label.contains("3.16.0"), "FFmpegBuild link label: \(build.label)")

        // T-034: Safari can be slow to launch on a CI simulator. Wait for it generously; a lost tap leaves Clip Deck in the
        // foreground and Safari not running, and is tapped again.
        let safari = XCUIApplication(bundleIdentifier: "com.apple.mobilesafari")
        openInSafari(ffmpeg, safari: safari, app: app)
        XCTAssertTrue(safari.wait(for: .runningForeground, timeout: 60), "FFmpeg source link opens Safari")
        attach(text: safari.debugDescription, name: "about-03-safari-ffmpeg-tree")
        attach(screenshot: safari.screenshot(), name: "about-03-safari-ffmpeg")

        app.activate()
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 30))
        XCTAssertTrue(UITestSupport.wait(timeout: 15) { build.exists && build.isHittable }, "About screen is still open after returning")
        openInSafari(build, safari: safari, app: app)
        XCTAssertTrue(safari.wait(for: .runningForeground, timeout: 60), "FFmpegBuild source link opens Safari")
        attach(text: safari.debugDescription, name: "about-04-safari-ffmpegbuild-tree")
        attach(screenshot: safari.screenshot(), name: "about-04-safari-ffmpegbuild")
        safari.terminate()
    }

    /// Added by loop-tester (T-012 round 2): the About screen shows the real app version (0.1.0 from MARKETING_VERSION,
    /// not XcodeGen's default 1.0), the FFmpeg copyright line, and the non-ASCII characters of Other-Components.txt
    /// (©, ñ, í) decoded as UTF-8, with no replacement characters or mojibake.
    @MainActor
    func testAboutShowsVersionAndNoticeTextIntact() throws {
        let app = XCUIApplication()
        app.launchArguments += ["-uiTesting", "-uiTestingNoSeed"]
        openAbout(app)

        // Versions section is at the top. On iOS 26 the LabeledContent row is one StaticText labelled
        // "Clip Deck, 0.1.0" (CI run 44679269822, about-05-versions-tree).
        let versionRow = app.staticTexts.matching(NSPredicate(format: "label == %@", "Clip Deck, 0.1.0")).firstMatch
        let versionValue = app.staticTexts.matching(NSPredicate(format: "label == %@", "0.1.0")).firstMatch
        attach(text: app.debugDescription, name: "about-05-versions-tree")
        attach(screenshot: app.screenshot(), name: "about-05-versions")
        XCTAssertTrue(UITestSupport.wait(timeout: 15) { versionRow.exists || versionValue.exists }, "About shows app version 0.1.0")
        XCTAssertFalse(app.staticTexts.matching(NSPredicate(format: "label == %@ OR label == %@", "1.0", "Clip Deck, 1.0"))
                        .firstMatch.exists, "About no longer shows XcodeGen's default 1.0")

        let notice = app.staticTexts["about.ffmpegNotice"]
        scrollTo(notice, in: app)
        XCTAssertTrue(UITestSupport.wait(timeout: 10) { notice.exists })
        XCTAssertTrue(notice.label.contains("Copyright (c) 2000-2026 the FFmpeg developers"), "FFmpeg copyright line is shown")

        let other = app.staticTexts["about.otherComponents"]
        var tries = 0
        while !(other.exists && other.isHittable) && tries < 60 {
            app.swipeUp(velocity: .fast)
            tries += 1
        }
        XCTAssertTrue(UITestSupport.wait(timeout: 10) { other.exists }, "Other components text is shown")
        let text = other.label
        attach(text: text, name: "about-06-other-components-label")
        // A screenshot of the whole (very tall) Text element fails to render on CI, so take the screen instead.
        attach(screenshot: app.screenshot(), name: "about-06-other-components")
        XCTAssertTrue(text.contains("Copyright © 2018-2025, VideoLAN and dav1d authors"), "dav1d line with ©")
        XCTAssertTrue(text.contains("Iñaki G. Etxebarria"), "libzvbi line with ñ")
        XCTAssertTrue(text.contains("Iñaki García Etxebarrria"), "ure.c notice with ñ and í")
        XCTAssertFalse(text.contains("\u{FFFD}"), "no replacement characters")
        XCTAssertFalse(text.contains("Ã") || text.contains("Â"), "no UTF-8 read as Latin-1")
    }

    /// Launches (no seeded show), opens Settings, then "About and licences". The waits are generous because a slow CI VM
    /// needed 19.8 s for one launch and 11.6 s for one tap (45083671012); a lost tap is tapped again. This is the only
    /// launch: a second `app.launch()` in the test first terminates the instance just started (T-034 S1).
    @MainActor
    private func openAbout(_ app: XCUIApplication) {
        app.launch()
        let settings = app.buttons["library.settings"]
        XCTAssertTrue(settings.waitForExistence(timeout: 45), "The library's Settings button appears")
        let row = app.buttons["settings.about"]
        let settingsBar = app.navigationBars["Anki settings"]
        UITestSupport.tap(settings, patience: 10) { settingsBar.exists }
        scrollTo(row, in: app)
        XCTAssertTrue(UITestSupport.wait(timeout: 10) { row.exists }, "Settings has an About and licences row")
        let bar = app.navigationBars["About and licences"]
        UITestSupport.tap(row, patience: 10) { bar.exists }
        XCTAssertTrue(bar.waitForExistence(timeout: 20), "About and licences opens")
    }

    /// Taps a link and waits for Safari to come to the front. If Clip Deck is still in front after the wait, the tap
    /// was lost and the link is tapped again; once Clip Deck is in the background, Safari is only slow, so it just waits.
    @MainActor
    private func openInSafari(_ link: XCUIElement, safari: XCUIApplication, app: XCUIApplication) {
        UITestSupport.tap(link, attempts: 3, patience: 15) {
            safari.state == .runningForeground || app.state != .runningForeground
        }
    }

    @MainActor
    private func attach(screenshot: XCUIScreenshot, name: String) {
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    @MainActor
    private func attach(text: String, name: String) {
        let attachment = XCTAttachment(string: text)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    @MainActor
    private func scrollTo(_ element: XCUIElement, in app: XCUIApplication, upward: Bool = true) {
        var tries = 0
        while !element.exists && tries < 12 {
            if upward { app.swipeUp() } else { app.swipeDown() }
            tries += 1
        }
    }
}
