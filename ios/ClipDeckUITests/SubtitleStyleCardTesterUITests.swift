import XCTest

/// Tester checks for T-016 that the builder's SubtitleStyleCardUITests leave out:
/// - AC-2: the `ViewThatFits` level at each panel width (one row of 13 with the panel closed, 7 + 6 at 25 %,
///   5 + 4 + 4 at 50 %), and every control inside the safe area and the video column, measured against the bars'
///   own controls (same paddings), not only against the window;
/// - AC-5: the line's bottom against the card's real top: the first row's top minus the card's `Spacing.s` (8 pt)
///   padding. (In CI 44972664549 XCUITest reported the card's own frame as its real frame, e.g. {0, 322, 874, 80}
///   for one row, unlike the T-015 sheet's union frame; the derived top matches it.)
/// - AC-5: after closing, with the controls hidden, the line rests at its styled place;
/// - the landscape opener no longer opens the portrait sheet;
/// - evidence for "every tap shows its effect": where the line is after each Up tap with the card open.
final class SubtitleStyleCardTesterUITests: XCTestCase {
    private let controlIDs = [
        "subtitleStyle.font.sans", "subtitleStyle.font.rounded", "subtitleStyle.font.serif",
        "subtitleStyle.font.more", "subtitleStyle.bold", "subtitleStyle.sizeDown", "subtitleStyle.sizeUp",
        "subtitleStyle.left", "subtitleStyle.up", "subtitleStyle.down", "subtitleStyle.right",
        "subtitleStyle.reset", "subtitleStyle.done",
    ]
    /// The card's top padding above its first row (`Spacing.s`).
    private let cardTopPadding: CGFloat = 8

    override func setUp() {
        continueAfterFailure = false
    }

    override func tearDown() async throws {
        await MainActor.run { XCUIDevice.shared.orientation = .portrait }
        try await super.tearDown()
    }

    // MARK: AC-2 + AC-5 at every panel width

    @MainActor
    func testTheCardKeepsToTheSafeAreaAndTheLineToItsRealTopAtEveryPanelWidth() throws {
        let app = launchLandscape(seed: #"{"sizeStep":1}"#)
        let line = showSecondLineAndClosePanel(app)
        XCTAssertTrue(line.exists)

        checkCard(app, state: "closed", expectedRows: [13])

        let toggle = app.buttons["player.panelToggle"]
        toggle.tap()
        let panel = app.descendants(matching: .any)["player.sidePanel"]
        XCTAssertTrue(panel.waitForExistence(timeout: 5))
        waitUntilSettled(panel)
        checkCard(app, state: "panel-25", expectedRows: [7, 6])

        let handle = app.descendants(matching: .any)["player.panelHandle"]
        XCTAssertTrue(handle.waitForExistence(timeout: 5))
        let start = handle.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        start.press(forDuration: 0.1, thenDragTo: start.withOffset(CGVector(dx: 2 - handle.frame.midX, dy: 0)))
        waitUntilSettled(panel)
        XCTAssertGreaterThan(panel.frame.width, app.windows.firstMatch.frame.width * 0.4, "The panel is at its widest")
        checkCard(app, state: "panel-50", expectedRows: [5, 4, 4], keepOpen: true)

        // The tallest card (three rows) with the biggest line: still above the card's real top, below the top bar.
        let sizeUp = app.buttons["subtitleStyle.sizeUp"]
        for _ in 0..<9 where sizeUp.isEnabled { sizeUp.tap() }
        settle()
        XCTAssertEqual(sizeUp.value as? String, "200 percent")
        let top = cardRealTop(app)
        let big = app.textViews["player.subtitle"].frame
        XCTAssertLessThanOrEqual(big.maxY, top + 0.5, "At 200 % the line still ends above the card's real top")
        let topBar = app.descendants(matching: .any)["player.topBar"].frame
        XCTAssertGreaterThanOrEqual(big.minY, topBar.maxY - 0.5, "At 200 % the line still starts below the top bar")
        attachText("line \(big)\ncard real top \(top)\ntop bar \(topBar)", name: "tester-card-200-percent")
        attachEvidence(app, name: "tester-card-200-percent")

        // The preset chips and More fonts, close up, for legibility of "Aあ".
        for id in ["subtitleStyle.font.sans", "subtitleStyle.font.rounded", "subtitleStyle.font.serif",
                   "subtitleStyle.font.more", "subtitleStyle.bold"] {
            let shot = XCTAttachment(screenshot: app.buttons[id].screenshot())
            shot.name = "tester-chip-\(id)"
            shot.lifetime = .keepAlways
            add(shot)
        }
    }

    // MARK: AC-5: after closing, the line rests at its styled place

    @MainActor
    func testAfterClosingTheLineRestsAtItsStyledPlace() throws {
        let app = launchLandscape(seed: nil)
        let line = showSecondLineAndClosePanel(app)
        let back = app.buttons["player.back"]

        tapVideo(app)
        XCTAssertTrue(back.waitForNonExistence(timeout: 5), "A tap hides the controls (paused)")
        settle()
        let rest = line.frame

        let unchanged = openTapUpCloseAndHide(app, upTaps: 0)
        XCTAssertEqual(unchanged.maxY, rest.maxY, accuracy: 1, "With the style unchanged, the line returns to its rest")
        XCTAssertEqual(unchanged.midX, rest.midX, accuracy: 1)

        let up2 = openTapUpCloseAndHide(app, upTaps: 2)
        let up4 = openTapUpCloseAndHide(app, upTaps: 2)
        let rise2 = rest.maxY - up2.maxY
        let rise4 = rest.maxY - up4.maxY
        XCTAssertGreaterThan(rise2, 10, "Up x2 raises the resting line")
        XCTAssertEqual(rise4, 2 * rise2, accuracy: 1.5, "The resting place follows the steps (5 % each), not the card")
        attachText("rest \(rest)\nunchanged \(unchanged)\nup2 \(up2)\nup4 \(up4)", name: "tester-rest-after-close")
        attachEvidence(app, name: "tester-rest-after-close")
    }

    // MARK: Evidence: does each Up tap show while the card is open?

    /// Records the line after each Up tap with the card open (panel closed, one-row card). T-014's placement pins
    /// the line above the card until its wanted place is higher than the card, so the first taps may not move it.
    /// The asserts are only what the ACs require; the per-tap list is the evidence for the "every tap shows" goal.
    @MainActor
    func testUpTapsWithTheCardOpenRecordWhereTheLineIs() throws {
        let app = launchLandscape(seed: nil)
        _ = showSecondLineAndClosePanel(app)
        openCard(app)
        settle()
        let top = cardRealTop(app)
        let opened = app.textViews["player.subtitle"].frame
        XCTAssertLessThanOrEqual(opened.maxY, top + 0.5, "The default line ends above the card's real top")

        var log = "card real top \(top)\nopened maxY \(opened.maxY) minY \(opened.minY)"
        let up = app.buttons["subtitleStyle.up"]
        var last = opened
        var previousMaxY = opened.maxY
        for tap in 1...8 {
            up.tap()
            settle()
            last = app.textViews["player.subtitle"].frame
            log += "\nup \(tap) (\(up.value as? String ?? "?")): maxY \(last.maxY) minY \(last.minY)"
            XCTAssertLessThanOrEqual(last.maxY, top + 0.5, "After up \(tap) the line still ends above the card")
            XCTAssertLessThan(last.maxY, previousMaxY - 1, "Up \(tap) visibly moves the line (a live preview)")
            previousMaxY = last.maxY
        }
        attachText(log, name: "tester-up-taps-card-open")
        XCTAssertLessThan(last.maxY, opened.maxY - 1, "Up x8 (40 %) lifts the line above where the card pinned it")
        attachEvidence(app, name: "tester-up-taps-card-open")
    }

    // MARK: Checks

    /// From hidden controls: shows them, opens the card, taps Up `upTaps` times, taps Done, hides the controls with a
    /// video tap, and returns the line's resting frame.
    @MainActor
    private func openTapUpCloseAndHide(_ app: XCUIApplication, upTaps: Int) -> CGRect {
        let back = app.buttons["player.back"]
        tapVideo(app)
        XCTAssertTrue(back.waitForExistence(timeout: 5), "A tap shows the controls")
        openCard(app)
        let up = app.buttons["subtitleStyle.up"]
        for _ in 0..<upTaps { up.tap() }
        app.buttons["subtitleStyle.done"].tap()
        XCTAssertTrue(cardElement(app).waitForNonExistence(timeout: 5), "Done closes the card")
        tapVideo(app)
        XCTAssertTrue(back.waitForNonExistence(timeout: 5), "A tap hides the controls again")
        settle()
        return app.textViews["player.subtitle"].frame
    }

    /// Measures the bars' reference edges with the card closed, opens the card, checks it, and closes it again
    /// (unless `keepOpen`).
    @MainActor
    private func checkCard(_ app: XCUIApplication, state: String, expectedRows: [Int], keepOpen: Bool = false) {
        // References: the top bar's back and panel buttons and the bottom bar's last row use the same paddings
        // (Spacing.m + the safe-area or handle insets, Spacing.s + the bottom inset) as the card. The row's bottom is
        // Make a Card's bottom: it is the tallest control in the row (about 47.7 pt), and the 44 pt play button is
        // centred in it, 1.8 pt higher (CI 44972664549).
        let back = app.buttons["player.back"]
        let toggle = app.buttons["player.panelToggle"]
        let play = app.buttons["player.playPause"]
        let makeCard = app.buttons["player.makeCard"]
        XCTAssertTrue(play.waitForExistence(timeout: 5), "The bottom bar shows (\(state))")
        XCTAssertTrue(makeCard.exists, "Make a Card is in the bottom bar (\(state))")
        let leading = back.frame.minX
        let trailing = toggle.frame.maxX
        let bottom = max(play.frame.maxY, makeCard.frame.maxY)

        openCard(app)
        settle()
        XCTAssertFalse(app.descendants(matching: .any)["subtitleStyle.sheet"].exists,
                       "Landscape opens the card, not the portrait sheet (\(state))")
        XCTAssertFalse(play.exists, "The card replaces the bottom bar (\(state))")
        XCTAssertTrue(back.exists, "The top bar stays (\(state))")

        var frames: [CGRect] = []
        for id in controlIDs {
            let control = app.buttons[id]
            XCTAssertTrue(control.exists, "\(id) is in the card (\(state))")
            XCTAssertTrue(control.isHittable, "\(id) is hittable (\(state))")
            let frame = control.frame
            frames.append(frame)
            XCTAssertGreaterThanOrEqual(frame.minX, leading - 0.5, "\(id) is inside the leading safe area (\(state))")
            XCTAssertLessThanOrEqual(frame.maxX, trailing + 0.5, "\(id) is inside the column's trailing edge (\(state))")
            XCTAssertLessThanOrEqual(frame.maxY, bottom + 0.5, "\(id) is inside the bottom safe area (\(state))")
            XCTAssertEqual(frame.width, 44, accuracy: 0.5, "\(id) keeps its 44 pt size (\(state))")
        }
        XCTAssertEqual(rowCounts(frames), expectedRows, "ViewThatFits level (\(state))")

        let top = cardRealTop(app)
        let line = app.textViews["player.subtitle"].frame
        XCTAssertLessThanOrEqual(line.maxY, top + 0.5, "The line ends above the card's real top (\(state))")
        let topBar = app.descendants(matching: .any)["player.topBar"].frame
        XCTAssertGreaterThanOrEqual(line.minY, topBar.maxY - 0.5, "The line starts below the top bar (\(state))")

        let measured = zip(controlIDs, frames).map { "\($0) \($1)" }.joined(separator: "\n")
        attachText(
            "state \(state)\nleading \(leading) trailing \(trailing) bottom \(bottom)\ncard real top \(top)\n"
                + "card union \(cardElement(app).frame)\nline \(line)\ntop bar \(topBar)\nrows \(rowCounts(frames))\n"
                + measured,
            name: "tester-card-\(state)")
        attachEvidence(app, name: "tester-card-\(state)")

        if !keepOpen {
            app.buttons["subtitleStyle.done"].tap()
            XCTAssertTrue(cardElement(app).waitForNonExistence(timeout: 5), "Done closes the card (\(state))")
            XCTAssertTrue(play.waitForExistence(timeout: 5), "The bottom bar comes back (\(state))")
            settle()
        }
    }

    /// The card background's top: the first row's top minus the card's top padding.
    @MainActor
    private func cardRealTop(_ app: XCUIApplication) -> CGFloat {
        let tops = controlIDs.map { app.buttons[$0].frame.minY }
        return (tops.min() ?? 0) - cardTopPadding
    }

    /// How many controls sit on each row, top to bottom (rows grouped within 4 pt).
    private func rowCounts(_ frames: [CGRect]) -> [Int] {
        var rows: [(y: CGFloat, count: Int)] = []
        for frame in frames.sorted(by: { $0.minY < $1.minY }) {
            if let lastRow = rows.last, abs(frame.minY - lastRow.y) <= 4 {
                rows[rows.count - 1].count += 1
            } else {
                rows.append((y: frame.minY, count: 1))
            }
        }
        return rows.map(\.count)
    }

    // MARK: Helpers

    /// Launches, opens Episode 1, rotates to landscape and brings the controls up (the player is paused, so they stay).
    @MainActor
    private func launchLandscape(seed: String?) -> XCUIApplication {
        XCUIDevice.shared.orientation = .portrait
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
        XCUIDevice.shared.orientation = .landscapeLeft
        XCTAssertTrue(app.descendants(matching: .any)["player.video"].waitForExistence(timeout: 10))
        tapVideo(app)
        XCTAssertTrue(app.buttons["player.back"].waitForExistence(timeout: 5), "A tap shows the controls")
        return app
    }

    /// Seeks to the second line through the side list, then closes the list again (paused, controls up).
    @MainActor
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

    /// The video's element screenshot (unrotated in landscape, with the card drawn over it) and the whole
    /// accessibility tree with every frame.
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
