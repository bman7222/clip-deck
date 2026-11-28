import XCTest

/// T-028: the Dictionaries sheet. `-uiTestingDictionary` imports the checked-in fixtures (words-v3, words-second,
/// frequency; ids 1, 2, 3) from `$CLIPDECK_FIXTURES/dictionaries` into a fresh temporary database. The JMdict
/// download is never tapped: UI tests don't use the network.
final class DictionaryManagerUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    @MainActor
    private func launch(seeded: Bool) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments += ["-uiTesting", "-uiTestingNoSeed"] + (seeded ? ["-uiTestingDictionary"] : [])
        app.launchEnvironment["CLIPDECK_FIXTURES"] = ProcessInfo.processInfo.environment["CLIPDECK_FIXTURES"] ?? ""
        app.launch()
        return app
    }

    @MainActor
    private func openSheet(_ app: XCUIApplication) {
        let button = app.buttons["library.dictionaries"]
        XCTAssertTrue(button.waitForExistence(timeout: 90), "The library shows the Dictionaries button")
        let bar = app.navigationBars["Dictionaries"]
        UITestSupport.tap(button, patience: 10) { bar.exists }
        XCTAssertTrue(bar.waitForExistence(timeout: 20), "The Dictionaries sheet opens")
    }

    @MainActor
    private func element(_ app: XCUIApplication, _ identifier: String) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: identifier).firstMatch
    }

    @MainActor
    private func closeSheet(_ app: XCUIApplication) {
        let bar = app.navigationBars["Dictionaries"]
        UITestSupport.tap(app.buttons["dictionaries.done"], patience: 10) { !bar.exists }
        XCTAssertTrue(UITestSupport.wait(timeout: 10) { !bar.exists }, "Done closes the sheet")
    }

    @MainActor
    func testTheButtonIsLeftmostInTheTrailingGroup() throws {
        let app = launch(seeded: false)
        let dictionaries = app.buttons["library.dictionaries"]
        let sync = app.buttons["library.sync"]
        let upload = app.buttons["library.upload"]
        XCTAssertTrue(dictionaries.waitForExistence(timeout: 90))
        XCTAssertTrue(sync.exists && upload.exists)
        XCTAssertEqual(dictionaries.label, "Dictionaries")
        XCTAssertLessThan(dictionaries.frame.minX, sync.frame.minX, "Dictionaries is left of Sync")
        XCTAssertLessThan(sync.frame.minX, upload.frame.minX, "Sync is left of Upload")
        XCTAssertGreaterThan(dictionaries.frame.minX, app.buttons["library.settings"].frame.maxX, "Dictionaries is in the trailing group")
    }

    @MainActor
    func testAnEmptySheetExplainsImportAndDownloadAndImportOpensTheFilePicker() throws {
        let app = launch(seeded: false)
        openSheet(app)
        XCTAssertTrue(element(app, "dictionaries.empty").waitForExistence(timeout: 10), "The empty sheet explains what to do")
        XCTAssertTrue(element(app, "dictionaries.sheet").exists)
        XCTAssertTrue(app.buttons["dictionaries.downloadJMdict"].exists, "The JMdict download button exists")
        XCTAssertTrue(app.buttons["dictionaries.downloadJMdict"].isEnabled)

        let importButton = app.buttons["dictionaries.import"]
        XCTAssertTrue(importButton.exists)
        importButton.tap()
        // The system picker is a remote view over the sheet, so the sheet's own button is no longer reachable.
        XCTAssertTrue(UITestSupport.wait(timeout: 20) { !importButton.isHittable }, "The file picker covers the sheet")
        UITestSupport.attachScreenshot(app, name: "dictionaries-01-file-picker", to: self)
        UITestSupport.attachText(app.debugDescription, name: "dictionaries-01-file-picker-tree", to: self)
    }

    @MainActor
    func testTheSheetListsTheFixturesInOrderWithKindAndCount() throws {
        let app = launch(seeded: true)
        openSheet(app)
        for id in 1...3 {
            XCTAssertTrue(element(app, "dictionaries.row.\(id)").waitForExistence(timeout: 20), "Row \(id) is listed")
        }
        let titles = ["Clip Test Words", "Second Test Words", "Test Frequency"]
        let details = ["Words · 9 entries · ", "Words · 2 entries · ", "Frequency · 4 entries · "]
        for index in 0..<3 {
            let title = app.staticTexts["dictionaries.title.\(index + 1)"]
            XCTAssertEqual(title.label, titles[index])
            let detail = app.staticTexts["dictionaries.detail.\(index + 1)"]
            XCTAssertTrue(detail.label.hasPrefix(details[index]), "Row \(index + 1) says: \(detail.label)")
            XCTAssertTrue(element(app, "dictionaries.enabled.\(index + 1)").exists, "Row \(index + 1) has its switch")
        }
        XCTAssertLessThan(element(app, "dictionaries.row.1").frame.minY, element(app, "dictionaries.row.2").frame.minY)
        XCTAssertLessThan(element(app, "dictionaries.row.2").frame.minY, element(app, "dictionaries.row.3").frame.minY)
        UITestSupport.attachScreenshot(app, name: "dictionaries-02-sheet", to: self)
    }

    @MainActor
    func testSwitchingOffAndDeletingWithConfirmation() throws {
        let app = launch(seeded: true)
        openSheet(app)
        let toggle = element(app, "dictionaries.enabled.2")
        XCTAssertTrue(toggle.waitForExistence(timeout: 20))
        XCTAssertTrue(UITestSupport.waitForValue(toggle, "1", timeout: 5), "Switched on at first")
        toggle.tap()
        XCTAssertTrue(UITestSupport.waitForValue(toggle, "0", timeout: 10), "The switch turns off")
        UITestSupport.attachScreenshot(app, name: "dictionaries-03-switched-off", to: self)

        let row = element(app, "dictionaries.row.2")
        row.swipeLeft()
        let delete = app.buttons["dictionaries.delete.2"]
        XCTAssertTrue(delete.waitForExistence(timeout: 10), "Swiping a row shows Delete")
        delete.tap()
        let confirms = app.buttons.matching(identifier: "Delete dictionary")
        XCTAssertTrue(confirms.firstMatch.waitForExistence(timeout: 10), "Delete asks first")
        UITestSupport.attachScreenshot(app, name: "dictionaries-04-confirm", to: self)
        XCTAssertTrue(row.exists, "Nothing is deleted before the confirmation")
        // iOS 26 puts the dialog's buttons in both a popover and its sheet, so the query matches more than one.
        let confirm = confirms.allElementsBoundByIndex.first { $0.isHittable } ?? confirms.firstMatch
        confirm.tap()
        XCTAssertTrue(UITestSupport.wait(timeout: 10) { !row.exists }, "The dictionary is gone after confirming")
        XCTAssertTrue(element(app, "dictionaries.row.1").exists)
        XCTAssertTrue(element(app, "dictionaries.row.3").exists)
        closeSheet(app)
        openSheet(app)
        XCTAssertTrue(element(app, "dictionaries.row.3").waitForExistence(timeout: 10))
        XCTAssertFalse(element(app, "dictionaries.row.2").exists, "The deletion survives reopening the sheet")
    }

    @MainActor
    func testAReorderSurvivesReopeningTheSheet() throws {
        let app = launch(seeded: true)
        openSheet(app)
        let first = app.staticTexts["dictionaries.title.1"]
        let third = app.staticTexts["dictionaries.title.3"]
        XCTAssertTrue(third.waitForExistence(timeout: 20))
        let reorder = app.buttons["dictionaries.reorder"]
        XCTAssertTrue(reorder.exists, "Reorder shows with two or more dictionaries")
        UITestSupport.tap(reorder, patience: 10) { app.buttons["Stop reordering"].exists }
        UITestSupport.settle()

        // Drag row 3's reorder control above row 1. The control is the list's own button, inside the row's inset.
        let thirdMid = element(app, "dictionaries.row.3").frame.midY
        let firstTop = element(app, "dictionaries.row.1").frame.minY
        let controls = app.buttons.matching(NSPredicate(format: "label BEGINSWITH[c] 'Reorder'")).allElementsBoundByIndex
        let control = controls.min { abs($0.frame.midY - thirdMid) < abs($1.frame.midY - thirdMid) }
        let origin = app.coordinate(withNormalizedOffset: .zero)
        let handleX = control.map { $0.frame.midX } ?? element(app, "dictionaries.row.3").frame.maxX - 22
        let handle = origin.withOffset(CGVector(dx: handleX, dy: thirdMid))
        let target = origin.withOffset(CGVector(dx: handleX, dy: firstTop - 4))
        handle.press(forDuration: 0.8, thenDragTo: target)
        let moved = UITestSupport.wait(timeout: 10) { third.frame.minY < first.frame.minY }
        if !moved {
            UITestSupport.attachText("reorder controls: \(controls.map { "\($0.label) \($0.frame)" })\n\n\(app.debugDescription)",
                                     name: "dictionaries-reorder-tree", to: self)
        }
        XCTAssertTrue(moved, "Row 3 moved above row 1")
        UITestSupport.attachScreenshot(app, name: "dictionaries-05-reordered", to: self)

        UITestSupport.tap(app.buttons["Stop reordering"], patience: 10) { app.buttons["Reorder"].exists }
        closeSheet(app)
        openSheet(app)
        XCTAssertTrue(third.waitForExistence(timeout: 10))
        XCTAssertLessThan(third.frame.minY, first.frame.minY, "The new order is still there after reopening")
        UITestSupport.attachScreenshot(app, name: "dictionaries-06-reopened", to: self)
    }

    @MainActor
    func testSourcesAreInTheSheetAndLinkedFromAbout() throws {
        let app = launch(seeded: true)
        openSheet(app)
        let sources = element(app, "dictionaries.sources")
        var tries = 0
        while !(sources.exists && sources.isHittable) && tries < 10 {
            app.swipeUp()
            tries += 1
        }
        XCTAssertTrue(sources.exists, "The sheet has a Sources section")
        XCTAssertTrue(sources.label.contains("CC BY-SA 4.0"))
        XCTAssertTrue(sources.label.contains("EDRDG"))
        let attribution = element(app, "dictionaries.attribution.1")
        tries = 0
        while !attribution.exists && tries < 10 {
            app.swipeUp()
            tries += 1
        }
        XCTAssertTrue(attribution.exists, "An installed dictionary's own attribution is listed")
        XCTAssertTrue(attribution.label.contains("Test data written for Clip Deck"), attribution.label)
        closeSheet(app)

        let settings = app.buttons["library.settings"]
        UITestSupport.tap(settings, patience: 10) { app.navigationBars["Anki settings"].exists }
        let aboutRow = app.buttons["settings.about"]
        tries = 0
        while !aboutRow.exists && tries < 12 {
            app.swipeUp()
            tries += 1
        }
        let aboutBar = app.navigationBars["About and licences"]
        UITestSupport.tap(aboutRow, patience: 10) { aboutBar.exists }
        let link = element(app, "about.dictionarySources")
        XCTAssertTrue(link.waitForExistence(timeout: 20), "About links to the dictionary sources")
        let sourcesBar = app.navigationBars["Dictionary sources"]
        UITestSupport.tap(link, patience: 10) { sourcesBar.exists }
        XCTAssertTrue(sourcesBar.waitForExistence(timeout: 20))
        XCTAssertTrue(element(app, "dictionaries.sources").waitForExistence(timeout: 10))
        let aboutAttribution = element(app, "dictionaries.attribution.1")
        tries = 0
        while !aboutAttribution.exists && tries < 10 {
            app.swipeUp()
            tries += 1
        }
        XCTAssertTrue(aboutAttribution.exists, "About's sources list the installed dictionary's attribution")
        UITestSupport.attachScreenshot(app, name: "dictionaries-07-about-sources", to: self)
    }
}
