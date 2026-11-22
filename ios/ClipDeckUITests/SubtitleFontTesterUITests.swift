import UIKit
import XCTest

/// Tester checks for T-017 that the builder's SubtitleFontUITests leave out:
/// - SheetFit and the font picker: the style sheet's top is the same before the picker opens, after Cancel, and on
///   the next open (so no wrong rise was measured or cached while the picker covered the sheet). Also when the
///   picker is opened at once, before the sheet's own fit has measured anything.
/// - Close-up element shots of the More fonts row and of the line in Georgia (bold and regular), so the Latin and
///   the Japanese faces can be judged at full resolution.
final class SubtitleFontTesterUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    override func tearDown() async throws {
        await MainActor.run { XCUIDevice.shared.orientation = .portrait }
        try await super.tearDown()
    }

    /// The sheet settles and fits, then the picker opens and is cancelled: the sheet comes back to the same top,
    /// and a second open (which starts from the cached rise) lands there too.
    @MainActor
    func testCancellingThePickerLeavesTheSheetTopAndTheCachedRiseAlone() throws {
        let app = launch(seed: nil)
        let video = app.descendants(matching: .any)["player.video"].frame
        openStyleSheet(app)
        settle(2)
        let before = try XCTUnwrap(sheetTop(app), "The sheet's own frame is in the tree")

        let more = app.buttons["subtitleStyle.font.more"]
        XCTAssertTrue(more.isHittable, "More fonts can be tapped at the first detent")
        more.tap()
        let cancel = pickerCancel(app)
        XCTAssertTrue(cancel.waitForExistence(timeout: 15), "The picker opens with a Cancel button")
        settle(1.5)
        attach(app, name: "tester-picker-open", text: "video \(video); sheet top before \(before)")
        cancel.tap()
        XCTAssertTrue(cancel.waitForNonExistence(timeout: 10), "Cancel closes the picker")
        settle(2)
        let afterCancel = try XCTUnwrap(sheetTop(app), "The sheet is still open after Cancel")
        attach(app, name: "tester-after-cancel",
               text: "video \(video); sheet top before \(before), after cancel \(afterCancel)")

        app.buttons["subtitleStyle.done"].tap()
        XCTAssertTrue(app.buttons["subtitleStyle.done"].waitForNonExistence(timeout: 5), "Done closes the sheet")
        openStyleSheet(app)
        settle(2)
        let reopened = try XCTUnwrap(sheetTop(app), "The sheet's own frame is in the tree on the next open")
        attach(app, name: "tester-reopened",
               text: "video \(video); before \(before), after cancel \(afterCancel), reopened \(reopened)")

        XCTAssertEqual(afterCancel, before, accuracy: 1, "Cancel puts the sheet back where it was")
        XCTAssertEqual(reopened, before, accuracy: 1, "The next open uses a correct cached rise")
        for top in [before, afterCancel, reopened] {
            XCTAssertGreaterThanOrEqual(top - video.maxY, -0.5, "The sheet starts below the video: \(top) vs \(video.maxY)")
            XCTAssertLessThanOrEqual(top - video.maxY, 16, "The sheet isn't far below the video: \(top) vs \(video.maxY)")
        }
        XCTAssertEqual(app.buttons["player.subtitleStyle"].value as? String, "Default", "Cancel changed nothing")
        app.terminate()
    }

    /// The picker is opened right away, inside the sheet's 0.45 s settle wait, so the fit loop is still running
    /// when the picker covers the sheet. After Cancel the sheet must still end just under the video, and so must
    /// the next open.
    @MainActor
    func testOpeningThePickerBeforeTheSheetHasSettledCachesNoWrongRise() throws {
        let app = launch(seed: nil)
        let video = app.descendants(matching: .any)["player.video"].frame
        let opener = app.buttons["player.subtitleStyle"]
        XCTAssertTrue(opener.waitForExistence(timeout: 10))
        opener.tap()
        let more = app.buttons["subtitleStyle.font.more"]
        XCTAssertTrue(more.waitForExistence(timeout: 5), "The sheet opens with More fonts")
        more.tap()
        let cancel = pickerCancel(app)
        XCTAssertTrue(cancel.waitForExistence(timeout: 15), "The picker opens with a Cancel button")
        settle(2.5)
        cancel.tap()
        XCTAssertTrue(cancel.waitForNonExistence(timeout: 10), "Cancel closes the picker")
        settle(2.5)
        let afterCancel = try XCTUnwrap(sheetTop(app), "The sheet is still open after Cancel")

        app.buttons["subtitleStyle.done"].tap()
        XCTAssertTrue(app.buttons["subtitleStyle.done"].waitForNonExistence(timeout: 5), "Done closes the sheet")
        openStyleSheet(app)
        settle(2)
        let reopened = try XCTUnwrap(sheetTop(app), "The sheet's own frame is in the tree on the next open")
        attach(app, name: "tester-early-picker",
               text: "video \(video); after cancel \(afterCancel), reopened \(reopened)")
        for top in [afterCancel, reopened] {
            XCTAssertGreaterThanOrEqual(top - video.maxY, -0.5, "The sheet starts below the video: \(top) vs \(video.maxY)")
            XCTAssertLessThanOrEqual(top - video.maxY, 16, "The sheet isn't far below the video: \(top) vs \(video.maxY)")
        }
        app.terminate()
    }

    /// AC-1: picking a preset clears the picked font. Seeded Georgia, then Serif is tapped: More fonts goes back to
    /// "None" and not selected, Serif is selected, and the style is still not the default (Serif).
    @MainActor
    func testPickingAPresetClearsThePickedFont() throws {
        let app = launch(seed: #"{"pickedFontName":"Georgia"}"#)
        openStyleSheet(app)
        let more = app.buttons["subtitleStyle.font.more"]
        XCTAssertTrue(more.waitForExistence(timeout: 5))
        XCTAssertEqual(more.value as? String, "Georgia")
        let serif = app.buttons["subtitleStyle.font.serif"]
        XCTAssertTrue(serif.isHittable)
        serif.tap()
        settle(0.8)
        XCTAssertEqual(more.value as? String, "None", "Picking a preset clears the picked font")
        XCTAssertFalse(more.isSelected, "More fonts is no longer aqua")
        XCTAssertTrue(serif.isSelected, "Serif is selected")
        XCTAssertFalse(app.buttons["subtitleStyle.font.sans"].isSelected)
        XCTAssertEqual(app.buttons["player.subtitleStyle"].value as? String, "Changed", "Serif is not the default")
        app.buttons["subtitleStyle.font.sans"].tap()
        settle(0.8)
        XCTAssertEqual(app.buttons["player.subtitleStyle"].value as? String, "Default",
                       "Sans after a cleared pick is the default again")
        app.terminate()
    }

    /// Close-ups for judging the faces: the line ("元気ですか", all Japanese, so all Hiragino Mincho for Georgia) and
    /// the More fonts row's sample "Aa あア漢字", with Bold on and off.
    @MainActor
    func testGeorgiaCloseUps() throws {
        for (seed, tag) in [(#"{"pickedFontName":"Georgia"}"#, "bold"), (#"{"pickedFontName":"Georgia","bold":false}"#, "regular")] {
            let app = launch(seed: seed)
            let row = app.descendants(matching: .any)["cue.row.1"]
            XCTAssertTrue(row.waitForExistence(timeout: 10))
            row.tap()
            let line = app.textViews["player.subtitle"]
            XCTAssertTrue(line.waitForExistence(timeout: 10))
            settle(0.8)
            keep(line.screenshot(), name: "tester-georgia-\(tag)-line")
            openStyleSheet(app)
            settle(1.5)
            let more = app.buttons["subtitleStyle.font.more"]
            XCTAssertTrue(more.isHittable)
            XCTAssertEqual(more.value as? String, "Georgia")
            keep(more.screenshot(), name: "tester-georgia-\(tag)-row")
            keep(app.buttons["subtitleStyle.font.serif"].screenshot(), name: "tester-georgia-\(tag)-serif-preset")
            keep(app.screenshot(), name: "tester-georgia-\(tag)-screen")
            app.terminate()
        }
    }

    // MARK: Helpers

    /// The font picker's dismiss button. On iOS 26 it is an X labelled "close" (CI 44957727655), elsewhere "Cancel".
    @MainActor
    private func pickerCancel(_ app: XCUIApplication) -> XCUIElement {
        app.buttons.matching(NSPredicate(format: "label IN %@", ["Cancel", "close", "Close"])).firstMatch
    }

    /// The top of the sheet itself, in window points: the innermost element that contains `subtitleStyle.sheet`.
    /// Same helper as SubtitleStyleSheetTesterUITests (see CONTEXT Learned on container frames).
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
    private func openStyleSheet(_ app: XCUIApplication) {
        let opener = app.buttons["player.subtitleStyle"]
        XCTAssertTrue(opener.waitForExistence(timeout: 10), "The controls row has the style button")
        opener.tap()
        XCTAssertTrue(app.buttons["subtitleStyle.done"].waitForExistence(timeout: 5), "The style sheet opens")
    }

    @MainActor
    private func settle(_ seconds: TimeInterval) {
        RunLoop.current.run(until: Date().addingTimeInterval(seconds))
    }

    @MainActor
    private func keep(_ screenshot: XCUIScreenshot, name: String) {
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    @MainActor
    private func attach(_ app: XCUIApplication, name: String, text: String) {
        let attachment = XCTAttachment(string: text + "\n\n" + app.debugDescription)
        attachment.name = name + "-frames"
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
