import XCTest

/// T-021: the centred playback overlay (back 5 s, play/pause, forward 5 s) and the bar without ±5 s, in both
/// orientations. Uses the seeded "Sample Show" with a 30-second video (`-uiTestingSampleSeconds 30`, so a slow
/// runner can't play it to its end), paused at 0:00.
///
/// Timing rules: wait on state (an element appearing, a value changing), never on a fixed sleep. The only fixed
/// waits are the ones that check "still there after 3 s" (a paused overlay), which can only be a wait.
final class PlaybackOverlayUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    override func tearDown() async throws {
        await MainActor.run { XCUIDevice.shared.orientation = .portrait }
        try await super.tearDown()
    }

    // MARK: Position

    @MainActor func testOverlayIsCentredPortrait() throws { try checkOverlayPosition(landscape: false) }
    @MainActor func testOverlayIsCentredLandscape() throws { try checkOverlayPosition(landscape: true) }

    /// The three centres sit at 25 %, 50 % and 75 % of the video's width and at its vertical centre.
    @MainActor
    private func checkOverlayPosition(landscape: Bool) throws {
        let app = openSample(landscape: landscape)
        showOverlay(app)
        let videoFrame = video(app).frame
        let expected: [(id: String, share: CGFloat, size: CGFloat)] = [
            ("player.overlay.back5", 0.25, 44),
            ("player.overlay.playPause", 0.5, 52),
            ("player.overlay.forward5", 0.75, 44),
        ]
        for item in expected {
            let frame = app.buttons[item.id].frame
            XCTAssertEqual(frame.midX, videoFrame.minX + videoFrame.width * item.share, accuracy: 2, "\(item.id) x")
            XCTAssertEqual(frame.midY, videoFrame.midY, accuracy: 2, "\(item.id) y")
            XCTAssertEqual(frame.width, item.size, accuracy: 2, "\(item.id) diameter")
        }
        let playPause = app.buttons["player.overlay.playPause"]
        XCTAssertEqual(playPause.label, "Play")
        XCTAssertEqual(playPause.value as? String, "Paused")
        XCTAssertEqual(app.buttons["player.overlay.back5"].label, "Back 5 seconds")
        XCTAssertEqual(app.buttons["player.overlay.forward5"].label, "Forward 5 seconds")
    }

    // MARK: Skips and play/pause

    @MainActor func testSkipsAndPlayPauseWorkPortrait() throws { try checkSkipsAndPlayPause(landscape: false) }
    @MainActor func testSkipsAndPlayPauseWorkLandscape() throws { try checkSkipsAndPlayPause(landscape: true) }

    /// Paused at 0:00: forward 5 s lands on about 0:05, back 5 s returns to about 0:00, and the overlay's
    /// play/pause starts and stops playback. (From 0:00 so that neither skip is clamped at the start of the clip.)
    @MainActor
    private func checkSkipsAndPlayPause(landscape: Bool) throws {
        let app = openSample(landscape: landscape)
        showOverlay(app)
        XCTAssertTrue(waitForElapsed(app, near: 0, timeout: 5), "Starts at 0:00 (\(elapsedText(app)))")

        app.buttons["player.overlay.forward5"].tap()
        XCTAssertTrue(waitForElapsed(app, near: 5, timeout: 5), "Forward 5 s moves to about 0:05 (\(elapsedText(app)))")
        app.buttons["player.overlay.back5"].tap()
        XCTAssertTrue(waitForElapsed(app, near: 0, timeout: 5), "Back 5 s returns to about 0:00 (\(elapsedText(app)))")

        let overlayPlay = app.buttons["player.overlay.playPause"]
        overlayPlay.tap()
        // Playing: the overlay hides 3 s after the tap, so read it right away (see `readValue`).
        XCTAssertEqual(readValue(app, id: "player.overlay.playPause", expecting: "Playing").value, "Playing",
                       "The overlay button starts playback")
        if !overlayPlay.exists { showOverlay(app) }
        overlayPlay.tap()
        XCTAssertTrue(waitForValue(overlayPlay, "Paused", timeout: 5), "The overlay button pauses playback")
    }

    // MARK: Timing

    @MainActor func testOverlayHidesWhilePlayingAndStaysWhilePausedPortrait() throws { try checkTiming(landscape: false) }
    @MainActor func testOverlayHidesWhilePlayingAndStaysWhilePausedLandscape() throws { try checkTiming(landscape: true) }

    /// Paused: the overlay stays past 3 s. Playing: it is gone about 3 s after playback starts. The check for
    /// "gone" starts right after the Play tap and returns as soon as the overlay is gone.
    @MainActor
    private func checkTiming(landscape: Bool) throws {
        let app = openSample(landscape: landscape)
        showOverlay(app)
        let overlayPlay = app.buttons["player.overlay.playPause"]
        XCTAssertFalse(overlayPlay.waitForNonExistence(timeout: 3.5), "Paused: the overlay stays past 3 s")

        let barPlay = app.buttons["player.playPause"]
        XCTAssertTrue(barPlay.waitForExistence(timeout: 5))
        barPlay.tap()
        XCTAssertTrue(
            overlayPlay.waitForNonExistence(timeout: 5),
            "Playing: the overlay hides on its own (bar value: \(barPlay.exists ? String(describing: barPlay.value) : "bar hidden"))")
    }

    // MARK: Bar

    @MainActor func testBarHasNoSkipButtonsPortrait() throws { try checkBarHasNoSkips(landscape: false) }
    @MainActor func testBarHasNoSkipButtonsLandscape() throws { try checkBarHasNoSkips(landscape: true) }

    /// Neither the landscape `player.bottomBar` nor the portrait controls hold a 5-second skip. The overlay is
    /// the only place with them, so with it shown there is exactly one of each in the whole screen.
    @MainActor
    private func checkBarHasNoSkips(landscape: Bool) throws {
        let app = openSample(landscape: landscape)
        let back = app.buttons.matching(NSPredicate(format: "label == %@", "Back 5 seconds"))
        let forward = app.buttons.matching(NSPredicate(format: "label == %@", "Forward 5 seconds"))
        if !landscape {
            // Portrait controls are always visible; the overlay starts hidden.
            XCTAssertTrue(app.buttons["player.playPause"].waitForExistence(timeout: 5))
            XCTAssertEqual(back.count, 0, "No Back 5 seconds in the portrait controls")
            XCTAssertEqual(forward.count, 0, "No Forward 5 seconds in the portrait controls")
        }
        showOverlay(app)
        XCTAssertEqual(back.count, 1, "Only the overlay has Back 5 seconds")
        XCTAssertEqual(forward.count, 1, "Only the overlay has Forward 5 seconds")
        if landscape {
            let bar = app.descendants(matching: .any)["player.bottomBar"]
            XCTAssertTrue(bar.waitForExistence(timeout: 5), "Landscape bottom bar is shown")
            XCTAssertTrue(bar.buttons["player.playPause"].exists, "The bar keeps its play/pause button")
            XCTAssertEqual(bar.buttons.matching(NSPredicate(format: "label CONTAINS %@", "5 seconds")).count, 0,
                           "No 5-second skip in the landscape bar")
        }
    }

    // MARK: Bar play/pause value

    @MainActor func testBarPlayPauseValuePortrait() throws { try checkBarValue(landscape: false) }
    @MainActor func testBarPlayPauseValueLandscape() throws { try checkBarValue(landscape: true) }

    /// `player.playPause` reads "Paused", then "Playing" after a tap. Its label stays "Play"/"Pause".
    @MainActor
    private func checkBarValue(landscape: Bool) throws {
        let app = openSample(landscape: landscape)
        if landscape { showOverlay(app) }
        let barPlay = app.buttons["player.playPause"]
        XCTAssertTrue(barPlay.waitForExistence(timeout: 5))
        XCTAssertEqual(barPlay.value as? String, "Paused")
        XCTAssertEqual(barPlay.label, "Play")
        barPlay.tap()
        // Landscape: the bar hides 3 s after playing starts, so read it right away, not through a 1 s wait.
        let state = readValue(app, id: "player.playPause", expecting: "Playing")
        XCTAssertEqual(state.value, "Playing", "After a tap the bar button reads Playing")
        XCTAssertEqual(state.label, "Pause")
    }

    /// Tester (T-021 round 3): the fallback in `readValue`, the path a slow runner takes when the Play tap's own
    /// wait outlasts the 3 s auto-hide. Playing in landscape, the bar hides on its own; `readValue` then has to
    /// bring the controls back with a video tap and find the bar still reading "Playing" with the label "Pause"
    /// (the 30 s clip is still playing).
    @MainActor
    func testBarValueIsReadAfterTheBarHidLandscape() throws {
        let app = openSample(landscape: true)
        showOverlay(app)
        let barPlay = app.buttons["player.playPause"]
        XCTAssertTrue(barPlay.waitForExistence(timeout: 5))
        barPlay.tap()
        XCTAssertTrue(barPlay.waitForNonExistence(timeout: 8), "Playing: the bar hides on its own")
        let state = readValue(app, id: "player.playPause", expecting: "Playing")
        XCTAssertEqual(state.value, "Playing", "A video tap brings the bar back, still playing")
        XCTAssertEqual(state.label, "Pause")
    }

    // MARK: Style card

    @MainActor func testOverlayGivesWayToTheStyleCardLandscape() throws {
        let app = openSample(landscape: true)
        showOverlay(app)
        let overlayPlay = app.buttons["player.overlay.playPause"]
        let styleButton = app.buttons["player.subtitleStyle"]
        XCTAssertTrue(styleButton.waitForExistence(timeout: 5))
        styleButton.tap()
        XCTAssertTrue(app.buttons["subtitleStyle.done"].waitForExistence(timeout: 5), "The style card opens")
        XCTAssertTrue(overlayPlay.waitForNonExistence(timeout: 5), "The overlay hides while the style card is open")
        XCTAssertFalse(app.buttons["player.overlay.back5"].exists)
        XCTAssertFalse(app.buttons["player.overlay.forward5"].exists)
        app.buttons["subtitleStyle.done"].tap()
        XCTAssertTrue(app.buttons["subtitleStyle.done"].waitForNonExistence(timeout: 5), "Done closes the card")
        XCTAssertTrue(overlayPlay.waitForExistence(timeout: 5), "The overlay comes back on Done")
    }

    // MARK: Rotation

    /// Rotating always starts with the overlay hidden.
    @MainActor
    func testRotationHidesTheOverlay() throws {
        let app = openSample(landscape: false)
        showOverlay(app)
        XCUIDevice.shared.orientation = .landscapeLeft
        XCTAssertTrue(video(app).waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons["player.overlay.playPause"].waitForNonExistence(timeout: 5),
                      "Rotating hides the overlay")
    }

    // MARK: Helpers

    @MainActor
    private func openSample(landscape: Bool) -> XCUIApplication {
        let app = XCUIApplication()
        // A 30 s clip, so a slow runner can't play it to its end (which pauses it and brings the overlay back)
        // while a test is still waiting. The default 6 s sample is too short for tests that play.
        app.launchArguments += ["-uiTesting", "-uiTestingSampleSeconds", "30"]
        let showTile = UITestSupport.launchSeeded(app)
        showTile.tap()
        let episodeRow = app.buttons["episode.row.Episode 1"]
        XCTAssertTrue(episodeRow.waitForExistence(timeout: 5))
        episodeRow.tap()
        // With the idle-stall guard (T-034): a stalled app is relaunched once and opened again.
        if landscape { UITestSupport.rotateToLandscape(app) }
        XCTAssertTrue(video(app).waitForExistence(timeout: 10))
        return app
    }

    @MainActor
    private func video(_ app: XCUIApplication) -> XCUIElement {
        app.descendants(matching: .any)["player.video"]
    }

    /// Taps the video between the back button and the centre button (and above the line), so it can never land on
    /// an overlay button, then waits for the overlay.
    @MainActor
    private func showOverlay(_ app: XCUIApplication) {
        video(app).coordinate(withNormalizedOffset: CGVector(dx: 0.37, dy: 0.15)).tap()
        XCTAssertTrue(app.buttons["player.overlay.playPause"].waitForExistence(timeout: 5), "A tap shows the overlay")
    }

    /// The scrubber's elapsed-time label ("0:05.0") as text.
    @MainActor
    private func elapsedText(_ app: XCUIApplication) -> String {
        app.staticTexts["player.currentTime"].label
    }

    /// The elapsed time in seconds, or nil if the label isn't there or can't be read.
    @MainActor
    private func elapsedSeconds(_ app: XCUIApplication) -> Double? {
        let label = app.staticTexts["player.currentTime"]
        guard label.exists else { return nil }
        let parts = label.label.split(separator: ":")
        guard parts.count == 2, let minutes = Double(parts[0]), let seconds = Double(parts[1]) else { return nil }
        return minutes * 60 + seconds
    }

    /// Polls until the elapsed time is within 0.2 s of `target`.
    @MainActor
    private func waitForElapsed(_ app: XCUIApplication, near target: Double, timeout: TimeInterval) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        repeat {
            if let now = elapsedSeconds(app), abs(now - target) <= 0.2 { return true }
            RunLoop.current.run(until: Date().addingTimeInterval(0.1))
        } while Date() < deadline
        return false
    }

    /// Reads an element's value and label with direct property reads, right after a tap. While playing, the
    /// landscape bar and the overlay hide 3 s after playback starts, so a slow predicate wait could miss them.
    /// Returns as soon as the value is `expected`. If the element isn't there (it hid), taps the video to bring
    /// the controls back (the 30 s clip is still playing) and reads again, at most 3 times; while it is there
    /// with another value, it polls (about 4 s at most).
    @MainActor
    private func readValue(_ app: XCUIApplication, id: String, expecting expected: String)
        -> (value: String?, label: String?) {
        var last: (value: String?, label: String?) = (nil, nil)
        var reshows = 0
        for _ in 0..<40 {
            let element = app.buttons[id]
            // One snapshot gives exists, value and label together, so they agree and nothing hides between three queries.
            if let read = UITestSupport.readTogether(element) {
                last = (read.value, read.label)
                if last.value == expected { return last }
                RunLoop.current.run(until: Date().addingTimeInterval(0.1))
            } else if reshows < 3 {
                reshows += 1
                video(app).coordinate(withNormalizedOffset: CGVector(dx: 0.37, dy: 0.15)).tap()
                // waitForExistence checks first about 1 s after it starts (of the bar's 3 s); poll sooner than that.
                _ = UITestSupport.wait(timeout: 3, interval: 0.05) { element.exists }
            } else {
                break
            }
        }
        return last
    }

    @MainActor
    private func waitForValue(_ element: XCUIElement, _ value: String, timeout: TimeInterval) -> Bool {
        let predicate = NSPredicate(format: "value == %@", value)
        let expectation = XCTNSPredicateExpectation(predicate: predicate, object: element)
        return XCTWaiter().wait(for: [expectation], timeout: timeout) == .completed
    }
}
