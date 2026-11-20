import XCTest

/// The primary workflow on the seeded "Sample Show" (a generated 6-second video + 3-line SRT):
/// open the episode, jump to a line from the list, Make a Card, save it, see it waiting to sync.
final class MiningFlowUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    @MainActor
    func testMakeACardFromSubtitleLine() throws {
        let app = XCUIApplication()
        app.launchArguments += ["-uiTesting"]
        app.launch()

        let showTile = app.buttons["library.show.Sample Show"]
        XCTAssertTrue(showTile.waitForExistence(timeout: 30), "Seeded show should appear")
        attachScreenshot(app, "01-library")
        showTile.tap()

        let episodeRow = app.buttons["episode.row.Episode 1"]
        XCTAssertTrue(episodeRow.waitForExistence(timeout: 5))
        attachScreenshot(app, "02-show")
        episodeRow.tap()

        // Tap the second line in the subtitle list: the player seeks to 0:02.0.
        let secondLine = app.descendants(matching: .any)["cue.row.1"]
        XCTAssertTrue(secondLine.waitForExistence(timeout: 10))
        secondLine.tap()
        XCTAssertTrue(app.textViews["player.subtitle"].waitForExistence(timeout: 5), "Current line shows over the video")
        attachScreenshot(app, "03-player")

        // Make a Card: plays 0:02.0–0:04.0, cuts the audio, opens the editor.
        app.buttons["player.makeCard"].tap()
        let save = app.buttons["card.save"]
        XCTAssertTrue(save.waitForExistence(timeout: 20), "Card editor should open after recording")
        XCTAssertEqual(app.staticTexts["card.range"].label, "0:02.0 – 0:04.0")
        let sentence = app.textFields["card.field.sentence"].exists
            ? app.textFields["card.field.sentence"]
            : app.textViews["card.field.sentence"]
        XCTAssertEqual(sentence.value as? String, "元気ですか")

        // Partial-segment editing: extend into the next line, which requires a re-record.
        app.buttons["card.addNext"].tap()
        XCTAssertEqual(app.staticTexts["card.range"].label, "0:02.0 – 0:05.5")
        XCTAssertFalse(save.isEnabled, "Saving waits for the re-record")
        app.buttons["card.rerecord"].tap()
        XCTAssertTrue(save.waitForEnabled(timeout: 20))
        XCTAssertEqual(sentence.value as? String, "元気ですか\nまたね")
        attachScreenshot(app, "04-card-editor")
        save.tap()

        XCTAssertTrue(app.descendants(matching: .any)["toast"].waitForExistence(timeout: 5), "Saved confirmation shows")

        // Back to the library: one card waiting to sync.
        app.navigationBars.buttons.element(boundBy: 0).tap()
        app.navigationBars.buttons.element(boundBy: 0).tap()
        let sync = app.buttons["library.sync"]
        XCTAssertTrue(sync.waitForExistence(timeout: 5))
        XCTAssertEqual(sync.value as? String, "1 waiting")
        attachScreenshot(app, "05-library-pending")

        sync.tap()
        XCTAssertTrue(app.staticTexts["sync.waiting"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.staticTexts["sync.waiting"].label, "1 card waiting to sync")
        attachScreenshot(app, "06-sync")

        // T-013 AC-6 (tester): with an action, ErrorBanner keeps the message as one element and the action is its
        // own button. Under the old `.combine` both were merged into one element labelled "<message>, <action>".
        let problem = "Add your computer's AnkiConnect address in Anki settings."
        let openSettings = app.buttons["Open Anki settings"]
        XCTAssertTrue(openSettings.waitForExistence(timeout: 5), "the banner's action is its own button")
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label == %@", problem)).firstMatch.exists,
                      "the banner's message is its own element, without the button's title")
        openSettings.tap()
        XCTAssertTrue(app.descendants(matching: .any)["settings.url"].waitForExistence(timeout: 5),
                      "the banner's button opens Anki settings")
    }

    @MainActor
    private func attachScreenshot(_ app: XCUIApplication, _ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}

private extension XCUIElement {
    func waitForEnabled(timeout: TimeInterval) -> Bool {
        let predicate = NSPredicate(format: "isEnabled == true")
        let expectation = XCTNSPredicateExpectation(predicate: predicate, object: self)
        return XCTWaiter().wait(for: [expectation], timeout: timeout) == .completed
    }
}
