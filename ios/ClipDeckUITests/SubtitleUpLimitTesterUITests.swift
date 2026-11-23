import XCTest

/// Tester checks for T-018 that the builder's `testUpDisablesWhenTheLineCanNoLongerMoveUp` (one-row card) leaves out:
/// - AC-1 with the two-row (panel 25 %) and three-row (panel 50 %) cards: Up dims only once the line has reached the
///   top-bar clamp (its top within about 1 pt of the top bar + `Spacing.s`), so it doesn't dim early, and never
///   because of the stored 90 % limit;
/// - AC-1 "the value text keeps showing the stored percent": Down's spoken value follows the stored steps while Up
///   says "Highest";
/// - one Down re-enables Up, and the next Up brings the line back to the same top place and dims Up again;
/// - closing and reopening the card at the same stored place keeps Up dimmed;
/// - a stored place already past the clamp opens the card with Up dimmed, while the portrait sheet keeps its rule
///   (Up enabled until 90 %).
final class SubtitleUpLimitTesterUITests: XCTestCase {
    private let controlIDs = [
        "subtitleStyle.font.sans", "subtitleStyle.font.rounded", "subtitleStyle.font.serif",
        "subtitleStyle.font.more", "subtitleStyle.bold", "subtitleStyle.sizeDown", "subtitleStyle.sizeUp",
        "subtitleStyle.left", "subtitleStyle.up", "subtitleStyle.down", "subtitleStyle.right",
        "subtitleStyle.reset", "subtitleStyle.done",
    ]
    /// The line's top-bar clearance (`Spacing.s`): the line can't start higher than the top bar's bottom + 8.
    private let topBarGap: CGFloat = 8

    override func setUp() {
        continueAfterFailure = false
    }

    override func tearDown() async throws {
        await MainActor.run { XCUIDevice.shared.orientation = .portrait }
        try await super.tearDown()
    }

    // MARK: AC-1 with the two- and three-row cards

    @MainActor
    func testUpDimsExactlyWhenTheLineReachesTheTopBarWithTwoAndThreeRowCards() throws {
        let app = launchLandscape(seed: nil)
        showSecondLineAndClosePanel(app)
        var log: [String] = []

        let toggle = app.buttons["player.panelToggle"]
        toggle.tap()
        let panel = app.descendants(matching: .any)["player.sidePanel"]
        XCTAssertTrue(panel.waitForExistence(timeout: 5))
        waitUntilSettled(panel)
        log += climbUntilUpDims(app, state: "panel-25", expectedRows: 2)

        let handle = app.descendants(matching: .any)["player.panelHandle"]
        XCTAssertTrue(handle.waitForExistence(timeout: 5))
        let start = handle.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        start.press(forDuration: 0.1, thenDragTo: start.withOffset(CGVector(dx: 2 - handle.frame.midX, dy: 0)))
        waitUntilSettled(panel)
        XCTAssertGreaterThan(panel.frame.width, app.windows.firstMatch.frame.width * 0.4, "The panel is at its widest")
        log += climbUntilUpDims(app, state: "panel-50", expectedRows: 3)

        attachText(log.joined(separator: "\n"), name: "tester-t018-climb")
    }

    // MARK: AC-1 a stored place past the clamp; the portrait sheet keeps its rule

    @MainActor
    func testAStoredPlacePastTheClampDimsUpInTheCardButNotInThePortraitSheet() throws {
        let app = launchLandscape(seed: #"{"upSteps":17}"#)
        let line = showSecondLineAndClosePanel(app)
        openCard(app)
        settle()
        let up = app.buttons["subtitleStyle.up"]
        let down = app.buttons["subtitleStyle.down"]
        XCTAssertFalse(up.isEnabled, "With the line already under the top bar, Up opens dimmed")
        XCTAssertEqual(up.value as? String, "Highest")
        XCTAssertTrue(down.isEnabled, "Down stays enabled")
        XCTAssertEqual(down.value as? String, "85 percent up", "The other controls keep the stored percent")
        let topBar = app.descendants(matching: .any)["player.topBar"].frame
        let clampTop = topBar.maxY + topBarGap
        XCTAssertEqual(line.frame.minY, clampTop, accuracy: 2, "The line sits right under the top bar")
        attachText("line \(line.frame)\ntop bar \(topBar)\nclamp top \(clampTop)", name: "tester-t018-stored-17")
        attachEvidence(app, name: "tester-t018-stored-17")

        // A rotation closes the card; the portrait sheet still lets Up go to the stored limit.
        XCUIDevice.shared.orientation = .portrait
        XCTAssertTrue(cardElement(app).waitForNonExistence(timeout: 5), "A rotation closes the card")
        settle()
        let opener = app.buttons["player.subtitleStyle"]
        XCTAssertTrue(opener.waitForExistence(timeout: 10), "The portrait controls row has the style button")
        opener.tap()
        XCTAssertTrue(app.buttons["subtitleStyle.done"].waitForExistence(timeout: 5), "The style sheet opens")
        XCTAssertTrue(app.descendants(matching: .any)["subtitleStyle.sheet"].waitForExistence(timeout: 5),
                      "Portrait opens the sheet, not the card")
        let sheetUp = app.buttons["subtitleStyle.up"]
        reveal(sheetUp, in: app)
        XCTAssertTrue(sheetUp.isEnabled, "The portrait sheet's Up disables only at the stored limit")
        XCTAssertEqual(sheetUp.value as? String, "85 percent up")
        sheetUp.tap()
        XCTAssertEqual(sheetUp.value as? String, "90 percent up")
        XCTAssertFalse(sheetUp.isEnabled, "At 90 % the sheet's Up is disabled")
        XCTAssertTrue(app.staticTexts["subtitleStyle.positionValue"].label.hasPrefix("Up 90%"),
                      "The value text shows the stored percent: \(app.staticTexts["subtitleStyle.positionValue"].label)")
        app.terminate()
    }

    // MARK: Checks

    /// Opens the card at the default place, taps Up until it dims (each tap must move the line by more than 1 pt and
    /// keep Down's value on the stored percent), then checks where the line stopped, Down/Up recovery, and
    /// close/reopen. Closes the card at the end.
    @MainActor
    private func climbUntilUpDims(_ app: XCUIApplication, state: String, expectedRows: Int) -> [String] {
        openCard(app)
        settle()
        let reset = app.buttons["subtitleStyle.reset"]
        if reset.isEnabled {
            reset.tap()
            settle()
        }
        let up = app.buttons["subtitleStyle.up"]
        let down = app.buttons["subtitleStyle.down"]
        let line = app.textViews["player.subtitle"]
        XCTAssertEqual(down.value as? String, "At the default height", "Starts at the default place (\(state))")
        XCTAssertEqual(rowCount(app), expectedRows, "Card rows (\(state))")

        let opened = line.frame
        var log = ["\(state): rows \(rowCount(app)), opened \(opened)"]
        var previousMinY = opened.minY
        var taps = 0
        while up.isEnabled && taps < 19 {
            // T-034: a lost Up tap is tapped again after waiting for Down's stored percent; a doubled step fails here.
            let before = UITestSupport.upText((taps) * 5)
            taps += 1
            XCTAssertTrue(UITestSupport.tapStep(up, reader: down, from: before, to: UITestSupport.upText(taps * 5)),
                          "Up tap \(taps) steps the stored place once (\(state))")
            let reference = previousMinY
            XCTAssertTrue(UITestSupport.waitForFrame(line, timeout: 6) { $0.minY < reference - 1 },
                          "Up tap \(taps) moves the line (\(state))")
            settle()
            let now = line.frame
            log.append("\(state) up \(taps) (up \(up.value as? String ?? "?"), down \(down.value as? String ?? "?")): \(now)")
            XCTAssertLessThan(now.minY, previousMinY - 1, "Up tap \(taps) moves the line by more than 1 pt (\(state))")
            XCTAssertEqual(down.value as? String, "\(taps * 5) percent up",
                           "The other controls keep the stored percent after Up \(taps) (\(state))")
            previousMinY = now.minY
        }
        XCTAssertGreaterThan(taps, 1, "Up starts enabled (\(state))")
        XCTAssertLessThan(taps, 18, "The top bar, not the stored 90 % limit, stopped Up (\(state))")
        XCTAssertFalse(up.isEnabled, "Up is dimmed (\(state))")
        XCTAssertEqual(up.value as? String, "Highest", "Dimmed Up reads Highest (\(state))")

        let topBar = app.descendants(matching: .any)["player.topBar"].frame
        let clampTop = topBar.maxY + topBarGap
        let highest = line.frame
        log.append("\(state): top bar \(topBar), clamp top \(clampTop), highest \(highest), taps \(taps)")
        XCTAssertGreaterThanOrEqual(highest.minY, clampTop - 1, "The line stays below the top bar (\(state))")
        XCTAssertLessThanOrEqual(highest.minY, clampTop + 2,
                                 "Up dims only once the line has reached the top bar, not earlier (\(state))")

        // One Down: Up comes back, and the next Up returns to the same top place and dims again.
        down.tap()
        settle()
        XCTAssertGreaterThan(line.frame.minY, highest.minY + 1, "Down moves the line down (\(state))")
        XCTAssertTrue(up.isEnabled, "After one Down, Up is enabled again (\(state))")
        XCTAssertEqual(up.value as? String, "\((taps - 1) * 5) percent up", "Up reads the stored percent again (\(state))")
        up.tap()
        settle()
        XCTAssertEqual(line.frame.minY, highest.minY, accuracy: 0.5, "Up returns to the same top place (\(state))")
        XCTAssertFalse(up.isEnabled, "Up dims again (\(state))")

        // Close and reopen at the same stored place: Up is still dimmed.
        tapDone(app, closing: cardElement(app))
        XCTAssertTrue(cardElement(app).waitForNonExistence(timeout: 5), "Done closes the card (\(state))")
        settle()
        openCard(app)
        settle()
        XCTAssertFalse(up.isEnabled, "Reopened at the same place, Up is still dimmed (\(state))")
        XCTAssertEqual(down.value as? String, "\(taps * 5) percent up", "Reopened, Down keeps the stored percent (\(state))")
        attachEvidence(app, name: "tester-t018-\(state)")
        tapDone(app, closing: cardElement(app))
        XCTAssertTrue(cardElement(app).waitForNonExistence(timeout: 5), "Done closes the card (\(state))")
        settle()
        return log
    }

    /// How many rows the card's controls sit on (rows grouped within 4 pt).
    @MainActor
    private func rowCount(_ app: XCUIApplication) -> Int {
        var rows: [CGFloat] = []
        for top in controlIDs.map({ app.buttons[$0].frame.minY }).sorted() {
            if let last = rows.last, abs(top - last) <= 4 { continue }
            rows.append(top)
        }
        return rows.count
    }

    // MARK: Helpers

    /// Taps Done and waits for the card to close. A lost tap leaves the card and Done on screen, so it taps again
    /// while Done still exists and is hittable (T-034: "Done closes the card (panel-25)" failed on a lost tap).
    @MainActor
    private func tapDone(_ app: XCUIApplication, closing card: XCUIElement) {
        UITestSupport.tap(app.buttons["subtitleStyle.done"], patience: 5) { !card.exists }
    }

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

    /// Seeks to the second line through the side list, then closes the list again (paused, controls up).
    @MainActor
    @discardableResult
    private func showSecondLineAndClosePanel(_ app: XCUIApplication) -> XCUIElement {
        let toggle = app.buttons["player.panelToggle"]
        XCTAssertTrue(toggle.waitForExistence(timeout: 5))
        toggle.tap()
        let row = app.descendants(matching: .any)["cue.row.1"]
        XCTAssertTrue(row.waitForExistence(timeout: 10), "The side list shows the lines")
        row.tap()
        let line = app.textViews["player.subtitle"]
        XCTAssertTrue(line.waitForExistence(timeout: 10), "Tapping a line seeks and shows it")
        toggle.tap()
        XCTAssertTrue(app.descendants(matching: .any)["player.sidePanel"].waitForNonExistence(timeout: 5),
                      "The side list closes")
        settle()
        XCTAssertTrue(app.buttons["player.back"].exists, "The controls are still up")
        return line
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
    }

    /// Upper left of the screen: on the video, clear of the bars, the card, the line and the panel handle.
    @MainActor
    private func tapVideo(_ app: XCUIApplication) {
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.3, dy: 0.35)).tap()
    }

    /// The position controls may be below the sheet's first detent; reach them by scrolling.
    @MainActor
    private func reveal(_ element: XCUIElement, in app: XCUIApplication) {
        var swipes = 0
        while !element.isHittable && swipes < 8 {
            app.swipeUp()
            swipes += 1
        }
        XCTAssertTrue(element.isHittable, "The control can be reached")
    }

    /// Lets the 0.2 s placement animation, the card's 0.25 s transition and the controls' fade finish.
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

    /// The video's element screenshot (unrotated in landscape) and the whole accessibility tree with every frame.
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
