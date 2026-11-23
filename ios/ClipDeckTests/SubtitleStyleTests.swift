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
        #expect(style.up == 0)
        #expect(style.right == 0)
        #expect(style.isDefault)
        #expect(style.isFontDefault)
        #expect(style.isPositionDefault)
        #expect(abs(style.scale - 1.0) < 0.0001)
        #expect(SubtitleStyle() == .default)
    }

    @Test func scaleRunsFromSixtyToTwoHundredPercent() {
        #expect(abs(SubtitleStyle(sizeStep: -4).scale - 0.6) < 0.0001)
        #expect(abs(SubtitleStyle(sizeStep: 10).scale - 2.0) < 0.0001)
        #expect(abs(SubtitleStyle(sizeStep: 3).scale - 1.3) < 0.0001)
    }

    @Test func initClampsEveryField() {
        let style = SubtitleStyle(sizeStep: 99, up: -0.15, right: 4.95)
        #expect(style.sizeStep == 10)
        #expect(style.up == 0)
        #expect(style.right == 0.40)
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
        #expect(style.up == 0)
        style.up = 0.85
        let reachedTop = style.stepUp(1)
        #expect(reachedTop == false)
        #expect(style.up == 0.90)
        #expect(!style.canMoveUp)
        let pastTop = style.stepUp(1)
        #expect(pastTop == false)
        #expect(style.up == 0.90)
        #expect(style.canMoveDown)

        style.right = 0.35
        let reachedRight = style.stepRight(1)
        #expect(reachedRight == false)
        #expect(style.right == 0.40)
        #expect(!style.canMoveRight)
        style.right = -0.35
        let reachedLeft = style.stepRight(-1)
        #expect(reachedLeft == false)
        #expect(style.right == -0.40)
        #expect(!style.canMoveLeft)
        #expect(style.canMoveRight)
        let moreRoom = style.stepRight(2)
        #expect(moreRoom)
        #expect(style.right == -0.30)
    }

    @Test func eighteenUpTapsFromZeroReachExactlyNinetyPercent() {
        var style = SubtitleStyle.default
        for _ in 0..<18 { style.stepUp(1) }
        #expect(style.up == 0.90)
        #expect(!style.canMoveUp)
        let reportedAtTop = style.stepUp(1)
        #expect(reportedAtTop == false)
        #expect(style.up == 0.90)
        for _ in 0..<18 { style.stepUp(-1) }
        #expect(style.up == 0)
        #expect(!style.canMoveDown)
        var side = SubtitleStyle.default
        for _ in 0..<8 { side.stepRight(1) }
        #expect(side.right == 0.40)
        #expect(!side.canMoveRight)
    }

    @Test func aValueBetweenStepsStepsFromWhereItIs() {
        var style = SubtitleStyle(up: 0.37, right: -0.12)
        style.stepUp(1)
        #expect(style.up == 0.42)
        style.stepUp(-2)
        #expect(style.up == 0.32)
        style.stepRight(1)
        #expect(style.right == -0.07)
        // Writes are rounded to 4 decimals.
        #expect(SubtitleStyle(up: 0.123456).up == 0.1235)
    }

    @Test func nonFinitePositionsFallBackOrClamp() {
        #expect(SubtitleStyle(up: .nan, right: .nan) == .default)
        #expect(SubtitleStyle(up: .infinity, right: -.infinity).up == 0.90)
        #expect(SubtitleStyle(up: .infinity, right: -.infinity).right == -0.40)
    }

    // MARK: Separate resets (T-023)

    @Test func resetFontLeavesThePositionAlone() {
        var style = SubtitleStyle(font: .serif, bold: false, sizeStep: 5, up: 0.37, right: -0.2, pickedFontName: "Georgia")
        #expect(!style.isFontDefault)
        #expect(!style.isPositionDefault)
        style.resetFont()
        #expect(style.isFontDefault)
        #expect(!style.isPositionDefault)
        #expect(style.font == .sans && style.bold && style.sizeStep == 0 && style.pickedFontName == nil)
        #expect(style.up == 0.37)
        #expect(style.right == -0.2)
        #expect(!style.isDefault)
    }

    @Test func resetPositionLeavesTheFontAlone() {
        var style = SubtitleStyle(font: .serif, bold: false, sizeStep: 5, up: 0.37, right: -0.2, pickedFontName: "Georgia")
        style.resetPosition()
        #expect(style.isPositionDefault)
        #expect(!style.isFontDefault)
        #expect(style.up == 0 && style.right == 0)
        #expect(style.font == .serif && !style.bold && style.sizeStep == 5 && style.pickedFontName == "Georgia")
        #expect(!style.isDefault)
        style.resetFont()
        #expect(style.isDefault)
    }

    @Test func clampedFixesValuesSetDirectly() {
        var style = SubtitleStyle.default
        style.sizeStep = 50
        style.up = -50
        style.right = -50
        let fixed = style.clamped()
        #expect(fixed.sizeStep == 10)
        #expect(fixed.up == 0)
        #expect(fixed.right == -0.40)
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
        #expect(mixed.up == 0.15)
        #expect(mixed.bold)
    }

    @Test func unknownFontAndWrongTypesFallBackPerField() {
        let style = SubtitleStyle.decoded(from: #"{"font":"comic","bold":"yes","sizeStep":3.5,"rightSteps":2}"#)
        #expect(style.font == .sans)
        #expect(style.bold)
        #expect(style.sizeStep == 0)
        #expect(style.right == 0.10)
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
        #expect(style.up == 0)
        #expect(style.right == -0.40)
    }

    @Test func oldStepKeysMigrateToFractions() {
        let style = SubtitleStyle.decoded(from: #"{"upSteps":4,"rightSteps":-4}"#)
        #expect(style.up == 0.20)
        #expect(style.right == -0.20)
        let extreme = SubtitleStyle.decoded(from: #"{"upSteps":99,"rightSteps":-99}"#)
        #expect(extreme.up == 0.90)
        #expect(extreme.right == -0.40)
        let negative = SubtitleStyle.decoded(from: #"{"upSteps":-3}"#)
        #expect(negative.up == 0)
    }

    @Test func newKeysWinOverOldOnes() {
        let style = SubtitleStyle.decoded(from: #"{"up":0.37,"right":0.1,"upSteps":4,"rightSteps":-4}"#)
        #expect(style.up == 0.37)
        #expect(style.right == 0.10)
        let outOfRange = SubtitleStyle.decoded(from: #"{"up":5,"right":-5,"upSteps":4}"#)
        #expect(outOfRange.up == 0.90)
        #expect(outOfRange.right == -0.40)
    }

    @Test func garbagePositionValuesGiveTheDefault() {
        let wrongTypes = SubtitleStyle.decoded(from: #"{"up":"high","right":true,"upSteps":"x","rightSteps":1.5}"#)
        #expect(wrongTypes.up == 0)
        #expect(wrongTypes.right == 0)
        let nulls = SubtitleStyle.decoded(from: #"{"up":null,"right":null,"upSteps":null}"#)
        #expect(nulls.isPositionDefault)
    }

    @Test func encodingWritesOnlyTheNewKeys() {
        let json = SubtitleStyle(up: 0.20, right: -0.20).json
        #expect(json.contains("\"up\":0.2"))
        #expect(json.contains("\"right\":-0.2"))
        #expect(!json.contains("upSteps"))
        #expect(!json.contains("rightSteps"))
        #expect(SubtitleStyle.decoded(from: json) == SubtitleStyle(up: 0.20, right: -0.20))
    }

    @Test func aBetweenStepsValueSurvivesTheSavedJSON() {
        let style = SubtitleStyle(up: 0.3723, right: -0.0417)
        #expect(SubtitleStyle.decoded(from: style.json) == style)
    }

    @Test func jsonRoundTrips() {
        let style = SubtitleStyle(font: .serif, bold: false, sizeStep: 5, up: 0.2, right: -0.2)
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
        _ style: SubtitleStyle, line: CGSize? = nil, top: CGFloat = 0, bottom: CGFloat = 0, fromCard: Bool = false,
        avoid: CGRect? = nil
    ) -> CGRect {
        SubtitlePlacement.frame(
            videoSize: video, margins: margins, topObstruction: top, bottomObstruction: bottom,
            lineSize: line ?? self.line, style: style, stepsFromObstruction: fromCard, avoid: avoid)
    }

    // MARK: The overlay band (T-022)

    /// For the 400 x 225 video the band is x 70...330 and y 78.5...146.5 (buttons 78...322 x 86.5...138.5, plus 8).
    private var band: CGRect { SubtitlePlacement.overlayBand(videoSize: video) }

    @Test func overlayBandCoversTheThreeButtonsPlusPadding() {
        expectFrame(band, 70, 78.5, 260, 68)
    }

    @Test func aLineMeetingTheBandMovesAboveWhenThatIsSmaller() {
        // up 9: bottom 120.75, top 80.75. Above: bottom 78.5 (move 42.25). Below: bottom 186.5 (move 65.75).
        let frame = place(SubtitleStyle(up: 0.45), avoid: band)
        expectFrame(frame, 100, 38.5, 200, 40)
        #expect(frame.maxY == band.minY)
    }

    @Test func aLineMeetingTheBandMovesBelowWhenThatIsSmaller() {
        // up 7: bottom 141.25, top 101.25. Above: move 62.75. Below: bottom 186.5 (move 45.25).
        let frame = place(SubtitleStyle(up: 0.35), avoid: band)
        expectFrame(frame, 100, 146.5, 200, 40)
        #expect(frame.minY == band.maxY)
    }

    @Test func aLineClearOfTheBandDoesNotMove() {
        #expect(place(.default, avoid: band) == place(.default))
        // Moved far enough sideways that its width no longer meets the band's x range.
        let narrow = CGSize(width: 30, height: 40)   // x 37.8...67.8, left of the band's 70
        let style = SubtitleStyle(up: 0.45, right: -0.4)
        #expect(place(style, line: narrow, avoid: band) == place(style, line: narrow))
    }

    @Test func whenNeitherFitsTheLineGoesBelowAndStaysInTheRegion() {
        // Region cut to y 60...165: above would start at 38.5 (< 60) and below would end at 186.5 (> 165).
        let frame = place(SubtitleStyle(up: 0.45), top: 60, bottom: 60, avoid: band)
        expectFrame(frame, 100, 125, 200, 40)
        #expect(isInside(frame, of: CGRect(x: 16, y: 60, width: 368, height: 105)))
    }

    @Test func aNilBandReproducesTodaysFrames() {
        let styles = [SubtitleStyle.default, SubtitleStyle(up: 0.2, right: -0.2), SubtitleStyle(up: 0.9)]
        for style in styles {
            #expect(place(style, avoid: nil) == place(style))
            #expect(place(style, top: 30, bottom: 70, avoid: nil) == place(style, top: 30, bottom: 70))
        }
        expectFrame(place(SubtitleStyle(up: 0.2, right: -0.2), avoid: nil), 26.4, 132, 200, 40)
    }

    @Test func aTopBarRulesOutTheSmallerMoveAndTheLineGoesBelow() {
        // up 9: above (move 42.25) would start at 38.5, under the top bar at 50, so it doesn't fit; below does.
        let frame = place(SubtitleStyle(up: 0.45), top: 50, avoid: band)
        expectFrame(frame, 100, 146.5, 200, 40)
        // Without the bar the smaller move (above) wins.
        expectFrame(place(SubtitleStyle(up: 0.45), avoid: band), 100, 38.5, 200, 40)
    }

    @Test func theBandCombinesWithTheLandscapeBars() {
        // Top bar to y 30, bottom bar from y 155: below would end at 186.5 (> 155), so only "above" fits (top 38.5 >= 30).
        let frame = place(SubtitleStyle(up: 0.45), top: 30, bottom: 70, avoid: band)
        expectFrame(frame, 100, 38.5, 200, 40)
        #expect(isInside(frame, of: CGRect(x: 16, y: 30, width: 368, height: 125)))
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
        let frame = place(SubtitleStyle(up: 0.2, right: -0.2))
        expectFrame(frame, 26.4, 132, 200, 40)
    }

    @Test func aBarPushesTheLineUp() {
        // The bar's top is at 225 - 100 = 125, so the line's bottom is 125.
        let frame = place(.default, bottom: 100)
        expectFrame(frame, 100, 85, 200, 40)
    }

    @Test func aLineAlreadyClearOfTheBarDoesNotMove() {
        let style = SubtitleStyle(up: 0.6)   // bottom at 213 - 123 = 90, above the bar at 125
        let without = place(style)
        let with = place(style, bottom: 100)
        expectFrame(without, 100, 50, 200, 40)
        #expect(with == without)
    }

    @Test func theTopBarPushesTheLineDown() {
        let frame = place(SubtitleStyle(up: 0.9), top: 60)
        #expect(abs(frame.minY - 60) < 0.01)
    }

    @Test func extremeStepsStayInsideTheResting() {
        let resting = SubtitlePlacement.restingRegion(videoSize: video, margins: margins)
        let high = place(SubtitleStyle(up: 0.9, right: 0.4))
        expectFrame(high, 184, 8, 200, 40)
        #expect(isInside(high, of: resting))
        let left = place(SubtitleStyle(up: 0.9, right: -0.4))
        expectFrame(left, 16, 8, 200, 40)
        #expect(isInside(left, of: resting))
    }

    @Test func stepsOutsideTheRangesAreClampedAtLayoutToo() {
        var wild = SubtitleStyle.default
        wild.up = 500
        wild.right = -500
        let resting = SubtitlePlacement.restingRegion(videoSize: video, margins: margins)
        #expect(isInside(place(wild), of: resting))
    }

    @Test func aWideLineIsNarrowedToTheRegion() {
        let frame = place(SubtitleStyle(right: 0.4), line: CGSize(width: 900, height: 40))
        expectFrame(frame, 16, 173, 368, 40)
    }

    @Test func aLineTallerThanTheRegionIsPinnedToTheBottom() {
        let frame = place(SubtitleStyle(up: 0.5), line: CGSize(width: 200, height: 300))
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
            videoSize: size, margins: landscape, lineSize: lineSize, style: SubtitleStyle(right: 0.4))
        #expect(abs(farRight.maxX - 734.3) < 0.01)
        #expect(farRight.maxX <= size.width - 32)   // clear of the handle's touch area
        let farLeft = SubtitlePlacement.frame(
            videoSize: size, margins: landscape, lineSize: lineSize, style: SubtitleStyle(right: -0.4))
        #expect(abs(farLeft.minX - 92.7) < 0.01)

        let wide = CGSize(width: 300, height: 30)
        let wideRight = SubtitlePlacement.frame(
            videoSize: size, margins: landscape, lineSize: wide, style: SubtitleStyle(right: 0.4))
        #expect(abs(wideRight.maxX - 752) < 0.01)
        #expect(wideRight.maxX <= size.width - 32)
        let wideLeft = SubtitlePlacement.frame(
            videoSize: size, margins: landscape, lineSize: wide, style: SubtitleStyle(right: -0.4))
        #expect(abs(wideLeft.minX - 75) < 0.01)
    }

    @Test func bothBarsShowingKeepTheLineBetweenThem() {
        let frame = place(SubtitleStyle(up: 0.9), top: 60, bottom: 100)
        #expect(frame.minY >= 60 - 0.01)
        #expect(frame.maxY <= 125 + 0.01)
    }

    // MARK: Landscape card open (T-016)

    /// A 100 pt card: the active bottom is 225 - 100 = 125, and one step is 5% of the 205 pt region = 10.25 pt.
    @Test func withTheCardOpenEachUpStepMovesTheLineOneStepFromJustAboveIt() {
        for steps in 0...7 {
            let frame = place(SubtitleStyle(up: Double(steps) * 0.05), bottom: 100, fromCard: true)
            #expect(abs(frame.maxY - (125 - CGFloat(steps) * 10.25)) < 0.01)
        }
        // Down is the same move the other way: back at the card's edge at 0 steps, and never below it.
        #expect(abs(place(SubtitleStyle(up: 0.0), bottom: 100, fromCard: true).maxY - 125) < 0.01)
    }

    @Test func withTheCardOpenTheLineStillStopsBelowTheTopBar() {
        let frame = place(SubtitleStyle(up: 0.9), top: 30, bottom: 100, fromCard: true)
        #expect(abs(frame.minY - 30) < 0.01)
        #expect(frame.maxY <= 125 + 0.01)
        let inside = place(SubtitleStyle(up: 0.9, right: 0.4), top: 30, bottom: 100, fromCard: true)
        #expect(video.width >= inside.maxX)
        #expect(inside.minX >= 16 - 0.01)
    }

    @Test func withTheCardOpenSidewaysStepsAreUnchanged() {
        let style = SubtitleStyle(up: 0.15, right: -0.2)
        #expect(abs(place(style, bottom: 100, fromCard: true).minX - place(style, bottom: 100).minX) < 0.01)
    }

    @Test func afterTheCardClosesThePlacementIsTheNormalRule() {
        let style = SubtitleStyle(up: 0.6)
        let plain = SubtitlePlacement.frame(
            videoSize: video, margins: margins, bottomObstruction: 0, lineSize: line, style: style)
        let closed = place(style, bottom: 0, fromCard: false)
        #expect(plain == closed)
        // 213 - 12 x 10.25 = 90, as before; only the open card changes where the steps start.
        #expect(abs(closed.maxY - 90) < 0.01)
        #expect(abs(place(style, bottom: 100, fromCard: false).maxY - 90) < 0.01)
        // With the card open the same 12 steps run past the top and are clamped to the region's top.
        #expect(abs(place(style, bottom: 100, fromCard: true).maxY - 48) < 0.01)
    }

    // MARK: Menu (T-015)

    @Test func stepsDoNotOverflowWhenAFieldIsSetToTheExtremesInCode() {
        var style = SubtitleStyle.default
        style.sizeStep = Int.max
        style.up = .greatestFiniteMagnitude
        style.right = -.greatestFiniteMagnitude
        let size = style.stepSize(1)
        let up = style.stepUp(1)
        let left = style.stepRight(-1)
        #expect(!size && !up && !left)
        #expect(style.sizeStep == 10)
        #expect(style.up == 0.90)
        #expect(style.right == -0.40)
        #expect(SubtitleStyle.clampedSum(0, Int.max, to: SubtitleStyle.sizeRange) == 10)
        #expect(SubtitleStyle.clampedSum(0, Int.min, to: SubtitleStyle.sizeRange) == -4)
        #expect(SubtitleStyle.positionSum(0.3, Int.max, to: SubtitleStyle.upRange) == 0.90)
        #expect(SubtitleStyle.positionSum(0.3, Int.min, to: SubtitleStyle.upRange) == 0)
    }

    @Test func menuTextsShowSizeAndPosition() {
        #expect(SubtitleStyle.default.sizeText == "100%")
        #expect(SubtitleStyle(sizeStep: 3).sizeText == "130%")
        #expect(SubtitleStyle(sizeStep: -4).sizeText == "60%")
        #expect(SubtitleStyle(sizeStep: 3).sizeSpoken == "130 percent")
        #expect(SubtitleStyle.default.positionText == "Default place")
        #expect(SubtitleStyle(up: 0.2, right: -0.1).positionText == "Up 20% \u{00B7} Left 10%")
        #expect(SubtitleStyle(up: 0.37).verticalSpoken == "37 percent up")
        #expect(SubtitleStyle(up: 0.376, right: 0.0449).positionText == "Up 38% \u{00B7} Right 4%")
        #expect(SubtitleStyle(right: 0.15).positionText == "Right 15%")
        #expect(SubtitleStyle(up: 0.2).verticalSpoken == "20 percent up")
        #expect(SubtitleStyle(right: -0.1).horizontalSpoken == "10 percent left")
        #expect(SubtitleStyle.default.horizontalSpoken == "Centred")
    }

    @Test func eachMutatorDisablesItsButtonAtTheLimit() {
        let top = SubtitleStyle(sizeStep: 10, up: 0.9, right: 0.4)
        #expect(!top.canSizeUp && top.canSizeDown && !top.canMoveUp && top.canMoveDown)
        #expect(!top.canMoveRight && top.canMoveLeft)
        let bottom = SubtitleStyle(sizeStep: -4, up: 0.0, right: -0.4)
        #expect(bottom.canSizeUp && !bottom.canSizeDown && !bottom.canMoveDown && !bottom.canMoveLeft)
    }

    // MARK: Style sheet first detent

    /// iPhone 17 Pro portrait: window 874, video bottom 342.
    private let iPhone17Pro = SheetClearance(windowHeight: 874, videoMaxY: 342)

    @Test func firstDetentStaysUnderTheVideo() {
        // Room 532, less the 8 pt gap and the 20 pt first guess.
        #expect(SheetFit.detentHeight(for: iPhone17Pro, rise: SheetFit.firstGuessRise) == 504)
        // A bigger rise (an edge-to-edge sheet that adds the 34 pt bottom inset) makes a shorter detent.
        #expect(SheetFit.detentHeight(for: iPhone17Pro, rise: 34) == 490)
        // A small room never goes below the minimum; the content scrolls.
        #expect(SheetFit.detentHeight(for: SheetClearance(windowHeight: 400, videoMaxY: 380), rise: 20) == 120)
        #expect(SheetFit.detentHeight(for: iPhone17Pro, rise: 500) == SheetFit.minimumDetentHeight)
    }

    @Test func riseComesFromTheMeasuredSheetTop() throws {
        // CI 44888942981 (iOS 26.5): a 504 pt detent drew its top at 349.4, so the rise is 370 - 349.4.
        let rise = try #require(SheetFit.rise(windowHeight: 874, detentHeight: 504, sheetTop: 349.4))
        #expect(abs(rise - 20.6) < 0.001)
        // Round 1 on the same OS: a 520 pt detent drew its top at 334.
        let earlier = try #require(SheetFit.rise(windowHeight: 874, detentHeight: 520, sheetTop: 334))
        #expect(abs(earlier - 20) < 0.001)
        // A sheet exactly at window minus detent has no rise.
        #expect(SheetFit.rise(windowHeight: 874, detentHeight: 504, sheetTop: 370) == 0)
    }

    @Test func nonsensicalMeasurementsAreIgnored() {
        // At `.large` the top is near the status bar: an implausible rise.
        #expect(SheetFit.rise(windowHeight: 874, detentHeight: 504, sheetTop: 62) == nil)
        #expect(SheetFit.correction(for: iPhone17Pro, detentHeight: 504, sheetTop: 62) == nil)
        // Still off screen (the presentation hasn't started), or not laid out yet.
        #expect(SheetFit.rise(windowHeight: 874, detentHeight: 504, sheetTop: 874) == nil)
        #expect(SheetFit.rise(windowHeight: 874, detentHeight: 504, sheetTop: 0) == nil)
        #expect(SheetFit.rise(windowHeight: 874, detentHeight: 504, sheetTop: -10) == nil)
        #expect(SheetFit.rise(windowHeight: 874, detentHeight: 504, sheetTop: .nan) == nil)
        #expect(SheetFit.rise(windowHeight: 874, detentHeight: 504, sheetTop: .infinity) == nil)
        // Mid-animation, far lower than any real detent sits.
        #expect(SheetFit.rise(windowHeight: 874, detentHeight: 504, sheetTop: 600) == nil)
        // No window.
        #expect(SheetFit.rise(windowHeight: 0, detentHeight: 504, sheetTop: 349) == nil)
    }

    @Test func oneCorrectionPutsTheSheetJustUnderTheVideo() throws {
        // An edge-to-edge sheet that really rises 34 pt opened at the 20 pt guess: it covers 6 pt of the video.
        let trueRise: CGFloat = 34
        let guess = SheetFit.detentHeight(for: iPhone17Pro, rise: SheetFit.firstGuessRise)
        let firstTop = iPhone17Pro.windowHeight - guess - trueRise
        #expect(firstTop < iPhone17Pro.videoMaxY)
        let fix = try #require(SheetFit.correction(for: iPhone17Pro, detentHeight: guess, sheetTop: firstTop))
        #expect(abs(fix.rise - trueRise) < 0.001)
        #expect(abs(fix.detentHeight - 490) < 0.001)
        // At the corrected height the sheet starts the gap below the video ...
        let correctedTop = iPhone17Pro.windowHeight - fix.detentHeight - trueRise
        #expect(abs(correctedTop - (iPhone17Pro.videoMaxY + SheetFit.gapBelowVideo)) < 0.001)
        // ... and measuring again changes nothing: it has converged.
        let again = try #require(SheetFit.correction(for: iPhone17Pro, detentHeight: fix.detentHeight, sheetTop: correctedTop))
        #expect(again.detentHeight == fix.detentHeight)
        // The cached rise makes the next open right from the start.
        #expect(SheetFit.detentHeight(for: iPhone17Pro, rise: again.rise) == fix.detentHeight)
    }

    @Test func aSheetSittingTooLowIsRaised() throws {
        // A home-button iPhone that doesn't rise at all: the 20 pt guess leaves a 28 pt gap; one fix closes it.
        let fix = try #require(SheetFit.correction(for: iPhone17Pro, detentHeight: 504, sheetTop: 370))
        #expect(fix.rise == 0)
        #expect(fix.detentHeight == 524)
    }

    @Test func aSubPointDifferenceIsLeftAlone() throws {
        // iOS 26.5: the measured 20.6 pt rise asks for 503.4, within a point of 504, so the sheet stays put.
        let fix = try #require(SheetFit.correction(for: iPhone17Pro, detentHeight: 504, sheetTop: 349.4))
        #expect(fix.detentHeight == 504)
        #expect(abs(fix.rise - 20.6) < 0.001)
    }

    @Test func theFloorHoldsAfterACorrection() throws {
        // Little room under the video: the fix never goes below the minimum, so the content scrolls instead.
        let short = SheetClearance(windowHeight: 667, videoMaxY: 520)
        let fix = try #require(SheetFit.correction(for: short, detentHeight: 120, sheetTop: 667 - 120 - 34))
        #expect(fix.detentHeight == SheetFit.minimumDetentHeight)
    }
}

// MARK: Up with the landscape card open (T-018)

extension SubtitlePlacementTests {
    /// A landscape video 800 x 360, margins 8 / 75 / 33 / 48 (resting y 8...327, 319 high, so a step is 15.95 pt),
    /// a 52 pt top bar clearance and a 30 pt line (so the line's bottom can't go above 82).
    private func upTapsPossible(cardClearance: CGFloat) -> Int {
        let size = CGSize(width: 800, height: 360)
        let margins = SubtitleMargins(top: 8, leading: 75, bottom: 33, trailing: 48)
        let lineSize = CGSize(width: 100, height: 30)
        var style = SubtitleStyle.default
        var taps = 0
        while taps < 40 {
            let canStep = SubtitlePlacement.canStepUpWithCardOpen(
                videoSize: size, margins: margins, topObstruction: 52, bottomObstruction: cardClearance,
                lineSize: lineSize, style: style)
            if !canStep { break }
            let before = SubtitlePlacement.frame(
                videoSize: size, margins: margins, topObstruction: 52, bottomObstruction: cardClearance,
                lineSize: lineSize, style: style, stepsFromObstruction: true)
            style.stepUp(1)
            let after = SubtitlePlacement.frame(
                videoSize: size, margins: margins, topObstruction: 52, bottomObstruction: cardClearance,
                lineSize: lineSize, style: style, stepsFromObstruction: true)
            #expect(before.minY - after.minY > 1)   // every enabled tap shows
            taps += 1
        }
        return taps
    }

    @Test func oneRowCardAllowsFourteenUpTaps() {
        #expect(upTapsPossible(cardClearance: 68) == 14)
    }

    @Test func twoRowCardAllowsElevenUpTaps() {
        #expect(upTapsPossible(cardClearance: 108) == 11)
    }

    @Test func threeRowCardAllowsNineUpTaps() {
        #expect(upTapsPossible(cardClearance: 148) == 9)
    }

    @Test func theStoredLimitStillStopsUpAndAnUnmeasuredVideoDoesNot() {
        let size = CGSize(width: 800, height: 360)
        let margins = SubtitleMargins(top: 8, leading: 75, bottom: 33, trailing: 48)
        let atLimit = SubtitlePlacement.canStepUpWithCardOpen(
            videoSize: size, margins: margins, topObstruction: 0, bottomObstruction: 68,
            lineSize: CGSize(width: 100, height: 4), style: SubtitleStyle(up: 0.9))
        #expect(!atLimit)
        let unmeasured = SubtitlePlacement.canStepUpWithCardOpen(
            videoSize: .zero, margins: margins, topObstruction: 52, bottomObstruction: 68,
            lineSize: .zero, style: .default)
        #expect(unmeasured)
    }

    private func highest(cardClearance: CGFloat) -> Double {
        SubtitlePlacement.highestReachableUp(
            videoSize: CGSize(width: 800, height: 360), margins: SubtitleMargins(top: 8, leading: 75, bottom: 33, trailing: 48),
            topObstruction: 52, bottomObstruction: cardClearance, lineSize: CGSize(width: 100, height: 30))
    }

    @Test func theHighestReachableUpMatchesTheUpTaps() {
        #expect(highest(cardClearance: 68) == 0.70)
        #expect(highest(cardClearance: 108) == 0.55)
        #expect(highest(cardClearance: 148) == 0.45)
    }

    @Test func aStoredUpAboveTheHighestReachableJumpsToOneStepBelowItOnTheFirstDown() {
        let top = highest(cardClearance: 68)
        let below = SubtitleStyle.clampPosition(top - 0.05, to: SubtitleStyle.upRange)
        #expect(SubtitlePlacement.upAfterDownWithCardOpen(stored: 0.85, highestReachable: top) == below)
        #expect(SubtitlePlacement.upAfterDownWithCardOpen(stored: 0.90, highestReachable: top) == below)
        #expect(SubtitlePlacement.upAfterDownWithCardOpen(stored: top + 0.05, highestReachable: top) == below)
        // At or below the highest reachable value, Down is 0.05 as before (from wherever it is), never below 0.
        #expect(SubtitlePlacement.upAfterDownWithCardOpen(stored: top, highestReachable: top) == below)
        #expect(SubtitlePlacement.upAfterDownWithCardOpen(stored: 0.25, highestReachable: top) == 0.20)
        #expect(SubtitlePlacement.upAfterDownWithCardOpen(stored: 0.37, highestReachable: top) == 0.32)
        #expect(SubtitlePlacement.upAfterDownWithCardOpen(stored: 0.02, highestReachable: top) == 0)
        #expect(SubtitlePlacement.upAfterDownWithCardOpen(stored: 0, highestReachable: top) == 0)
    }

    @Test func aMenuAtTheTopCanCountUpFromTheBottomInstead() {
        let size = CGSize(width: 800, height: 360)
        let margins = SubtitleMargins(top: 8, leading: 75, bottom: 33, trailing: 48)
        let lineSize = CGSize(width: 100, height: 30)
        // From the bottom the line reaches the top bar after more taps than from a 68 pt card.
        let fromBottom = SubtitlePlacement.highestReachableUp(
            videoSize: size, margins: margins, topObstruction: 52, bottomObstruction: 0, lineSize: lineSize,
            stepsFromObstruction: false)
        #expect(fromBottom > 0 && fromBottom < 0.90)
        let canStepBelow = SubtitlePlacement.canStepUpWithCardOpen(
            videoSize: size, margins: margins, topObstruction: 52, bottomObstruction: 0, lineSize: lineSize,
            style: SubtitleStyle(up: fromBottom - 0.05), stepsFromObstruction: false)
        #expect(canStepBelow)
    }

    @Test func theJumpedStepMovesTheLineByMoreThanOnePoint() {
        let size = CGSize(width: 800, height: 360)
        let margins = SubtitleMargins(top: 8, leading: 75, bottom: 33, trailing: 48)
        let lineSize = CGSize(width: 100, height: 30)
        let target = SubtitlePlacement.upAfterDownWithCardOpen(stored: 0.85, highestReachable: highest(cardClearance: 68))
        let pinned = SubtitlePlacement.frame(
            videoSize: size, margins: margins, topObstruction: 52, bottomObstruction: 68,
            lineSize: lineSize, style: SubtitleStyle(up: 0.85), stepsFromObstruction: true)
        let moved = SubtitlePlacement.frame(
            videoSize: size, margins: margins, topObstruction: 52, bottomObstruction: 68,
            lineSize: lineSize, style: SubtitleStyle(up: target), stepsFromObstruction: true)
        #expect(moved.minY - pinned.minY > 1)
    }
}
