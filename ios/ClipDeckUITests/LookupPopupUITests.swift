import XCTest

/// T-029a: the dictionary popup over the player. `-uiTestingLookup <text>` runs an exact lookup of the text when the
/// player appears; with `-uiTestingDictionary` the store holds the fixtures (words-v3, words-second, frequency, and
/// popup-frequency, which gives 元気 a badge). Nothing here plays the video, so nothing depends on playback timing.
///
/// In UI-test launches the popup's label is "Dictionary area x y w h": the area the popup may use, in screen points.
final class LookupPopupUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    override func tearDown() async throws {
        await MainActor.run { XCUIDevice.shared.orientation = .portrait }
        try await super.tearDown()
    }

    // MARK: Helpers

    @MainActor
    private func openPlayer(text: String, dictionaries: Bool, landscape: Bool) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments += ["-uiTesting", "-uiTestingLookup", text] + (dictionaries ? ["-uiTestingDictionary"] : [])
        app.launchEnvironment["CLIPDECK_FIXTURES"] = ProcessInfo.processInfo.environment["CLIPDECK_FIXTURES"] ?? ""
        UITestSupport.launchAndOpenSampleEpisode(app)
        if landscape { UITestSupport.rotateToLandscape(app) }
        return app
    }

    @MainActor
    private func popup(_ app: XCUIApplication) -> XCUIElement {
        app.descendants(matching: .any)["lookup.popup"]
    }

    /// The text of the web view that contains `fragment`; the page is one WKWebView, so its text is found there.
    @MainActor
    private func webText(_ app: XCUIApplication, containing fragment: String) -> XCUIElement {
        app.webViews.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", fragment)).firstMatch
    }

    /// The popup's frame and its allowed area, from one snapshot.
    @MainActor
    private func frameAndArea(_ popup: XCUIElement) throws -> (frame: CGRect, area: CGRect) {
        let snapshot = try popup.snapshot()
        let numbers = snapshot.label.split(separator: " ").dropFirst(2).compactMap { Double($0) }
        XCTAssertEqual(numbers.count, 4, "The popup label holds its area: \(snapshot.label)")
        guard numbers.count == 4 else { return (snapshot.frame, .zero) }
        return (snapshot.frame, CGRect(x: numbers[0], y: numbers[1], width: numbers[2], height: numbers[3]))
    }

    @MainActor
    private func attach(_ element: XCUIElement, _ app: XCUIApplication, name: String) {
        let attachment = XCTAttachment(screenshot: element.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
        UITestSupport.attachText(app.debugDescription, name: "\(name)-tree", to: self)
    }

    /// Waits for the popup to show the 元気 entry.
    @MainActor
    private func waitForEntry(_ app: XCUIApplication) {
        XCTAssertTrue(UITestSupport.waitForValue(popup(app), "元気 げんき", timeout: 60), "The popup reads 元気 げんき: \(String(describing: popup(app).value))")
    }

    // MARK: Content

    @MainActor func testPortraitShowsTheEntryAndTheCloseButtonClosesIt() throws { try checkEntryAndClose(landscape: false) }
    @MainActor func testLandscapeShowsTheEntryAndTheCloseButtonClosesIt() throws { try checkEntryAndClose(landscape: true) }

    /// 元気: the headword, the definition text and the frequency badge are all in the web view, each dictionary has its section.
    @MainActor
    private func checkEntryAndClose(landscape: Bool) throws {
        let app = openPlayer(text: "元気", dictionaries: true, landscape: landscape)
        let entry = popup(app)
        waitForEntry(app)
        XCTAssertTrue(UITestSupport.wait(timeout: 30) { app.webViews.firstMatch.exists }, "The popup has a web view")
        XCTAssertTrue(UITestSupport.wait(timeout: 30) { webText(app, containing: "healthy").exists }, "The definition text is in the web view")
        XCTAssertTrue(webText(app, containing: "energetic").exists, "Every gloss is shown")
        XCTAssertTrue(webText(app, containing: "1,234").exists, "The frequency badge shows its value")
        XCTAssertTrue(webText(app, containing: "Popup Frequency").exists, "The frequency badge names its dictionary")
        XCTAssertTrue(webText(app, containing: "Clip Test Words").exists, "The definitions sit in their dictionary's section")
        attach(entry, app, name: landscape ? "lookup-popup-landscape" : "lookup-popup-portrait")

        let close = app.buttons["lookup.popup.close"]
        XCTAssertTrue(close.exists, "The popup has a close button")
        XCTAssertFalse(app.buttons["lookup.popup.useForCard"].exists, "Use for a card shows only when a handler is given")
        UITestSupport.tap(close, patience: 10) { !entry.exists }
        XCTAssertTrue(UITestSupport.wait(timeout: 10) { !entry.exists }, "The close button closes the popup")
    }

    @MainActor
    func testAWordWithNoEntryShowsNoEntriesFor() throws {
        let app = openPlayer(text: "zzz", dictionaries: true, landscape: false)
        let message = app.descendants(matching: .any)["lookup.popup.message"]
        XCTAssertTrue(UITestSupport.waitForLabel(message, "No entries for zzz", timeout: 60), "The popup says there are no entries: \(message.label)")
        XCTAssertEqual(popup(app).value as? String, "No entries for zzz")
        attach(popup(app), app, name: "lookup-popup-no-entries")
    }

    @MainActor
    func testAnEmptyStoreShowsNoDictionariesYet() throws {
        let app = openPlayer(text: "元気", dictionaries: false, landscape: false)
        let message = app.descendants(matching: .any)["lookup.popup.message"]
        XCTAssertTrue(UITestSupport.waitForLabel(message, "No dictionaries yet", timeout: 60), "The popup says there are no dictionaries: \(message.label)")
        XCTAssertTrue(app.staticTexts["Add one with the Dictionaries button in the Library."].exists, "It points to the Dictionaries button")
        XCTAssertEqual(popup(app).value as? String, "No dictionaries yet")
        attach(popup(app), app, name: "lookup-popup-no-dictionaries")
    }

    // MARK: Placement

    /// Portrait: x = 16, width = the safe area's width − 32, 260 pt tall, its bottom 16 pt above the safe area's bottom.
    @MainActor
    func testPortraitDefaultFrameAndPlayPauseStaysHittable() throws {
        let app = openPlayer(text: "元気", dictionaries: true, landscape: false)
        waitForEntry(app)
        let window = app.windows.firstMatch.frame
        let (frame, area) = try frameAndArea(popup(app))
        UITestSupport.attachText("frame \(frame)\narea \(area)\nwindow \(window)", name: "lookup-popup-portrait-frame", to: self)

        XCTAssertEqual(frame.minX, area.minX + 16, accuracy: 1, "x is 16 pt in")
        XCTAssertEqual(frame.width, area.width - 32, accuracy: 1, "full width less 16 pt each side")
        XCTAssertEqual(frame.height, 260, accuracy: 1, "260 pt tall")
        XCTAssertEqual(frame.maxY, area.maxY - 16, accuracy: 1, "the bottom is 16 pt above the safe area's bottom")
        XCTAssertGreaterThanOrEqual(area.minX, window.minX, "The area is inside the window")
        XCTAssertLessThanOrEqual(area.maxX, window.maxX)
        XCTAssertLessThanOrEqual(area.maxY, window.maxY)
        XCTAssertGreaterThanOrEqual(frame.minY, area.minY, "The popup is inside the safe area")

        let playPause = app.buttons["player.playPause"]
        XCTAssertTrue(UITestSupport.wait(timeout: 20) { playPause.exists && playPause.isHittable }, "Play/pause stays hittable with the popup open")
    }

    /// Landscape: 300 x 200, 16 pt in from the top and trailing edges of the video column, inside the safe area; the
    /// bars (and so play/pause) stay on top of it.
    @MainActor
    func testLandscapeDefaultFrameAndPlayPauseStaysHittable() throws {
        let app = openPlayer(text: "元気", dictionaries: true, landscape: true)
        waitForEntry(app)
        let video = app.descendants(matching: .any)["player.video"].frame
        let (frame, area) = try frameAndArea(popup(app))
        UITestSupport.attachText("frame \(frame)\narea \(area)\nvideo \(video)", name: "lookup-popup-landscape-frame", to: self)

        XCTAssertEqual(frame.width, 300, accuracy: 1, "300 pt wide")
        XCTAssertEqual(frame.height, 200, accuracy: 1, "200 pt tall")
        XCTAssertEqual(frame.maxX, area.maxX - 16, accuracy: 1, "16 pt in from the trailing edge")
        XCTAssertEqual(frame.minY, area.minY + 16, accuracy: 1, "16 pt in from the top edge")
        XCTAssertGreaterThanOrEqual(area.minX, video.minX - 1, "The area is inside the video column")
        XCTAssertLessThanOrEqual(area.maxX, video.maxX + 1)
        XCTAssertGreaterThanOrEqual(area.minY, video.minY - 1)
        XCTAssertLessThanOrEqual(frame.maxX, video.maxX - 16 + 1, "The popup is 16 pt or more inside the column's trailing edge")
        XCTAssertGreaterThanOrEqual(frame.minY, video.minY + 16 - 1, "The popup is 16 pt or more inside the column's top edge")

        // The controls start hidden in landscape: a tap shows them, and they lie above the popup.
        let playPause = app.buttons["player.playPause"]
        for _ in 0..<3 where !playPause.exists {
            app.coordinate(withNormalizedOffset: CGVector(dx: 0.35, dy: 0.35)).tap()
            _ = UITestSupport.wait(timeout: 5) { playPause.exists }
        }
        XCTAssertTrue(UITestSupport.wait(timeout: 20) { playPause.exists && playPause.isHittable }, "Play/pause stays hittable with the popup open")
        let toggle = app.buttons["player.panelToggle"]
        XCTAssertTrue(toggle.exists, "The top bar shows")
        XCTAssertLessThanOrEqual(frame.maxX, toggle.frame.maxX, "The popup stays inside the safe area, like the top bar's buttons")
        UITestSupport.attachText(app.debugDescription, name: "lookup-popup-landscape-controls-tree", to: self)
    }
}
