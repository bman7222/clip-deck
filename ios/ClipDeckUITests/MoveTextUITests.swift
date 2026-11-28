import XCTest

/// T-024a: the Move-Text button (✥A) after Aa, its portrait sheet and landscape card, pausing while it is open,
/// the hidden centred overlay, Reset (position only), and the blue outline.
///
/// The seeded "Sample Show" is a 30 s video (`-uiTestingSampleSeconds 30`), so a slow runner can't play it to its
/// end; the subtitles are in its first seconds. Timing rules: wait on state, never on a fixed sleep.
final class MoveTextUITests: XCTestCase {
    /// The portrait region's margins (`SubtitleMargins` defaults: Spacing.s, l, m, l), for the 5 % step.
    private let portraitRegionInsetX: CGFloat = 32
    private let portraitRegionInsetY: CGFloat = 20
    /// Outline gap, and the line's frame measured against it (±1 pt).
    private let gap: CGFloat = 6

    override func setUp() {
        continueAfterFailure = false
    }

    override func tearDown() async throws {
        await MainActor.run { XCUIDevice.shared.orientation = .portrait }
        try await super.tearDown()
    }

    // MARK: AC-1: the button sits right after Aa

    @MainActor func testButtonSitsAfterAaPortrait() throws { try checkButtonOrder(landscape: false) }
    @MainActor func testButtonSitsAfterAaLandscape() throws { try checkButtonOrder(landscape: true) }

    @MainActor
    private func checkButtonOrder(landscape: Bool) throws {
        let app = launch(seed: nil, landscape: landscape)
        let aa = app.buttons["player.subtitleStyle"]
        let move = app.buttons["player.moveText"]
        XCTAssertTrue(move.waitForExistence(timeout: 5), "The Move-Text button shows")
        XCTAssertEqual(move.label, "Move subtitles")
        XCTAssertEqual(move.value as? String, "Default place", "Idle at the default place")
        XCTAssertEqual(move.frame.minY, aa.frame.minY, accuracy: 2, "Same row as Aa")
        let space = move.frame.minX - aa.frame.maxX
        XCTAssertGreaterThanOrEqual(space, 0, "After Aa, not over it")
        XCTAssertLessThanOrEqual(space, 16, "Right after Aa (gap \(space))")
        UITestSupport.attachText(app.debugDescription, name: "move-button-\(landscape ? "landscape" : "portrait")", to: self)
    }

    // MARK: AC-2, AC-4, AC-4b: the portrait sheet, pausing and the overlay

    @MainActor
    func testSheetPausesAndDoneResumesPortrait() throws {
        let app = launch(seed: nil, landscape: false)
        let playPause = app.buttons["player.playPause"]
        XCTAssertTrue(playPause.waitForExistence(timeout: 5))
        XCTAssertTrue(UITestSupport.tap(playPause, until: { (playPause.value as? String) == "Playing" }),
                      "The video is playing")

        app.buttons["player.moveText"].tap()
        let sheet = app.descendants(matching: .any)["moveText.sheet"]
        XCTAssertTrue(sheet.waitForExistence(timeout: 5), "The sheet opens")
        XCTAssertTrue(UITestSupport.waitForValue(playPause, "Paused", timeout: 5), "Opening the menu pauses the video")
        XCTAssertTrue(app.staticTexts["moveText.title"].exists)
        for id in ["left", "up", "down", "right", "reset", "done"] {
            XCTAssertTrue(app.buttons["moveText.\(id)"].exists, "The sheet has \(id)")
        }
        let video = app.descendants(matching: .any)["player.video"].frame
        XCTAssertGreaterThanOrEqual(app.staticTexts["moveText.title"].frame.minY, video.maxY,
                                    "The sheet leaves the video visible")
        UITestSupport.attachText(app.debugDescription, name: "move-sheet-open", to: self)

        app.buttons["moveText.done"].tap()
        XCTAssertTrue(sheet.waitForNonExistence(timeout: 5), "Done closes the sheet")
        XCTAssertTrue(UITestSupport.waitForValue(playPause, "Playing", timeout: 5), "Done resumes playback")
    }

    @MainActor
    func testOpenedWhilePausedStaysPausedAndTheOverlayReturnsPortrait() throws {
        let app = launch(seed: nil, landscape: false)
        let playPause = app.buttons["player.playPause"]
        XCTAssertTrue(playPause.waitForExistence(timeout: 5))
        XCTAssertEqual(playPause.value as? String, "Paused", "The player starts paused")
        // Show the overlay (portrait starts with it hidden).
        let overlay = app.buttons["player.overlay.playPause"]
        tapVideo(app)
        XCTAssertTrue(overlay.waitForExistence(timeout: 5), "A tap on the video shows the overlay")

        app.buttons["player.moveText"].tap()
        let sheet = app.descendants(matching: .any)["moveText.sheet"]
        XCTAssertTrue(sheet.waitForExistence(timeout: 5))
        XCTAssertTrue(overlay.waitForNonExistence(timeout: 5), "No overlay button while the menu is open")
        for id in ["back5", "playPause", "forward5"] {
            XCTAssertFalse(app.buttons["player.overlay.\(id)"].exists, "No overlay \(id) while the menu is open")
        }

        app.buttons["moveText.done"].tap()
        XCTAssertTrue(sheet.waitForNonExistence(timeout: 5))
        XCTAssertTrue(overlay.waitForExistence(timeout: 5), "The overlay is back after Done")
        XCTAssertEqual(playPause.value as? String, "Paused", "Opened while paused, Done leaves it paused")
    }

    @MainActor
    func testATapOnTheVideoClosesTheSheetPortrait() throws {
        let app = launch(seed: nil, landscape: false)
        app.buttons["player.moveText"].tap()
        let sheet = app.descendants(matching: .any)["moveText.sheet"]
        XCTAssertTrue(sheet.waitForExistence(timeout: 5))
        tapVideo(app)
        XCTAssertTrue(sheet.waitForNonExistence(timeout: 5), "A tap on the video closes the sheet")
    }

    // MARK: AC-2, AC-5: arrows, Reset and the outline (portrait)

    @MainActor
    func testUpAndRightMoveTheLineByFivePercentPortrait() throws {
        let app = launch(seed: nil, landscape: false)
        let line = showSecondLine(app, landscape: false)
        let video = app.descendants(matching: .any)["player.video"].frame
        let regionHeight = video.height - portraitRegionInsetY
        let regionWidth = video.width - portraitRegionInsetX

        app.buttons["player.moveText"].tap()
        XCTAssertTrue(app.descendants(matching: .any)["moveText.sheet"].waitForExistence(timeout: 5))
        let value = app.staticTexts["moveText.value"]
        XCTAssertEqual(value.label, "Default place")
        let start = line.frame

        // The value line is a Text with no accessibility value, so each step is read from a button's spoken value.
        let down = app.buttons["moveText.down"]
        let left = app.buttons["moveText.left"]
        XCTAssertTrue(UITestSupport.tapStep(app.buttons["moveText.up"], reader: down, from: UITestSupport.upText(0),
                                            to: UITestSupport.upText(5)))
        XCTAssertEqual(value.label, "Up 5%")
        XCTAssertTrue(UITestSupport.waitForFrame(line, timeout: 5) { abs($0.minY - (start.minY - regionHeight * 0.05)) <= 1 },
                      "Up moves the line up by 5 % of the region (\(regionHeight * 0.05) pt); now \(line.frame), was \(start)")
        let afterUp = line.frame
        XCTAssertTrue(UITestSupport.tapStep(app.buttons["moveText.right"], reader: left, from: "Centred",
                                            to: "5 percent right"))
        XCTAssertEqual(value.label, "Up 5% · Right 5%")
        XCTAssertTrue(UITestSupport.waitForFrame(line, timeout: 5) { abs($0.minX - (afterUp.minX + regionWidth * 0.05)) <= 1 },
                      "Right moves the line right by 5 % of the region (\(regionWidth * 0.05) pt); now \(line.frame)")
        XCTAssertEqual(app.buttons["player.moveText"].value as? String, "Up 5% · Right 5%", "The button speaks the place")
        UITestSupport.attachText("start \(start)\nafterUp \(afterUp)\nafterRight \(line.frame)\nregion \(regionWidth) x \(regionHeight)",
                                 name: "move-steps", to: self)
    }

    @MainActor
    func testResetPutsTheLineBackAndKeepsTheFontPortrait() throws {
        let app = launch(seed: #"{"font":"serif","bold":false,"sizeStep":5,"up":0.2,"right":-0.2}"#, landscape: false)
        _ = showSecondLine(app, landscape: false)
        app.buttons["player.moveText"].tap()
        XCTAssertTrue(app.descendants(matching: .any)["moveText.sheet"].waitForExistence(timeout: 5))
        let value = app.staticTexts["moveText.value"]
        XCTAssertEqual(value.label, "Up 20% · Left 20%")
        let reset = app.buttons["moveText.reset"]
        XCTAssertTrue(reset.isEnabled, "Reset is enabled away from the default place")
        reset.tap()
        XCTAssertTrue(UITestSupport.wait(timeout: 5) { value.label == "Default place" }, "Reset restores the place")
        XCTAssertFalse(reset.isEnabled, "Reset is disabled at the default place")
        app.buttons["moveText.done"].tap()
        XCTAssertTrue(app.descendants(matching: .any)["moveText.sheet"].waitForNonExistence(timeout: 5))

        // The font group stays: the Aa menu still shows a serif font at 150 %.
        app.buttons["player.subtitleStyle"].tap()
        let sizeUp = app.buttons["subtitleStyle.sizeUp"]
        XCTAssertTrue(sizeUp.waitForExistence(timeout: 5))
        XCTAssertEqual(sizeUp.value as? String, "150 percent", "The size is left alone")
        XCTAssertTrue(app.buttons["subtitleStyle.font.serif"].isSelected, "The serif font is left alone")
    }

    @MainActor
    func testOutlineSitsSixPointsOutsideTheLinePortrait() throws {
        let app = launch(seed: nil, landscape: false)
        let line = showSecondLine(app, landscape: false)
        let outline = app.descendants(matching: .any)["moveText.outline"]
        XCTAssertFalse(outline.exists, "No outline while the menu is closed")
        app.buttons["player.moveText"].tap()
        XCTAssertTrue(outline.waitForExistence(timeout: 5), "The outline shows while the menu is open")
        // Let the sheet and any placement settle.
        UITestSupport.settle()
        assertOutline(outline.frame, around: line.frame, message: "with a line")
        UITestSupport.attachText("line \(line.frame)\noutline \(outline.frame)", name: "move-outline-line", to: self)
        UITestSupport.attachScreenshot(app, name: "move-outline-line", to: self)

        app.buttons["moveText.done"].tap()
        XCTAssertTrue(outline.waitForNonExistence(timeout: 5), "The outline goes when the menu closes")
    }

    @MainActor
    func testOutlineFramesASampleWhenNoLineIsShowingPortrait() throws {
        let app = launch(seed: nil, landscape: false)
        // Near the end of the 30 s clip no cue is on screen.
        let slider = app.sliders.firstMatch
        XCTAssertTrue(slider.waitForExistence(timeout: 5))
        slider.adjust(toNormalizedSliderPosition: 0.97)
        XCTAssertTrue(app.textViews["player.subtitle"].waitForNonExistence(timeout: 10), "No line is on screen")

        app.buttons["player.moveText"].tap()
        let outline = app.descendants(matching: .any)["moveText.outline"]
        XCTAssertTrue(outline.waitForExistence(timeout: 5), "The outline shows with no line")
        let sample = app.textViews["moveText.sample"]
        XCTAssertTrue(sample.waitForExistence(timeout: 5), "A sample line stands in for the missing line")
        UITestSupport.settle()
        assertOutline(outline.frame, around: sample.frame, message: "with the sample")
        UITestSupport.attachText("sample \(sample.frame)\noutline \(outline.frame)", name: "move-outline-sample", to: self)
        UITestSupport.attachScreenshot(app, name: "move-outline-sample", to: self)
        app.buttons["moveText.done"].tap()
        XCTAssertTrue(outline.waitForNonExistence(timeout: 5), "The outline goes when the menu closes")
        XCTAssertFalse(sample.exists, "The sample goes too")
    }

    // MARK: AC-3, AC-4, AC-4b, AC-5: the landscape card

    @MainActor
    func testCardReplacesTheBarsAndPausesLandscape() throws {
        let app = launch(seed: nil, landscape: true)
        let playPause = app.buttons["player.playPause"]
        XCTAssertTrue(playPause.waitForExistence(timeout: 5))
        UITestSupport.tap(playPause, until: { (playPause.value as? String) == "Playing" })
        // The bars hide 3 s after Play: go straight to the button.
        let move = app.buttons["player.moveText"]
        XCTAssertTrue(UITestSupport.tap(move, patience: 1.5, until: {
            app.descendants(matching: .any)["moveText.card"].exists
        }), "The card opens (Move-Text tapped while the bar was up)")

        XCTAssertFalse(app.descendants(matching: .any)["player.topBar"].exists, "The top bar gives way to the card")
        XCTAssertFalse(app.descendants(matching: .any)["player.bottomBar"].exists, "The bottom bar is hidden")
        for id in ["back5", "playPause", "forward5"] {
            XCTAssertFalse(app.buttons["player.overlay.\(id)"].exists, "No overlay \(id) while the card is open")
        }
        for id in ["left", "up", "down", "right", "reset", "done"] {
            XCTAssertTrue(app.buttons["moveText.\(id)"].exists, "The card has \(id)")
        }
        UITestSupport.attachText(app.debugDescription, name: "move-card-open", to: self)

        // Playback was paused by opening the menu: closing it resumes. The bar returns with the controls.
        app.buttons["moveText.done"].tap()
        XCTAssertTrue(app.descendants(matching: .any)["moveText.card"].waitForNonExistence(timeout: 5), "Done closes the card")
        XCTAssertEqual(playPauseValue(app), "Playing", "Done resumes playback")
    }

    @MainActor
    func testOpenedWhilePausedStaysPausedAndTheOverlayReturnsLandscape() throws {
        let app = launch(seed: nil, landscape: true)
        let playPause = app.buttons["player.playPause"]
        XCTAssertTrue(playPause.waitForExistence(timeout: 5))
        XCTAssertEqual(playPause.value as? String, "Paused")
        let overlay = app.buttons["player.overlay.playPause"]
        XCTAssertTrue(overlay.waitForExistence(timeout: 5), "The overlay shows with the controls")

        app.buttons["player.moveText"].tap()
        let card = app.descendants(matching: .any)["moveText.card"]
        XCTAssertTrue(card.waitForExistence(timeout: 5))
        XCTAssertTrue(overlay.waitForNonExistence(timeout: 5), "No overlay button while the card is open")

        app.buttons["moveText.done"].tap()
        XCTAssertTrue(card.waitForNonExistence(timeout: 5))
        XCTAssertTrue(overlay.waitForExistence(timeout: 5), "The overlay is back after Done")
        XCTAssertEqual(playPauseValue(app), "Paused", "Opened while paused, Done leaves it paused")
    }

    @MainActor
    func testUpDimsAtHighestJustUnderTheCardLandscape() throws {
        let app = launch(seed: nil, landscape: true)
        let line = showSecondLine(app, landscape: true)
        app.buttons["player.moveText"].tap()
        let card = app.descendants(matching: .any)["moveText.card"]
        XCTAssertTrue(card.waitForExistence(timeout: 5))
        XCTAssertTrue(app.descendants(matching: .any)["moveText.outline"].waitForExistence(timeout: 5),
                      "The outline shows around the line")
        UITestSupport.settle()

        let up = app.buttons["moveText.up"]
        var frames = ["start \(line.frame)"]
        var taps = 0
        while up.isEnabled, taps < 25 {
            let before = line.frame.minY
            up.tap()
            taps += 1
            let moved = UITestSupport.waitForFrame(line, timeout: 5) { abs($0.minY - before) > 1 }
            frames.append("tap \(taps): \(line.frame)")
            if !moved {
                // The tap landed as the last step, or was lost: only the dimmed button explains a line that stays.
                UITestSupport.settle()
                XCTAssertFalse(up.isEnabled, "Up is still enabled but tap \(taps) didn't move the line (\(line.frame))")
            }
        }
        UITestSupport.attachText(frames.joined(separator: "\n"), name: "move-card-up-taps", to: self)
        XCTAssertGreaterThan(taps, 1, "Up moved the line more than once")
        XCTAssertFalse(up.isEnabled, "Up dims once the line can't move further")
        XCTAssertEqual(up.value as? String, "Highest")
        let gapUnderCard = line.frame.minY - card.frame.maxY
        XCTAssertEqual(gapUnderCard, 8, accuracy: 2, "The line sits just under the card (gap \(gapUnderCard))")
        attachText(app.debugDescription, name: "move-card-highest")
    }

    @MainActor
    func testOutlineSitsSixPointsOutsideTheLineLandscape() throws {
        let app = launch(seed: nil, landscape: true)
        let line = showSecondLine(app, landscape: true)
        app.buttons["player.moveText"].tap()
        let outline = app.descendants(matching: .any)["moveText.outline"]
        XCTAssertTrue(outline.waitForExistence(timeout: 5))
        UITestSupport.settle()
        assertOutline(outline.frame, around: line.frame, message: "with a line, landscape")
        UITestSupport.attachText("line \(line.frame)\noutline \(outline.frame)", name: "move-outline-landscape", to: self)
    }

    // MARK: T-025: dragging the outline

    @MainActor func testDraggingTheOutlineMovesTheLinePortrait() throws { try checkDrag(landscape: false) }
    @MainActor func testDraggingTheOutlineMovesTheLineLandscape() throws { try checkDrag(landscape: true) }

    @MainActor
    private func checkDrag(landscape: Bool) throws {
        let app = launch(seed: nil, landscape: landscape)
        let line = showSecondLine(app, landscape: landscape)
        app.buttons["player.moveText"].tap()
        let outline = app.descendants(matching: .any)["moveText.outline"]
        XCTAssertTrue(outline.waitForExistence(timeout: 5), "The outline shows")
        UITestSupport.settle()
        XCTAssertEqual(outline.label, "Subtitle position")
        XCTAssertEqual(outline.value as? String, "Default place")
        let step = measureArrowStep(app, line)
        let start = line.frame

        dragOutline(outline, dy: -80)
        XCTAssertTrue(UITestSupport.waitForFrame(line, timeout: 5) { abs($0.minY - (start.minY - 80)) <= 10 },
                      "The line follows an 80 pt drag up: was \(start), now \(line.frame)")
        XCTAssertEqual(line.frame.minX, start.minX, accuracy: 3, "A straight drag doesn't move the line sideways")
        XCTAssertTrue(UITestSupport.wait(timeout: 5) { (outline.value as? String) != "Default place" },
                      "The value text changes")
        UITestSupport.settle()
        assertOutline(outline.frame, around: line.frame, message: "after the drag")
        let dropped = line.frame

        let down = app.buttons["moveText.down"]
        XCTAssertTrue(UITestSupport.tap(down, until: { abs(line.frame.minY - (dropped.minY + step)) <= 1 }),
                      "Down steps 5 % (\(step) pt) from where the drag left the line: was \(dropped), now \(line.frame)")

        dragOutline(outline, dy: 40 - outline.frame.midY)
        UITestSupport.settle()
        let highest = line.frame
        if landscape {
            let card = app.descendants(matching: .any)["moveText.card"]
            XCTAssertEqual(highest.minY - card.frame.maxY, 8, accuracy: 2, "The line stops just under the card")
            XCTAssertFalse(app.buttons["moveText.up"].isEnabled, "Up dims at the limit")
            XCTAssertEqual(app.buttons["moveText.up"].value as? String, "Highest")
        } else {
            let video = app.descendants(matching: .any)["player.video"].frame
            XCTAssertEqual(highest.minY - video.minY, 8, accuracy: 2, "The line stops at the top of its region")
        }
        XCTAssertTrue(UITestSupport.tap(down, until: { abs(line.frame.minY - (highest.minY + step)) <= 1 }),
                      "Down steps 5 % (\(step) pt) from the limit: was \(highest), now \(line.frame)")
        UITestSupport.attachText("start \(start)\ndropped \(dropped)\nhighest \(highest)\nstep \(step)\n"
                                 + app.debugDescription, name: "move-drag-\(landscape ? "landscape" : "portrait")", to: self)
    }

    @MainActor
    func testDraggingTheOutlineMovesTheSampleWhenNoLineIsShowingPortrait() throws {
        let app = launch(seed: nil, landscape: false)
        let slider = app.sliders.firstMatch
        XCTAssertTrue(slider.waitForExistence(timeout: 5))
        slider.adjust(toNormalizedSliderPosition: 0.97)
        XCTAssertTrue(app.textViews["player.subtitle"].waitForNonExistence(timeout: 10), "No line is on screen")
        app.buttons["player.moveText"].tap()
        let outline = app.descendants(matching: .any)["moveText.outline"]
        let sample = app.textViews["moveText.sample"]
        XCTAssertTrue(sample.waitForExistence(timeout: 5), "The sample stands in")
        UITestSupport.settle()
        let start = outline.frame

        dragOutline(outline, dy: -60)
        XCTAssertTrue(UITestSupport.waitForFrame(outline, timeout: 5) { abs($0.minY - (start.minY - 60)) <= 10 },
                      "The outline follows the drag: was \(start), now \(outline.frame)")
        UITestSupport.settle()
        assertOutline(outline.frame, around: sample.frame, message: "after dragging the sample")
    }

    @MainActor
    private func dragOutline(_ outline: XCUIElement, dy: CGFloat) {
        let centre = outline.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        centre.press(forDuration: 0.3, thenDragTo: centre.withOffset(CGVector(dx: 0, dy: dy)))
    }

    /// How far one Up tap moves the line from the default place, in points (5 % of the region). Taps Down to go back.
    @MainActor
    private func measureArrowStep(_ app: XCUIApplication, _ line: XCUIElement) -> CGFloat {
        let start = line.frame.minY
        XCTAssertTrue(UITestSupport.tap(app.buttons["moveText.up"], until: { abs(line.frame.minY - start) > 1 }),
                      "Up moves the line")
        UITestSupport.settle(0.3)
        let step = start - line.frame.minY
        XCTAssertTrue(UITestSupport.tap(app.buttons["moveText.down"], until: { abs(line.frame.minY - start) <= 1 }),
                      "Down puts it back")
        return step
    }

    // MARK: Helpers

    private func assertOutline(_ outline: CGRect, around inner: CGRect, message: String,
                               file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertEqual(inner.minX - outline.minX, gap, accuracy: 1, "Left gap \(message)", file: file, line: line)
        XCTAssertEqual(inner.minY - outline.minY, gap, accuracy: 1, "Top gap \(message)", file: file, line: line)
        XCTAssertEqual(outline.maxX - inner.maxX, gap, accuracy: 1, "Right gap \(message)", file: file, line: line)
        XCTAssertEqual(outline.maxY - inner.maxY, gap, accuracy: 1, "Bottom gap \(message)", file: file, line: line)
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
    private func tapVideo(_ app: XCUIApplication) {
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.3, dy: 0.35)).tap()
    }

    /// Launches the player in portrait or landscape, paused, with controls up in landscape.
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

    /// Seeks to the second line (paused) and returns it. Landscape lists the lines in a side panel: open it, tap the
    /// row, close it again.
    @MainActor
    private func showSecondLine(_ app: XCUIApplication, landscape: Bool) -> XCUIElement {
        let toggle = app.buttons["player.panelToggle"]
        if landscape {
            XCTAssertTrue(toggle.waitForExistence(timeout: 5))
            toggle.tap()
        }
        let row = app.descendants(matching: .any)["cue.row.1"]
        XCTAssertTrue(row.waitForExistence(timeout: 10), "The list shows the second line")
        row.tap()
        let line = app.textViews["player.subtitle"]
        XCTAssertTrue(line.waitForExistence(timeout: 10), "Tapping a line seeks and shows it")
        if landscape {
            toggle.tap()
            XCTAssertTrue(app.descendants(matching: .any)["player.sidePanel"].waitForNonExistence(timeout: 5),
                          "The side list closes")
        }
        UITestSupport.settle()
        return line
    }

    @MainActor
    private func attachText(_ text: String, name: String) {
        UITestSupport.attachText(text, name: name, to: self)
    }
}
