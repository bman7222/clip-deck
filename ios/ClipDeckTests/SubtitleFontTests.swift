import CoreText
import Foundation
import Testing
import UIKit
@testable import ClipDeck

/// T-017: a picked font (any installed family), its closest preset, the Japanese cascade, real bold only,
/// and what happens when the saved font is gone.
@MainActor
struct SubtitleFontTests {
    private let sample = "Aa あア漢字"

    /// One CoreText run of the drawn sample: its text and the PostScript name of the font really used.
    private struct Run {
        var text: String
        var fontName: String
    }

    private func runs(of style: SubtitleStyle) -> [Run] {
        let font = style.uiFont(pointSize: 40)
        let attributed = NSAttributedString(string: sample, attributes: [.font: font])
        let line = CTLineCreateWithAttributedString(attributed)
        guard let ctRuns = CTLineGetGlyphRuns(line) as? [CTRun] else { return [] }
        let text = sample as NSString
        var result: [Run] = []
        for run in ctRuns {
            let range = CTRunGetStringRange(run)
            let attributes = CTRunGetAttributes(run) as? [String: Any] ?? [:]
            guard let value = attributes[kCTFontAttributeName as String] else { continue }
            let ctFont = value as! CTFont
            let name = CTFontCopyPostScriptName(ctFont) as String
            let piece = text.substring(with: NSRange(location: range.location, length: range.length))
            result.append(Run(text: piece, fontName: name))
        }
        return result
    }

    private func hasJapanese(_ text: String) -> Bool {
        text.unicodeScalars.contains { $0.value >= 0x3040 }
    }

    // MARK: Closest preset

    @Test func namesDecideTheClosestPresetBeforeTheFamilyClass() {
        let none: UIFontDescriptor.SymbolicTraits = []
        #expect(SubtitleStyle.closestPreset(familyName: "Foo Mincho", fontName: "FooMincho-Regular", traits: none) == .serif)
        #expect(SubtitleStyle.closestPreset(familyName: "Foo Serif", fontName: "FooSerif", traits: none) == .serif)
        #expect(SubtitleStyle.closestPreset(familyName: "Foo Rounded", fontName: "FooRounded", traits: none) == .rounded)
        #expect(SubtitleStyle.closestPreset(familyName: "Foo Maru Gothic", fontName: "FooMaru", traits: none) == .rounded)
        // Mincho is checked before Rounded: the first match wins.
        #expect(SubtitleStyle.closestPreset(familyName: "Rounded Mincho", fontName: "RM", traits: none) == .serif)
        // "Sans" cancels the Serif name rule.
        #expect(SubtitleStyle.closestPreset(familyName: "Foo Sans Serif", fontName: "FooSansSerif", traits: none) == .sans)
        // A name rule wins over a sans class.
        #expect(SubtitleStyle.closestPreset(familyName: "Foo Rounded", fontName: "FooRounded", traits: [.classSansSerif]) == .rounded)
    }

    @Test func serifFamilyClassesGiveSerifAndEverythingElseSans() {
        let serifClasses: [UIFontDescriptor.SymbolicTraits] = [
            .classOldStyleSerifs, .classTransitionalSerifs, .classModernSerifs,
            .classClarendonSerifs, .classSlabSerifs, .classFreeformSerifs,
        ]
        for traits in serifClasses {
            #expect(SubtitleStyle.closestPreset(familyName: "Plain", fontName: "Plain", traits: traits) == .serif)
            // Other traits next to the class change nothing.
            #expect(SubtitleStyle.closestPreset(familyName: "Plain", fontName: "Plain", traits: traits.union(.traitBold)) == .serif)
        }
        let others: [UIFontDescriptor.SymbolicTraits] = [[], .classSansSerif, .classScripts, .classSymbolic, .traitBold]
        for traits in others {
            #expect(SubtitleStyle.closestPreset(familyName: "Plain", fontName: "Plain", traits: traits) == .sans)
        }
    }

    @Test func realFontsMapToTheirPreset() throws {
        let georgia = try #require(UIFont(name: "Georgia", size: 20))
        let rounded = try #require(UIFont(name: "ArialRoundedMTBold", size: 20))
        let helvetica = try #require(UIFont(name: "Helvetica", size: 20))
        #expect(SubtitleStyle.closestPreset(of: georgia) == .serif)
        #expect(SubtitleStyle.closestPreset(of: rounded) == .rounded)
        #expect(SubtitleStyle.closestPreset(of: helvetica) == .sans)
    }

    // MARK: Cascade

    @Test func georgiaDrawsLatinInGeorgiaAndJapaneseInHiraginoMincho() {
        let drawn = runs(of: SubtitleStyle(bold: false, pickedFontName: "Georgia"))
        #expect(!drawn.isEmpty)
        let latin = drawn.filter { $0.text.contains("A") }
        #expect(!latin.isEmpty)
        #expect(latin.allSatisfy { $0.fontName == "Georgia" })
        let japanese = drawn.filter { hasJapanese($0.text) }
        #expect(!japanese.isEmpty)
        #expect(japanese.allSatisfy { $0.fontName == "HiraMinProN-W3" })
        #expect(drawn.allSatisfy { !$0.fontName.contains("LastResort") })
    }

    @Test func georgiaBoldUsesItsBoldFaceAndTheHeavierMincho() {
        let style = SubtitleStyle(bold: true, pickedFontName: "Georgia")
        #expect(style.uiFont(pointSize: 30).fontName == "Georgia-Bold")
        #expect(style.pickedFontHasBold)
        let drawn = runs(of: style)
        #expect(drawn.filter { $0.text.contains("A") }.allSatisfy { $0.fontName == "Georgia-Bold" })
        #expect(drawn.filter { hasJapanese($0.text) }.allSatisfy { $0.fontName == "HiraMinProN-W6" })
        #expect(drawn.allSatisfy { !$0.fontName.contains("LastResort") })
        #expect(style.japaneseFallbackName == "HiraMinProN-W6")
    }

    @Test func aFamilyWithoutBoldKeepsItsFace() {
        let style = SubtitleStyle(bold: true, pickedFontName: "Zapfino")
        #expect(!style.pickedFontHasBold)
        #expect(style.uiFont(pointSize: 30).fontName == "Zapfino")
        #expect(SubtitleStyle(bold: false, pickedFontName: "Zapfino").uiFont(pointSize: 30).fontName == "Zapfino")
        // The Japanese fallback still follows Bold.
        #expect(style.japaneseFallbackName?.hasSuffix("-W6") == true)
        #expect(SubtitleStyle(bold: false, pickedFontName: "Zapfino").japaneseFallbackName?.hasSuffix("-W3") == true)
        let drawn = runs(of: style)
        #expect(drawn.allSatisfy { !$0.fontName.contains("LastResort") })
    }

    @Test func aRoundedPickedFontFallsBackToMaruGothicWhateverTheWeight() {
        #expect(SubtitleStyle(bold: true, pickedFontName: "ArialRoundedMTBold").japaneseFallbackName == "HiraMaruProN-W4")
        #expect(SubtitleStyle(bold: false, pickedFontName: "ArialRoundedMTBold").japaneseFallbackName == "HiraMaruProN-W4")
    }

    @Test func aSansPickedFontFallsBackToHiraginoSansExplicitly() {
        #expect(SubtitleStyle(bold: false, pickedFontName: "Helvetica").japaneseFallbackName == "HiraginoSans-W3")
        #expect(SubtitleStyle(bold: true, pickedFontName: "Helvetica").japaneseFallbackName == "HiraginoSans-W6")
        let uiFont = SubtitleStyle(pickedFontName: "Helvetica").uiFont(pointSize: 20)
        let cascade = uiFont.fontDescriptor.object(forKey: .cascadeList) as? [UIFontDescriptor]
        #expect(cascade?.isEmpty == false)
    }

    @Test func pickedFontKeepsTheRequestedSize() {
        #expect(SubtitleStyle(pickedFontName: "Georgia").uiFont(pointSize: 27).pointSize == 27)
    }

    // MARK: Saved form

    @Test func pickedFontIsSavedAndDecodedBack() {
        let style = SubtitleStyle(sizeStep: 2, pickedFontName: "Georgia")
        let back = SubtitleStyle.decoded(from: style.json)
        #expect(back.pickedFontName == "Georgia")
        #expect(back == style)
        #expect(!style.isDefault)
        #expect(SubtitleStyle.decoded(from: #"{"pickedFontName":"Georgia"}"#).pickedFontName == "Georgia")
    }

    @Test func aPickedFontIsNeverTheDefaultStyle() {
        #expect(!SubtitleStyle(pickedFontName: "Georgia").isDefault)
        #expect(SubtitleStyle(pickedFontName: nil).isDefault)
    }

    @Test func aMissingFontDecodesToSansAndKeepsTheRest() {
        let json = #"{"pickedFontName":"NoSuchFont-Regular","font":"serif","bold":false,"sizeStep":3,"upSteps":2}"#
        let style = SubtitleStyle.decoded(from: json)
        #expect(style.pickedFontName == nil)
        #expect(style.font == .sans)
        #expect(!style.bold)
        #expect(style.sizeStep == 3)
        #expect(style.upSteps == 2)
        // And a style that only carries the missing font is the default again.
        #expect(SubtitleStyle.decoded(from: #"{"pickedFontName":"NoSuchFont-Regular"}"#).isDefault)
        #expect(SubtitleStyle.decoded(from: #"{"pickedFontName":""}"#).pickedFontName == nil)
        #expect(SubtitleStyle.decoded(from: #"{"pickedFontName":7}"#).pickedFontName == nil)
    }

    @Test func aMissingFontIsDrawnAsSansEvenWhenSetDirectly() {
        let style = SubtitleStyle(font: .serif, bold: true, pickedFontName: "NoSuchFont-Regular")
        #expect(style.uiFont(pointSize: 20).fontName == UIFont.systemFont(ofSize: 20, weight: .bold).fontName)
        #expect(style.pickedFamilyName == nil)
        #expect(!style.pickedFontHasBold)
    }

    @Test func oldSavedStylesWithoutTheFieldStillDecode() {
        let old = SubtitleStyle.decoded(from: #"{"font":"serif","bold":false,"sizeStep":5,"upSteps":4,"rightSteps":-4}"#)
        #expect(old.pickedFontName == nil)
        #expect(old.font == .serif)
        #expect(old.sizeStep == 5)
        #expect(old.rightSteps == -4)
    }

    @Test func aPresetStyleSavesNoPickedFont() {
        #expect(!SubtitleStyle(font: .serif).json.contains("pickedFontName"))
    }

    @Test func theSeedKeepsAMissingNameSoTheReadCanDropIt() {
        let seed = #"{"pickedFontName":"NoSuchFont-Regular"}"#
        let seeded = SubtitleStyle.seeded(from: seed)
        #expect(seeded.pickedFontName == "NoSuchFont-Regular")
        #expect(SubtitleStyle.decoded(from: seeded.json).pickedFontName == nil)
        #expect(SubtitleStyle.seeded(from: #"{"pickedFontName":"Georgia"}"#).pickedFontName == "Georgia")
        #expect(SubtitleStyle.seeded(from: nil) == .default)
    }
}
