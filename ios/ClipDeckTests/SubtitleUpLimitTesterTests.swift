import Foundation
import Testing
import UIKit
@testable import ClipDeck

/// Tester edge cases for T-018's `SubtitlePlacement.canStepUpWithCardOpen`, on the builder's geometry: a landscape
/// video 800 x 360, margins 8 / 75 / 33 / 48 (resting y 8...327, 319 high, a step is 15.95 pt), a 52 pt top bar
/// clearance and a one-row card clearance of 68 (so the line's bottom can't go below 292).
@MainActor
struct SubtitleUpLimitTesterTests {
    private let size = CGSize(width: 800, height: 360)
    private let margins = SubtitleMargins(top: 8, leading: 75, bottom: 33, trailing: 48)

    private func canStep(upSteps: Int, lineHeight: CGFloat, top: CGFloat = 52, card: CGFloat = 68) -> Bool {
        SubtitlePlacement.canStepUpWithCardOpen(
            videoSize: size, margins: margins, topObstruction: top, bottomObstruction: card,
            lineSize: CGSize(width: 100, height: lineHeight), style: SubtitleStyle(up: Double(upSteps) * 0.05))
    }

    private func minY(upSteps: Int, lineHeight: CGFloat) -> CGFloat {
        SubtitlePlacement.frame(
            videoSize: size, margins: margins, topObstruction: 52, bottomObstruction: 68,
            lineSize: CGSize(width: 100, height: lineHeight), style: SubtitleStyle(up: Double(upSteps) * 0.05),
            stepsFromObstruction: true
        ).minY
    }

    /// The last tap may move less than a full step (here 2.65 pt, from 54.65 to the clamp at 52): it still shows, so
    /// Up stays enabled for it, and dims right after.
    @Test func aPartialLastStepStillCountsAndUpDimsRightAfter() {
        #expect(abs(minY(upSteps: 13, lineHeight: 30) - 54.65) < 0.01)
        #expect(abs(minY(upSteps: 14, lineHeight: 30) - 52) < 0.01)
        #expect(canStep(upSteps: 13, lineHeight: 30))
        #expect(!canStep(upSteps: 14, lineHeight: 30))
    }

    /// A move of 1 pt or less doesn't count as "the line moved": with a 32 pt line, step 13 sits 0.65 pt under
    /// the clamp, so Up is already dimmed there, while step 12 (a full 15.95 pt move next) is not.
    @Test func aMoveOfOnePointOrLessDoesNotCount() {
        #expect(canStep(upSteps: 12, lineHeight: 32))
        #expect(!canStep(upSteps: 13, lineHeight: 32))
    }

    /// A stored place already past the clamp (set in portrait, say) opens the card with Up dimmed.
    @Test func aStoredPlacePastTheClampDimsUp() {
        for steps in 14...17 {
            #expect(!canStep(upSteps: steps, lineHeight: 30), "upSteps \(steps)")
        }
    }

    /// A line taller than the room between the top bar and the card can't move at all, so Up is dimmed at once.
    @Test func aLineTallerThanTheRoomDimsUpAtOnce() {
        // Three-row card: room 52...212 is 160 pt; a 200 pt line is pinned to the card.
        #expect(!canStep(upSteps: 0, lineHeight: 200, card: 148))
    }

    /// Without a top bar clearance the clamp is the resting top (8), so Up allows more taps (16, not 14).
    @Test func withoutTheTopBarTheRestingTopIsTheClamp() {
        var style = SubtitleStyle.default
        var taps = 0
        while taps < 40 {
            let can = SubtitlePlacement.canStepUpWithCardOpen(
                videoSize: size, margins: margins, topObstruction: 0, bottomObstruction: 68,
                lineSize: CGSize(width: 100, height: 30), style: style)
            if !can { break }
            style.stepUp(1)
            taps += 1
        }
        #expect(taps == 16)
    }

    /// T-023 tester: `stepsFromObstruction: false` really reaches both helpers. With no bottom obstruction the two
    /// modes give the same frames, so this uses a 40 pt one (active bottom 320, resting bottom 327, clamp 82):
    /// counted from the obstruction the line reaches the top-bar clamp at 0.75 (320 - 239.25 = 80.75 -> 82), counted
    /// from the region's bottom only at 0.80 (0.75 still sits at 87.75, so one more Up moves it 5.75 pt).
    @Test func stepsFromObstructionFalseCountsFromTheRegionBottom() {
        let line = CGSize(width: 100, height: 30)
        let fromObstruction = SubtitlePlacement.highestReachableUp(
            videoSize: size, margins: margins, topObstruction: 52, bottomObstruction: 40, lineSize: line)
        let fromBottom = SubtitlePlacement.highestReachableUp(
            videoSize: size, margins: margins, topObstruction: 52, bottomObstruction: 40, lineSize: line,
            stepsFromObstruction: false)
        #expect(fromObstruction == 0.75)
        #expect(fromBottom == 0.80)
        let canFromObstruction = SubtitlePlacement.canStepUpWithCardOpen(
            videoSize: size, margins: margins, topObstruction: 52, bottomObstruction: 40, lineSize: line,
            style: SubtitleStyle(up: 0.75))
        let canFromBottom = SubtitlePlacement.canStepUpWithCardOpen(
            videoSize: size, margins: margins, topObstruction: 52, bottomObstruction: 40, lineSize: line,
            style: SubtitleStyle(up: 0.75), stepsFromObstruction: false)
        #expect(!canFromObstruction)
        #expect(canFromBottom)
    }
}
