import XCTest

final class LaunchUITests: XCTestCase {
    /// Update this assertion when RootView is replaced: assert the real first screen instead.
    @MainActor
    func testAppLaunchesToFirstScreen() throws {
        let app = XCUIApplication()
        app.launch()
        XCTAssertTrue(app.staticTexts["Clip Deck"].waitForExistence(timeout: 10))
    }
}
