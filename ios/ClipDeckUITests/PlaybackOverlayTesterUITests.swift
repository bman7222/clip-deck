import XCTest

/// Tester checks for T-021 beyond PlaybackOverlayUITests: a second portrait tap hides the overlay, a real pause
/// shows it, the skips move 5 s from mid-video, a skip tap restarts the 3 s countdown, the overlay re-centres when
/// the side panel opens and is resized, a rotation resets the portrait overlay, and screenshots of the overlay and
/// the bar's play/pause in light mode (AC-1, AC-2, AC-4, AC-5, AC-6). Uses the seeded "Sample Show": a 6 s
/// video, paused at 0:00.
final class PlaybackOverlayTesterUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    override func tearDown() async throws {
        await MainActor.run {
            XCUIDevice.shared.orientation = .portrait
        }
        try await super.tearDown()
    }

    // MARK: AC-2 portrait tap and pause

    /// A second tap on the portrait video hides the overlay again (paused, so nothing else can hide it), and
    /// neither tap plays. This also shows the overlay's own layer doesn't swallow taps meant for the video.
    @MainActor
    func testPortraitSecondTapHidesTheOverlay() throws {
        let app = openSample(landscape: false)
        let overlay = app.buttons["player.overlay.playPause"]
        let barPlay = app.buttons["player.playPause"]
        XCTAssertTrue(barPlay.waitForExistence(timeout: 5))
        XCTAssertFalse(overlay.exists, "Portrait starts with the overlay hidden")

        tapVideoClear(app)
        XCTAssertTrue(overlay.waitForExistence(timeout: 5), "The first tap shows the overlay")
        tapVideoClear(app)
        XCTAssertTrue(overlay.waitForNonExistence(timeout: 3), "The second tap hides it")
        XCTAssertEqual(barPlay.value as? String, "Paused", "Neither tap plays")
        tapVideoClear(app)
        XCTAssertTrue(overlay.waitForExistence(timeout: 5), "A third tap shows it again")
        XCTAssertEqual(barPlay.value as? String, "Paused", "Still paused")
    }

    /// A real pause (playing -> paused) shows the portrait overlay with no tap on the video.
    @MainActor
    func testPortraitRealPauseShowsTheOverlay() throws {
        let app = openSample(landscape: false, sampleSeconds: 30)
        let overlay = app.buttons["player.overlay.playPause"]
        let barPlay = app.buttons["player.playPause"]
        XCTAssertTrue(barPlay.waitForExistence(timeout: 5))
        XCTAssertFalse(overlay.exists, "Portrait starts with the overlay hidden")

        barPlay.tap()
        guard waitForValue(barPlay, "Playing", timeout: 5) else {
            // A slow runner can play a whole 6 s clip during one tap (this test now uses a 30 s one). Its end is also a real pause.
            XCTAssertTrue(overlay.waitForExistence(timeout: 3), "The clip's end (a real pause) shows the overlay")
            return
        }
        // Only conclusive if it is still playing after the check (a slow snapshot could outlast a short clip).
        let shownWhilePlaying = overlay.exists
        if barPlay.value as? String == "Playing" {
            XCTAssertFalse(shownWhilePlaying, "Playing from the bar doesn't show the overlay")
        }
        barPlay.tap()
        XCTAssertTrue(waitForValue(barPlay, "Paused", timeout: 5), "The bar button pauses")
        XCTAssertTrue(overlay.waitForExistence(timeout: 3), "A real pause shows the overlay")
        XCTAssertFalse(overlay.waitForNonExistence(timeout: 3.5), "and it stays while paused")
    }

    // MARK: AC-6 skips mid-video

    @MainActor func testSkipsMoveFiveSecondsMidVideoPortrait() throws { try checkSkipsMidVideo(landscape: false) }
    @MainActor func testSkipsMoveFiveSecondsMidVideoLandscape() throws { try checkSkipsMidVideo(landscape: true) }

    /// Paused mid-video, back 5 s and forward 5 s each move the time by 5 s. Two forward taps from 0:00 reach the
    /// end of the 6 s clip (the second is clamped there). Back 5 s from the end lands about 1 s in, which a jump to
    /// the start (0:00) can't fake, and forward 5 s from there lands on the end again. No playback, so no timing.
    @MainActor
    private func checkSkipsMidVideo(landscape: Bool) throws {
        let app = openSample(landscape: landscape)
        tapVideoClear(app)
        let back = app.buttons["player.overlay.back5"]
        let forward = app.buttons["player.overlay.forward5"]
        XCTAssertTrue(forward.waitForExistence(timeout: 5), "A tap shows the overlay")
        XCTAssertTrue(waitForElapsed(app, near: 0, timeout: 5), "Starts at 0:00 (\(elapsedText(app)))")

        forward.tap()
        XCTAssertTrue(waitForElapsed(app, near: 5, timeout: 5), "Forward 5 s: about 0:05 (\(elapsedText(app)))")
        forward.tap()
        XCTAssertTrue(waitForElapsed(app, atLeast: 5.5, timeout: 5), "Forward 5 s again: clamped at the end (\(elapsedText(app)))")
        RunLoop.current.run(until: Date().addingTimeInterval(0.5))
        let end = try XCTUnwrap(elapsedSeconds(app), "The elapsed time can be read")
        XCTAssertGreaterThan(end - 5, 0.5, "The clip is long enough to tell back 5 s from a jump to the start")

        back.tap()
        XCTAssertTrue(waitForElapsed(app, near: end - 5, timeout: 5),
                      "Back 5 s from \(end) s lands about 5 s earlier (\(elapsedText(app)))")
        forward.tap()
        XCTAssertTrue(waitForElapsed(app, near: end, timeout: 5),
                      "Forward 5 s from \(end - 5) s lands about 5 s later (\(elapsedText(app)))")
        XCTAssertEqual(app.buttons["player.playPause"].value as? String, "Paused", "Skips don't play")
    }

    // MARK: AC-2 a skip restarts the countdown

    @MainActor func testSkipRestartsTheCountdownPortrait() throws { try checkSkipRestartsCountdown(landscape: false) }
    @MainActor func testSkipRestartsTheCountdownLandscape() throws { try checkSkipRestartsCountdown(landscape: true) }

    /// Playing, back 5 s is tapped about once a second. Each tap is made while the overlay shows, and sends the
    /// clip back to 0:00 (a 30 s clip, so it can't end either way). Without the restart the overlay is gone about 3 s after Play; with
    /// it, it is still there 4.5 s after Play, and then hides on its own 3 s or more after the last skip.
    /// A runner too slow to check and tap again within about 2.3 s of the previous tap can't decide it, and the
    /// test is skipped (XCTSkip), not failed.
    @MainActor
    private func checkSkipRestartsCountdown(landscape: Bool) throws {
        let app = openSample(landscape: landscape, sampleSeconds: 30)
        tapVideoClear(app)
        let overlayPlay = app.buttons["player.overlay.playPause"]
        let back = app.buttons["player.overlay.back5"]
        XCTAssertTrue(overlayPlay.waitForExistence(timeout: 5), "A tap shows the overlay")

        let playStart = Date()
        overlayPlay.tap()
        // The app has handled the tap when tap() returns, so without a restart the overlay is gone by t0 + 3.2 s.
        let t0 = Date()
        var log = "play tap took \(format(t0.timeIntervalSince(playStart))) s"
        var lastTapStart = playStart
        var skips = 0
        while true {
            RunLoop.current.run(until: lastTapStart.addingTimeInterval(1.0))
            let checkStart = Date()
            let shown = back.exists
            let checked = Date()
            let sinceTap = checked.timeIntervalSince(lastTapStart)
            log += "\ncheck \(format(checkStart.timeIntervalSince(t0)))-\(format(checked.timeIntervalSince(t0))) s after Play: "
            log += "shown \(shown), \(format(sinceTap)) s after the last tap started"
            if !shown {
                attachText(log, name: "tester-skip-restart-\(landscape ? "landscape" : "portrait")")
                if sinceTap >= 2.8 {
                    throw XCTSkip("Runner too slow to decide: \(format(sinceTap)) s since the last tap. \(log)")
                }
                XCTFail("The overlay hid \(format(sinceTap)) s after a tap, before the 3 s countdown ended. \(log)")
                return
            }
            if checkStart.timeIntervalSince(t0) >= 4.5 { break }
            if sinceTap >= 2.3 {
                // A tap now could race the 3 s hide of a correct app, so this runner can't decide it.
                attachText(log, name: "tester-skip-restart-\(landscape ? "landscape" : "portrait")")
                throw XCTSkip("Runner too slow to decide: \(format(sinceTap)) s since the last tap. \(log)")
            }
            lastTapStart = Date()
            back.tap()
            skips += 1
        }
        XCTAssertGreaterThanOrEqual(skips, 2, "At least two skips were tapped")
        XCTAssertTrue(back.waitForNonExistence(timeout: 6), "With no more skips it hides on its own. \(log)")
        let hidAfter = Date().timeIntervalSince(lastTapStart)
        log += "\nhidden \(format(hidAfter)) s after the last tap started"
        attachText(log, name: "tester-skip-restart-\(landscape ? "landscape" : "portrait")")
        XCTAssertGreaterThanOrEqual(hidAfter, 2.9, "It hides 3 s after the last skip, not before. \(log)")
    }

    // MARK: AC-1 re-centring with the side panel

    /// Landscape: the overlay is centred on the video column, so it follows the column when the side panel opens
    /// (25 %) and when the panel is dragged to its widest (50 %). Also checks the bar order (AC-5) at each width.
    @MainActor
    func testOverlayRecentresWhenThePanelOpensAndResizes() throws {
        let app = openSample(landscape: true)
        tapVideoClear(app)
        let toggle = app.buttons["player.panelToggle"]
        XCTAssertTrue(toggle.waitForExistence(timeout: 5), "The controls show")
        XCTAssertTrue(app.buttons["player.overlay.playPause"].waitForExistence(timeout: 5), "The overlay shows")
        checkCentres(app, state: "panel-closed")

        toggle.tap()
        let panel = app.descendants(matching: .any)["player.sidePanel"]
        XCTAssertTrue(panel.waitForExistence(timeout: 5), "The panel opens")
        waitUntilSettled(panel)
        waitUntilSettled(app.buttons["player.overlay.forward5"])
        checkCentres(app, state: "panel-25")

        let handle = app.descendants(matching: .any)["player.panelHandle"]
        XCTAssertTrue(handle.waitForExistence(timeout: 5))
        let start = handle.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        start.press(forDuration: 0.1, thenDragTo: start.withOffset(CGVector(dx: 2 - handle.frame.midX, dy: 0)))
        waitUntilSettled(panel)
        waitUntilSettled(app.buttons["player.overlay.forward5"])
        XCTAssertGreaterThan(panel.frame.width, app.windows.firstMatch.frame.width * 0.4, "The panel is at its widest")
        checkCentres(app, state: "panel-50")
    }

    // MARK: AC-2 rotation

    /// A portrait overlay that was shown is hidden after a trip to landscape and back.
    @MainActor
    func testRotationResetsThePortraitOverlay() throws {
        let app = openSample(landscape: false)
        let overlay = app.buttons["player.overlay.playPause"]
        tapVideoClear(app)
        XCTAssertTrue(overlay.waitForExistence(timeout: 5), "A portrait tap shows the overlay")

        XCUIDevice.shared.orientation = .landscapeLeft
        XCTAssertTrue(app.navigationBars.firstMatch.waitForNonExistence(timeout: 10), "Landscape")
        XCTAssertTrue(overlay.waitForNonExistence(timeout: 5), "Landscape starts with the overlay hidden")
        tapVideoClear(app)
        XCTAssertTrue(overlay.waitForExistence(timeout: 5), "A landscape tap shows it with the controls")

        XCUIDevice.shared.orientation = .portrait
        XCTAssertTrue(app.navigationBars.firstMatch.waitForExistence(timeout: 10), "Portrait again")
        XCTAssertTrue(overlay.waitForNonExistence(timeout: 5), "Back in portrait the overlay is hidden")
        XCTAssertFalse(overlay.waitForExistence(timeout: 2), "and it stays hidden")
    }

    // MARK: Visual evidence (AC-1, AC-4)

    // There is no dark variant: on CI the simulator stayed light when the appearance was set from XCUIDevice
    // (round 2, C2), so a "dark" test only took light pictures. Dark mode stays unverified for Brent to check.
    @MainActor func testScreenshotsLight() throws { try captureScreens() }

    /// The overlay and the bar's play/pause, paused and playing, in portrait and landscape. Landscape uses element
    /// screenshots of the video (unrotated, with the bars and the overlay drawn over it) and the frames as text.
    @MainActor
    private func captureScreens() throws {
        let mode = "light"
        let app = openSample(landscape: false, sampleSeconds: 30)
        let barPlay = app.buttons["player.playPause"]
        let overlayPlay = app.buttons["player.overlay.playPause"]
        XCTAssertTrue(barPlay.waitForExistence(timeout: 5))

        tapVideoClear(app)
        XCTAssertTrue(overlayPlay.waitForExistence(timeout: 5), "A tap shows the overlay")
        settle()
        keep(app.screenshot(), name: "tester-portrait-paused-\(mode)-screen")
        keep(video(app).screenshot(), name: "tester-portrait-paused-\(mode)-video")
        keep(barPlay.screenshot(), name: "tester-portrait-paused-\(mode)-barPlay")
        attachText(app.debugDescription, name: "tester-portrait-paused-\(mode)-frames")

        barPlay.tap()
        // The sample is 30 s here, so a slow runner can't play it to its end during the tap.
        if waitForValue(barPlay, "Playing", timeout: 5) {
            let overlayState = overlayPlay.exists
                ? "overlay label \(overlayPlay.label) value \(String(describing: overlayPlay.value))" : "overlay hidden"
            attachText("bar label \(barPlay.label) value \(String(describing: barPlay.value)); \(overlayState)",
                       name: "tester-portrait-playing-\(mode)-state")
            keep(app.screenshot(), name: "tester-portrait-playing-\(mode)-screen")
            keep(barPlay.screenshot(), name: "tester-portrait-playing-\(mode)-barPlay")
            barPlay.tap()
        }
        XCTAssertTrue(waitForValue(barPlay, "Paused", timeout: 8), "Paused again")

        XCUIDevice.shared.orientation = .landscapeLeft
        XCTAssertTrue(app.navigationBars.firstMatch.waitForNonExistence(timeout: 10), "Landscape")
        tapVideoClear(app)
        XCTAssertTrue(overlayPlay.waitForExistence(timeout: 5), "A tap shows the controls and the overlay")
        settle()
        keep(video(app).screenshot(), name: "tester-landscape-paused-\(mode)-video")
        keep(barPlay.screenshot(), name: "tester-landscape-paused-\(mode)-barPlay")
        attachText(app.debugDescription, name: "tester-landscape-paused-\(mode)-frames")

        barPlay.tap()
        // The bars fade 3 s after Play, so don't assert on them; take the always-present video element instead
        // (the bars and the overlay lie over it).
        _ = waitForValue(barPlay, "Playing", timeout: 2)
        keep(video(app).screenshot(), name: "tester-landscape-playing-\(mode)-video")
    }

    // MARK: Helpers

    @MainActor
    private func checkCentres(_ app: XCUIApplication, state: String) {
        let videoFrame = video(app).frame
        var text = "state \(state)\nvideo \(videoFrame)"
        for (id, share, size) in [("player.overlay.back5", 0.25, 44.0), ("player.overlay.playPause", 0.5, 52.0),
                                  ("player.overlay.forward5", 0.75, 44.0)] as [(String, CGFloat, CGFloat)] {
            let frame = app.buttons[id].frame
            text += "\n\(id) \(frame)"
            XCTAssertEqual(frame.midX, videoFrame.minX + videoFrame.width * share, accuracy: 2, "\(state): \(id) x")
            XCTAssertEqual(frame.midY, videoFrame.midY, accuracy: 2, "\(state): \(id) y")
            XCTAssertEqual(frame.width, size, accuracy: 2, "\(state): \(id) diameter")
            XCTAssertLessThanOrEqual(frame.maxX, videoFrame.maxX + 0.5, "\(state): \(id) stays in the video column")
        }
        // AC-5: ⏯ ±0.0s Subs Aa … Make a Card, left to right, in whichever ViewThatFits variant fits.
        let order = ["player.playPause", "player.offset", "player.subtitlesMenu", "player.subtitleStyle", "player.makeCard"]
        let frames = order.map { app.buttons[$0].frame }
        for (id, frame) in zip(order, frames) { text += "\n\(id) \(frame)" }
        for index in 1..<frames.count {
            XCTAssertGreaterThan(frames[index].midX, frames[index - 1].midX, "\(state): \(order[index]) after \(order[index - 1])")
        }
        attachText(text, name: "tester-centres-\(state)")
        keep(video(app).screenshot(), name: "tester-centres-\(state)-video")
        attachText(app.debugDescription, name: "tester-centres-\(state)-frames")
    }

    @MainActor
    private func openSample(landscape: Bool, sampleSeconds: Int = 6) -> XCUIApplication {
        XCUIDevice.shared.orientation = .portrait
        let app = XCUIApplication()
        // Tests that play pass a longer clip (-uiTestingSampleSeconds), so a slow runner can't play it to its end.
        app.launchArguments += ["-uiTesting"]
        if sampleSeconds != 6 { app.launchArguments += ["-uiTestingSampleSeconds", "\(sampleSeconds)"] }
        app.launch()
        let showTile = app.buttons["library.show.Sample Show"]
        XCTAssertTrue(showTile.waitForExistence(timeout: 30), "Seeded show should appear")
        showTile.tap()
        let episodeRow = app.buttons["episode.row.Episode 1"]
        XCTAssertTrue(episodeRow.waitForExistence(timeout: 5))
        episodeRow.tap()
        if landscape { XCUIDevice.shared.orientation = .landscapeLeft }
        XCTAssertTrue(video(app).waitForExistence(timeout: 10))
        if landscape {
            XCTAssertTrue(app.navigationBars.firstMatch.waitForNonExistence(timeout: 10), "Landscape")
        }
        return app
    }

    @MainActor
    private func video(_ app: XCUIApplication) -> XCUIElement {
        app.descendants(matching: .any)["player.video"]
    }

    /// Between the back button (25 %) and the centre button (50 %), above the overlay row: clear of the overlay
    /// buttons, the line at the bottom, and (in landscape) below the top bar.
    @MainActor
    private func tapVideoClear(_ app: XCUIApplication) {
        video(app).coordinate(withNormalizedOffset: CGVector(dx: 0.37, dy: 0.3)).tap()
    }

    /// The scrubber's elapsed-time label ("0:05.0") as text.
    @MainActor
    private func elapsedText(_ app: XCUIApplication) -> String {
        let label = app.staticTexts["player.currentTime"]
        return label.exists ? label.label : "no elapsed label"
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

    /// Polls until the elapsed time is within 0.2 s of `target` (or, with `atLeast`, at or past it).
    @MainActor
    private func waitForElapsed(_ app: XCUIApplication, near target: Double? = nil, atLeast floor: Double? = nil,
                                timeout: TimeInterval) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        repeat {
            if let now = elapsedSeconds(app) {
                if let target, abs(now - target) <= 0.2 { return true }
                if let floor, now >= floor { return true }
            }
            RunLoop.current.run(until: Date().addingTimeInterval(0.1))
        } while Date() < deadline
        return false
    }

    @MainActor
    private func waitForValue(_ element: XCUIElement, _ value: String, timeout: TimeInterval) -> Bool {
        let predicate = NSPredicate(format: "value == %@", value)
        let expectation = XCTNSPredicateExpectation(predicate: predicate, object: element)
        return XCTWaiter().wait(for: [expectation], timeout: timeout) == .completed
    }

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

    /// Lets the 0.2 s fade finish.
    @MainActor
    private func settle() {
        RunLoop.current.run(until: Date().addingTimeInterval(0.8))
    }

    private func format(_ seconds: TimeInterval) -> String {
        String(format: "%.2f", seconds)
    }

    @MainActor
    private func keep(_ screenshot: XCUIScreenshot, name: String) {
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    @MainActor
    private func attachText(_ text: String, name: String) {
        let attachment = XCTAttachment(string: text)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
