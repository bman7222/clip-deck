import XCTest

/// T-022: while the centred playback overlay shows, a subtitle line that would sit under its buttons moves just
/// above or below them; when the overlay hides, the line goes back to where it was. The saved position is never
/// changed (the seed is `upSteps` 9, which is 45 %, in the middle of the video). Paused at the second line of the
/// seeded "Sample Show" (a 30 s video, so a slow runner can't play it to its end).
///
/// Timing rules: wait on state (a frame settling, an element appearing), never on a fixed sleep.
final class SubtitleAvoidOverlayUITests: XCTestCase {
    private let ids = ["player.overlay.back5", "player.overlay.playPause", "player.overlay.forward5"]

    override func setUp() {
        continueAfterFailure = false
    }

    override func tearDown() async throws {
        await MainActor.run { XCUIDevice.shared.orientation = .portrait }
        try await super.tearDown()
    }

    @MainActor func testLineAvoidsTheOverlayPortrait() throws { try checkAvoidance(landscape: false) }
    @MainActor func testLineAvoidsTheOverlayLandscape() throws { try checkAvoidance(landscape: true) }

    @MainActor
    private func checkAvoidance(landscape: Bool) throws {
        let app = XCUIApplication()
        app.launchArguments += ["-uiTesting", "-uiTestingSampleSeconds", "30",
                                "-uiTestingSubtitleStyle", #"{"upSteps":9}"#]
        UITestSupport.launchAndOpenSampleEpisode(app)
        let video = app.descendants(matching: .any)["player.video"]
        XCTAssertTrue(video.waitForExistence(timeout: 10))
        if landscape {
            UITestSupport.rotateToLandscape(app)
            XCTAssertTrue(video.waitForExistence(timeout: 10))
            // Landscape lists the lines in a side panel, behind the controls.
            tapVideo(video)
            let toggle = app.buttons["player.panelToggle"]
            XCTAssertTrue(toggle.waitForExistence(timeout: 5), "Controls offer the panel button")
            toggle.tap()
        }
        let row = app.descendants(matching: .any)["cue.row.1"]
        XCTAssertTrue(row.waitForExistence(timeout: 10), "The list shows the second line")
        row.tap()
        let line = app.textViews["player.subtitle"]
        XCTAssertTrue(line.waitForExistence(timeout: 10), "The line shows over the video")

        // Baseline: overlay hidden (portrait starts hidden; landscape toggles with a tap on the video).
        let playPause = app.buttons["player.overlay.playPause"]
        if playPause.exists {
            tapVideo(video)
            XCTAssertTrue(playPause.waitForNonExistence(timeout: 5), "A tap hides the overlay")
        }
        let baseline = try XCTUnwrap(settledFrame(line), "The line settles with the overlay hidden")

        // Show the overlay: the line moves clear of all three buttons (each grown by 8 pt).
        tapVideo(video)
        XCTAssertTrue(playPause.waitForExistence(timeout: 5), "A tap shows the overlay")
        let clear = UITestSupport.wait(timeout: 8) { meetsNoButton(app, line: line) }
        let shownFrame = line.frame
        UITestSupport.attachText(app.debugDescription, name: "avoid-overlay-shown-\(landscape ? "landscape" : "portrait")",
                                 to: self)
        XCTAssertTrue(clear, "The line stays clear of the overlay buttons (line \(shownFrame), "
                      + "buttons \(ids.map { app.buttons[$0].frame }))")
        XCTAssertGreaterThan(abs(shownFrame.minY - baseline.minY), 1, "The line moved to make room")

        // Hide it: the line goes back to where it was.
        tapVideo(video)
        XCTAssertTrue(playPause.waitForNonExistence(timeout: 5), "A tap hides the overlay again")
        let back = UITestSupport.wait(timeout: 8) {
            line.exists && abs(line.frame.minX - baseline.minX) <= 1 && abs(line.frame.minY - baseline.minY) <= 1
        }
        UITestSupport.attachText(app.debugDescription, name: "avoid-overlay-hidden-\(landscape ? "landscape" : "portrait")",
                                 to: self)
        XCTAssertTrue(back, "The line returns to \(baseline) (now \(line.frame))")
    }

    /// AC-6: in portrait the overlay gives way to the Aa style sheet, so the line shows at its true saved place
    /// and every Up step moves it; the overlay comes back when the sheet closes.
    @MainActor
    func testOverlayGivesWayToTheStyleSheetPortrait() throws {
        let app = XCUIApplication()
        app.launchArguments += ["-uiTesting", "-uiTestingSampleSeconds", "30",
                                "-uiTestingSubtitleStyle", #"{"upSteps":8}"#]
        UITestSupport.launchAndOpenSampleEpisode(app)
        let video = app.descendants(matching: .any)["player.video"]
        XCTAssertTrue(video.waitForExistence(timeout: 10))
        let row = app.descendants(matching: .any)["cue.row.1"]
        XCTAssertTrue(row.waitForExistence(timeout: 10))
        row.tap()
        let line = app.textViews["player.subtitle"]
        XCTAssertTrue(line.waitForExistence(timeout: 10), "The line shows over the video")

        let playPause = app.buttons["player.overlay.playPause"]
        tapVideo(video)
        XCTAssertTrue(playPause.waitForExistence(timeout: 5), "A tap shows the overlay")

        let opener = app.buttons["player.subtitleStyle"]
        XCTAssertTrue(opener.waitForExistence(timeout: 5))
        opener.tap()
        let done = app.buttons["subtitleStyle.done"]
        XCTAssertTrue(done.waitForExistence(timeout: 5), "The style sheet opens")
        XCTAssertTrue(playPause.waitForNonExistence(timeout: 5), "The overlay hides while the sheet is open")
        XCTAssertFalse(app.buttons["player.overlay.back5"].exists)
        XCTAssertFalse(app.buttons["player.overlay.forward5"].exists)

        // The position controls may be below the first detent; reach them by scrolling.
        let up = app.buttons["subtitleStyle.up"]
        var swipes = 0
        while !up.isHittable && swipes < 8 {
            app.swipeUp()
            swipes += 1
        }
        XCTAssertTrue(up.isHittable, "Up can be reached")
        XCTAssertTrue(UITestSupport.wait(timeout: 5) { line.exists }, "The line is still there")
        var previous = try XCTUnwrap(settledFrame(line), "The line settles")
        for step in 1...3 {
            up.tap()
            let moved = UITestSupport.waitForFrame(line, timeout: 8) { $0.minY < previous.minY - 1 }
            XCTAssertTrue(moved, "Up step \(step) moves the line (was \(previous), now \(line.frame))")
            previous = try XCTUnwrap(settledFrame(line), "The line settles after step \(step)")
        }
        UITestSupport.attachText(app.debugDescription, name: "avoid-overlay-style-sheet-portrait", to: self)

        done.tap()
        XCTAssertTrue(done.waitForNonExistence(timeout: 5), "Done closes the sheet")
        XCTAssertTrue(playPause.waitForExistence(timeout: 5), "The overlay comes back when the sheet closes")
    }

    // MARK: Helpers

    /// Taps the video left of the back button, in the middle of its height: never on a button or the line. At 15 %
    /// it is clear of the landscape Dynamic Island and still left of the band in every layout.
    @MainActor
    private func tapVideo(_ video: XCUIElement) {
        video.coordinate(withNormalizedOffset: CGVector(dx: 0.15, dy: 0.5)).tap()
    }

    /// True while the line's frame doesn't meet any overlay button's frame grown by 8 pt (a sliver under half a
    /// point doesn't count, so a line touching the padding edge passes).
    @MainActor
    private func meetsNoButton(_ app: XCUIApplication, line: XCUIElement) -> Bool {
        guard line.exists else { return false }
        let lineFrame = line.frame
        for id in ids {
            let button = app.buttons[id]
            guard button.exists else { return false }
            let overlap = lineFrame.intersection(button.frame.insetBy(dx: -8, dy: -8))
            if !overlap.isNull && overlap.width > 0.5 && overlap.height > 0.5 { return false }
        }
        return true
    }

    /// The line's frame once two reads 0.3 s apart agree (the 0.2 s move has finished). Nil if it never settles.
    @MainActor
    private func settledFrame(_ line: XCUIElement) -> CGRect? {
        var last = CGRect.null
        var result: CGRect?
        _ = UITestSupport.wait(timeout: 8, interval: 0.3) {
            guard line.exists else { return false }
            let now = line.frame
            defer { last = now }
            if now == last { result = now; return true }
            return false
        }
        return result
    }
}
