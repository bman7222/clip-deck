import XCTest

final class LaunchUITests: XCTestCase {
    @MainActor
    func testEmptyLibraryOffersUpload() throws {
        let app = XCUIApplication()
        // -uiTesting gives an empty in-memory library; -uiTestingNoSeed skips the sample episode.
        app.launchArguments += ["-uiTesting", "-uiTestingNoSeed"]
        app.launch()
        XCTAssertTrue(app.navigationBars["Clip Deck"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons["library.emptyUpload"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["library.sync"].exists)

        app.buttons["library.upload"].tap()
        XCTAssertTrue(app.navigationBars["Upload episode"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["upload.save"].isEnabled, "Add episode stays disabled until a video is chosen")
    }
}
