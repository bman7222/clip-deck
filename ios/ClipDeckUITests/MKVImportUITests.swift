import XCTest

/// T-006 AC-7: an MKV episode added through `EpisodeImporter` plays with its subtitle file and makes cards like any
/// other episode. `-uiTesting -uiTestingMKV` makes the app import MKV fixture 4 (H.264, AAC 5.1, no subtitle tracks)
/// as "MKV Show / Episode 1" with the sample SRT. The fixture folder reaches this runner as CLIPDECK_FIXTURES
/// (test-ios.sh exports TEST_RUNNER_CLIPDECK_FIXTURES) and is forwarded to the app through `launchEnvironment`.
final class MKVImportUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    @MainActor
    func testMKVEpisodePlaysAndMakesACard() throws {
        let fixtures = ProcessInfo.processInfo.environment["CLIPDECK_FIXTURES"] ?? ""
        XCTAssertFalse(fixtures.isEmpty, "CLIPDECK_FIXTURES must be set (run ./scripts/test-ios.sh, which generates the fixtures)")

        let app = XCUIApplication()
        app.launchArguments += ["-uiTesting", "-uiTestingMKV"]
        app.launchEnvironment["CLIPDECK_FIXTURES"] = fixtures
        app.launch()

        // The seed converts the MKV before the library shows, so allow for the conversion.
        let showTile = app.buttons["library.show.MKV Show"]
        if !showTile.waitForExistence(timeout: 90) {
            attach(text: app.debugDescription, name: "mkv-00-library-tree")
            XCTFail("The MKV show should appear after fixture 4 is imported (see the app log for UITestSeeder)")
        }
        showTile.tap()

        let episodeRow = app.buttons["episode.row.Episode 1"]
        XCTAssertTrue(episodeRow.waitForExistence(timeout: 5))
        episodeRow.tap()

        // The subtitle file imported with the MKV: its three lines are listed. On iOS 26 a row's time and text are one
        // label ("0:02.0, 元気ですか"), so match with contains.
        let firstLine = app.descendants(matching: .any)["cue.row.0"]
        XCTAssertTrue(firstLine.waitForExistence(timeout: 15), "The player should open with the subtitle list")
        XCTAssertTrue(firstLine.label.contains("こんにちは"), "First line: \(firstLine.label)")
        let secondLine = app.descendants(matching: .any)["cue.row.1"]
        XCTAssertTrue(secondLine.exists)
        XCTAssertTrue(secondLine.label.contains("元気ですか"), "Second line: \(secondLine.label)")
        let thirdLine = app.descendants(matching: .any)["cue.row.2"]
        XCTAssertTrue(thirdLine.exists)
        XCTAssertTrue(thirdLine.label.contains("またね"), "Third line: \(thirdLine.label)")

        // Jump to line 2: the converted video seeks and the line shows over it.
        secondLine.tap()
        XCTAssertTrue(app.textViews["player.subtitle"].waitForExistence(timeout: 5), "Current line shows over the video")
        attach(screenshot: app.screenshot(), name: "mkv-01-player")

        // Make a Card from the converted episode: the clip is cut from the MP4 the importer wrote.
        app.buttons["player.makeCard"].tap()
        let save = app.buttons["card.save"]
        XCTAssertTrue(save.waitForExistence(timeout: 20), "Card editor should open after recording")
        XCTAssertEqual(app.staticTexts["card.range"].label, "0:02.0 – 0:04.0")
        let sentence = app.textFields["card.field.sentence"].exists
            ? app.textFields["card.field.sentence"]
            : app.textViews["card.field.sentence"]
        XCTAssertEqual(sentence.value as? String, "元気ですか")
        attach(screenshot: app.screenshot(), name: "mkv-02-card")

        XCTAssertTrue(save.waitForEnabled(timeout: 20))
        save.tap()
        XCTAssertTrue(app.descendants(matching: .any)["toast"].waitForExistence(timeout: 5), "Saved confirmation shows")
    }

    /// AC-3: the upload sheet offers MKV, and Add episode stays disabled until a usable video is chosen.
    @MainActor
    func testUploadSheetOffersMKV() throws {
        let app = XCUIApplication()
        app.launchArguments += ["-uiTesting", "-uiTestingNoSeed"]
        app.launch()

        XCTAssertTrue(app.buttons["library.upload"].waitForExistence(timeout: 10))
        app.buttons["library.upload"].tap()
        XCTAssertTrue(app.navigationBars["Upload episode"].waitForExistence(timeout: 5))

        // iOS 26 may merge the row's label and value ("Video, Choose MP4, MOV, M4V or MKV"), so match with contains.
        let videoRow = app.buttons["upload.video"]
        XCTAssertTrue(videoRow.waitForExistence(timeout: 5))
        XCTAssertTrue(videoRow.label.contains("Choose MP4, MOV, M4V or MKV"), "Video row: \(videoRow.label)")
        XCTAssertFalse(app.buttons["upload.save"].isEnabled, "Add episode stays disabled until a video is chosen")
        XCTAssertFalse(app.descendants(matching: .any)["upload.audioTrack"].exists, "No audio picker before an MKV is chosen")
        attach(screenshot: app.screenshot(), name: "mkv-00-upload-sheet")
    }

    @MainActor
    private func attach(screenshot: XCUIScreenshot, name: String) {
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    @MainActor
    private func attach(text: String, name: String) {
        let attachment = XCTAttachment(string: text)
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
