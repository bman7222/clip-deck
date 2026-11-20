import XCTest

/// The install-expiry reminder (T-008). `-uiTestingExpiry <ISO date>` overrides the profile's expiry (Debug).
final class ExpiryBannerUITests: XCTestCase {
    private func iso(daysAhead: Double) -> String {
        ISO8601DateFormatter().string(from: Date().addingTimeInterval(daysAhead * 86_400))
    }

    // loop-tester (T-008 r1): RootView shows "Preparing sample episode…" until the sample is seeded, which took
    // about 17 s on CI (run 44788627149), so 10 s was too short. MiningFlowUITests waits 30 s for the same seed.
    @MainActor
    private func launch(daysAhead: Double, extra: [String] = []) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments += ["-uiTesting", "-uiTestingExpiry", iso(daysAhead: daysAhead)] + extra
        app.launch()
        XCTAssertTrue(app.navigationBars["Clip Deck"].waitForExistence(timeout: 60))
        return app
    }

    /// Settings is a lazy Form: rows below the fold are not in the accessibility tree until scrolled to.
    @MainActor
    private func scrollTo(_ element: XCUIElement, in app: XCUIApplication) {
        var tries = 0
        while !element.exists && tries < 12 {
            app.swipeUp()
            tries += 1
        }
    }

    @MainActor
    private func attach(_ app: XCUIApplication, _ name: String) {
        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = name
        shot.lifetime = .keepAlways
        add(shot)
    }

    @MainActor
    func testBannerShowsDismissesAndStaysHiddenToday() throws {
        var app = launch(daysAhead: 1)
        let banner = app.otherElements["library.expiryBanner"]
        XCTAssertTrue(banner.waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["library.expiryBanner.openSideStore"].exists)
        attach(app, "expiry-01-banner")

        let dismiss = app.buttons["library.expiryBanner.dismiss"]
        XCTAssertEqual(dismiss.label, "Dismiss until tomorrow")
        XCTAssertGreaterThanOrEqual(dismiss.frame.width, 44)
        XCTAssertGreaterThanOrEqual(dismiss.frame.height, 44)
        dismiss.tap()
        XCTAssertTrue(banner.waitForNonExistence(timeout: 5))
        XCTAssertTrue(app.buttons["library.sync"].exists)

        // Same day, new launch: the dismissal day survives (-uiTestingKeepExpiryDismissal), so no banner.
        app.terminate()
        app = launch(daysAhead: 1, extra: ["-uiTestingKeepExpiryDismissal"])
        XCTAssertFalse(app.otherElements["library.expiryBanner"].waitForExistence(timeout: 3))

        // loop-tester (T-008 r1): without the flag the "uiTesting" suite is cleared as before, so the banner is back.
        // This shows the hidden state above comes from the kept dismissal, and other UI tests still start clean.
        app.terminate()
        app = launch(daysAhead: 1)
        XCTAssertTrue(app.otherElements["library.expiryBanner"].waitForExistence(timeout: 5),
                      "a launch without -uiTestingKeepExpiryDismissal should start with no dismissal")
    }

    @MainActor
    func testFarExpiryShowsNoBannerAndSettingsShowsDate() throws {
        let app = launch(daysAhead: 10)
        XCTAssertFalse(app.otherElements["library.expiryBanner"].waitForExistence(timeout: 3))

        app.buttons["library.settings"].tap()
        XCTAssertTrue(app.navigationBars["Anki settings"].waitForExistence(timeout: 5))
        let line = app.descendants(matching: .any)["settings.expiry"]
        scrollTo(line, in: app)
        XCTAssertTrue(line.waitForExistence(timeout: 5), "Anki settings shows the install expiry line")
        XCTAssertTrue(line.label.hasPrefix("This install expires:"), line.label)
    }

    @MainActor
    func testLargeTextBannerWrapsWithoutCoveringSyncOrUpload() throws {
        let app = XCUIApplication()
        app.launchArguments += ["-uiTesting", "-uiTestingExpiry", iso(daysAhead: 1),
                                "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityL"]
        app.launch()
        let banner = app.otherElements["library.expiryBanner"]
        XCTAssertTrue(banner.waitForExistence(timeout: 60))
        attach(app, "expiry-02-large-text")

        let sync = app.buttons["library.sync"]
        let upload = app.buttons["library.upload"]
        XCTAssertTrue(sync.exists && upload.exists)
        XCTAssertFalse(banner.frame.intersects(sync.frame), "banner covers Sync")
        XCTAssertFalse(banner.frame.intersects(upload.frame), "banner covers Upload")
        XCTAssertTrue(sync.isHittable && upload.isHittable)
        XCTAssertTrue(app.buttons["library.expiryBanner.dismiss"].isHittable)
    }

    // Added by loop-tester (T-008 round 1): AC-3 swipe dismissal, with a short drag that must not dismiss.
    @MainActor
    func testHorizontalSwipeDismissesButShortDragDoesNot() throws {
        let app = launch(daysAhead: 1)
        let banner = app.otherElements["library.expiryBanner"]
        XCTAssertTrue(banner.waitForExistence(timeout: 5))

        // About 36 pt: below the 80 pt threshold, so the banner springs back and stays.
        banner.coordinate(withNormalizedOffset: CGVector(dx: 0.6, dy: 0.15))
            .press(forDuration: 0.05, thenDragTo: banner.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.15)))
        XCTAssertFalse(banner.waitForNonExistence(timeout: 2), "a short drag dismissed the banner")

        // About 200 pt to the left: dismisses.
        banner.coordinate(withNormalizedOffset: CGVector(dx: 0.6, dy: 0.15))
            .press(forDuration: 0.05, thenDragTo: banner.coordinate(withNormalizedOffset: CGVector(dx: 0.02, dy: 0.15)))
        XCTAssertTrue(banner.waitForNonExistence(timeout: 5), "a horizontal swipe did not dismiss the banner")
        XCTAssertTrue(app.buttons["library.sync"].isHittable)
    }

    // Added by loop-tester (T-008 round 1): AC-4 false path. The simulator has no SideStore, so openURL returns false.
    @MainActor
    func testOpenSideStoreWithoutSideStoreKeepsBannerAndExplains() throws {
        let app = launch(daysAhead: 1)
        let banner = app.otherElements["library.expiryBanner"]
        XCTAssertTrue(banner.waitForExistence(timeout: 5))
        app.buttons["library.expiryBanner.openSideStore"].tap()

        XCTAssertTrue(app.staticTexts["library.expiryBanner.openError"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.state, .runningForeground)
        XCTAssertTrue(banner.exists)
        let text = app.staticTexts["library.expiryBanner.text"]
        XCTAssertTrue(text.label.hasPrefix("Clip Deck stops opening on"), text.label)
        XCTAssertTrue(text.label.hasSuffix("Open SideStore and tap Refresh All."), text.label)
        attach(app, "expiry-03-open-failed")
    }
}
