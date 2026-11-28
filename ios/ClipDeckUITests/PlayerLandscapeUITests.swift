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
        let showTile = UITestSupport.launchSeeded(app)
        showTile.tap()
        let episodeRow = app.buttons["episode.row.Episode 1"]
        XCTAssertTrue(episodeRow.waitForExistence(timeout: 5))
        episodeRow.tap()

        UITestSupport.rotateToLandscape(app)

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
        let showTile = UITestSupport.launchSeeded(app)
        showTile.tap()
        let episodeRow = app.buttons["episode.row.Episode 1"]
        XCTAssertTrue(episodeRow.waitForExistence(timeout: 5))
        episodeRow.tap()
        UITestSupport.rotateToLandscape(app)

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
        XCTAssertTrue(app.buttons["card.save"].waitForExistence(timeout: 60), "Card editor opens from the panel")
        attachScreenshot(app, "landscape-04-panel-card")
    }

    /// T-011: the divider handle resizes the panel, the width is remembered, and a double-tap resets it.
    @MainActor
    func testPanelHandleResizesRemembersAndResets() throws {
        var app = launchWithPanelOpen()
        var handle = app.descendants(matching: .any)["player.panelHandle"]
        var panel = app.descendants(matching: .any)["player.sidePanel"]
        XCTAssertTrue(handle.waitForExistence(timeout: 5), "Panel has a drag handle")
        XCTAssertGreaterThanOrEqual(handle.frame.width, 44, "Handle touch area is at least 44 pt wide")
        let window = app.windows.firstMatch.frame

        // Start from the default (an earlier run may have left another width).
        handle.doubleTap()
        waitUntilSettled(panel)
        let defaultWidth = panel.frame.width
        // AC-5 (tester): VoiceOver names the handle and reads the width as a percentage.
        XCTAssertEqual(handle.label, "Subtitle panel width", "VoiceOver names the handle")
        XCTAssertEqual(handle.value as? String, "25 percent", "VoiceOver reads the width as a percentage")

        // Drag 120 pt to the left: the panel grows and the video shrinks.
        drag(handle, dx: -120)
        waitUntilSettled(panel)
        let widerWidth = panel.frame.width
        XCTAssertGreaterThan(widerWidth, defaultWidth + 60, "Dragging left widens the panel")
        let video = app.descendants(matching: .any)["player.video"]
        XCTAssertEqual(video.frame.width + widerWidth, window.width, accuracy: window.width * 0.02,
                       "Video and panel still fill the window")
        XCTAssertEqual(video.frame.minX, 0, accuracy: 1, "Video stays on the left")
        attachFrames(app, panel: panel, name: "landscape-05-panel-resized")

        // The width is remembered across a relaunch.
        app.terminate()
        app = launchWithPanelOpen(keepWidth: true)
        panel = app.descendants(matching: .any)["player.sidePanel"]
        handle = app.descendants(matching: .any)["player.panelHandle"]
        waitUntilSettled(panel)
        XCTAssertEqual(panel.frame.width, widerWidth, accuracy: 4, "Panel width survives a relaunch")

        // Drag far to the right: it stops at the 180 pt minimum (plus the trailing inset).
        XCTAssertTrue(handle.waitForExistence(timeout: 5))
        drag(handle, dx: window.width - handle.frame.midX - 2)
        waitUntilSettled(panel)
        XCTAssertLessThan(panel.frame.width, defaultWidth, "Dragging right narrows the panel")
        let back = app.buttons["player.back"]
        if !back.exists { tapVideo(app) }
        XCTAssertTrue(back.waitForExistence(timeout: 5))
        let inset = back.frame.minX - 12
        XCTAssertGreaterThanOrEqual(panel.frame.width - inset, 178, "Panel content never drops below 180 pt")
        XCTAssertEqual(panel.frame.width - inset, 180, accuracy: 4, "Panel stops at the minimum")

        // AC-2 (tester): drag far to the left: it stops at 50% of the usable width.
        let usable = window.width - 2 * inset
        drag(handle, dx: 2 - handle.frame.midX)
        waitUntilSettled(panel)
        XCTAssertEqual((panel.frame.width - inset) / usable, 0.5, accuracy: 0.02, "Panel stops at 50% of the usable width")
        XCTAssertEqual(handle.value as? String, "50 percent", "VoiceOver value follows the width")
        XCTAssertEqual(app.descendants(matching: .any)["player.video"].frame.minX, 0, accuracy: 1,
                       "Video stays on the left at the maximum")
        // Round 4: the bars can't widen or shift the video column, so the back button keeps its place inside the
        // leading safe area (12 pt of bar padding past the inset).
        XCTAssertTrue(back.waitForExistence(timeout: 5), "Controls are up at the maximum")
        XCTAssertEqual(back.frame.minX, inset + 12, accuracy: 1, "Back button stays inside the safe area at the maximum")
        // Tester: with the least room for the bars, the panel toggle and the bar's Make a Card stay clear of the
        // handle's touch area (which reaches 32 pt over the video).
        let barToggle = app.buttons["player.panelToggle"]
        let barMakeCard = app.buttons["player.makeCard"]
        XCTAssertTrue(barToggle.waitForExistence(timeout: 5), "Controls are still up at the maximum")
        XCTAssertTrue(barMakeCard.waitForExistence(timeout: 5), "Bar has Make a Card at the maximum")
        attachFrames(app, panel: panel, name: "landscape-05-panel-max")
        XCTAssertLessThanOrEqual(barToggle.frame.maxX, handle.frame.minX, "Panel toggle is clear of the handle")
        XCTAssertLessThanOrEqual(barMakeCard.frame.maxX, handle.frame.minX, "Bar Make a Card is clear of the handle")

        // Double-tap goes back to 25% of the usable width (leaves the default for other tests).
        handle.doubleTap()
        waitUntilSettled(panel)
        XCTAssertEqual((panel.frame.width - inset) / usable, 0.25, accuracy: 0.02, "Double-tap resets to 25%")
        XCTAssertEqual(panel.frame.width, defaultWidth, accuracy: 2, "Back to the default width")
    }

    /// T-011: the handle's touch area sits over the video, so a tap near the left edge of a cue row still seeks.
    @MainActor
    func testCueRowEdgeTapSeeksWithHandlePresent() throws {
        let app = launchWithPanelOpen()
        let row = app.descendants(matching: .any)["cue.row.1"]
        XCTAssertTrue(row.waitForExistence(timeout: 5), "Panel lists the subtitle lines")
        XCTAssertTrue(app.descendants(matching: .any)["player.panelHandle"].exists)
        let tapPoint = row.coordinate(withNormalizedOffset: .zero).withOffset(CGVector(dx: 16, dy: row.frame.height / 2))
        tapPoint.tap()
        XCTAssertTrue(app.textViews["player.subtitle"].waitForExistence(timeout: 5),
                      "A tap 16 pt from the row's leading edge seeks and shows the line")
    }

    /// T-011: the handle's touch area covers the video's rightmost 32 pt, so a single tap there still shows or
    /// hides the controls (after the double-tap window), and it does not resize the panel.
    @MainActor
    func testHandleSingleTapTogglesControls() throws {
        let app = launchWithPanelOpen()
        let handle = app.descendants(matching: .any)["player.panelHandle"]
        let panel = app.descendants(matching: .any)["player.sidePanel"]
        XCTAssertTrue(handle.waitForExistence(timeout: 5), "Panel has a drag handle")
        waitUntilSettled(panel)
        let width = panel.frame.width
        let back = app.buttons["player.back"]
        XCTAssertTrue(back.waitForExistence(timeout: 5), "Paused: the controls are up before the tap")

        // Normalized x 0.25 is 11 pt into the 44 pt area: over the video, clear of the cue rows.
        let strip = handle.coordinate(withNormalizedOffset: CGVector(dx: 0.25, dy: 0.5))
        strip.tap()
        XCTAssertTrue(back.waitForNonExistence(timeout: 3), "A single tap on the handle hides the controls")
        // Let the double-tap window pass, so the next tap is read as a new single tap.
        RunLoop.current.run(until: Date().addingTimeInterval(0.6))
        strip.tap()
        XCTAssertTrue(back.waitForExistence(timeout: 3), "Another single tap on the handle shows them again")
        waitUntilSettled(panel)
        XCTAssertEqual(panel.frame.width, width, accuracy: 1, "A single tap does not resize the panel")
    }

    /// Brent (T-011 fix round 4): opening the player with the phone already in landscape starts with the controls
    /// hidden, the same as rotating into landscape.
    @MainActor
    func testControlsStartHiddenWhenOpenedInLandscape() throws {
        let app = XCUIApplication()
        app.launchArguments += ["-uiTesting"]
        let showTile = UITestSupport.launchSeeded(app)
        XCUIDevice.shared.orientation = .landscapeLeft
        XCTAssertTrue(showTile.waitForExistence(timeout: 5), "Library still shows the show in landscape")
        showTile.tap()
        let episodeRow = app.buttons["episode.row.Episode 1"]
        XCTAssertTrue(episodeRow.waitForExistence(timeout: 5))
        episodeRow.tap()

        XCTAssertTrue(app.descendants(matching: .any)["player.video"].waitForExistence(timeout: 10))
        let back = app.buttons["player.back"]
        XCTAssertFalse(back.waitForExistence(timeout: 3), "Opened in landscape: the controls start hidden")
        XCTAssertFalse(app.buttons["player.makeCard"].exists, "Opened in landscape: no bottom bar either")
        tapVideo(app)
        XCTAssertTrue(back.waitForExistence(timeout: 5), "A tap on the video shows the controls")
    }

    @MainActor
    private func launchWithPanelOpen(keepWidth: Bool = false) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments += ["-uiTesting"]
        if keepWidth { app.launchArguments += ["-uiTestingKeepPanelWidth"] }
        let showTile = UITestSupport.launchSeeded(app)
        showTile.tap()
        let episodeRow = app.buttons["episode.row.Episode 1"]
        XCTAssertTrue(episodeRow.waitForExistence(timeout: 5))
        episodeRow.tap()
        // On the keep-width relaunch the device is already in landscape: then the rotation changes nothing and only
        // the stall check runs.
        UITestSupport.rotateToLandscape(app)
        XCTAssertTrue(app.descendants(matching: .any)["player.video"].waitForExistence(timeout: 10))
        let toggle = app.buttons["player.panelToggle"]
        // Brent (T-011 fix round 4): landscape always starts with the controls hidden, both after a rotation and
        // when the player opens with the device already in landscape (the relaunch step). Before that change the
        // paused video brought them up by itself on the relaunch (tester, CI 44661143691).
        XCTAssertFalse(toggle.waitForExistence(timeout: 2), "Landscape starts with the controls hidden")
        tapVideo(app)
        XCTAssertTrue(toggle.waitForExistence(timeout: 5), "Controls show the panel button")
        toggle.tap()
        XCTAssertTrue(app.descendants(matching: .any)["player.sidePanel"].waitForExistence(timeout: 5))
        return app
    }

    @MainActor
    private func drag(_ handle: XCUIElement, dx: CGFloat) {
        let start = handle.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        let end = start.withOffset(CGVector(dx: dx, dy: 0))
        start.press(forDuration: 0.1, thenDragTo: end)
    }

    /// Waits until the panel frame stops changing (the spring settles).
    @MainActor
    private func waitUntilSettled(_ element: XCUIElement) {
        var last = element.frame
        let deadline = Date().addingTimeInterval(5)
        while Date() < deadline {
            RunLoop.current.run(until: Date().addingTimeInterval(0.4))
            let now = element.frame
            if now == last { return }
            last = now
        }
    }

    @MainActor
    private func attachFrames(_ app: XCUIApplication, panel: XCUIElement, name: String) {
        let frames = XCTAttachment(string: "panel \(panel.frame)\n\n\(app.debugDescription)")
        frames.name = name + "-frames"
        frames.lifetime = .keepAlways
        add(frames)
        let shot = XCTAttachment(screenshot: panel.screenshot())
        shot.name = name
        shot.lifetime = .keepAlways
        add(shot)
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
