import XCTest

/// Landscape player: the video fills the screen; a tap on it brings the controls up, another tap hides them.
final class PlayerLandscapeUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    override func tearDown() async throws {
        await MainActor.run { XCUIDevice.shared.orientation = .portrait }
        try await super.tearDown()
    }

    @MainActor
    func testControlsAppearOnTapInLandscape() throws {
        let app = XCUIApplication()
        app.launchArguments += ["-uiTesting"]
        app.launch()

        let showTile = app.buttons["library.show.Sample Show"]
        XCTAssertTrue(showTile.waitForExistence(timeout: 30), "Seeded show should appear")
        showTile.tap()
        let episodeRow = app.buttons["episode.row.Episode 1"]
        XCTAssertTrue(episodeRow.waitForExistence(timeout: 5))
        episodeRow.tap()

        XCUIDevice.shared.orientation = .landscapeLeft

        // Fullscreen: the video is there, the controls are not.
        XCTAssertTrue(app.descendants(matching: .any)["player.video"].waitForExistence(timeout: 10))
        // Screenshot before the hidden-controls asserts, so a failure still leaves visual evidence.
        attachScreenshot(app, "landscape-01-fullscreen")
        XCTAssertTrue(app.buttons["player.back"].waitForNonExistence(timeout: 5), "Controls start hidden")
        XCTAssertFalse(app.buttons["player.makeCard"].exists)

        // Tap the video (upper middle, clear of the subtitle and the bars): controls appear.
        tapVideo(app)
        XCTAssertTrue(app.buttons["player.back"].waitForExistence(timeout: 5), "Tap shows the top bar")
        XCTAssertTrue(app.buttons["player.makeCard"].waitForExistence(timeout: 5), "Tap shows the bottom bar")
        attachScreenshot(app, "landscape-02-controls")

        // Tap again: they go away (the sample is paused, so nothing else hides them).
        tapVideo(app)
        XCTAssertTrue(app.buttons["player.back"].waitForNonExistence(timeout: 5), "Second tap hides the top bar")
        XCTAssertTrue(app.buttons["player.makeCard"].waitForNonExistence(timeout: 5), "Second tap hides the bottom bar")
    }

    @MainActor
    private func tapVideo(_ app: XCUIApplication) {
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.35)).tap()
    }

    @MainActor
    private func attachScreenshot(_ app: XCUIApplication, _ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
