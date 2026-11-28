import XCTest

/// T-033: the clip timeline in Make a Card, on the sample's line 2 (2.0 to 4.0 s). The sample SRT has its edges at
/// 0.5, 2.0, 4.0 and 5.5 s. The video is 120 s so a slow runner can't play it to its end; the zoom window is 30 s.
final class CardTimelineUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    @MainActor
    private func openEditor(_ app: XCUIApplication) {
        let tile = UITestSupport.launchSeeded(app)
        UITestSupport.openSampleEpisode(app, tile: tile)
        let secondLine = app.descendants(matching: .any)["cue.row.1"]
        XCTAssertTrue(secondLine.waitForExistence(timeout: 10), "Subtitle list should show line 2")
        secondLine.tap()
        let makeCard = app.buttons["player.makeCard"]
        XCTAssertTrue(makeCard.waitForExistence(timeout: 10))
        makeCard.tap()
        XCTAssertTrue(app.buttons["card.save"].waitForExistence(timeout: 60), "Card editor should open after recording")
    }

    @MainActor
    private func launchArguments() -> [String] { ["-uiTesting", "-uiTestingSampleSeconds", "120"] }

    @MainActor
    private func element(_ app: XCUIApplication, _ id: String) -> XCUIElement {
        app.descendants(matching: .any)[id]
    }

    /// Drags the end handle by `seconds` of the zoomed track (points per second from the two handles, 2.0 s apart).
    @MainActor
    private func dragEnd(_ app: XCUIApplication, bySeconds seconds: Double) {
        let start = element(app, "card.timeline.start")
        let end = element(app, "card.timeline.end")
        let pointsPerSecond = (end.frame.midX - start.frame.midX) / 2.0
        let from = end.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        from.press(forDuration: 0.2, thenDragTo: from.withOffset(CGVector(dx: pointsPerSecond * seconds, dy: 0)))
    }

    @MainActor
    func testTimelineAndBothHandlesExist() throws {
        let app = XCUIApplication()
        app.launchArguments += launchArguments()
        openEditor(app)
        XCTAssertTrue(element(app, "card.timeline").exists)
        XCTAssertTrue(element(app, "card.timeline.start").exists)
        XCTAssertTrue(element(app, "card.timeline.end").exists)
        XCTAssertEqual(element(app, "card.timeline.snap").value as? String, "On", "Snap starts on")
        XCTAssertEqual(element(app, "card.timeline.start").label, "Clip start")
        XCTAssertEqual(element(app, "card.timeline.end").value as? String, "0:04.0")
        UITestSupport.attachScreenshot(app, name: "timeline-editor", to: self)
    }

    @MainActor
    func testSnapOnDragLandsOnTheNextEdgeThenRerecordAndSave() throws {
        let app = XCUIApplication()
        app.launchArguments += launchArguments()
        openEditor(app)
        let range = app.staticTexts["card.range"]
        let save = app.buttons["card.save"]
        XCTAssertEqual(range.label, "0:02.0 – 0:04.0")

        // 2.0 s, not 1.5: unsnapped the end reads 0:06.0, so only snapping gives 5.5, and the pointer clears the
        // 16 pt hold on the 4.0 s notch (1.5 s is about 15.5 pt on a 402 pt phone, so it could stay at 4.0).
        dragEnd(app, bySeconds: 2.0)
        XCTAssertTrue(UITestSupport.waitForLabel(range, "0:02.0 – 0:05.5", timeout: 10), "The end snaps to the 5.5 s edge, got \(range.label)")
        XCTAssertFalse(save.isEnabled, "Saving waits for the re-record")
        let rerecord = app.buttons["card.rerecord"]
        XCTAssertTrue(rerecord.waitForExistence(timeout: 5), "Re-record shows after a drag")

        rerecord.tap()
        XCTAssertTrue(UITestSupport.wait(timeout: 60) { save.isEnabled }, "Save works after the re-record")
        XCTAssertEqual(range.label, "0:02.0 – 0:05.5")
        save.tap()
        XCTAssertTrue(element(app, "toast").waitForExistence(timeout: 10), "Saved confirmation shows")
    }

    /// AC-5: at a large Dynamic Type size the timeline row still spans the panel and stays on screen.
    @MainActor
    func testTimelineFitsAtALargeDynamicTypeSize() throws {
        let app = XCUIApplication()
        app.launchArguments += launchArguments() + ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityL"]
        openEditor(app)
        let windowStart = element(app, "card.timeline.windowStart")
        let windowEnd = element(app, "card.timeline.windowEnd")
        XCTAssertTrue(windowEnd.waitForExistence(timeout: 5))
        XCTAssertTrue(element(app, "card.timeline.start").exists)
        XCTAssertTrue(element(app, "card.timeline.end").exists)
        XCTAssertTrue(element(app, "card.timeline.snap").exists)
        let screenWidth = app.frame.width
        XCTAssertGreaterThanOrEqual(windowStart.frame.minX, 0, "Window start label is on screen")
        XCTAssertLessThanOrEqual(windowEnd.frame.maxX, screenWidth, "Window end label is on screen")
        XCTAssertGreaterThanOrEqual(windowEnd.frame.maxX - windowStart.frame.minX, screenWidth - 80,
                                    "The timeline row spans the panel (screen \(screenWidth))")
        UITestSupport.attachScreenshot(app, name: "timeline-editor-large-type", to: self)
    }

    @MainActor
    func testSnapOffDragLandsBetweenEdges() throws {
        let app = XCUIApplication()
        app.launchArguments += launchArguments()
        openEditor(app)
        let snap = element(app, "card.timeline.snap")
        XCTAssertTrue(UITestSupport.tapStep(snap, reader: snap, from: "On", to: "Off"))

        dragEnd(app, bySeconds: 0.75)
        let range = app.staticTexts["card.range"]
        XCTAssertTrue(UITestSupport.wait(timeout: 10) { range.label != "0:02.0 – 0:04.0" }, "The end moved")
        let edges = ["0:04.0", "0:05.5"]
        let end = range.label.components(separatedBy: " – ").last ?? ""
        XCTAssertFalse(edges.contains(end), "With Snap off the end is between edges, got \(end)")
        XCTAssertTrue(range.label.hasPrefix("0:02.0 – 0:04."), "The end moved about 0.75 s, got \(range.label)")
    }

    @MainActor
    func testNudgeMovesTheEndHandleRight() throws {
        let app = XCUIApplication()
        app.launchArguments += launchArguments()
        openEditor(app)
        let end = element(app, "card.timeline.end")
        let before = end.frame.midX
        let nudge = app.buttons["End later by 100 milliseconds"]
        XCTAssertTrue(nudge.waitForExistence(timeout: 5))
        nudge.tap()
        XCTAssertTrue(UITestSupport.waitForLabel(app.staticTexts["card.range"], "0:02.0 – 0:04.1", timeout: 10))
        XCTAssertTrue(UITestSupport.wait(timeout: 5) { end.frame.midX > before }, "The handle follows the nudge")
    }

    @MainActor
    func testSnapChipSurvivesARelaunchWithTheKeepFlag() throws {
        let app = XCUIApplication()
        app.launchArguments += launchArguments()
        openEditor(app)
        let snap = element(app, "card.timeline.snap")
        XCTAssertTrue(UITestSupport.tapStep(snap, reader: snap, from: "On", to: "Off"))

        app.terminate()
        app.launchArguments += ["-uiTestingKeepTimelineSnap"]
        openEditor(app)
        XCTAssertEqual(element(app, "card.timeline.snap").value as? String, "Off", "The chip's state is remembered")
    }
}
