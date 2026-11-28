import XCTest

/// T-016: the landscape subtitle style card. The "Aa" button in the bottom bar swaps the bar for the card
/// (`subtitleStyle.card`), which holds the 9 controls, keeps the controls up, pushes the line above it, and closes on
/// Done, a tap on the video or a rotation. Uses the seeded "Sample Show": a 6-second video paused at 0:00, with lines
/// at 0.5-2.0, 2.0-4.0 and 4.0-5.5 s.
///
/// Evidence follows the landscape tips in CONTEXT.md: `XCUIElement.screenshot()` of the video (not
/// `app.screenshot()`, which comes out rotated and cropped) and `app.debugDescription` as text. The card is an
/// `.accessibilityElement(children: .contain)` container, so its reported frame is the union of its controls: the
/// checks that need real edges use the controls themselves.
final class SubtitleStyleCardUITests: XCTestCase {
    private let controlIDs = [
        "subtitleStyle.font.sans", "subtitleStyle.font.rounded", "subtitleStyle.font.serif",
        "subtitleStyle.font.more", "subtitleStyle.bold", "subtitleStyle.sizeDown", "subtitleStyle.sizeUp",
        "subtitleStyle.reset", "subtitleStyle.done",
    ]

    override func setUp() {
        continueAfterFailure = false
    }

    override func tearDown() async throws {
        await MainActor.run { XCUIDevice.shared.orientation = .portrait }
        try await super.tearDown()
    }

    // MARK: AC-6 (a): the controls stay up

    /// Play from the first cue, open the card, and watch the top bar's back button and the card for 3.5 s. The
    /// sample is 6 s long: play starts about 1.5 s before the card opens (the same timing as
    /// `testOpenSubtitlesMenuKeepsControlsUpWhilePlaying`). Opening the card restarts the hide timer, so with the
    /// rule broken the bar hides 3 s after opening, inside the 3.5 s window, and the end of playback (which would
    /// bring the controls back by itself) comes only about 4.5 s after opening.
    @MainActor
    func testCardKeepsTheControlsUpWhilePlaying() throws {
        let app = launchLandscape(seed: nil)
        let playPause = app.buttons["player.playPause"]
        XCTAssertTrue(playPause.waitForExistence(timeout: 5))
        playPause.tap()
        openCard(app)

        let back = app.buttons["player.back"]
        let card = cardElement(app)
        XCTAssertTrue(back.exists, "Controls are up when the card opens")
        XCTAssertTrue(app.buttons["subtitleStyle.done"].exists)
        let deadline = Date().addingTimeInterval(3.5)
        while Date() < deadline {
            XCTAssertTrue(back.exists, "Controls stay up while the card is open and the video plays")
            XCTAssertTrue(card.exists, "The card is not torn down by the auto-hide")
            RunLoop.current.run(until: Date().addingTimeInterval(0.4))
        }
        XCTAssertFalse(app.buttons["player.makeCard"].exists, "The card replaces the bottom bar")
        attachEvidence(app, name: "landscape-style-01-card")
    }

    // MARK: AC-6 (b): live changes, the line stays above the card

    @MainActor
    func testSizeChangesTheLineLiveAndItStaysAboveTheCard() throws {
        let app = launchLandscape(seed: nil)
        _ = showSecondLine(app)
        openCard(app)
        settle()
        let card = cardElement(app)
        let before = app.textViews["player.subtitle"].frame
        XCTAssertLessThanOrEqual(before.maxY, card.frame.minY + 1, "The default line is already above the card")

        let sizeUp = app.buttons["subtitleStyle.sizeUp"]
        for _ in 0..<2 { sizeUp.tap() }
        settle()

        let after = app.textViews["player.subtitle"].frame
        XCTAssertGreaterThan(after.height, before.height, "Size up x2 makes a taller line")
        XCTAssertGreaterThan(after.width, before.width, "Size up x2 makes a wider line")
        XCTAssertLessThan(after.minY, before.minY, "A bigger line, lifted above the card, moves the top edge up")
        XCTAssertLessThanOrEqual(after.maxY, card.frame.minY + 1, "The line stays above the card")
        let top = app.descendants(matching: .any)["player.topBar"]
        XCTAssertGreaterThanOrEqual(after.minY, top.frame.maxY - 1, "The line stays below the top bar")
        XCTAssertEqual(app.buttons["subtitleStyle.sizeUp"].value as? String, "120 percent", "VoiceOver reads the size")
        attachEvidence(app, name: "landscape-style-03-live")
    }

    // MARK: AC-1, AC-2, AC-6 (c): the panel at 50 %

    @MainActor
    func testEveryControlIsHittableInsideTheVideoColumnWithThePanelAt50Percent() throws {
        let app = launchLandscape(seed: #"{"sizeStep":1}"#)
        let toggle = app.buttons["player.panelToggle"]
        XCTAssertTrue(toggle.waitForExistence(timeout: 5))
        toggle.tap()
        let panel = app.descendants(matching: .any)["player.sidePanel"]
        let handle = app.descendants(matching: .any)["player.panelHandle"]
        XCTAssertTrue(panel.waitForExistence(timeout: 5))
        XCTAssertTrue(handle.waitForExistence(timeout: 5))
        let start = handle.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        start.press(forDuration: 0.1, thenDragTo: start.withOffset(CGVector(dx: 2 - handle.frame.midX, dy: 0)))
        waitUntilSettled(panel)
        let window = app.windows.firstMatch.frame
        XCTAssertGreaterThan(panel.frame.width, window.width * 0.4, "The panel is at its widest")

        // AC-1: the opener fits in the bottom bar with the panel at 50 %, inside the video column.
        let opener = app.buttons["player.subtitleStyle"]
        XCTAssertTrue(opener.waitForExistence(timeout: 5), "The style button is in the bottom bar")
        XCTAssertTrue(opener.isHittable, "The style button is hittable at 50 %")
        XCTAssertLessThanOrEqual(opener.frame.maxX, panel.frame.minX, "The style button is inside the video column")
        XCTAssertTrue(app.buttons["player.subtitlesMenu"].isHittable, "The subtitles button is still hittable")
        XCTAssertGreaterThan(opener.frame.minX, app.buttons["player.subtitlesMenu"].frame.maxX - 1,
                             "The style button sits next to the subtitles button")

        opener.tap()
        XCTAssertTrue(app.buttons["subtitleStyle.done"].waitForExistence(timeout: 5), "The card opens")
        settle()
        let card = cardElement(app)
        XCTAssertLessThanOrEqual(card.frame.maxX, panel.frame.minX + 1, "The card is inside the video column")
        for id in controlIDs {
            let control = app.buttons[id]
            XCTAssertTrue(control.exists, "\(id) is in the card")
            XCTAssertTrue(control.isHittable, "\(id) is hittable at 50 %")
            XCTAssertGreaterThanOrEqual(control.frame.minX, window.minX, "\(id) is inside the screen")
            XCTAssertLessThanOrEqual(control.frame.maxX, panel.frame.minX + 1, "\(id) is inside the video column")
            XCTAssertLessThanOrEqual(control.frame.maxY, window.maxY, "\(id) is inside the screen")
        }
        let measured = controlIDs.map { "\($0) \(app.buttons[$0].frame)" }.joined(separator: "\n")
        attachText("card \(card.frame)\npanel \(panel.frame)\nwindow \(window)\n\(measured)", name: "landscape-style-02-panel-50-controls")
        attachEvidence(app, name: "landscape-style-02-panel-50")
    }

    // MARK: AC-6 (d): closing

    @MainActor
    func testDoneAVideoTapAndARotationEachCloseTheCard() throws {
        let app = launchLandscape(seed: nil)
        let card = cardElement(app)
        let back = app.buttons["player.back"]

        openCard(app)
        app.buttons["subtitleStyle.done"].tap()
        XCTAssertTrue(card.waitForNonExistence(timeout: 5), "Done closes the card")
        XCTAssertTrue(app.buttons["player.makeCard"].waitForExistence(timeout: 5), "The bottom bar comes back")

        openCard(app)
        tapVideo(app)
        XCTAssertTrue(card.waitForNonExistence(timeout: 5), "A tap on the video closes the card")
        RunLoop.current.run(until: Date().addingTimeInterval(0.8))
        XCTAssertTrue(back.exists, "That tap only closes the card; it doesn't also hide the controls")
        XCTAssertTrue(app.buttons["player.makeCard"].exists, "The bottom bar is back")

        openCard(app)
        XCUIDevice.shared.orientation = .portrait
        XCTAssertTrue(card.waitForNonExistence(timeout: 10), "A rotation closes the card")
        XCUIDevice.shared.orientation = .landscapeLeft
        XCTAssertTrue(app.descendants(matching: .any)["player.video"].waitForExistence(timeout: 10))
        RunLoop.current.run(until: Date().addingTimeInterval(1))
        XCTAssertFalse(card.exists, "The card does not come back after rotating again")
    }

    // MARK: T-024b: two resets, two jobs

    /// Font Reset restores Sans at 100 % and leaves the moved place alone, and the card has no arrows. The expected line is
    /// the one a position-only seed draws with the same bar and panel state, so the old font can't shift the comparison.
    @MainActor
    func testFontResetRestoresTheFontAndKeepsThePlaceLandscape() throws {
        let referenceApp = launchLandscape(seed: #"{"up":0.30,"right":-0.20}"#)
        let moved = showSecondLine(referenceApp).frame
        XCTAssertEqual(referenceApp.buttons["player.subtitleStyle"].value as? String, "Default",
                       "T-024b AC-3: a moved line alone doesn't light Aa")
        referenceApp.terminate()

        let app = launchLandscape(seed: #"{"font":"serif","sizeStep":3,"up":0.30,"right":-0.20}"#)
        let line = showSecondLine(app)
        openCard(app)
        for id in ["up", "down", "left", "right"] {
            XCTAssertFalse(app.buttons["subtitleStyle.\(id)"].exists, "The card has no \(id) arrow")
        }
        let reset = app.buttons["subtitleStyle.reset"]
        XCTAssertTrue(reset.isEnabled, "Reset is enabled while the font group isn't the default")
        XCTAssertEqual(reset.value as? String, "Changed")
        reset.tap()
        XCTAssertTrue(UITestSupport.wait(timeout: 5) { !reset.isEnabled }, "Reset disables itself at the default font group")
        XCTAssertEqual(reset.value as? String, "Already the default")
        XCTAssertEqual(app.buttons["subtitleStyle.sizeUp"].value as? String, "100 percent")
        XCTAssertTrue(app.buttons["subtitleStyle.font.sans"].isSelected, "Reset picks Sans")
        app.buttons["subtitleStyle.done"].tap()
        XCTAssertTrue(cardElement(app).waitForNonExistence(timeout: 5))
        settle()

        XCTAssertEqual(app.buttons["player.moveText"].value as? String, "Up 30% · Left 20%", "The place is left alone")
        let after = line.frame
        for (name, now, was) in [("minX", after.minX, moved.minX), ("minY", after.minY, moved.minY),
                                 ("width", after.width, moved.width), ("height", after.height, moved.height)] {
            XCTAssertEqual(now, was, accuracy: 1, "\(name) stays at the moved place")
        }
        attachText("moved \(moved)\nafter \(after)", name: "font-reset-keeps-place")
    }

    /// Move-Text Reset puts the line back and leaves the serif font and the size alone (landscape; the portrait twin
    /// is MoveTextUITests/testResetPutsTheLineBackAndKeepsTheFontPortrait).
    @MainActor
    func testMoveTextResetKeepsTheFontAndSizeLandscape() throws {
        let app = launchLandscape(seed: #"{"font":"serif","sizeStep":3,"up":0.30,"right":-0.20}"#)
        _ = showSecondLine(app)
        app.buttons["player.moveText"].tap()
        let moveCard = app.descendants(matching: .any)["moveText.card"]
        XCTAssertTrue(moveCard.waitForExistence(timeout: 5), "The Move-Text card opens")
        let reset = app.buttons["moveText.reset"]
        XCTAssertTrue(reset.isEnabled, "Reset is enabled away from the default place")
        reset.tap()
        XCTAssertTrue(UITestSupport.wait(timeout: 5) { !reset.isEnabled }, "Reset restores the default place")
        app.buttons["moveText.done"].tap()
        XCTAssertTrue(moveCard.waitForNonExistence(timeout: 5))
        XCTAssertEqual(app.buttons["player.moveText"].value as? String, "Default place")

        openCard(app)
        XCTAssertEqual(app.buttons["subtitleStyle.sizeUp"].value as? String, "130 percent", "The size is left alone")
        XCTAssertTrue(app.buttons["subtitleStyle.font.serif"].isSelected, "The serif font is left alone")
    }

    // MARK: AC-6 (e): More fonts

    @MainActor
    func testMoreFontsOpensThePickerAndCancelReturnsToTheOpenCard() throws {
        let app = launchLandscape(seed: nil)
        openCard(app)
        let more = app.buttons["subtitleStyle.font.more"]
        XCTAssertEqual(more.label, "More fonts")
        XCTAssertEqual(more.value as? String, "None")
        more.tap()

        // iOS 26 gives the picker an X button labelled "close" instead of "Cancel" (CONTEXT.md Learned).
        let cancel = app.buttons.matching(NSPredicate(format: "label IN %@", ["Cancel", "close", "Close"])).firstMatch
        let search = app.searchFields.firstMatch
        XCTAssertTrue(search.waitForExistence(timeout: 15) || cancel.waitForExistence(timeout: 5),
                      "The system font picker opens")
        XCTAssertTrue(cancel.waitForExistence(timeout: 5), "The picker has a close button")
        cancel.tap()
        XCTAssertTrue(cancel.waitForNonExistence(timeout: 10), "Closing dismisses the picker")

        XCTAssertTrue(app.buttons["subtitleStyle.done"].waitForExistence(timeout: 5), "The card is still open")
        XCTAssertTrue(app.buttons["player.back"].exists, "The controls are still up")
        XCTAssertEqual(app.buttons["subtitleStyle.font.more"].value as? String, "None", "Cancel changes nothing")
        XCTAssertTrue(app.buttons["subtitleStyle.font.sans"].isSelected, "Sans is still selected")
    }

    // MARK: Chips and the picked font

    @MainActor
    func testPresetChipsSelectAndAPickedFontShowsItsNameOnMoreFonts() throws {
        let app = launchLandscape(seed: #"{"pickedFontName":"Georgia"}"#)
        openCard(app)
        let more = app.buttons["subtitleStyle.font.more"]
        XCTAssertEqual(more.value as? String, "Georgia", "VoiceOver reads the picked font's name")
        XCTAssertTrue(more.isSelected, "More fonts is aqua while a font is picked")
        XCTAssertFalse(app.buttons["subtitleStyle.font.sans"].isSelected)
        XCTAssertEqual(app.buttons["subtitleStyle.font.serif"].label, "Serif font")

        app.buttons["subtitleStyle.font.serif"].tap()
        settle()
        XCTAssertTrue(app.buttons["subtitleStyle.font.serif"].isSelected, "A preset chip selects")
        XCTAssertFalse(app.buttons["subtitleStyle.font.more"].isSelected, "A preset clears the picked font")
        XCTAssertEqual(app.buttons["subtitleStyle.font.more"].value as? String, "None")
        attachEvidence(app, name: "landscape-style-04-chips")
    }

    // MARK: T-017 C1: a bold-only family

    @MainActor
    func testABoldOnlyFontSaysItIsAlwaysBold() throws {
        XCUIDevice.shared.orientation = .portrait
        let app = XCUIApplication()
        app.launchArguments += ["-uiTesting", "-uiTestingSubtitleStyle", #"{"bold":false,"pickedFontName":"ArialRoundedMTBold"}"#]
        let showTile = UITestSupport.launchSeeded(app)
        showTile.tap()
        let episodeRow = app.buttons["episode.row.Episode 1"]
        XCTAssertTrue(episodeRow.waitForExistence(timeout: 5))
        episodeRow.tap()
        let opener = app.buttons["player.subtitleStyle"]
        XCTAssertTrue(opener.waitForExistence(timeout: 10))
        opener.tap()
        XCTAssertTrue(app.buttons["subtitleStyle.done"].waitForExistence(timeout: 5))
        let note = app.staticTexts["subtitleStyle.font.alwaysBold"]
        XCTAssertTrue(note.waitForExistence(timeout: 3), "The always-bold note shows")
        XCTAssertEqual(note.label, "This font is always bold.")
        XCTAssertFalse(app.staticTexts["subtitleStyle.font.noBold"].exists, "It is not reported as having no bold")
    }

    // MARK: Helpers

    /// Launches, opens Episode 1, rotates to landscape and brings the controls up (the player is paused, so they stay).
    @MainActor
    private func launchLandscape(seed: String?) -> XCUIApplication {
        XCUIDevice.shared.orientation = .portrait
        let app = XCUIApplication()
        app.launchArguments += ["-uiTesting"]
        if let seed { app.launchArguments += ["-uiTestingSubtitleStyle", seed] }
        let showTile = UITestSupport.launchSeeded(app)
        showTile.tap()
        let episodeRow = app.buttons["episode.row.Episode 1"]
        XCTAssertTrue(episodeRow.waitForExistence(timeout: 5))
        episodeRow.tap()
        UITestSupport.rotateToLandscape(app)
        XCTAssertTrue(app.descendants(matching: .any)["player.video"].waitForExistence(timeout: 10))
        tapVideo(app)
        XCTAssertTrue(app.buttons["player.back"].waitForExistence(timeout: 5), "A tap shows the controls")
        return app
    }

    @MainActor
    private func cardElement(_ app: XCUIApplication) -> XCUIElement {
        app.descendants(matching: .any)["subtitleStyle.card"]
    }

    @MainActor
    private func openCard(_ app: XCUIApplication) {
        let opener = app.buttons["player.subtitleStyle"]
        XCTAssertTrue(opener.waitForExistence(timeout: 10), "The bottom bar has the style button")
        opener.tap()
        XCTAssertTrue(app.buttons["subtitleStyle.done"].waitForExistence(timeout: 5), "The style card opens")
        XCTAssertTrue(cardElement(app).exists, "The card container exists")
    }

    /// Opens the subtitle list, seeks to the second line, and returns the line (the panel stays open at 25 %).
    @MainActor
    private func showSecondLine(_ app: XCUIApplication) -> XCUIElement {
        let toggle = app.buttons["player.panelToggle"]
        XCTAssertTrue(toggle.waitForExistence(timeout: 5))
        toggle.tap()
        let row = app.descendants(matching: .any)["cue.row.1"]
        XCTAssertTrue(row.waitForExistence(timeout: 10), "The side list shows the lines")
        row.tap()
        let line = app.textViews["player.subtitle"]
        XCTAssertTrue(line.waitForExistence(timeout: 10), "Tapping a line seeks and shows it")
        settle()
        return line
    }

    /// Upper left of the screen: on the video, clear of the bars, the card, the line and the panel handle.
    @MainActor
    private func tapVideo(_ app: XCUIApplication) {
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.3, dy: 0.35)).tap()
    }

    /// Lets the 0.2 s placement animation, the card's transition and the controls' fade finish.
    @MainActor
    private func settle() {
        RunLoop.current.run(until: Date().addingTimeInterval(0.8))
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
        let attachment = XCTAttachment(string: text)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    /// The video's element screenshot (unrotated and correct in landscape, and it includes the card drawn over it)
    /// and the whole accessibility tree with every frame.
    @MainActor
    private func attachEvidence(_ app: XCUIApplication, name: String) {
        let video = app.descendants(matching: .any)["player.video"]
        let shot = XCTAttachment(screenshot: video.screenshot())
        shot.name = name
        shot.lifetime = .keepAlways
        add(shot)
        attachText(app.debugDescription, name: name + "-frames")
    }
}
