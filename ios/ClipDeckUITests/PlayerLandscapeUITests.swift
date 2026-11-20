import XCTest

/// Landscape player: the video fills the screen; a tap on it brings the controls up, another tap hides them.
final class PlayerLandscapeUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    override func tearDown() async throws {
        await MainActor.run { XCUIDevice.shared.orientation = .portrait }
        try await super.tearDown()
    }

    @MainActor
    func testControlsAppearOnTapInLandscape() throws {
        let app = XCUIApplication()
        app.launchArguments += ["-uiTesting"]
        app.launch()

        let showTile = app.buttons["library.show.Sample Show"]
        XCTAssertTrue(showTile.waitForExistence(timeout: 30), "Seeded show should appear")
        showTile.tap()
        let episodeRow = app.buttons["episode.row.Episode 1"]
        XCTAssertTrue(episodeRow.waitForExistence(timeout: 5))
        episodeRow.tap()

        XCUIDevice.shared.orientation = .landscapeLeft

        // Fullscreen: the video is there, the controls are not.
        XCTAssertTrue(app.descendants(matching: .any)["player.video"].waitForExistence(timeout: 10))
        // Screenshot before the hidden-controls asserts, so a failure still leaves visual evidence.
        attachScreenshot(app, "landscape-01-fullscreen")
        XCTAssertTrue(app.buttons["player.back"].waitForNonExistence(timeout: 5), "Controls start hidden")
        XCTAssertFalse(app.buttons["player.makeCard"].exists)

        // Tap the video (upper middle, clear of the subtitle and the bars): controls appear.
        tapVideo(app)
        XCTAssertTrue(app.buttons["player.back"].waitForExistence(timeout: 5), "Tap shows the top bar")
        XCTAssertTrue(app.buttons["player.makeCard"].waitForExistence(timeout: 5), "Tap shows the bottom bar")
        attachScreenshot(app, "landscape-02-controls")

        // Tap again: they go away (the sample is paused, so nothing else hides them).
        tapVideo(app)
        XCTAssertTrue(app.buttons["player.back"].waitForNonExistence(timeout: 5), "Second tap hides the top bar")
        XCTAssertTrue(app.buttons["player.makeCard"].waitForNonExistence(timeout: 5), "Second tap hides the bottom bar")
    }

    /// T-002 AC-6: the panel button splits the screen 75 / 25; the list, tap-to-seek and the panel's Make a Card work.
    @MainActor
    func testSubtitlePanelOpensOnTheRight() throws {
        let app = XCUIApplication()
        app.launchArguments += ["-uiTesting"]
        app.launch()
        let showTile = app.buttons["library.show.Sample Show"]
        XCTAssertTrue(showTile.waitForExistence(timeout: 30), "Seeded show should appear")
        showTile.tap()
        let episodeRow = app.buttons["episode.row.Episode 1"]
        XCTAssertTrue(episodeRow.waitForExistence(timeout: 5))
        episodeRow.tap()
        XCUIDevice.shared.orientation = .landscapeLeft

        let video = app.descendants(matching: .any)["player.video"]
        XCTAssertTrue(video.waitForExistence(timeout: 10))
        tapVideo(app)
        let toggle = app.buttons["player.panelToggle"]
        XCTAssertTrue(toggle.waitForExistence(timeout: 5), "Controls show the panel button")
        // The top bar pads Spacing.m (12 pt) inside the leading safe-area inset, so the back button gives the inset.
        let back = app.buttons["player.back"]
        XCTAssertTrue(back.waitForExistence(timeout: 5))
        let sideInset = back.frame.minX - 12
        toggle.tap()

        let panel = app.descendants(matching: .any)["player.sidePanel"]
        XCTAssertTrue(panel.waitForExistence(timeout: 5), "Panel slides in")
        // Let the 0.3 s spring settle (the panel stops growing), then measure what the screen shows.
        let window = app.windows.firstMatch.frame
        let deadline = Date().addingTimeInterval(5)
        while panel.frame.width < window.width * 0.2, Date() < deadline {
            RunLoop.current.run(until: Date().addingTimeInterval(0.1))
        }
        RunLoop.current.run(until: Date().addingTimeInterval(0.5))
        // Panel content is max(25% of the usable width, 180 pt) plus the trailing inset, so the panel is at
        // least 180 pt and the video and panel together fill the window.
        XCTAssertGreaterThanOrEqual(panel.frame.width, 180, "Panel is at least 180 pt")
        XCTAssertLessThanOrEqual(panel.frame.width, window.width * 0.35, "Panel stays a side panel")
        XCTAssertEqual(video.frame.width + panel.frame.width, window.width, accuracy: window.width * 0.02,
                       "Video and panel fill the window")
        XCTAssertGreaterThan(video.frame.width, window.width * 0.65, "Video keeps at least 65%")
        XCTAssertLessThan(video.frame.width, window.width * 0.75, "Video shrinks below 75%")

        let secondLine = app.descendants(matching: .any)["cue.row.1"]
        XCTAssertTrue(secondLine.waitForExistence(timeout: 5), "Panel lists the subtitle lines")

        // Brent's rule (T-002 fix round 2): panel = max(25% of the usable width, 180 pt) + the trailing inset.
        // iPhone landscape insets are symmetric, so usable = window - 2 * inset.
        let expectedPanel = max((window.width - 2 * sideInset) * 0.25, 180) + sideInset
        let frames = """
            window \(window)
            sideInset \(sideInset)
            expectedPanel \(expectedPanel)
            panel \(panel.frame)
            video \(video.frame)
            cue.row.1 \(secondLine.frame)
            panel.makeCard \(app.buttons["player.panel.makeCard"].frame)

            \(app.debugDescription)
            """
        let framesAttachment = XCTAttachment(string: frames)
        framesAttachment.name = "landscape-03-panel-frames"
        framesAttachment.lifetime = .keepAlways
        add(framesAttachment)
        let panelShot = XCTAttachment(screenshot: panel.screenshot())
        panelShot.name = "landscape-03-panel-element"
        panelShot.lifetime = .keepAlways
        add(panelShot)
        XCTAssertGreaterThan(sideInset, 0, "Notched iPhone in landscape has a side inset")
        XCTAssertEqual(panel.frame.width, expectedPanel, accuracy: 2,
                       "Panel content is max(25% of the usable width, 180) plus the trailing inset")
        // Readability: compact rows leave the line text the row width minus 24 pt of padding.
        XCTAssertGreaterThanOrEqual(secondLine.frame.width, 144, "Cue rows leave the text at least ~120 pt")
        secondLine.tap()
        XCTAssertTrue(app.textViews["player.subtitle"].waitForExistence(timeout: 5), "Tapping a line seeks and shows it")
        attachScreenshot(app, "landscape-03-panel")

        let panelMakeCard = app.buttons["player.panel.makeCard"]
        XCTAssertTrue(panelMakeCard.waitForExistence(timeout: 5), "Panel has its own Make a Card")
        panelMakeCard.tap()
        XCTAssertTrue(app.buttons["card.save"].waitForExistence(timeout: 20), "Card editor opens from the panel")
        attachScreenshot(app, "landscape-04-panel-card")
    }

    @MainActor
    private func tapVideo(_ app: XCUIApplication) {
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.35)).tap()
    }

    @MainActor
    private func attachScreenshot(_ app: XCUIApplication, _ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
