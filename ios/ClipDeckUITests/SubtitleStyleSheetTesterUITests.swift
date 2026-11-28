import UIKit
import XCTest

/// Tester checks for T-015 that the builder's SubtitleStyleUITests leave out:
/// - AC-5: every control (not only the first few) starts below the video at the default text size, and the sheet
///   itself leaves the bottom of the video uncovered (a pixel check on the screenshot);
/// - AC-4: each control's spoken label and value;
/// - AC-3: the size limit at 60% disables its own button (the position limits are in MoveTextTesterUITests);
/// - AC-3: opening and using the sheet doesn't pause playback;
/// - T-024b AC-7: a tap on the video closes the sheet and leaves the overlay as it was.
final class SubtitleStyleSheetTesterUITests: XCTestCase {
    private let controlIds = [
        "subtitleStyle.done", "subtitleStyle.font.sans", "subtitleStyle.font.rounded", "subtitleStyle.font.serif",
        "subtitleStyle.bold", "subtitleStyle.sizeDown", "subtitleStyle.sizeUp",
        "subtitleStyle.reset",
    ]

    override func setUp() {
        continueAfterFailure = false
    }

    override func tearDown() async throws {
        await MainActor.run { XCUIDevice.shared.orientation = .portrait }
        try await super.tearDown()
    }

    @MainActor
    func testEveryControlStartsBelowTheVideoAndIsLabelled() throws {
        XCUIDevice.shared.orientation = .portrait
        let app = launch(seed: nil)
        let video = app.descendants(matching: .any)["player.video"].frame
        let navigationBar = app.navigationBars.firstMatch
        let barBefore = navigationBar.frame
        XCTAssertTrue(navigationBar.buttons["BackButton"].exists, "Back is shown before the sheet opens")
        openStyleSheet(app)
        RunLoop.current.run(until: Date().addingTimeInterval(1))
        attach(app, name: "tester-sheet-open", text: "video \(video)")

        // C2: back is hidden while the sheet is open, and hiding it doesn't move the bar or the video.
        XCTAssertFalse(navigationBar.buttons["BackButton"].exists, "Back is hidden while the sheet is open")
        XCTAssertEqual(navigationBar.frame, barBefore, "The navigation bar doesn't move when back hides")
        XCTAssertEqual(app.descendants(matching: .any)["player.video"].frame, video, "The video doesn't move")

        // The sheet itself (not only its controls) must leave the video uncovered: near the video's bottom edge,
        // left of the centred line, the pixel is still the video's colour, the same as 40 pt higher.
        let shot = app.screenshot()
        let image = XCTAttachment(screenshot: shot)
        image.name = "tester-sheet-open-screenshot"
        image.lifetime = .keepAlways
        add(image)
        let x = video.minX + video.width * 0.2
        let nearBottom = rgb(shot, at: CGPoint(x: x, y: video.maxY - 3))
        let higher = rgb(shot, at: CGPoint(x: x, y: video.maxY - 40))
        let difference = zip(nearBottom, higher).map { abs($0 - $1) }.max() ?? 255

        for id in controlIds {
            let control = app.buttons[id]
            XCTAssertTrue(control.exists, "\(id) is a button in the sheet")
            XCTAssertGreaterThanOrEqual(control.frame.minY, video.maxY - 1, "\(id) starts below the video")
            XCTAssertFalse(control.label.isEmpty, "\(id) has a spoken label")
        }

        expect(app, "subtitleStyle.sizeUp", label: "Larger text", value: "100 percent")
        expect(app, "subtitleStyle.sizeDown", label: "Smaller text", value: "100 percent")
        for id in ["up", "down", "left", "right"] {
            XCTAssertFalse(app.buttons["subtitleStyle.\(id)"].exists, "The Font sheet has no \(id) arrow")
        }
        expect(app, "subtitleStyle.bold", label: "Bold", value: "On")
        XCTAssertEqual(app.buttons["subtitleStyle.font.serif"].label, "Serif font")
        XCTAssertEqual(app.buttons["subtitleStyle.font.rounded"].label, "Rounded font")
        XCTAssertTrue(app.buttons["subtitleStyle.font.sans"].isSelected, "The selected chip has the selected trait")
        XCTAssertFalse(app.buttons["subtitleStyle.font.serif"].isSelected)
        XCTAssertEqual(app.buttons["subtitleStyle.done"].label, "Done")
        XCTAssertFalse(app.buttons["subtitleStyle.reset"].isEnabled, "Reset is disabled at the default font group")
        XCTAssertEqual(app.buttons["subtitleStyle.reset"].value as? String, "Default")
        // Checked last, so a failure here doesn't hide the label checks above (continueAfterFailure is false).
        XCTAssertLessThanOrEqual(difference, 24,
                                 "The sheet covers the bottom of the video: \(nearBottom) at maxY-3 vs \(higher) at maxY-40")
        // Round 3 (S2): the first detent is measured and corrected, so the sheet sits just under the video: neither
        // over it nor much lower (the target gap is 8 pt).
        let sheet = app.descendants(matching: .any)["subtitleStyle.sheet"].firstMatch
        XCTAssertTrue(sheet.exists, "The sheet's container is in the tree")
        let top = try XCTUnwrap(sheetTop(app), "The sheet's own frame is in the tree")
        let gap = top - video.maxY
        XCTAssertGreaterThanOrEqual(gap, -0.5, "The sheet starts below the video: top \(top), video \(video.maxY)")
        XCTAssertLessThanOrEqual(gap, 16, "The sheet doesn't sit too low: top \(top), video \(video.maxY)")
        app.terminate()
    }

    /// S2 end to end: a wrong saved rise (0 pt, as if the system drew the sheet about 20 pt lower than it does) opens
    /// the first detent too tall, so at first the sheet covers the bottom of the video. Once it has settled, the sheet
    /// measures its own top and corrects the detent once, ending just under the video. The launch argument overrides
    /// `player.styleSheetRise` for this launch only (the argument domain), so later tests keep the measured value.
    /// The early screenshots record whether the wrong first position was caught before the correction (it's a race
    /// with the 0.45 s settle wait, so that part is attached, not asserted).
    @MainActor
    func testAWrongSavedRiseIsCorrectedOnceTheSheetHasSettled() throws {
        XCUIDevice.shared.orientation = .portrait
        let zeroRise = #"<?xml version="1.0" encoding="UTF-8"?><plist version="1.0"><real>0</real></plist>"#
        let app = launch(seed: nil, extraArguments: ["-player.styleSheetRise", zeroRise])
        let video = app.descendants(matching: .any)["player.video"].frame
        let opener = app.buttons["player.subtitleStyle"]
        XCTAssertTrue(opener.waitForExistence(timeout: 10), "The controls row has the style button")
        opener.tap()

        // About 3 s of screenshots: is the bottom of the video covered (the sheet's white near maxY instead of the
        // video's colour 40 pt higher)?
        let start = Date()
        var log: [String] = []
        var coveredEarly = false
        while Date().timeIntervalSince(start) < 3 {
            let shot = app.screenshot()
            let x = video.minX + video.width * 0.2
            let nearBottom = rgb(shot, at: CGPoint(x: x, y: video.maxY - 3))
            let higher = rgb(shot, at: CGPoint(x: x, y: video.maxY - 40))
            let difference = zip(nearBottom, higher).map { abs($0 - $1) }.max() ?? 255
            if difference > 24 { coveredEarly = true }
            let elapsed = (Date().timeIntervalSince(start) * 100).rounded() / 100
            log.append("t \(elapsed) s: maxY-3 \(nearBottom) vs maxY-40 \(higher) (difference \(difference))")
        }
        XCTAssertTrue(app.buttons["subtitleStyle.done"].waitForExistence(timeout: 5), "The style sheet opens")
        let top = try XCTUnwrap(sheetTop(app), "The sheet's own frame is in the tree")
        log.append("covered early: \(coveredEarly); settled sheet top \(top), video maxY \(video.maxY)")
        attach(app, name: "tester-wrong-rise", text: log.joined(separator: "\n"))

        let gap = top - video.maxY
        XCTAssertGreaterThanOrEqual(gap, -0.5, "After the correction the sheet starts below the video: top \(top), video \(video.maxY)")
        XCTAssertLessThanOrEqual(gap, 16, "After the correction the sheet doesn't sit too low: top \(top), video \(video.maxY)")
        let shot = app.screenshot()
        let x = video.minX + video.width * 0.2
        let nearBottom = rgb(shot, at: CGPoint(x: x, y: video.maxY - 3))
        let higher = rgb(shot, at: CGPoint(x: x, y: video.maxY - 40))
        let difference = zip(nearBottom, higher).map { abs($0 - $1) }.max() ?? 255
        XCTAssertLessThanOrEqual(difference, 24,
                                 "After the correction the sheet leaves the video uncovered: \(nearBottom) vs \(higher)")
        app.terminate()
    }

    @MainActor
    func testSizeDownDisablesAtSixtyPercent() throws {
        XCUIDevice.shared.orientation = .portrait
        let app = launch(seed: #"{"sizeStep":-4}"#)
        openStyleSheet(app)
        XCTAssertEqual(app.staticTexts["subtitleStyle.sizeValue"].label, "60%")
        XCTAssertFalse(app.buttons["subtitleStyle.sizeDown"].isEnabled, "Size down is disabled at 60%")
        XCTAssertTrue(app.buttons["subtitleStyle.sizeUp"].isEnabled)
        expect(app, "subtitleStyle.sizeDown", label: "Smaller text", value: "60 percent")
        XCTAssertTrue(app.buttons["subtitleStyle.reset"].isEnabled, "Reset is enabled away from the default")
        XCTAssertEqual(app.buttons["subtitleStyle.reset"].value as? String, "Changed")
        app.terminate()
    }

    /// The clip is 20 s here (`-uiTestingSampleSeconds 20`): the 6 s default ended 4 to 5 s after Play, and the read
    /// flaked (CI 45168178904). Playback is read while the sheet is still open (the player stays in the
    /// accessibility tree under the sheet; CI 44888942981 `tester-sheet-open-frames`).
    @MainActor
    func testUsingTheSheetDoesNotPausePlayback() throws {
        XCUIDevice.shared.orientation = .portrait
        let app = launch(seed: nil, extraArguments: ["-uiTestingSampleSeconds", "20"])
        let playPause = app.buttons["player.playPause"]
        XCTAssertTrue(playPause.waitForExistence(timeout: 5))
        playPause.tap()
        openStyleSheet(app)
        XCTAssertEqual(playPause.label, "Pause", "Opening the sheet didn't pause playback")
        app.buttons["subtitleStyle.sizeUp"].tap()
        XCTAssertEqual(playPause.label, "Pause", "Tapping a control in the sheet didn't pause playback")
        XCTAssertEqual(app.staticTexts["subtitleStyle.sizeValue"].label, "110%")
        let done = app.buttons["subtitleStyle.done"]
        done.tap()
        XCTAssertTrue(done.waitForNonExistence(timeout: 5), "Done closes the sheet")
        XCTAssertTrue(app.navigationBars.buttons["BackButton"].waitForExistence(timeout: 5),
                      "Back comes back when the sheet closes")
        app.terminate()
    }

    /// T-024b AC-7: a tap on the video closes the sheet, as Done does, and the centred overlay keeps the state it had
    /// (hidden, then shown), instead of the tap silently toggling it.
    @MainActor
    func testATapOnTheVideoClosesTheSheetAndLeavesTheOverlayAsItWas() throws {
        XCUIDevice.shared.orientation = .portrait
        let app = launch(seed: nil)
        let overlay = app.buttons["player.overlay.playPause"]
        let done = app.buttons["subtitleStyle.done"]
        XCTAssertFalse(overlay.exists, "Portrait starts with the overlay hidden")

        openStyleSheet(app)
        tapVideo(app)
        XCTAssertTrue(done.waitForNonExistence(timeout: 5), "A tap on the video closes the sheet")
        RunLoop.current.run(until: Date().addingTimeInterval(1))
        XCTAssertFalse(overlay.exists, "The tap only closed the sheet: the hidden overlay stays hidden")

        tapVideo(app)
        XCTAssertTrue(overlay.waitForExistence(timeout: 5), "A tap on the video shows the overlay")
        openStyleSheet(app)
        tapVideo(app)
        XCTAssertTrue(done.waitForNonExistence(timeout: 5), "A tap on the video closes the sheet again")
        XCTAssertTrue(overlay.waitForExistence(timeout: 5), "The tap only closed the sheet: the shown overlay stays shown")
        app.terminate()
    }

    // MARK: Helpers

    @MainActor
    private func tapVideo(_ app: XCUIApplication) {
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.3, dy: 0.35)).tap()
    }

    /// The RGB of one point (in points, from the top left) of a screenshot.
    @MainActor
    private func rgb(_ shot: XCUIScreenshot, at point: CGPoint) -> [Int] {
        let image = shot.image
        guard let cg = image.cgImage, image.size.width > 0 else { return [] }
        let scale = CGFloat(cg.width) / image.size.width
        let px = (point.x * scale).rounded(.down)
        let py = (point.y * scale).rounded(.down)
        var pixel = [UInt8](repeating: 0, count: 4)
        let drawn: Bool = pixel.withUnsafeMutableBytes { buffer in
            guard let context = CGContext(
                data: buffer.baseAddress, width: 1, height: 1, bitsPerComponent: 8, bytesPerRow: 4,
                space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
            else { return false }
            // Core Graphics counts rows from the bottom, so the wanted row is moved onto the context's only pixel.
            context.draw(cg, in: CGRect(x: -px, y: -(CGFloat(cg.height) - 1 - py),
                                        width: CGFloat(cg.width), height: CGFloat(cg.height)))
            return true
        }
        return drawn ? pixel.prefix(3).map { Int($0) } : []
    }

    @MainActor
    private func expect(_ app: XCUIApplication, _ id: String, label: String, value: String,
                        file: StaticString = #filePath, line: UInt = #line) {
        let control = app.buttons[id]
        XCTAssertEqual(control.label, label, "\(id) label", file: file, line: line)
        XCTAssertEqual(control.value as? String, value, "\(id) value", file: file, line: line)
    }

    /// The top of the sheet itself, in window points: the innermost element that contains `subtitleStyle.sheet`.
    /// The container can't be used: XCUITest reports a `.contain` container as the union of its children, so its
    /// top is Done's top, under the header's padding (CI 44893660834: container 364.8, the sheet 349.4).
    /// The `containing` query also returns the container itself (CI 44896666698: a `<=` filter picked 364.8), so
    /// the container's own frame is left out by identifier and by a strict comparison.
    @MainActor
    private func sheetTop(_ app: XCUIApplication) -> CGFloat? {
        let container = app.descendants(matching: .any)["subtitleStyle.sheet"].firstMatch
        guard container.exists else { return nil }
        let containerTop = container.frame.minY
        let wrappers = app.otherElements.containing(.any, identifier: "subtitleStyle.sheet").allElementsBoundByIndex
        return wrappers
            .filter { $0.identifier != "subtitleStyle.sheet" }
            .map { $0.frame.minY }
            .filter { $0 > 0 && $0 < containerTop - 0.5 }
            .max()
    }

    @MainActor
    private func launch(seed: String?, extraArguments: [String] = []) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments += ["-uiTesting"]
        if let seed { app.launchArguments += ["-uiTestingSubtitleStyle", seed] }
        app.launchArguments += extraArguments
        let showTile = UITestSupport.launchSeeded(app)
        showTile.tap()
        let episodeRow = app.buttons["episode.row.Episode 1"]
        XCTAssertTrue(episodeRow.waitForExistence(timeout: 5))
        episodeRow.tap()
        XCTAssertTrue(app.descendants(matching: .any)["player.video"].waitForExistence(timeout: 10))
        return app
    }

    @MainActor
    private func openStyleSheet(_ app: XCUIApplication) {
        let opener = app.buttons["player.subtitleStyle"]
        XCTAssertTrue(opener.waitForExistence(timeout: 10), "The controls row has the style button")
        opener.tap()
        XCTAssertTrue(app.buttons["subtitleStyle.done"].waitForExistence(timeout: 5), "The style sheet opens")
    }

    @MainActor
    private func attach(_ app: XCUIApplication, name: String, text: String) {
        let attachment = XCTAttachment(string: text + "\n\n" + app.debugDescription)
        attachment.name = name + "-frames"
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
