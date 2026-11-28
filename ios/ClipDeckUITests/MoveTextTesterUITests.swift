import XCTest

/// Tester checks for T-024a that the builder's `MoveTextUITests` leave out:
/// - AC-1: ✥A sits right after Aa in the panel-open landscape bar variants too (panel 25 % and 50 %), and element
///   screenshots of the button at the default place and away from it (plain, then aqua);
/// - AC-2: each arrow of the portrait sheet dims at its own limit (Up 90 %, Left 40 %, Down at the default height),
///   with the Aa menu's spoken values; Reset puts the line itself back (centred, on the region's bottom) and is then
///   disabled;
/// - AC-3: with the panel at 50 % the card still holds every control, hittable, inside the video column;
/// - AC-3 (T-018 AC-5, T-023 C1): a stored place above the highest reachable one opens the card with Up dimmed at
///   "Highest" and the line just under the card. The first Down moves the line at once (it jumps to one step below
///   the reachable top; a plain step would stay pinned under the card), Up comes back, and one Up returns the line to
///   the same top place and dims Up again;
/// - AC-4: in landscape, opening the card pauses a playing video (the 18 s it stays open don't play), and Done resumes;
/// - AC-4: a swipe down of the portrait sheet closes it and resumes playback;
/// - AC-4: a rotation closes the menu without resuming.
final class MoveTextTesterUITests: XCTestCase {
    /// The line's clearance under the card (`Spacing.s`).
    private let cardGap: CGFloat = 8
    /// How long the landscape card stays open in the pause check.
    private let heldOpen: TimeInterval = 18

    override func setUp() {
        continueAfterFailure = false
    }

    override func tearDown() async throws {
        await MainActor.run { XCUIDevice.shared.orientation = .portrait }
        try await super.tearDown()
    }

    // MARK: AC-1 and AC-3: every landscape bar variant, and the card at half width

    @MainActor
    func testButtonFollowsAaInEveryLandscapeBarVariantAndTheCardFitsAtHalfWidth() throws {
        let app = launch(seed: nil, landscape: true)
        var log: [String] = []
        let move = app.buttons["player.moveText"]
        XCTAssertTrue(move.waitForExistence(timeout: 5))
        attachElementShot(move, name: "tester-move-button-default")
        log.append(checkOrder(app, state: "panel closed"))

        let toggle = app.buttons["player.panelToggle"]
        toggle.tap()
        let panel = app.descendants(matching: .any)["player.sidePanel"]
        XCTAssertTrue(panel.waitForExistence(timeout: 5), "The side list opens")
        waitUntilSettled(panel)
        log.append(checkOrder(app, state: "panel 25 %"))

        let handle = app.descendants(matching: .any)["player.panelHandle"]
        XCTAssertTrue(handle.waitForExistence(timeout: 5))
        let start = handle.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        start.press(forDuration: 0.1, thenDragTo: start.withOffset(CGVector(dx: 2 - handle.frame.midX, dy: 0)))
        waitUntilSettled(panel)
        XCTAssertGreaterThan(panel.frame.width, app.windows.firstMatch.frame.width * 0.4, "The panel is at its widest")
        log.append(checkOrder(app, state: "panel 50 %"))

        // The card at half width: every control is there, hittable, inside the card and the video column.
        XCTAssertTrue(move.waitForExistence(timeout: 5))
        move.tap()
        let card = cardElement(app)
        XCTAssertTrue(card.waitForExistence(timeout: 5), "The card opens with the panel at 50 %")
        UITestSupport.settle()
        let video = app.descendants(matching: .any)["player.video"].frame
        let cardFrame = card.frame
        log.append("panel 50 %: card \(cardFrame), video \(video), panel \(panel.frame)")
        for id in ["left", "up", "down", "right", "reset", "done"] {
            let control = app.buttons["moveText.\(id)"]
            XCTAssertTrue(control.exists, "The card has \(id) at half width")
            let frame = control.frame
            log.append("  moveText.\(id) \(frame) hittable \(control.isHittable)")
            if !control.isHittable { UITestSupport.dismissSystemBanner() }
            XCTAssertTrue(control.isHittable, "\(id) can be tapped at half width (\(frame))")
            XCTAssertGreaterThanOrEqual(frame.minX, cardFrame.minX - 0.5, "\(id) starts inside the card")
            XCTAssertLessThanOrEqual(frame.maxX, cardFrame.maxX + 0.5, "\(id) ends inside the card (\(frame), card \(cardFrame))")
            XCTAssertLessThanOrEqual(frame.maxX, video.maxX + 0.5, "\(id) ends inside the video column (\(frame), video \(video))")
        }
        log.append("  value text shown: \(app.staticTexts["moveText.value"].exists)")
        attachElementShot(card, name: "tester-move-card-half-width")
        attachText(log.joined(separator: "\n"), name: "tester-move-variants")
        attachText(app.debugDescription, name: "tester-move-card-half-width-frames")
        UITestSupport.tap(app.buttons["moveText.done"], patience: 5) { !card.exists }
        XCTAssertTrue(card.waitForNonExistence(timeout: 5), "Done closes the card")
    }

    // MARK: AC-3: the first Down from above the reachable top (T-018 AC-5 with the card at the top)

    @MainActor
    func testFirstDownFromAboveTheReachableTopMovesTheLineLandscape() throws {
        let app = launch(seed: #"{"up":0.9}"#, landscape: true)
        let move = app.buttons["player.moveText"]
        XCTAssertTrue(move.waitForExistence(timeout: 5))
        XCTAssertEqual(move.value as? String, "Up 90%", "The button speaks the stored place")
        attachElementShot(move, name: "tester-move-button-changed")
        let line = showSecondLine(app)

        XCTAssertTrue(move.waitForExistence(timeout: 5))
        move.tap()
        let card = cardElement(app)
        XCTAssertTrue(card.waitForExistence(timeout: 5), "The card opens")
        UITestSupport.settle()
        let up = app.buttons["moveText.up"]
        let down = app.buttons["moveText.down"]
        XCTAssertFalse(up.isEnabled, "With the stored place above the reachable top, Up opens dimmed")
        XCTAssertEqual(up.value as? String, "Highest")
        XCTAssertTrue(down.isEnabled, "Down stays enabled")
        XCTAssertEqual(down.value as? String, "90 percent up", "Down keeps the stored percent")
        let pinned = line.frame
        let cardFrame = card.frame
        var log = ["card \(cardFrame)", "pinned \(pinned) (gap \(pinned.minY - cardFrame.maxY))"]
        XCTAssertEqual(pinned.minY - cardFrame.maxY, cardGap, accuracy: 2, "The line sits just under the card")

        // One Down: the line moves at once.
        UITestSupport.tap(down, patience: 4) { (down.value as? String) != "90 percent up" }
        XCTAssertTrue(UITestSupport.waitForFrame(line, timeout: 5) { $0.minY > pinned.minY + 1 },
                      "The first Down moves the line at once (now \(line.frame), pinned \(pinned))")
        UITestSupport.settle()
        let afterDown = line.frame
        let storedAfterDown = down.value as? String
        log.append("after Down \(afterDown), down value \(storedAfterDown ?? "nil"), up enabled \(up.isEnabled)")
        XCTAssertNotEqual(storedAfterDown, "85 percent up",
                          "The first Down jumps to one step below the reachable top, not one plain step from 90 %")
        XCTAssertTrue(up.isEnabled, "Up is enabled again one step below the reachable top")

        // One Up: back to the same top place, and Up dims again.
        UITestSupport.tap(up, patience: 4) { !up.isEnabled }
        XCTAssertTrue(UITestSupport.waitForFrame(line, timeout: 5) { abs($0.minY - pinned.minY) <= 1.5 },
                      "One Up returns the line to the top place (now \(line.frame), pinned \(pinned))")
        UITestSupport.settle()
        log.append("after Up \(line.frame), up value \(up.value as? String ?? "nil"), down value \(down.value as? String ?? "nil")")
        XCTAssertFalse(up.isEnabled, "Up dims again at the top place")
        XCTAssertEqual(up.value as? String, "Highest")
        attachText(log.joined(separator: "\n"), name: "tester-move-first-down")
        attachText(app.debugDescription, name: "tester-move-first-down-frames")
        attachElementShot(card, name: "tester-move-card")
        attachElementShot(app.descendants(matching: .any)["player.video"], name: "tester-move-card-video")

        // T-024b (from SubtitleUpLimitTesterUITests): closed and reopened at the same top place, Up is still dimmed.
        UITestSupport.tap(app.buttons["moveText.done"], patience: 5) { !card.exists }
        XCTAssertTrue(card.waitForNonExistence(timeout: 5), "Done closes the card")
        XCTAssertTrue(move.waitForExistence(timeout: 5))
        move.tap()
        XCTAssertTrue(card.waitForExistence(timeout: 5), "The card opens again")
        UITestSupport.settle()
        XCTAssertFalse(up.isEnabled, "Reopened at the same place, Up is still dimmed")
        XCTAssertEqual(up.value as? String, "Highest")
    }

    /// T-024b (from SubtitleStyleSheetTesterUITests): Right dims at its own limit, 40 % right, and Left stays enabled.
    @MainActor
    func testRightDimsAtFortyPercentRightPortrait() throws {
        let app = launch(seed: #"{"right":0.4}"#, landscape: false)
        _ = showSecondLinePortrait(app)
        app.buttons["player.moveText"].tap()
        XCTAssertTrue(app.descendants(matching: .any)["moveText.sheet"].waitForExistence(timeout: 5))
        let right = app.buttons["moveText.right"]
        XCTAssertEqual(app.staticTexts["moveText.value"].label, "Right 40%")
        XCTAssertFalse(right.isEnabled, "Right dims at 40 % right")
        XCTAssertTrue(app.buttons["moveText.left"].isEnabled, "Left stays enabled")
        XCTAssertEqual(right.value as? String, "40 percent right")
    }

    // MARK: AC-2: each arrow dims at its own limit, with the spoken values of the Aa menu

    @MainActor
    func testArrowsDimAtTheirLimitsPortrait() throws {
        let app = launch(seed: #"{"up":0.9,"right":-0.4}"#, landscape: false)
        let line = showSecondLinePortrait(app)
        let moved = line.frame
        app.buttons["player.moveText"].tap()
        XCTAssertTrue(app.descendants(matching: .any)["moveText.sheet"].waitForExistence(timeout: 5))
        let left = app.buttons["moveText.left"]
        let up = app.buttons["moveText.up"]
        let down = app.buttons["moveText.down"]
        let right = app.buttons["moveText.right"]
        let reset = app.buttons["moveText.reset"]
        XCTAssertEqual(app.staticTexts["moveText.value"].label, "Up 90% · Left 40%")
        XCTAssertFalse(up.isEnabled, "Up dims at 90 %")
        XCTAssertFalse(left.isEnabled, "Left dims at 40 % left")
        XCTAssertTrue(down.isEnabled, "Down stays enabled")
        XCTAssertTrue(right.isEnabled, "Right stays enabled")
        XCTAssertEqual(up.value as? String, "90 percent up")
        XCTAssertEqual(left.value as? String, "40 percent left")
        XCTAssertTrue(reset.isEnabled)
        UITestSupport.attachText(app.debugDescription, name: "tester-move-sheet-limits", to: self)

        reset.tap()
        XCTAssertTrue(UITestSupport.wait(timeout: 5) { app.staticTexts["moveText.value"].label == "Default place" })
        XCTAssertFalse(down.isEnabled, "Down dims at the default height")
        XCTAssertTrue(up.isEnabled, "Up is enabled at the default height")
        XCTAssertTrue(left.isEnabled && right.isEnabled, "Left and Right are enabled when centred")
        XCTAssertEqual(down.value as? String, "At the default height")
        XCTAssertEqual(right.value as? String, "Centred")
        XCTAssertFalse(reset.isEnabled, "Reset is disabled at the default place")
        XCTAssertEqual(app.buttons["player.moveText"].value as? String, "Default place")

        // Reset puts the line back: centred on the video, its bottom on the region's bottom (margin Spacing.m).
        let video = app.descendants(matching: .any)["player.video"].frame
        XCTAssertTrue(UITestSupport.waitForFrame(line, timeout: 5) {
            abs($0.midX - video.midX) <= 1 && abs($0.maxY - (video.maxY - 12)) <= 1
        }, "Reset puts the line back at the default place (now \(line.frame), video \(video), was \(moved))")
        UITestSupport.attachText("moved \(moved)\nreset \(line.frame)\nvideo \(video)", name: "tester-move-reset-frames",
                                 to: self)
    }

    // MARK: AC-4: pausing in landscape, the swipe down, and a rotation

    @MainActor
    func testOpeningTheCardPausesPlaybackAndDoneResumesLandscape() throws {
        let app = launch(seed: nil, landscape: true)
        let playPause = app.buttons["player.playPause"]
        XCTAssertTrue(playPause.waitForExistence(timeout: 5))
        XCTAssertTrue(UITestSupport.tap(playPause, until: { (playPause.value as? String) == "Playing" }),
                      "The video is playing")
        let card = cardElement(app)
        XCTAssertTrue(UITestSupport.tapBarButtonWhilePlaying(app, app.buttons["player.moveText"], until: card),
                      "The card opens while the video plays")

        // Held open well past the 3 s auto-hide: if opening hadn't paused, these seconds would play.
        UITestSupport.settle(heldOpen)
        XCTAssertTrue(card.exists, "The card stays up while it is open")
        XCTAssertFalse(app.descendants(matching: .any)["player.bottomBar"].exists, "The bottom bar stays hidden")
        UITestSupport.tap(app.buttons["moveText.done"], patience: 5) { !card.exists }
        XCTAssertTrue(card.waitForNonExistence(timeout: 5), "Done closes the card")

        let elapsed = elapsedSeconds(app)
        attachText("elapsed after Done: \(elapsed.map { String($0) } ?? "nil") (card held open \(heldOpen) s)",
                   name: "tester-move-landscape-pause")
        XCTAssertNotNil(elapsed, "The elapsed time can be read after Done")
        XCTAssertLessThan(elapsed ?? .infinity, heldOpen,
                          "Opening the card paused the video: the \(heldOpen) s it was open didn't play")
        XCTAssertEqual(playPauseValue(app), "Playing", "Done resumes playback")
    }

    @MainActor
    func testSwipeDownClosesTheSheetAndResumesPortrait() throws {
        let app = launch(seed: nil, landscape: false)
        let playPause = app.buttons["player.playPause"]
        XCTAssertTrue(playPause.waitForExistence(timeout: 5))
        XCTAssertTrue(UITestSupport.tap(playPause, until: { (playPause.value as? String) == "Playing" }),
                      "The video is playing")
        app.buttons["player.moveText"].tap()
        let sheet = app.descendants(matching: .any)["moveText.sheet"]
        XCTAssertTrue(sheet.waitForExistence(timeout: 5), "The sheet opens")
        XCTAssertTrue(UITestSupport.waitForValue(playPause, "Paused", timeout: 5), "Opening the menu pauses the video")
        UITestSupport.settle()

        let title = app.staticTexts["moveText.title"]
        XCTAssertTrue(title.exists)
        let start = title.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        start.press(forDuration: 0.05, thenDragTo: start.withOffset(CGVector(dx: 0, dy: 450)),
                    withVelocity: .fast, thenHoldForDuration: 0)
        XCTAssertTrue(sheet.waitForNonExistence(timeout: 5), "A swipe down closes the sheet")
        XCTAssertTrue(UITestSupport.waitForValue(playPause, "Playing", timeout: 5),
                      "Closed by a swipe down, playback resumes because opening the menu paused it")
    }

    @MainActor
    func testRotationClosesTheMenuWithoutResuming() throws {
        let app = launch(seed: nil, landscape: true)
        let playPause = app.buttons["player.playPause"]
        XCTAssertTrue(playPause.waitForExistence(timeout: 5))
        XCTAssertTrue(UITestSupport.tap(playPause, until: { (playPause.value as? String) == "Playing" }),
                      "The video is playing")
        let card = cardElement(app)
        XCTAssertTrue(UITestSupport.tapBarButtonWhilePlaying(app, app.buttons["player.moveText"], until: card),
                      "The card opens while the video plays")

        XCUIDevice.shared.orientation = .portrait
        XCTAssertTrue(card.waitForNonExistence(timeout: 10), "A rotation closes the card")
        XCTAssertTrue(playPause.waitForExistence(timeout: 10), "The portrait controls show")
        XCTAssertFalse(app.descendants(matching: .any)["moveText.sheet"].exists, "No Move-Text sheet in portrait")
        let first = elapsedSeconds(app)
        UITestSupport.settle(2)
        let second = elapsedSeconds(app)
        attachText("elapsed \(String(describing: first)) then \(String(describing: second)), "
                   + "play/pause \(playPause.value as? String ?? "nil")", name: "tester-move-rotation")
        XCTAssertEqual(playPause.value as? String, "Paused", "A rotation closes the menu without resuming")
        XCTAssertNotNil(first)
        XCTAssertEqual(first, second, "The video stays paused after the rotation")
    }

    // MARK: Helpers

    /// ✥A is on the same row as Aa and right after it.
    @MainActor
    private func checkOrder(_ app: XCUIApplication, state: String) -> String {
        let aa = app.buttons["player.subtitleStyle"]
        let move = app.buttons["player.moveText"]
        XCTAssertTrue(move.waitForExistence(timeout: 5), "The Move-Text button shows (\(state))")
        XCTAssertTrue(aa.exists, "Aa shows (\(state))")
        let space = move.frame.minX - aa.frame.maxX
        XCTAssertEqual(move.frame.minY, aa.frame.minY, accuracy: 2, "Same row as Aa (\(state))")
        XCTAssertGreaterThanOrEqual(space, 0, "After Aa, not over it (\(state))")
        XCTAssertLessThanOrEqual(space, 16, "Right after Aa (\(state), gap \(space))")
        if !move.isHittable { UITestSupport.dismissSystemBanner() }
        XCTAssertTrue(move.isHittable, "The Move-Text button can be tapped (\(state))")
        let bar = app.descendants(matching: .any)["player.bottomBar"].frame
        return "\(state): Aa \(aa.frame), move \(move.frame), gap \(space), bottom bar \(bar)"
    }

    /// The scrubber's elapsed time in seconds ("0:05.0"); the landscape bars are brought back first if they hid.
    @MainActor
    private func elapsedSeconds(_ app: XCUIApplication) -> Double? {
        let label = app.staticTexts["player.currentTime"]
        if !label.exists {
            tapVideo(app)
            _ = label.waitForExistence(timeout: 3)
        }
        guard let text = UITestSupport.readTogether(label)?.label else { return nil }
        let parts = text.split(separator: ":")
        guard parts.count == 2, let minutes = Double(parts[0]), let seconds = Double(parts[1]) else { return nil }
        return minutes * 60 + seconds
    }

    /// `player.playPause` is in the landscape bar, which hides while playing: show the controls first when needed.
    @MainActor
    private func playPauseValue(_ app: XCUIApplication) -> String? {
        let button = app.buttons["player.playPause"]
        if !button.exists {
            tapVideo(app)
            _ = button.waitForExistence(timeout: 3)
        }
        return UITestSupport.readTogether(button)?.value
    }

    @MainActor
    private func cardElement(_ app: XCUIApplication) -> XCUIElement {
        app.descendants(matching: .any)["moveText.card"]
    }

    /// Upper left of the video, clear of the bars, the card, the line and the panel handle (x >= 65 pt in landscape).
    @MainActor
    private func tapVideo(_ app: XCUIApplication) {
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.3, dy: 0.35)).tap()
    }

    /// Launches the player with the 30 s sample, in portrait or landscape (paused, controls up in landscape).
    @MainActor
    private func launch(seed: String?, landscape: Bool) -> XCUIApplication {
        XCUIDevice.shared.orientation = .portrait
        let app = XCUIApplication()
        app.launchArguments += ["-uiTesting", "-uiTestingSampleSeconds", "30"]
        if let seed { app.launchArguments += ["-uiTestingSubtitleStyle", seed] }
        UITestSupport.launchAndOpenSampleEpisode(app)
        XCTAssertTrue(app.descendants(matching: .any)["player.video"].waitForExistence(timeout: 10))
        if landscape {
            UITestSupport.rotateToLandscape(app)
            XCTAssertTrue(app.descendants(matching: .any)["player.video"].waitForExistence(timeout: 10))
            tapVideo(app)
            XCTAssertTrue(app.buttons["player.back"].waitForExistence(timeout: 5), "A tap shows the controls")
        }
        return app
    }

    /// Landscape: seeks to the second line through the side list (paused), then closes the list again.
    @MainActor
    private func showSecondLine(_ app: XCUIApplication) -> XCUIElement {
        let toggle = app.buttons["player.panelToggle"]
        XCTAssertTrue(toggle.waitForExistence(timeout: 5))
        toggle.tap()
        let row = app.descendants(matching: .any)["cue.row.1"]
        XCTAssertTrue(row.waitForExistence(timeout: 10), "The side list shows the second line")
        row.tap()
        let line = app.textViews["player.subtitle"]
        XCTAssertTrue(line.waitForExistence(timeout: 10), "Tapping a line seeks and shows it")
        toggle.tap()
        XCTAssertTrue(app.descendants(matching: .any)["player.sidePanel"].waitForNonExistence(timeout: 5),
                      "The side list closes")
        UITestSupport.settle()
        return line
    }

    /// Portrait: seeks to the second line through the list under the controls (paused).
    @MainActor
    private func showSecondLinePortrait(_ app: XCUIApplication) -> XCUIElement {
        let row = app.descendants(matching: .any)["cue.row.1"]
        XCTAssertTrue(row.waitForExistence(timeout: 10), "The list shows the second line")
        row.tap()
        let line = app.textViews["player.subtitle"]
        XCTAssertTrue(line.waitForExistence(timeout: 10), "Tapping a line seeks and shows it")
        UITestSupport.settle()
        return line
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

    @MainActor
    private func attachText(_ text: String, name: String) {
        UITestSupport.attachText(text, name: name, to: self)
    }

    /// An element screenshot (unrotated and correct in landscape, unlike `app.screenshot()`).
    @MainActor
    private func attachElementShot(_ element: XCUIElement, name: String) {
        let attachment = XCTAttachment(screenshot: element.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
