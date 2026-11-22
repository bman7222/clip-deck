import XCTest

/// T-017: the "More fonts…" row in the portrait style sheet. A picked font is seeded with
/// `-uiTestingSubtitleStyle {"pickedFontName":"Georgia"}`. The system font picker is only opened and cancelled;
/// choosing a font inside it is not driven (it is flaky).
final class SubtitleFontUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    override func tearDown() async throws {
        await MainActor.run { XCUIDevice.shared.orientation = .portrait }
        try await super.tearDown()
    }

    @MainActor
    func testSeededGeorgiaShowsInTheMoreFontsRowAndTheLineShows() throws {
        let app = launch(seed: #"{"pickedFontName":"Georgia"}"#)
        let line = seekToSecondLine(app)
        XCTAssertTrue(line.exists, "The line shows in the picked font")
        XCTAssertGreaterThan(line.frame.width, 20)
        XCTAssertEqual(app.buttons["player.subtitleStyle"].value as? String, "Changed", "A picked font is not the default")

        openStyleSheet(app)
        let more = app.buttons["subtitleStyle.font.more"]
        reveal(more, in: app)
        XCTAssertEqual(more.label, "More fonts")
        XCTAssertEqual(more.value as? String, "Georgia", "The row shows the picked font")
        XCTAssertTrue(more.isSelected, "The opener is aqua (selected) while a font is picked")
        XCTAssertFalse(app.buttons["subtitleStyle.font.sans"].isSelected, "The picked font takes the place of the preset")
        XCTAssertFalse(app.staticTexts["subtitleStyle.font.noBold"].exists, "Georgia has a bold weight")
        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = "style-03-picked-font"
        shot.lifetime = .keepAlways
        add(shot)
        app.terminate()
    }

    @MainActor
    func testAFontWithoutBoldSaysSo() throws {
        let app = launch(seed: #"{"pickedFontName":"Zapfino"}"#)
        openStyleSheet(app)
        let more = app.buttons["subtitleStyle.font.more"]
        reveal(more, in: app)
        XCTAssertEqual(more.value as? String, "Zapfino")
        XCTAssertTrue(app.staticTexts["subtitleStyle.font.noBold"].waitForExistence(timeout: 3), "The no-bold note shows")
        XCTAssertEqual(app.staticTexts["subtitleStyle.font.noBold"].label, "This font has no bold weight.")
        app.terminate()
    }

    @MainActor
    func testAMissingFontQuietlyBecomesSans() throws {
        let app = launch(seed: #"{"pickedFontName":"NoSuchFont-Regular"}"#)
        let line = seekToSecondLine(app)
        XCTAssertTrue(line.exists, "The player opens and shows the line without a crash")
        XCTAssertEqual(app.buttons["player.subtitleStyle"].value as? String, "Default", "Nothing is picked any more")

        openStyleSheet(app)
        XCTAssertTrue(app.buttons["subtitleStyle.font.sans"].isSelected, "Sans is selected")
        let more = app.buttons["subtitleStyle.font.more"]
        reveal(more, in: app)
        XCTAssertFalse(more.isSelected, "The opener is not aqua")
        XCTAssertEqual(more.value as? String, "None")
        app.terminate()
    }

    @MainActor
    func testMoreFontsOpensThePickerAndCancelReturnsToTheSheet() throws {
        let app = launch(seed: nil)
        openStyleSheet(app)
        let more = app.buttons["subtitleStyle.font.more"]
        reveal(more, in: app)
        XCTAssertEqual(more.value as? String, "None")
        more.tap()

        // iOS 26 gives the picker ("Choose Font") an X button labelled "close" instead of "Cancel"
        // (CI 44957727655 UI hierarchy), so either label is accepted.
        let cancel = app.buttons.matching(NSPredicate(format: "label IN %@", ["Cancel", "close", "Close"])).firstMatch
        let search = app.searchFields.firstMatch
        XCTAssertTrue(search.waitForExistence(timeout: 15) || cancel.waitForExistence(timeout: 5),
                      "The system font picker opens")
        XCTAssertTrue(cancel.waitForExistence(timeout: 5), "The picker has a Cancel (close) button")
        cancel.tap()
        XCTAssertTrue(cancel.waitForNonExistence(timeout: 10), "Cancel closes the picker")

        let done = app.buttons["subtitleStyle.done"]
        XCTAssertTrue(done.waitForExistence(timeout: 5), "The style sheet is still open")
        settle()
        XCTAssertEqual(app.buttons["subtitleStyle.font.more"].value as? String, "None", "Cancel changes nothing")
        XCTAssertTrue(app.buttons["subtitleStyle.font.sans"].isSelected, "Sans is still selected")
        XCTAssertEqual(app.buttons["player.subtitleStyle"].value as? String, "Default")
        app.terminate()
    }

    // MARK: Driving the player

    @MainActor
    private func launch(seed: String?) -> XCUIApplication {
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
    private func openStyleSheet(_ app: XCUIApplication) {
        let opener = app.buttons["player.subtitleStyle"]
        XCTAssertTrue(opener.waitForExistence(timeout: 10), "The controls row has the style button")
        opener.tap()
        XCTAssertTrue(app.buttons["subtitleStyle.done"].waitForExistence(timeout: 5), "The style sheet opens")
    }

    /// Swipes up (the sheet's content scrolls, or the sheet grows) until the element can be tapped.
    @MainActor
    private func reveal(_ element: XCUIElement, in app: XCUIApplication) {
        var swipes = 0
        while !element.isHittable && swipes < 8 {
            app.swipeUp()
            swipes += 1
        }
        XCTAssertTrue(element.isHittable, "The control can be reached")
    }

    @MainActor
    private func settle() {
        RunLoop.current.run(until: Date().addingTimeInterval(0.8))
    }
}
