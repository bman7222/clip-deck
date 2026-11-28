import Foundation
import Testing
import UIKit
@testable import ClipDeck

/// T-025: `SubtitlePlacement.dragged`, the inverse of `frame` used by the outline drag. A 400 x 300 video with margins
/// 10 / 20 / 10 / 20 gives the resting region x 20...380 (360 wide) and y 10...290 (280 high).
@MainActor
struct SubtitleDragTests {
    private let video = CGSize(width: 400, height: 300)
    private let margins = SubtitleMargins(top: 10, leading: 20, bottom: 10, trailing: 20)

    private func drag(
        _ style: SubtitleStyle = .default, dx: CGFloat = 0, dy: CGFloat = 0, top: CGFloat = 0,
        line: CGSize = CGSize(width: 100, height: 30)
    ) -> SubtitleStyle {
        SubtitlePlacement.dragged(
            style, by: CGSize(width: dx, height: dy), videoSize: video, margins: margins,
            topObstruction: top, lineSize: line)
    }

    @Test func draggingUpAddsThePointsOverTheRegionHeight() {
        #expect(abs(drag(dy: -28).up - 0.1) < 0.0001)
        #expect(abs(drag(SubtitleStyle(up: 0.3), dy: -14).up - 0.35) < 0.0001)
        #expect(abs(drag(SubtitleStyle(up: 0.3), dy: 28).up - 0.2) < 0.0001)
    }

    @Test func draggingSidewaysAddsThePointsOverTheRegionWidth() {
        #expect(abs(drag(dx: 36).right - 0.1) < 0.0001)
        #expect(abs(drag(SubtitleStyle(right: 0.1), dx: -72).right + 0.1) < 0.0001)
    }

    @Test func theMovedLineLandsWhereTheDragPutIt() {
        let style = SubtitleStyle(up: 0.2, right: -0.1)
        let line = CGSize(width: 100, height: 30)
        func frame(_ style: SubtitleStyle) -> CGRect {
            SubtitlePlacement.frame(videoSize: video, margins: margins, lineSize: line, style: style)
        }
        let before = frame(style)
        let after = frame(drag(style, dx: 40, dy: -50))
        #expect(abs(after.minY - (before.minY - 50)) < 0.1)
        #expect(abs(after.minX - (before.minX + 40)) < 0.1)
    }

    @Test func theLimitsHoldAtTheRangesAndTheRegion() {
        let small = CGSize(width: 40, height: 0)
        #expect(drag(dy: -5_000, line: small).up == SubtitleStyle.upRange.upperBound)
        #expect(drag(SubtitleStyle(up: 0.5), dy: 5_000).up == 0)
        #expect(drag(dx: 5_000, line: small).right == SubtitleStyle.rightRange.upperBound)
        #expect(drag(dx: -5_000, line: small).right == SubtitleStyle.rightRange.lowerBound)
        // A line 100 wide leaves 130 pt each side of the centre: 130 / 360.
        #expect(abs(drag(dx: 5_000).right - 130.0 / 360.0) < 0.0001)
        // A line 30 high leaves 250 of the 280 pt: 250 / 280.
        #expect(abs(drag(dy: -5_000).up - 250.0 / 280.0) < 0.0001)
    }

    @Test func aTopObstructionClampsTheRegion() {
        #expect(abs(drag(dy: -5_000, top: 60).up - 200.0 / 280.0) < 0.0001)
    }

    @Test func aLineStuckAboveTheClampStartsFromWhereItIsDrawn() {
        let pinned = SubtitleStyle(up: 0.9)
        #expect(abs(drag(pinned, dy: 28, top: 60).up - (200.0 / 280.0 - 0.1)) < 0.0001)
    }

    @Test func aDragThatReturnsToItsStartGivesTheOriginalBack() {
        let start = SubtitleStyle(up: 0.3, right: -0.1)
        #expect(drag(start) == start)
        let there = drag(start, dx: 30, dy: -20)
        let back = drag(there, dx: -30, dy: 20)
        #expect(abs(back.up - start.up) < 0.0001)
        #expect(abs(back.right - start.right) < 0.0001)
    }

    @Test func theFontIsLeftAlone() {
        let start = SubtitleStyle(font: .serif, bold: false, sizeStep: 3, up: 0.2)
        let moved = drag(start, dy: -10)
        #expect(moved.font == .serif)
        #expect(!moved.bold)
        #expect(moved.sizeStep == 3)
    }

    @Test func anUnmeasuredVideoChangesNothing() {
        let start = SubtitleStyle(up: 0.3)
        let unmeasured = SubtitlePlacement.dragged(
            start, by: CGSize(width: 10, height: -10), videoSize: .zero, margins: margins,
            topObstruction: 0, lineSize: .zero)
        #expect(unmeasured == start)
    }
}
