import XCTest

/// Landscape player behaviour beyond the basic tap toggle (T-001 AC-1, AC-2, AC-4, AC-5, AC-6).
/// Uses the seeded "Sample Show": a 6-second video, paused at 0:00, with lines at 0.5-2.0, 2.0-4.0 and 4.0-5.5 s.
final class PlayerLandscapeBehaviourUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    override func tearDown() async throws {
        await MainActor.run { XCUIDevice.shared.orientation = .portrait }
        try await super.tearDown()
    }

    /// AC-1 + AC-3: no navigation bar in landscape; `player.back` returns to the episode list.
    @MainActor
    func testNavigationBarHiddenAndBackReturnsToEpisodes() throws {
        let app = openSampleEpisode()
        XCUIDevice.shared.orientation = .landscapeLeft
        XCTAssertTrue(video(app).waitForExistence(timeout: 10))
        XCTAssertTrue(app.navigationBars.firstMatch.waitForNonExistence(timeout: 5), "Navigation bar is hidden in landscape")

        tapVideo(app)
        let back = app.buttons["player.back"]
        XCTAssertTrue(back.waitForExistence(timeout: 5))
        back.tap()
        XCTAssertTrue(app.buttons["episode.row.Episode 1"].waitForExistence(timeout: 5), "Back returns to the episode list")
    }

    /// AC-2: paused, the controls stay up; playing, they hide after ~3 s; when playback stops they come back.
    @MainActor
    func testControlsStayWhilePausedAndAutoHideWhilePlaying() throws {
        let app = openSampleEpisode()
        XCUIDevice.shared.orientation = .landscapeLeft
        XCTAssertTrue(video(app).waitForExistence(timeout: 10))

        tapVideo(app)
        let back = app.buttons["player.back"]
        XCTAssertTrue(back.waitForExistence(timeout: 5))
        XCTAssertFalse(back.waitForNonExistence(timeout: 5), "Paused: controls stay up past 3 s")

        let playPause = app.buttons["player.playPause"]
        playPause.tap()
        XCTAssertTrue(back.waitForNonExistence(timeout: 5), "Playing: controls hide on their own")
        attachScreenshot(app, "landscape-05-autohidden")

        // The 6-second sample plays to its end and stops (AVPlayer actionAtItemEnd = .pause).
        // PlayerView brings the controls back on pause; if that did not happen, a tap must show them.
        if !back.waitForExistence(timeout: 10) {
            tapVideo(app)
            XCTAssertTrue(back.waitForExistence(timeout: 5), "Tap shows the controls after the end")
        }
        attachScreenshot(app, "landscape-07-ended")
        // AC-2: stopped means paused, so the button offers Play and the controls do not auto-hide.
        XCTAssertEqual(playPause.label, "Play", "Stopped at the end: the player no longer thinks it is playing")
        XCTAssertFalse(back.waitForNonExistence(timeout: 5), "Stopped at the end: controls stay up past 3 s")
    }

    /// AC-2: while playing, an open subtitles menu keeps the controls (and so the menu) up past the 3 s auto-hide.
    /// In landscape `player.subtitlesMenu` is a button that opens a confirmation dialog (a SwiftUI Menu can't be
    /// tracked on iOS 26). The dialog's actions are buttons in the app's sheet/popover tree, so `app.buttons` finds them.
    /// The sample is 6 s long; the menu opens about 1-2 s in, so a broken rule hides the bar around 4-5 s,
    /// before playback ends and pauses (which would bring the controls back on its own).
    @MainActor
    func testOpenSubtitlesMenuKeepsControlsUpWhilePlaying() throws {
        let app = openSampleEpisode()
        XCUIDevice.shared.orientation = .landscapeLeft
        XCTAssertTrue(video(app).waitForExistence(timeout: 10))

        tapVideo(app)
        let playPause = app.buttons["player.playPause"]
        XCTAssertTrue(playPause.waitForExistence(timeout: 5))
        playPause.tap()
        let menu = app.buttons["player.subtitlesMenu"]
        XCTAssertTrue(menu.waitForExistence(timeout: 2))
        menu.tap()
        // The dialog's only action now is "Load different subtitles" (the list moved to the panel button, T-002).
        let showList = app.buttons["Load different subtitles"]
        // XCUITest snapshots lag while the video plays (run 44639515011: the menu was on screen ~1.3 s
        // but not found within 2 s), so allow 5 s. With the rule broken, the menu is torn down ~1.5 s after
        // opening, so this assert or the next one fails; with it working, the menu stays open throughout.
        XCTAssertTrue(showList.waitForExistence(timeout: 5), "Menu opens and stays open while playing")
        // The dialog hangs off the landscape root, so it survives the overlay being removed: watching only the
        // dialog cannot catch a broken keep-up rule. Watch the bar itself. Play starts ~1.4 s before the dialog
        // opens, so a broken rule hides the bar ~1.6 s later and the sample (6 s) only ends ~3 s after that.
        let back = app.buttons["player.back"]
        XCTAssertTrue(back.exists, "Controls are up when the dialog opens")
        XCTAssertFalse(back.waitForNonExistence(timeout: 3.5), "Controls stay up while the subtitles dialog is open")
        XCTAssertTrue(showList.exists, "Open dialog is not torn down by the auto-hide")
        attachScreenshot(app, "landscape-06-menu-open")
    }

    /// T-002: the panel button opens the subtitle list in landscape; the line shows on the video;
    /// Make a Card works from landscape and opens the editor.
    @MainActor
    func testSubtitleListAndMakeACardInLandscape() throws {
        let app = openSampleEpisode()
        XCUIDevice.shared.orientation = .landscapeLeft
        XCTAssertTrue(video(app).waitForExistence(timeout: 10))

        tapVideo(app)
        let toggle = app.buttons["player.panelToggle"]
        XCTAssertTrue(toggle.waitForExistence(timeout: 5), "Controls offer the panel button")
        toggle.tap()

        let secondLine = app.descendants(matching: .any)["cue.row.1"]
        XCTAssertTrue(secondLine.waitForExistence(timeout: 5), "Side list opens in landscape")
        secondLine.tap()
        XCTAssertTrue(app.textViews["player.subtitle"].waitForExistence(timeout: 5), "Current line shows over the video")
        attachScreenshot(app, "landscape-03-list")

        let makeCard = app.buttons["player.makeCard"]
        XCTAssertTrue(makeCard.waitForExistence(timeout: 5), "Paused: controls are still up")
        makeCard.tap()
        attachScreenshot(app, "landscape-04-recording")
        XCTAssertTrue(app.buttons["card.save"].waitForExistence(timeout: 20), "Card editor opens from landscape")
        XCTAssertEqual(app.staticTexts["card.range"].label, "0:02.0 – 0:04.0")
    }

    /// T-001 carry-over: "Load different subtitles" from the landscape dialog opens the subtitle picker.
    /// The "Show subtitle list" item is gone from the dialog (T-002 AC-5).
    @MainActor
    func testLoadDifferentSubtitlesFromLandscapeDialog() throws {
        let app = openSampleEpisode()
        XCUIDevice.shared.orientation = .landscapeLeft
        XCTAssertTrue(video(app).waitForExistence(timeout: 10))

        tapVideo(app)
        let menu = app.buttons["player.subtitlesMenu"]
        XCTAssertTrue(menu.waitForExistence(timeout: 5))
        menu.tap()
        let load = app.buttons["Load different subtitles"]
        XCTAssertTrue(load.waitForExistence(timeout: 5), "Dialog offers loading subtitles")
        // The panel toggle behind the dialog is also labelled "Show subtitle list" (run 44646676783 matched it),
        // so look only for a dialog action with that label.
        let oldItem = app.buttons.matching(
            NSPredicate(format: "label == %@ AND identifier != %@", "Show subtitle list", "player.panelToggle")
        )
        XCTAssertEqual(oldItem.count, 0, "The list item moved to the panel button")
        load.tap()
        let picker = app.navigationBars["Subtitles for Episode 1"]
        XCTAssertTrue(picker.waitForExistence(timeout: 5), "Subtitle picker sheet opens")
    }

    /// T-002 AC-3: the panel stays open when the controls auto-hide while playing; the bars and the
    /// subtitle line stay inside the video column (left of the panel).
    @MainActor
    func testPanelStaysOpenWhenControlsAutoHide() throws {
        let app = openSampleEpisode()
        XCUIDevice.shared.orientation = .landscapeLeft
        XCTAssertTrue(video(app).waitForExistence(timeout: 10))

        tapVideo(app)
        let toggle = app.buttons["player.panelToggle"]
        XCTAssertTrue(toggle.waitForExistence(timeout: 5))
        toggle.tap()
        let panel = app.descendants(matching: .any)["player.sidePanel"]
        XCTAssertTrue(panel.waitForExistence(timeout: 5), "Panel opens")
        XCTAssertTrue(waitForLabel(toggle, "Hide subtitle list", timeout: 3), "Open panel: the button offers to hide it")
        waitUntilSettled(video(app))

        let videoFrame = video(app).frame
        XCTAssertLessThanOrEqual(videoFrame.maxX, panel.frame.minX + 1, "Video column sits left of the panel")
        XCTAssertLessThanOrEqual(toggle.frame.maxX, videoFrame.maxX + 1, "Top bar stays inside the video area")
        XCTAssertLessThanOrEqual(app.buttons["player.makeCard"].frame.maxX, videoFrame.maxX + 1,
                                 "Bottom bar stays inside the video area")

        let playPause = app.buttons["player.playPause"]
        playPause.tap()
        let back = app.buttons["player.back"]
        XCTAssertTrue(back.waitForNonExistence(timeout: 5), "Playing: controls hide on their own")
        XCTAssertTrue(panel.exists, "Panel stays open when the controls auto-hide")
        XCTAssertTrue(app.descendants(matching: .any)["cue.row.1"].exists, "Panel still lists the lines")
        let subtitle = app.textViews["player.subtitle"]
        if subtitle.waitForExistence(timeout: 2) {
            XCTAssertLessThanOrEqual(subtitle.frame.maxX, videoFrame.maxX + 1, "Subtitle line stays inside the video area")
        }
        attachScreenshot(app, "landscape-08-panel-autohidden")
    }

    /// T-002 AC-4: rotating to portrait shows the portrait screen; rotating back restores the panel's state;
    /// the button closes the panel and the video returns to full width.
    @MainActor
    func testPanelClosesAndSurvivesRotation() throws {
        let app = openSampleEpisode()
        XCUIDevice.shared.orientation = .landscapeLeft
        XCTAssertTrue(video(app).waitForExistence(timeout: 10))

        tapVideo(app)
        let toggle = app.buttons["player.panelToggle"]
        XCTAssertTrue(toggle.waitForExistence(timeout: 5))
        XCTAssertEqual(toggle.label, "Show subtitle list")
        toggle.tap()
        let panel = app.descendants(matching: .any)["player.sidePanel"]
        XCTAssertTrue(panel.waitForExistence(timeout: 5), "Panel opens")

        XCUIDevice.shared.orientation = .portrait
        XCTAssertTrue(app.navigationBars.firstMatch.waitForExistence(timeout: 5), "Portrait shows the navigation bar")
        XCTAssertTrue(panel.waitForNonExistence(timeout: 5), "No side panel in portrait")
        XCTAssertTrue(app.buttons["player.makeCard"].waitForExistence(timeout: 5), "Portrait controls are shown")

        XCUIDevice.shared.orientation = .landscapeLeft
        XCTAssertTrue(panel.waitForExistence(timeout: 5), "Rotating back restores the open panel")

        tapVideo(app)
        XCTAssertTrue(toggle.waitForExistence(timeout: 5))
        XCTAssertTrue(waitForLabel(toggle, "Hide subtitle list", timeout: 3))
        toggle.tap()
        XCTAssertTrue(panel.waitForNonExistence(timeout: 5), "Second tap closes the panel")
        waitUntilSettled(video(app))
        let window = app.windows.firstMatch.frame
        XCTAssertEqual(video(app).frame.width, window.width, accuracy: 2, "Closed: the video is full width again")

        XCUIDevice.shared.orientation = .portrait
        XCTAssertTrue(app.navigationBars.firstMatch.waitForExistence(timeout: 5))
        XCUIDevice.shared.orientation = .landscapeLeft
        XCTAssertTrue(video(app).waitForExistence(timeout: 10))
        XCTAssertTrue(app.navigationBars.firstMatch.waitForNonExistence(timeout: 5))
        XCTAssertFalse(panel.waitForExistence(timeout: 2), "Rotating back keeps a closed panel closed")
    }

    /// T-021 AC-6: in portrait, a tap on the video shows the playback overlay and leaves the play state alone.
    @MainActor
    func testPortraitTapShowsOverlayWithoutTogglingPlay() throws {
        let app = openSampleEpisode()
        let videoView = video(app)
        XCTAssertTrue(videoView.waitForExistence(timeout: 10))
        let playPause = app.buttons["player.playPause"]
        XCTAssertTrue(playPause.waitForExistence(timeout: 5))
        XCTAssertEqual(playPause.label, "Play")
        let overlay = app.buttons["player.overlay.playPause"]
        XCTAssertFalse(overlay.exists, "Portrait starts with the overlay hidden")

        // Between the centre and the back button, so a second tap can never land on an overlay button.
        videoView.coordinate(withNormalizedOffset: CGVector(dx: 0.37, dy: 0.15)).tap()
        XCTAssertTrue(overlay.waitForExistence(timeout: 3), "A portrait tap shows the overlay")
        XCTAssertEqual(playPause.label, "Play", "A portrait tap no longer starts playback")
        XCTAssertEqual(playPause.value as? String, "Paused")
        XCTAssertTrue(app.navigationBars.firstMatch.exists, "Portrait keeps the navigation bar")
    }

    // MARK: Helpers

    @MainActor
    private func openSampleEpisode() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments += ["-uiTesting"]
        app.launch()
        let showTile = app.buttons["library.show.Sample Show"]
        XCTAssertTrue(showTile.waitForExistence(timeout: 30), "Seeded show should appear")
        showTile.tap()
        let episodeRow = app.buttons["episode.row.Episode 1"]
        XCTAssertTrue(episodeRow.waitForExistence(timeout: 5))
        episodeRow.tap()
        return app
    }

    @MainActor
    private func video(_ app: XCUIApplication) -> XCUIElement {
        app.descendants(matching: .any)["player.video"]
    }

    /// Upper middle of the screen: on the video, clear of the subtitle line and both bars.
    @MainActor
    private func tapVideo(_ app: XCUIApplication) {
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.35, dy: 0.35)).tap()
    }

    @MainActor
    private func waitForLabel(_ element: XCUIElement, _ label: String, timeout: TimeInterval) -> Bool {
        let predicate = NSPredicate(format: "label == %@", label)
        let expectation = XCTNSPredicateExpectation(predicate: predicate, object: element)
        return XCTWaiter().wait(for: [expectation], timeout: timeout) == .completed
    }

    /// Waits until the element's frame stops changing (the panel's 0.3 s spring), up to 3 s.
    @MainActor
    private func waitUntilSettled(_ element: XCUIElement) {
        var last = element.frame
        let deadline = Date().addingTimeInterval(3)
        repeat {
            RunLoop.current.run(until: Date().addingTimeInterval(0.25))
            let now = element.frame
            if now == last { return }
            last = now
        } while Date() < deadline
    }

    @MainActor
    private func attachScreenshot(_ app: XCUIApplication, _ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
