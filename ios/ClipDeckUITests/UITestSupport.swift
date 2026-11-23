import XCTest

/// Shared helpers for the UI tests (T-034). They wait for state instead of time, and they re-tap only after a tap
/// had its chance to show. Slow CI runners lose taps, launch slowly, and freeze the app's UI for seconds.
@MainActor
enum UITestSupport {
    /// One generous wait for the seeded "Sample Show" after a launch. The first launch on a cold simulator can take
    /// up to a minute; if the library is still empty after `showWait` seconds, the app is relaunched once, which
    /// seeds again (the seed is in memory and runs on every `-uiTesting` launch).
    static let showWait: TimeInterval = 45

    /// Launches `app` with the seeded library and returns the "Sample Show" tile once it is on screen.
    /// `app.launchArguments` must already hold `-uiTesting` (and any other flags).
    @discardableResult
    static func launchSeeded(_ app: XCUIApplication, file: StaticString = #filePath, line: UInt = #line) -> XCUIElement {
        let tile = app.buttons["library.show.Sample Show"]
        app.launch()
        if !tile.waitForExistence(timeout: showWait) {
            app.terminate()
            app.launch()
            XCTAssertTrue(tile.waitForExistence(timeout: showWait), "Seeded show should appear", file: file, line: line)
        }
        return tile
    }

    /// From the library: opens "Sample Show", then "Episode 1" (the player).
    static func openSampleEpisode(_ app: XCUIApplication, tile: XCUIElement, file: StaticString = #filePath, line: UInt = #line) {
        tile.tap()
        let episodeRow = app.buttons["episode.row.Episode 1"]
        XCTAssertTrue(episodeRow.waitForExistence(timeout: 10), "Episode row should appear", file: file, line: line)
        episodeRow.tap()
    }

    /// `launchSeeded` and `openSampleEpisode` in one call.
    static func launchAndOpenSampleEpisode(_ app: XCUIApplication, file: StaticString = #filePath, line: UInt = #line) {
        let tile = launchSeeded(app, file: file, line: line)
        openSampleEpisode(app, tile: tile, file: file, line: line)
    }

    // MARK: Landscape and the idle stall

    /// A step that takes longer than this waited out XCTest's 60 s "animations idle" timeout: the idle stall. A
    /// healthy rotation or probe takes well under 2 s, even on a slow runner.
    static let stallLimit: TimeInterval = 50

    /// Test setup: rotates the player (open in portrait) to landscape, waits for the video, and guards against the
    /// idle stall (T-034).
    ///
    /// On a slow runner the app can stop answering XCTest's "animations idle" request within about a second of this
    /// rotation, for the rest of that app process (6 of 375 rotations in CI). Every later action then waits 2 x 60 s,
    /// which outlasts any 3 s or 30 s check. So after the rotation and a 1 s settle this sets the same orientation
    /// again. That changes nothing in the app and is only XCTest's wait for idle: well under a second, or 60 s when
    /// the app is stalled.
    ///
    /// On a stall (the rotation or that probe over `stallLimit`) it logs it, terminates the app, runs `reopen`
    /// (launch and open the player again, in portrait; by default `launchAndOpenSampleEpisode`, which reuses
    /// `app.launchArguments`) and rotates once more. It relaunches at most once: a second stall is logged and the
    /// test goes on. The log is an activity named "Idle stall guard…" with an attachment named "idle-stall-guard"
    /// (scripts/test-ios.sh turns it into a GitHub warning), plus a line on the test runner's stdout. A healthy run
    /// logs nothing, so any of these means the guard fired.
    static func rotateToLandscape(_ app: XCUIApplication, reopen: (@MainActor () -> Void)? = nil,
                                  file: StaticString = #filePath, line: UInt = #line) {
        let video = app.descendants(matching: .any)["player.video"]
        var stalledBefore = false
        for attempt in 1...2 {
            let rotation = timed { XCUIDevice.shared.orientation = .landscapeLeft }
            XCTAssertTrue(video.waitForExistence(timeout: 10), "The player shows in landscape", file: file, line: line)
            var probe: TimeInterval?
            if rotation <= stallLimit {
                settle(1)
                probe = timed { XCUIDevice.shared.orientation = .landscapeLeft }
            }
            let probeText = probe.map { "\(seconds($0)) s" } ?? "skipped"
            let steps = "rotation \(seconds(rotation)) s, probe \(probeText) (limit \(seconds(stallLimit)) s)"
            let stalled = rotation > stallLimit || (probe ?? 0) > stallLimit
            if !stalled {
                if stalledBefore {
                    logStall("Idle stall guard: no stall after the relaunch (\(steps))", app: app)
                }
                return
            }
            if attempt == 2 {
                logStall("Idle stall guard: stalled again after the relaunch (\(steps)); going on without another relaunch",
                         app: app)
                return
            }
            stalledBefore = true
            logStall("Idle stall guard fired: the app stopped answering XCTest's animations-idle wait after the rotation "
                     + "(\(steps)); terminating and relaunching it once", app: app)
            app.terminate()
            XCUIDevice.shared.orientation = .portrait
            if let reopen { reopen() } else { launchAndOpenSampleEpisode(app, file: file, line: line) }
        }
    }

    /// Records one idle-stall guard event: an activity, a text attachment (the summary on its first line, then the
    /// app's element tree) and a stdout line.
    private static func logStall(_ summary: String, app: XCUIApplication) {
        print("UITestSupport: \(summary)")
        XCTContext.runActivity(named: summary) { activity in
            let attachment = XCTAttachment(string: summary + "\n\n" + app.debugDescription)
            attachment.name = "idle-stall-guard"
            attachment.lifetime = .keepAlways
            activity.add(attachment)
        }
    }

    /// How long `action` took, in seconds.
    private static func timed(_ action: () -> Void) -> TimeInterval {
        let start = Date()
        action()
        return Date().timeIntervalSince(start)
    }

    nonisolated private static func seconds(_ value: TimeInterval) -> String {
        String(format: "%.1f", value)
    }

    /// Polls `condition` until it holds or `timeout` passes. Returns whether it held. Always checks once more at the end.
    static func wait(timeout: TimeInterval, interval: TimeInterval = 0.2, until condition: () -> Bool) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        repeat {
            if condition() { return true }
            RunLoop.current.run(until: Date().addingTimeInterval(interval))
        } while Date() < deadline
        return condition()
    }

    /// Waits until `element`'s label equals `label`.
    static func waitForLabel(_ element: XCUIElement, _ label: String, timeout: TimeInterval) -> Bool {
        wait(timeout: timeout) { element.exists && element.label == label }
    }

    /// Waits until `element`'s value equals `value`.
    static func waitForValue(_ element: XCUIElement, _ value: String, timeout: TimeInterval) -> Bool {
        wait(timeout: timeout) { element.exists && (element.value as? String) == value }
    }

    /// Waits until `element`'s frame satisfies `check` (for example the line moved up).
    static func waitForFrame(_ element: XCUIElement, timeout: TimeInterval, _ check: (CGRect) -> Bool) -> Bool {
        wait(timeout: timeout) { element.exists && check(element.frame) }
    }

    /// Taps `element` and waits (`patience` seconds) for `condition`. If it doesn't hold, the tap was probably lost:
    /// taps again, up to `attempts` times in all. It re-taps only after the wait, and only while the element still
    /// exists and is hittable, so a tap that did land (and made the element go away) is never repeated. Use a
    /// condition that can tell a lost tap from a double step; a button that steps a value should use `tapStep`.
    @discardableResult
    static func tap(_ element: XCUIElement, attempts: Int = 3, patience: TimeInterval = 4,
                    until condition: () -> Bool) -> Bool {
        for _ in 0..<attempts {
            guard element.exists, element.isHittable else {
                // Nothing to tap: the tap already took (the button went away) or the UI is slow. Just wait.
                return wait(timeout: patience, until: condition)
            }
            element.tap()
            if wait(timeout: patience, until: condition) { return true }
        }
        return condition()
    }

    /// Taps `button`, which steps the stored value shown by `reader`'s value text from `before` to `after`.
    /// A tap that never landed leaves `before`, and is repeated; any other value (a slow tap that landed after a
    /// re-tap and stepped twice) stops with false so the caller fails on it instead of hiding it.
    @discardableResult
    static func tapStep(_ button: XCUIElement, reader: XCUIElement, from before: String, to after: String,
                        attempts: Int = 3, patience: TimeInterval = 5) -> Bool {
        for _ in 0..<attempts {
            guard button.exists, button.isHittable else { break }
            button.tap()
            if waitForValue(reader, after, timeout: patience) { return true }
            guard let now = reader.value as? String, now == before else { return false }
        }
        return waitForValue(reader, after, timeout: patience)
    }

    /// The spoken vertical place for `percent` percent up (SubtitleStyle.verticalSpoken).
    static func upText(_ percent: Int) -> String {
        percent > 0 ? "\(percent) percent up" : "At the default height"
    }

    /// Reads `exists`, `value` and `label` from one snapshot, so the three agree and nothing hides in between.
    /// Nil when the element isn't there or the snapshot fails.
    static func readTogether(_ element: XCUIElement) -> (value: String?, label: String)? {
        guard let snapshot = try? element.snapshot() else { return nil }
        return (snapshot.value as? String, snapshot.label)
    }

    /// Lets animations and fades finish.
    static func settle(_ seconds: TimeInterval = 0.8) {
        RunLoop.current.run(until: Date().addingTimeInterval(seconds))
    }

    /// Attaches `text` to `test` under `name`.
    static func attachText(_ text: String, name: String, to test: XCTestCase) {
        let attachment = XCTAttachment(string: text)
        attachment.name = name
        attachment.lifetime = .keepAlways
        test.add(attachment)
    }

    /// Attaches a screenshot of `app` to `test` under `name`.
    static func attachScreenshot(_ app: XCUIApplication, name: String, to test: XCTestCase) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        test.add(attachment)
    }
}
