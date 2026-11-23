import XCTest

/// Tester checks for T-014 that the builder's SubtitleStyleUITests leave out:
/// - a seeded style survives a relaunch with -uiTestingKeepSubtitleStyle, and a plain -uiTesting launch clears it;
/// - an extreme style moved fully LEFT in landscape stays clear of the leading safe area (the Dynamic Island side).
final class SubtitleStyleTesterUITests: XCTestCase {
    private let seeded = #"{"font":"serif","bold":false,"sizeStep":5,"upSteps":4,"rightSteps":-4}"#
    private let extremeLeft = #"{"sizeStep":10,"upSteps":18,"rightSteps":-8}"#

    override func setUp() {
        continueAfterFailure = false
    }

    override func tearDown() async throws {
        await MainActor.run { XCUIDevice.shared.orientation = .portrait }
        try await super.tearDown()
    }

    @MainActor
    func testStyleIsKeptAcrossRelaunchOnlyWithTheKeepFlag() throws {
        XCUIDevice.shared.orientation = .portrait
        let seededFrame = subtitleFrame(arguments: ["-uiTestingSubtitleStyle", seeded], name: "relaunch-1-seeded")
        let keptFrame = subtitleFrame(arguments: ["-uiTestingKeepSubtitleStyle"], name: "relaunch-2-kept")
        let clearedFrame = subtitleFrame(arguments: [], name: "relaunch-3-cleared")

        XCTAssertEqual(keptFrame.minX, seededFrame.minX, accuracy: 1, "Kept style: same place")
        XCTAssertEqual(keptFrame.minY, seededFrame.minY, accuracy: 1, "Kept style: same place")
        XCTAssertEqual(keptFrame.height, seededFrame.height, accuracy: 1, "Kept style: same size")
        XCTAssertGreaterThan(clearedFrame.minY, seededFrame.minY + 20, "A plain -uiTesting launch clears the style")
        XCTAssertLessThan(clearedFrame.height, seededFrame.height, "A plain -uiTesting launch clears the style")
    }

    @MainActor
    func testLandscapeExtremeLeftStaysClearOfTheLeadingSafeArea() throws {
        let app = launch(arguments: ["-uiTestingSubtitleStyle", extremeLeft])
        UITestSupport.rotateToLandscape(app)
        let video = app.descendants(matching: .any)["player.video"]
        XCTAssertTrue(video.waitForExistence(timeout: 10))
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.35)).tap()
        let toggle = app.buttons["player.panelToggle"]
        XCTAssertTrue(toggle.waitForExistence(timeout: 5), "Controls show the panel button")
        toggle.tap()
        let subtitle = seekToSecondLine(app)
        // The back button is inside the safe area by design (bar padding = inset + Spacing.m).
        let back = app.buttons["player.back"]
        XCTAssertTrue(back.waitForExistence(timeout: 5))
        let window = app.windows.firstMatch.frame
        let line = subtitle.frame
        attach(app, name: "extreme-left-shown", text: "subtitle \(line)\nback \(back.frame)\nvideo \(video.frame)\nwindow \(window)")
        XCTAssertGreaterThanOrEqual(line.minX, back.frame.minX, "The line starts right of the leading safe inset")
        XCTAssertTrue(video.frame.insetBy(dx: -1, dy: -1).contains(line), "\(line) inside \(video.frame)")

        app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.35)).tap()
        XCTAssertTrue(back.waitForNonExistence(timeout: 5), "A tap on the video hides the controls")
        RunLoop.current.run(until: Date().addingTimeInterval(0.8))
        let hidden = app.textViews["player.subtitle"].frame
        attach(app, name: "extreme-left-hidden", text: "subtitle \(hidden)\nvideo \(video.frame)")
        XCTAssertEqual(hidden.minX, line.minX, accuracy: 1, "The bars don't move the line sideways")
        XCTAssertTrue(video.frame.insetBy(dx: -1, dy: -1).contains(hidden), "\(hidden) inside \(video.frame)")
        app.terminate()
    }

    // MARK: Helpers

    @MainActor
    private func subtitleFrame(arguments: [String], name: String) -> CGRect {
        let app = launch(arguments: arguments)
        let subtitle = seekToSecondLine(app)
        let frame = subtitle.frame
        attach(app, name: name, text: "subtitle \(frame)")
        app.terminate()
        return frame
    }

    @MainActor
    private func launch(arguments: [String]) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments += ["-uiTesting"] + arguments
        let showTile = UITestSupport.launchSeeded(app)
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
        RunLoop.current.run(until: Date().addingTimeInterval(0.8))
        return subtitle
    }

    @MainActor
    private func attach(_ app: XCUIApplication, name: String, text: String) {
        let attachment = XCTAttachment(string: text + "\n\n" + app.debugDescription)
        attachment.name = name + "-frames"
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
