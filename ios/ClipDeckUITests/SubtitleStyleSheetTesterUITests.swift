import UIKit
import XCTest

/// Tester checks for T-015 that the builder's SubtitleStyleUITests leave out:
/// - AC-5: every control (not only the first few) starts below the video at the default text size, and the sheet
///   itself leaves the bottom of the video uncovered (a pixel check on the screenshot);
/// - AC-4: each control's spoken label and value;
/// - AC-3: every limit disables its own button (size at 60%, up at 18, left and right at ±8), not only 200% and down;
/// - AC-3: opening and using the sheet doesn't pause playback.
final class SubtitleStyleSheetTesterUITests: XCTestCase {
    private let controlIds = [
        "subtitleStyle.done", "subtitleStyle.font.sans", "subtitleStyle.font.rounded", "subtitleStyle.font.serif",
        "subtitleStyle.bold", "subtitleStyle.sizeDown", "subtitleStyle.sizeUp",
        "subtitleStyle.left", "subtitleStyle.up", "subtitleStyle.down", "subtitleStyle.right", "subtitleStyle.reset",
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
        openStyleSheet(app)
        RunLoop.current.run(until: Date().addingTimeInterval(1))
        attach(app, name: "tester-sheet-open", text: "video \(video)")

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
        expect(app, "subtitleStyle.up", label: "Move subtitles up", value: "At the default height")
        expect(app, "subtitleStyle.down", label: "Move subtitles down", value: "At the default height")
        expect(app, "subtitleStyle.left", label: "Move subtitles left", value: "Centred")
        expect(app, "subtitleStyle.right", label: "Move subtitles right", value: "Centred")
        expect(app, "subtitleStyle.bold", label: "Bold", value: "On")
        XCTAssertEqual(app.buttons["subtitleStyle.font.serif"].label, "Serif font")
        XCTAssertEqual(app.buttons["subtitleStyle.font.rounded"].label, "Rounded font")
        XCTAssertTrue(app.buttons["subtitleStyle.font.sans"].isSelected, "The selected chip has the selected trait")
        XCTAssertFalse(app.buttons["subtitleStyle.font.serif"].isSelected)
        XCTAssertEqual(app.buttons["subtitleStyle.done"].label, "Done")
        XCTAssertFalse(app.buttons["subtitleStyle.reset"].isEnabled, "Reset is disabled at the default style")
        // Checked last, so a failure here doesn't hide the label checks above (continueAfterFailure is false).
        XCTAssertLessThanOrEqual(difference, 24,
                                 "The sheet covers the bottom of the video: \(nearBottom) at maxY-3 vs \(higher) at maxY-40")
        app.terminate()
    }

    @MainActor
    func testEveryLimitDisablesItsOwnButton() throws {
        XCUIDevice.shared.orientation = .portrait
        // Smallest size, top, far right.
        var app = launch(seed: #"{"sizeStep":-4,"upSteps":18,"rightSteps":8}"#)
        openStyleSheet(app)
        XCTAssertEqual(app.staticTexts["subtitleStyle.sizeValue"].label, "60%")
        XCTAssertEqual(app.staticTexts["subtitleStyle.positionValue"].label, "Up 90% \u{00B7} Right 40%")
        XCTAssertFalse(app.buttons["subtitleStyle.sizeDown"].isEnabled, "Size down is disabled at 60%")
        XCTAssertTrue(app.buttons["subtitleStyle.sizeUp"].isEnabled)
        XCTAssertFalse(app.buttons["subtitleStyle.up"].isEnabled, "Up is disabled at 18 steps")
        XCTAssertTrue(app.buttons["subtitleStyle.down"].isEnabled)
        XCTAssertFalse(app.buttons["subtitleStyle.right"].isEnabled, "Right is disabled at +8")
        XCTAssertTrue(app.buttons["subtitleStyle.left"].isEnabled)
        expect(app, "subtitleStyle.sizeDown", label: "Smaller text", value: "60 percent")
        expect(app, "subtitleStyle.up", label: "Move subtitles up", value: "90 percent up")
        expect(app, "subtitleStyle.right", label: "Move subtitles right", value: "40 percent right")
        XCTAssertTrue(app.buttons["subtitleStyle.reset"].isEnabled, "Reset is enabled away from the default")
        app.terminate()

        // Far left.
        app = launch(seed: #"{"rightSteps":-8}"#)
        openStyleSheet(app)
        XCTAssertEqual(app.staticTexts["subtitleStyle.positionValue"].label, "Left 40%")
        XCTAssertFalse(app.buttons["subtitleStyle.left"].isEnabled, "Left is disabled at -8")
        XCTAssertTrue(app.buttons["subtitleStyle.right"].isEnabled)
        expect(app, "subtitleStyle.left", label: "Move subtitles left", value: "40 percent left")
        app.terminate()
    }

    /// The sample is 6 s long, so this plays, opens the sheet, taps once and closes it in a few seconds.
    @MainActor
    func testUsingTheSheetDoesNotPausePlayback() throws {
        XCUIDevice.shared.orientation = .portrait
        let app = launch(seed: nil)
        let playPause = app.buttons["player.playPause"]
        XCTAssertTrue(playPause.waitForExistence(timeout: 5))
        playPause.tap()
        XCTAssertEqual(playPause.label, "Pause", "Playing")
        openStyleSheet(app)
        app.buttons["subtitleStyle.sizeUp"].tap()
        XCTAssertEqual(app.staticTexts["subtitleStyle.sizeValue"].label, "110%")
        let done = app.buttons["subtitleStyle.done"]
        done.tap()
        XCTAssertTrue(done.waitForNonExistence(timeout: 5), "Done closes the sheet")
        XCTAssertEqual(playPause.label, "Pause", "Opening the sheet and tapping a control didn't pause playback")
        app.terminate()
    }

    // MARK: Helpers

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

    @MainActor
    private func launch(seed: String?) -> XCUIApplication {
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
