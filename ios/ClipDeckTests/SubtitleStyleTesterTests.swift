import SwiftUI
import Testing
import UIKit
@testable import ClipDeck

/// Tester checks for T-014: the default style must give exactly the font the line used before styles existed.
@MainActor
struct SubtitleStyleTesterTests {
    /// The font `SelectableText` built for the line before T-014 (title3, bold, scaled by UIFontMetrics).
    private func fontBeforeStyles() -> UIFont {
        let base = UIFont.systemFont(ofSize: UIFont.preferredFont(forTextStyle: .title3).pointSize, weight: .bold)
        return UIFontMetrics(forTextStyle: .title3).scaledFont(for: base)
    }

    /// Region heights of the iPhone 17 Pro player: portrait (402 x 226 video, margins 8 + 12) and landscape
    /// (402 pt tall, margins 8 + 12 + 21 bottom inset).
    @Test(arguments: [206.0, 361.0])
    func defaultStyleGivesTheFontTheLineHadBefore(regionHeight: Double) {
        let before = fontBeforeStyles()
        let now = SubtitleStyle.default.uiFont(regionHeight: CGFloat(regionHeight))
        #expect(now.pointSize == before.pointSize)
        #expect(now.fontName == before.fontName)
        #expect(now.familyName == before.familyName)
        #expect(now.fontDescriptor.symbolicTraits == before.fontDescriptor.symbolicTraits)
        #expect(now.lineHeight == before.lineHeight)
    }

    // MARK: Hugging width (risk: the hugged width re-wraps or clips the text)

    private func size(_ view: SelectableText, width: CGFloat) -> CGSize {
        UIHostingController(rootView: view).sizeThatFits(in: CGSize(width: width, height: 10_000))
    }

    private func line(_ text: String, _ font: UIFont, hugs: Bool) -> SelectableText {
        SelectableText(text: text, textStyle: .title3, weight: .bold, color: .white, outlined: true,
                       font: font, hugsWidth: hugs, identifier: "player.subtitle")
    }

    /// The hugged line has exactly the height (so the same lines) as the full-width line it replaced, is no
    /// wider than the proposal, and gives the same size when its own width is proposed back.
    @Test(arguments: [
        "I don't think we should go there tonight, it's far too late for that kind of thing, don't you agree?",
        "今日はとても良い天気ですね。公園へ散歩に行きませんか？それとも家でゆっくりしますか？",
        "元気ですか？ I'm fine, thank you. それは良かった！ See you tomorrow at the station.",
        "こんにちは\nお元気ですか、今日も一日頑張りましょう",
        "またね",
    ])
    func huggedLineKeepsTheSameLinesAndIsStable(text: String) {
        let fonts = [
            SubtitleStyle.default.uiFont(pointSize: 20),
            SubtitleStyle(font: .serif, bold: false, sizeStep: 10).uiFont(pointSize: 40),
            SubtitleStyle(font: .rounded, sizeStep: 5).uiFont(pointSize: 30),
        ]
        let oneLine = size(line("A", fonts[0], hugs: false), width: 370).height
        #expect(oneLine > 0, "Hosting sized the text view")
        for font in fonts {
            for width in [370.0, 498.0, 250.0] as [CGFloat] {
                let full = size(line(text, font, hugs: false), width: width)
                let hugged = size(line(text, font, hugs: true), width: width)
                #expect(full.height > 0)
                #expect(hugged.height == full.height, "\(font.fontName) @\(width): hugged \(hugged) vs full \(full)")
                #expect(hugged.width <= width + 0.01)
                #expect(hugged.width > 0)
                let again = size(line(text, font, hugs: true), width: hugged.width)
                #expect(again == hugged, "\(font.fontName) @\(width): proposed back \(again) vs \(hugged)")
            }
        }
        let long = size(line(String(repeating: "元気ですか。", count: 12), fonts[0], hugs: true), width: 370)
        #expect(long.height > oneLine * 1.5, "A long line wraps (the measure is real)")
    }

    @Test func decodingTheSavedDefaultGivesTheSameFont() {
        let saved = SubtitleStyle.decoded(from: SubtitleStyle.default.json)
        #expect(saved.uiFont(regionHeight: 206).fontName == fontBeforeStyles().fontName)
        #expect(SubtitleStyle.decoded(from: "").uiFont(regionHeight: 206).pointSize == fontBeforeStyles().pointSize)
    }
}
