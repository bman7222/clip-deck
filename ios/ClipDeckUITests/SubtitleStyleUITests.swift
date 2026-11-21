import XCTest

/// T-014: the on-video line is drawn from a saved style and always stays inside the video. A style is seeded with
/// `-uiTestingSubtitleStyle <json>` (there is no menu yet). Each test seeks through a cue row while paused, so the
/// line stays put, and compares the `player.subtitle` frame with the `player.video` frame.
final class SubtitleStyleUITests: XCTestCase {
    /// size +5 (150%), up 4 (20%), left 4 (20%), serif, regular weight.
    private let seeded = #"{"font":"serif","bold":false,"sizeStep":5,"upSteps":4,"rightSteps":-4}"#
    /// size +10 (200%), up 18 (90%), right 8 (40%).
    private let extreme = #"{"sizeStep":10,"upSteps":18,"rightSteps":8}"#

    private struct Frames {
        var video: CGRect
        var subtitle: CGRect
        var topBar: CGRect?
        var bottomBar: CGRect?
        var window: CGRect
    }

    override func setUp() {
        continueAfterFailure = false
    }

    override func tearDown() async throws {
        await MainActor.run { XCUIDevice.shared.orientation = .portrait }
        try await super.tearDown()
    }

    // MARK: Portrait

    @MainActor
    func testPortraitSeededStyleIsBiggerHigherAndFurtherLeftAndStaysInsideTheVideo() throws {
        let plain = portraitFrames(seed: nil, name: "portrait-default")
        let styled = portraitFrames(seed: seeded, name: "portrait-seeded")

        XCTAssertGreaterThan(styled.subtitle.height, plain.subtitle.height, "Bigger text makes a taller line")
        XCTAssertGreaterThan(styled.subtitle.width, plain.subtitle.width, "Bigger text makes a wider line")
        XCTAssertLessThan(styled.subtitle.minY, plain.subtitle.minY - 20, "The line is higher")
        XCTAssertLessThan(styled.subtitle.midX, plain.subtitle.midX - 20, "The line is further left")
        assertInside(plain.subtitle, plain.video, "default line")
        assertInside(styled.subtitle, styled.video, "seeded line")
        // The default line is centred, near the bottom of the video.
        XCTAssertEqual(plain.subtitle.midX, plain.video.midX, accuracy: 3, "Default line is centred")
        XCTAssertEqual(plain.subtitle.maxY, plain.video.maxY - 12, accuracy: 3, "Default line sits 12 pt above the bottom")
    }

    @MainActor
    func testPortraitExtremeStyleStaysInsideTheVideoAndWindow() throws {
        let frames = portraitFrames(seed: extreme, name: "portrait-extreme")
        assertInside(frames.subtitle, frames.video, "extreme line in the video")
        assertInside(frames.subtitle, frames.window, "extreme line in the window")
    }

    // MARK: Landscape

    @MainActor
    func testLandscapeSeededStyleWithControlsHiddenAndShown() throws {
        let plain = landscapeFrames(seed: nil, name: "landscape-default")
        let styled = landscapeFrames(seed: seeded, name: "landscape-seeded")

        for (state, before, after) in [("hidden", plain.hidden, styled.hidden), ("shown", plain.shown, styled.shown)] {
            XCTAssertGreaterThan(after.subtitle.height, before.subtitle.height, "\(state): taller line")
            XCTAssertLessThan(after.subtitle.minY, before.subtitle.minY, "\(state): higher line")
            XCTAssertLessThan(after.subtitle.midX, before.subtitle.midX - 20, "\(state): further left")
            assertInside(before.subtitle, before.video, "\(state): default line in the video")
            assertInside(after.subtitle, after.video, "\(state): seeded line in the video")
        }
        for (name, frames) in [("default", plain.shown), ("seeded", styled.shown)] {
            let top = try XCTUnwrap(frames.topBar, "top bar frame")
            let bottom = try XCTUnwrap(frames.bottomBar, "bottom bar frame")
            XCTAssertGreaterThanOrEqual(frames.subtitle.minY, top.maxY - 1, "\(name): line is below the top bar")
            XCTAssertLessThanOrEqual(frames.subtitle.maxY, bottom.minY + 1, "\(name): line is above the bottom bar")
        }
        // The default line is where it always was: the bars lift it, hiding them puts it back at the bottom.
        XCTAssertLessThan(plain.shown.subtitle.maxY, plain.hidden.subtitle.maxY, "Bars lift the default line")
        // The open panel's handle clearance shifts the centre by at most 16 pt, so allow 40 pt.
        XCTAssertEqual(plain.hidden.subtitle.midX, plain.hidden.video.midX, accuracy: 40,
                       "Default line is centred in the video column")
    }

    @MainActor
    func testLandscapeExtremeStyleStaysInsideTheVideoAndWindow() throws {
        let result = landscapeFrames(seed: extreme, name: "landscape-extreme")
        for (state, frames) in [("hidden", result.hidden), ("shown", result.shown)] {
            assertInside(frames.subtitle, frames.video, "\(state): extreme line in the video")
            assertInside(frames.subtitle, frames.window, "\(state): extreme line in the window")
        }
        let top = try XCTUnwrap(result.shown.topBar, "top bar frame")
        let bottom = try XCTUnwrap(result.shown.bottomBar, "bottom bar frame")
        XCTAssertGreaterThanOrEqual(result.shown.subtitle.minY, top.maxY - 1, "Extreme line is below the top bar")
        XCTAssertLessThanOrEqual(result.shown.subtitle.maxY, bottom.minY + 1, "Extreme line is above the bottom bar")
    }

    // MARK: Driving the player

    @MainActor
    private func launch(seed: String?) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments += ["-uiTesting"]
        if let seed { app.launchArguments += ["-uiTestingSubtitleStyle", seed] }
        app.launch()
        let showTile = app.buttons["library.show.Sample Show"]
        XCTAssertTrue(showTile.waitForExistence(timeout: 30), "Seeded show should appear")
        showTile.tap()
        let episodeRow = app.buttons["episode.row.Episode 1"]
        XCTAssertTrue(episodeRow.waitForExistence(timeout: 5))
        episodeRow.tap()
        XCTAssertTrue(app.descendants(matching: .any)["player.video"].waitForExistence(timeout: 10))
        return app
    }

    @MainActor
    private func seekToSecondLine(_ app: XCUIApplication) -> XCUIElement {
        let row = app.descendants(matching: .any)["cue.row.1"]
        XCTAssertTrue(row.waitForExistence(timeout: 10), "The cue list shows the lines")
        row.tap()
        let subtitle = app.textViews["player.subtitle"]
        XCTAssertTrue(subtitle.waitForExistence(timeout: 10), "Tapping a line seeks and shows it")
        settle()
        return subtitle
    }

    @MainActor
    private func portraitFrames(seed: String?, name: String) -> Frames {
        XCUIDevice.shared.orientation = .portrait
        let app = launch(seed: seed)
        let subtitle = seekToSecondLine(app)
        let video = app.descendants(matching: .any)["player.video"]
        let frames = Frames(video: video.frame, subtitle: subtitle.frame, topBar: nil, bottomBar: nil,
                            window: app.windows.firstMatch.frame)
        attach(app, name: name, frames: frames)
        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = name + "-screenshot"
        shot.lifetime = .keepAlways
        add(shot)
        app.terminate()
        return frames
    }

    /// The line's frames with the controls hidden and then shown. A paused player keeps the controls up, so the
    /// first tap on the video (which hides nothing yet) is only needed to bring them up before the panel opens.
    @MainActor
    private func landscapeFrames(seed: String?, name: String) -> (hidden: Frames, shown: Frames) {
        let app = launch(seed: seed)
        XCUIDevice.shared.orientation = .landscapeLeft
        let video = app.descendants(matching: .any)["player.video"]
        XCTAssertTrue(video.waitForExistence(timeout: 10))

        // Controls start hidden in landscape; a tap brings them up. Open the list to reach a cue row.
        tapVideo(app)
        let toggle = app.buttons["player.panelToggle"]
        XCTAssertTrue(toggle.waitForExistence(timeout: 5), "Controls show the panel button")
        toggle.tap()
        XCTAssertTrue(app.descendants(matching: .any)["player.sidePanel"].waitForExistence(timeout: 5))
        let subtitle = seekToSecondLine(app)
        let back = app.buttons["player.back"]
        XCTAssertTrue(back.waitForExistence(timeout: 5), "The paused player keeps the controls up")

        let shown = measure(app, subtitle: subtitle, bars: true)
        attach(app, name: name + "-shown", frames: shown)
        attachVideoShot(video, name: name + "-shown-video")

        tapVideo(app)
        XCTAssertTrue(back.waitForNonExistence(timeout: 5), "A tap on the video hides the controls")
        settle()
        let hidden = measure(app, subtitle: app.textViews["player.subtitle"], bars: false)
        attach(app, name: name + "-hidden", frames: hidden)
        attachVideoShot(video, name: name + "-hidden-video")
        app.terminate()
        return (hidden, shown)
    }

    @MainActor
    private func measure(_ app: XCUIApplication, subtitle: XCUIElement, bars: Bool) -> Frames {
        let video = app.descendants(matching: .any)["player.video"]
        return Frames(
            video: video.frame,
            subtitle: subtitle.frame,
            topBar: bars ? app.descendants(matching: .any)["player.topBar"].frame : nil,
            bottomBar: bars ? app.descendants(matching: .any)["player.bottomBar"].frame : nil,
            window: app.windows.firstMatch.frame
        )
    }

    // MARK: Helpers

    @MainActor
    private func tapVideo(_ app: XCUIApplication) {
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.35)).tap()
    }

    /// Lets the 0.2 s placement animation and the controls' fade finish.
    @MainActor
    private func settle() {
        RunLoop.current.run(until: Date().addingTimeInterval(0.8))
    }

    private func assertInside(_ inner: CGRect, _ outer: CGRect, _ message: String,
                              file: StaticString = #filePath, line: UInt = #line) {
        let outer = outer.insetBy(dx: -1, dy: -1)
        XCTAssertTrue(outer.contains(inner), "\(message): \(inner) should be inside \(outer)", file: file, line: line)
    }

    @MainActor
    private func attach(_ app: XCUIApplication, name: String, frames: Frames) {
        let text = """
            video \(frames.video)
            subtitle \(frames.subtitle)
            topBar \(frames.topBar.map { "\($0)" } ?? "none")
            bottomBar \(frames.bottomBar.map { "\($0)" } ?? "none")
            window \(frames.window)

            \(app.debugDescription)
            """
        let attachment = XCTAttachment(string: text)
        attachment.name = name + "-frames"
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    /// `XCUIElement.screenshot()` of one element comes out unrotated and correct in landscape (`app.screenshot()` doesn't).
    @MainActor
    private func attachVideoShot(_ video: XCUIElement, name: String) {
        let shot = XCTAttachment(screenshot: video.screenshot())
        shot.name = name
        shot.lifetime = .keepAlways
        add(shot)
    }
}
