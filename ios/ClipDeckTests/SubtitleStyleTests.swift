import Foundation
import Testing
import UIKit
@testable import ClipDeck

@MainActor
struct SubtitleStyleTests {
    // MARK: Value, steps and clamping

    @Test func defaultStyleIsToday() {
        let style = SubtitleStyle.default
        #expect(style.font == .sans)
        #expect(style.bold)
        #expect(style.sizeStep == 0)
        #expect(style.upSteps == 0)
        #expect(style.rightSteps == 0)
        #expect(style.isDefault)
        #expect(abs(style.scale - 1.0) < 0.0001)
        #expect(SubtitleStyle() == .default)
    }

    @Test func scaleRunsFromSixtyToTwoHundredPercent() {
        #expect(abs(SubtitleStyle(sizeStep: -4).scale - 0.6) < 0.0001)
        #expect(abs(SubtitleStyle(sizeStep: 10).scale - 2.0) < 0.0001)
        #expect(abs(SubtitleStyle(sizeStep: 3).scale - 1.3) < 0.0001)
    }

    @Test func initClampsEveryField() {
        let style = SubtitleStyle(sizeStep: 99, upSteps: -3, rightSteps: 99)
        #expect(style.sizeStep == 10)
        #expect(style.upSteps == 0)
        #expect(style.rightSteps == 8)
        #expect(!style.isDefault)
    }

    @Test func sizeStepsStopAtBothEndsAndReportWhetherAnotherStepIsPossible() {
        var style = SubtitleStyle.default
        let first = style.stepSize(1)
        #expect(first)
        #expect(style.sizeStep == 1)
        style.sizeStep = 9
        let reachedTop = style.stepSize(1)   // reached 10, nothing further
        #expect(reachedTop == false)
        #expect(style.sizeStep == 10)
        #expect(!style.canSizeUp)
        let pastTop = style.stepSize(1)      // already at the end: clamped, still 10
        #expect(pastTop == false)
        #expect(style.sizeStep == 10)

        style.sizeStep = -3
        let reachedBottom = style.stepSize(-1)   // reached -4
        #expect(reachedBottom == false)
        #expect(style.sizeStep == -4)
        #expect(!style.canSizeDown)
        #expect(style.canSizeUp)
        let pastBottom = style.stepSize(-1)
        #expect(pastBottom == false)
        #expect(style.sizeStep == -4)
        let noStep = style.stepSize(0)
        #expect(noStep == false)
    }

    @Test func positionStepsStopAtBothEnds() {
        var style = SubtitleStyle.default
        #expect(!style.canMoveDown)            // nothing goes below the default bottom place
        let belowBottom = style.stepUp(-1)
        #expect(belowBottom == false)
        #expect(style.upSteps == 0)
        style.upSteps = 17
        let reachedTop = style.stepUp(1)
        #expect(reachedTop == false)
        #expect(style.upSteps == 18)
        #expect(!style.canMoveUp)
        let pastTop = style.stepUp(1)
        #expect(pastTop == false)
        #expect(style.upSteps == 18)
        #expect(style.canMoveDown)

        style.rightSteps = 7
        let reachedRight = style.stepRight(1)
        #expect(reachedRight == false)
        #expect(style.rightSteps == 8)
        #expect(!style.canMoveRight)
        style.rightSteps = -7
        let reachedLeft = style.stepRight(-1)
        #expect(reachedLeft == false)
        #expect(style.rightSteps == -8)
        #expect(!style.canMoveLeft)
        #expect(style.canMoveRight)
        let moreRoom = style.stepRight(2)
        #expect(moreRoom)
        #expect(style.rightSteps == -6)
    }

    @Test func clampedFixesValuesSetDirectly() {
        var style = SubtitleStyle.default
        style.sizeStep = 50
        style.upSteps = -50
        style.rightSteps = -50
        let fixed = style.clamped()
        #expect(fixed.sizeStep == 10)
        #expect(fixed.upSteps == 0)
        #expect(fixed.rightSteps == -8)
    }

    // MARK: Saved JSON

    @Test(arguments: ["", "not json", "[]", "42", "{", "null", "\"serif\"", "[1,2,3]"])
    func garbageGivesTheDefault(json: String) {
        #expect(SubtitleStyle.decoded(from: json) == .default)
    }

    @Test func nothingSavedGivesTheDefault() {
        #expect(SubtitleStyle.decoded(from: nil) == .default)
        #expect(SubtitleStyle.decoded(from: "{}") == .default)
    }

    @Test func partialJSONKeepsWhatIsValid() {
        let onlyBold = SubtitleStyle.decoded(from: #"{"bold":false}"#)
        #expect(onlyBold == SubtitleStyle(bold: false))

        let mixed = SubtitleStyle.decoded(from: #"{"font":"serif","sizeStep":"big","upSteps":3}"#)
        #expect(mixed.font == .serif)
        #expect(mixed.sizeStep == 0)
        #expect(mixed.upSteps == 3)
        #expect(mixed.bold)
    }

    @Test func unknownFontAndWrongTypesFallBackPerField() {
        let style = SubtitleStyle.decoded(from: #"{"font":"comic","bold":"yes","sizeStep":3.5,"rightSteps":2}"#)
        #expect(style.font == .sans)
        #expect(style.bold)
        #expect(style.sizeStep == 0)
        #expect(style.rightSteps == 2)
    }

    @Test func unknownFieldsAreIgnoredSoLaterBuildsCanAddSome() {
        // T-017 adds a picked font name. An older build must read that JSON, and this one must read it too.
        let style = SubtitleStyle.decoded(from: #"{"pickedFontName":"Georgia","sizeStep":2,"font":"rounded"}"#)
        #expect(style.sizeStep == 2)
        #expect(style.font == .rounded)
    }

    @Test func outOfRangeJSONIsClamped() {
        let style = SubtitleStyle.decoded(from: #"{"sizeStep":99,"upSteps":-5,"rightSteps":-99}"#)
        #expect(style.sizeStep == 10)
        #expect(style.upSteps == 0)
        #expect(style.rightSteps == -8)
    }

    @Test func jsonRoundTrips() {
        let style = SubtitleStyle(font: .serif, bold: false, sizeStep: 5, upSteps: 4, rightSteps: -4)
        #expect(SubtitleStyle.decoded(from: style.json) == style)
        #expect(SubtitleStyle.decoded(from: SubtitleStyle.default.json) == .default)
        #expect(style.json == style.json)
        #expect(!style.json.isEmpty)
    }

    @Test(arguments: SubtitleFont.allCases)
    func everyFontRoundTrips(font: SubtitleFont) {
        let style = SubtitleStyle(font: font)
        #expect(SubtitleStyle.decoded(from: style.json).font == font)
    }

    @Test func seedFlagIsReadFromLaunchArguments() {
        let json = #"{"sizeStep":5}"#
        #expect(SubtitleStyle.seedJSON(in: ["-uiTesting", "-uiTestingSubtitleStyle", json]) == json)
        #expect(SubtitleStyle.seedJSON(in: ["-uiTesting"]) == nil)
        #expect(SubtitleStyle.seedJSON(in: ["-uiTesting", "-uiTestingSubtitleStyle"]) == nil)
    }

    // MARK: Fonts

    private func weight(of font: UIFont) -> CGFloat {
        let traits = font.fontDescriptor.object(forKey: .traits) as? [UIFontDescriptor.TraitKey: Any]
        return (traits?[.weight] as? CGFloat) ?? 0
    }

    @Test func sansIsTheSystemFontInBoldOrRegular() {
        let bold = SubtitleStyle(font: .sans, bold: true).uiFont(pointSize: 20)
        let regular = SubtitleStyle(font: .sans, bold: false).uiFont(pointSize: 20)
        #expect(bold.pointSize == 20)
        #expect(bold.fontName == UIFont.systemFont(ofSize: 20, weight: .bold).fontName)
        #expect(regular.fontName == UIFont.systemFont(ofSize: 20, weight: .regular).fontName)
        #expect(bold.fontDescriptor.symbolicTraits.contains(.traitBold))
        #expect(!regular.fontDescriptor.symbolicTraits.contains(.traitBold))
    }

    @Test(arguments: [SubtitleFont.rounded, SubtitleFont.serif])
    func designedFontsAreSizedAndBoldIsNeverLighter(font: SubtitleFont) {
        let bold = SubtitleStyle(font: font, bold: true).uiFont(pointSize: 24)
        let regular = SubtitleStyle(font: font, bold: false).uiFont(pointSize: 24)
        #expect(bold.pointSize == 24)
        #expect(regular.pointSize == 24)
        #expect(weight(of: bold) >= weight(of: regular))
    }

    @Test func japaneseFallbackFacesFollowFontAndWeight() {
        #expect(SubtitleStyle(font: .sans, bold: true).japaneseFallbackName == nil)
        #expect(SubtitleStyle(font: .sans, bold: false).japaneseFallbackName == nil)
        #expect(SubtitleStyle(font: .rounded, bold: true).japaneseFallbackName == "HiraMaruProN-W4")
        #expect(SubtitleStyle(font: .rounded, bold: false).japaneseFallbackName == "HiraMaruProN-W4")
        #expect(SubtitleStyle(font: .serif, bold: true).japaneseFallbackName == "HiraMinProN-W6")
        #expect(SubtitleStyle(font: .serif, bold: false).japaneseFallbackName == "HiraMinProN-W3")
    }

    @Test(arguments: [SubtitleFont.rounded, SubtitleFont.serif])
    func designedFontsCarryAJapaneseCascade(font: SubtitleFont) {
        let uiFont = SubtitleStyle(font: font).uiFont(pointSize: 20)
        let cascade = uiFont.fontDescriptor.object(forKey: .cascadeList) as? [UIFontDescriptor]
        #expect(cascade?.isEmpty == false)
    }

    @Test func pointSizeIsCappedAtAQuarterOfTheRegionWithAFloor() {
        #expect(SubtitleStyle.cappedPointSize(100, regionHeight: 200) == 50)
        #expect(SubtitleStyle.cappedPointSize(30, regionHeight: 200) == 30)
        #expect(SubtitleStyle.cappedPointSize(100, regionHeight: 20) == 12)
        #expect(SubtitleStyle.cappedPointSize(8, regionHeight: 20) == 8)
    }

    @Test func pointSizeFollowsTheScale() {
        let normal = SubtitleStyle.default.pointSize(regionHeight: 10_000)
        let bigger = SubtitleStyle(sizeStep: 10).pointSize(regionHeight: 10_000)
        let smaller = SubtitleStyle(sizeStep: -4).pointSize(regionHeight: 10_000)
        #expect(abs(bigger - normal * 2) < 0.001)
        #expect(abs(smaller - normal * 0.6) < 0.001)
    }
}

@MainActor
struct SubtitlePlacementTests {
    /// A portrait video: 400 x 225, margins 16 / 8 / 12 / 16 (leading, top, bottom, trailing).
    /// Resting region: x 16...384, y 8...213 (368 x 205).
    private let video = CGSize(width: 400, height: 225)
    private let margins = SubtitleMargins(top: 8, leading: 16, bottom: 12, trailing: 16)
    private let line = CGSize(width: 200, height: 40)

    private func place(
        _ style: SubtitleStyle, line: CGSize? = nil, top: CGFloat = 0, bottom: CGFloat = 0
    ) -> CGRect {
        SubtitlePlacement.frame(
            videoSize: video, margins: margins, topObstruction: top, bottomObstruction: bottom,
            lineSize: line ?? self.line, style: style)
    }

    private func expectFrame(_ frame: CGRect, _ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat) {
        #expect(abs(frame.minX - x) < 0.01)
        #expect(abs(frame.minY - y) < 0.01)
        #expect(abs(frame.width - w) < 0.01)
        #expect(abs(frame.height - h) < 0.01)
    }

    private func isInside(_ frame: CGRect, of rect: CGRect) -> Bool {
        frame.minX >= rect.minX - 0.01 && frame.maxX <= rect.maxX + 0.01
            && frame.minY >= rect.minY - 0.01 && frame.maxY <= rect.maxY + 0.01
    }

    @Test func defaultIsBottomCentre() {
        // centre x 200 -> x 100; bottom at 213 -> y 173
        expectFrame(place(.default), 100, 173, 200, 40)
    }

    @Test func movedUpAndLeft() {
        // up 4 = 20% of 205 = 41, left 4 = 20% of 368 = 73.6
        let frame = place(SubtitleStyle(upSteps: 4, rightSteps: -4))
        expectFrame(frame, 26.4, 132, 200, 40)
    }

    @Test func aBarPushesTheLineUp() {
        // The bar's top is at 225 - 100 = 125, so the line's bottom is 125.
        let frame = place(.default, bottom: 100)
        expectFrame(frame, 100, 85, 200, 40)
    }

    @Test func aLineAlreadyClearOfTheBarDoesNotMove() {
        let style = SubtitleStyle(upSteps: 12)   // bottom at 213 - 123 = 90, above the bar at 125
        let without = place(style)
        let with = place(style, bottom: 100)
        expectFrame(without, 100, 50, 200, 40)
        #expect(with == without)
    }

    @Test func theTopBarPushesTheLineDown() {
        let frame = place(SubtitleStyle(upSteps: 18), top: 60)
        #expect(abs(frame.minY - 60) < 0.01)
    }

    @Test func extremeStepsStayInsideTheResting() {
        let resting = SubtitlePlacement.restingRegion(videoSize: video, margins: margins)
        let high = place(SubtitleStyle(upSteps: 18, rightSteps: 8))
        expectFrame(high, 184, 8, 200, 40)
        #expect(isInside(high, of: resting))
        let left = place(SubtitleStyle(upSteps: 18, rightSteps: -8))
        expectFrame(left, 16, 8, 200, 40)
        #expect(isInside(left, of: resting))
    }

    @Test func stepsOutsideTheRangesAreClampedAtLayoutToo() {
        var wild = SubtitleStyle.default
        wild.upSteps = 500
        wild.rightSteps = -500
        let resting = SubtitlePlacement.restingRegion(videoSize: video, margins: margins)
        #expect(isInside(place(wild), of: resting))
    }

    @Test func aWideLineIsNarrowedToTheRegion() {
        let frame = place(SubtitleStyle(rightSteps: 8), line: CGSize(width: 900, height: 40))
        expectFrame(frame, 16, 173, 368, 40)
    }

    @Test func aLineTallerThanTheRegionIsPinnedToTheBottom() {
        let frame = place(SubtitleStyle(upSteps: 10), line: CGSize(width: 200, height: 300))
        #expect(abs(frame.maxY - 213) < 0.01)
        let withBar = place(.default, line: CGSize(width: 200, height: 300), bottom: 100)
        #expect(abs(withBar.maxY - 125) < 0.01)
    }

    @Test func landscapeInsetsAndThePanelHandleClearance() {
        // 800 x 360 landscape video, side inset 59 + 16 leading, and the open panel's 32 pt handle + 16 trailing.
        let size = CGSize(width: 800, height: 360)
        let landscape = SubtitleMargins(top: 8, leading: 75, bottom: 33, trailing: 48)
        let lineSize = CGSize(width: 100, height: 30)
        let resting = SubtitlePlacement.restingRegion(videoSize: size, margins: landscape)
        #expect(abs(resting.width - 677) < 0.01)

        let centred = SubtitlePlacement.frame(
            videoSize: size, margins: landscape, lineSize: lineSize, style: .default)
        expectFrame(centred, 363.5, 297, 100, 30)

        // Tester (T-014 r1): right 8 = 40% of 677 = 270.8 from the centre 413.5, so a 100 pt line ends at 734.3
        // (the spec formula), not at the region's edge. A 300 pt line is clamped to the edges 752 and 75.
        let farRight = SubtitlePlacement.frame(
            videoSize: size, margins: landscape, lineSize: lineSize, style: SubtitleStyle(rightSteps: 8))
        #expect(abs(farRight.maxX - 734.3) < 0.01)
        #expect(farRight.maxX <= size.width - 32)   // clear of the handle's touch area
        let farLeft = SubtitlePlacement.frame(
            videoSize: size, margins: landscape, lineSize: lineSize, style: SubtitleStyle(rightSteps: -8))
        #expect(abs(farLeft.minX - 92.7) < 0.01)

        let wide = CGSize(width: 300, height: 30)
        let wideRight = SubtitlePlacement.frame(
            videoSize: size, margins: landscape, lineSize: wide, style: SubtitleStyle(rightSteps: 8))
        #expect(abs(wideRight.maxX - 752) < 0.01)
        #expect(wideRight.maxX <= size.width - 32)
        let wideLeft = SubtitlePlacement.frame(
            videoSize: size, margins: landscape, lineSize: wide, style: SubtitleStyle(rightSteps: -8))
        #expect(abs(wideLeft.minX - 75) < 0.01)
    }

    @Test func bothBarsShowingKeepTheLineBetweenThem() {
        let frame = place(SubtitleStyle(upSteps: 18), top: 60, bottom: 100)
        #expect(frame.minY >= 60 - 0.01)
        #expect(frame.maxY <= 125 + 0.01)
    }

    // MARK: Menu (T-015)

    @Test func stepsDoNotOverflowWhenAFieldIsSetToTheExtremesInCode() {
        var style = SubtitleStyle.default
        style.sizeStep = Int.max
        style.upSteps = Int.max
        style.rightSteps = Int.min
        let size = style.stepSize(1)
        let up = style.stepUp(1)
        let left = style.stepRight(-1)
        #expect(!size && !up && !left)
        #expect(style.sizeStep == 10)
        #expect(style.upSteps == 18)
        #expect(style.rightSteps == -8)
        #expect(SubtitleStyle.clampedSum(0, Int.max, to: SubtitleStyle.sizeRange) == 10)
        #expect(SubtitleStyle.clampedSum(0, Int.min, to: SubtitleStyle.sizeRange) == -4)
        #expect(SubtitleStyle.clampedSum(Int.max, Int.max, to: SubtitleStyle.upRange) == 18)
    }

    @Test func menuTextsShowSizeAndPosition() {
        #expect(SubtitleStyle.default.sizeText == "100%")
        #expect(SubtitleStyle(sizeStep: 3).sizeText == "130%")
        #expect(SubtitleStyle(sizeStep: -4).sizeText == "60%")
        #expect(SubtitleStyle(sizeStep: 3).sizeSpoken == "130 percent")
        #expect(SubtitleStyle.default.positionText == "Default place")
        #expect(SubtitleStyle(upSteps: 4, rightSteps: -2).positionText == "Up 20% \u{00B7} Left 10%")
        #expect(SubtitleStyle(rightSteps: 3).positionText == "Right 15%")
        #expect(SubtitleStyle(upSteps: 4).verticalSpoken == "20 percent up")
        #expect(SubtitleStyle(rightSteps: -2).horizontalSpoken == "10 percent left")
        #expect(SubtitleStyle.default.horizontalSpoken == "Centred")
    }

    @Test func eachMutatorDisablesItsButtonAtTheLimit() {
        let top = SubtitleStyle(sizeStep: 10, upSteps: 18, rightSteps: 8)
        #expect(!top.canSizeUp && top.canSizeDown && !top.canMoveUp && top.canMoveDown)
        #expect(!top.canMoveRight && top.canMoveLeft)
        let bottom = SubtitleStyle(sizeStep: -4, upSteps: 0, rightSteps: -8)
        #expect(bottom.canSizeUp && !bottom.canSizeDown && !bottom.canMoveDown && !bottom.canMoveLeft)
    }
}
