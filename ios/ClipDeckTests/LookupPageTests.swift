import CoreGraphics
import Foundation
import Testing
@testable import ClipDeck

/// The popup's page, its default place, and the lookup that feeds it (against the zips in scripts/fixtures/dictionaries).
@MainActor
struct LookupPageTests {
    let palette = LookupPage.Palette(ink: "#111111", inkSoft: "#222222", accent: "#333333", shell: "#444444")

    func result(_ entries: [LookupEntry]) -> LookupResult {
        let text = "元気"
        return LookupResult(range: text.startIndex..<text.endIndex, entries: entries)
    }

    func entry(_ expression: String, _ reading: String, reasons: [String] = [], frequencies: [LookupFrequency] = [],
               sections: [LookupSection] = []) -> LookupEntry {
        LookupEntry(expression: expression, reading: reading, reasons: reasons, matchLength: expression.count,
                    frequencies: frequencies, sections: sections)
    }

    func section(_ title: String, _ glosses: [String], tags: [String] = []) -> LookupSection {
        LookupSection(dictionaryID: 1, dictionaryTitle: title,
                      definitions: [LookupDefinition(tags: tags, termTags: [], glossary: glosses.map(GlossaryItem.text))])
    }

    // MARK: Headword

    @Test func theHeadwordShowsItsReadingAsFurigana() {
        #expect(LookupPage.headword("元気", reading: "げんき") == "<ruby>元気<rt>げんき</rt></ruby>")
    }

    @Test func kanaTheWordSharesWithItsReadingStayOutsideTheRuby() {
        #expect(LookupPage.headword("食べる", reading: "たべる") == "<ruby>食<rt>た</rt></ruby>べる")
        #expect(LookupPage.headword("お願い", reading: "おねがい") == "お<ruby>願<rt>ねが</rt></ruby>い")
    }

    @Test func aKanaWordOrAMissingReadingHasNoRuby() {
        #expect(LookupPage.headword("こんにちは", reading: "こんにちは") == "こんにちは")
        #expect(LookupPage.headword("猫", reading: "") == "猫")
    }

    @Test func theHeadwordIsEscaped() {
        #expect(LookupPage.headword("<b>", reading: "&") == "<ruby>&lt;b&gt;<rt>&amp;</rt></ruby>")
    }

    // MARK: Page

    @Test func thePageHasEveryEntryPartInOrder() {
        let frequency = LookupFrequency(dictionaryTitle: "Popup Frequency", value: 1234, displayText: "1,234")
        let page = LookupPage.html(result([
            entry("元気", "げんき", reasons: ["past", "negative"], frequencies: [frequency],
                  sections: [section("First", ["healthy"], tags: ["adj-na"]), section("Second", ["fine"])]),
        ]), palette: palette)
        #expect(page.contains("<ruby>元気<rt>げんき</rt></ruby>"))
        #expect(page.contains("past · negative"))
        #expect(page.contains("<span class='freq'><b>Popup Frequency</b>1,234</span>"))
        #expect(page.contains("<span>adj-na</span>"))
        #expect(page.contains("<li>healthy</li>"))
        let first = page.range(of: "<h3>First</h3>")
        let second = page.range(of: "<h3>Second</h3>")
        #expect(first != nil && second != nil)
        if let first, let second { #expect(first.lowerBound < second.lowerBound) }
    }

    @Test func severalDefinitionsOfOneDictionaryAreNumbered() {
        let definitions = [
            LookupDefinition(tags: [], termTags: [], glossary: [.text("one")]),
            LookupDefinition(tags: [], termTags: [], glossary: [.text("two")]),
        ]
        let page = LookupPage.html(result([
            entry("a", "a", sections: [LookupSection(dictionaryID: 1, dictionaryTitle: "D", definitions: definitions)]),
        ]), palette: palette)
        #expect(page.contains("<ol class='defs'><li class='def'><ul><li>one</li></ul></li><li class='def'><ul><li>two</li></ul></li></ol>"))
    }

    @Test func nothingInTheDataReachesThePageUnescaped() {
        let frequency = LookupFrequency(dictionaryTitle: "<i>F</i>", value: 1, displayText: "<u>1</u>")
        let page = LookupPage.html(result([
            entry("<x>", "<y>", reasons: ["<r>"], frequencies: [frequency], sections: [section("<s>", ["<script>alert(1)</script>"], tags: ["<t>"])]),
        ]), palette: palette)
        for raw in ["<x>", "<y>", "<r>", "<i>F", "<u>1", "<s>", "<t>", "<script>"] { #expect(!page.contains(raw), "\(raw) is escaped") }
        #expect(page.contains("&lt;script&gt;alert(1)&lt;/script&gt;"))
    }

    @Test func thePageBlocksEverythingButInlineStyles() {
        let page = LookupPage.html(result([entry("元気", "げんき")]), palette: palette)
        #expect(page.contains("Content-Security-Policy"))
        #expect(page.contains("default-src 'none'"))
        #expect(page.contains("style-src 'unsafe-inline'"))
        #expect(!page.contains("<script"))
        #expect(!page.contains("http://") && !page.contains("https://"))
    }

    @Test func thePageUsesThePaletteColours() {
        let page = LookupPage.html(result([entry("元気", "げんき")]), palette: palette)
        for colour in ["#111111", "#222222", "#333333", "#444444"] { #expect(page.contains(colour), "\(colour) is used") }
    }

    @Test func theSummaryIsTheTopEntrysExpressionAndReading() {
        #expect(LookupPage.summary(result([entry("元気", "げんき"), entry("犬", "いぬ")])) == "元気 げんき")
        #expect(LookupPage.summary(result([entry("こんにちは", "こんにちは")])) == "こんにちは")
        #expect(LookupPage.summary(result([])) == nil)
    }

    // MARK: Placement

    @Test func portraitSitsFullWidthMinusTheMarginsJustAboveTheBottom() {
        let area = CGRect(x: 0, y: 100, width: 402, height: 740)
        let frame = LookupPopupPlacement.defaultFrame(in: area, isLandscape: false)
        #expect(frame == CGRect(x: 16, y: 840 - 16 - 260, width: 370, height: 260))
    }

    @Test func landscapeSitsInTheTopTrailingCorner() {
        let area = CGRect(x: 62, y: 0, width: 750, height: 402)
        let frame = LookupPopupPlacement.defaultFrame(in: area, isLandscape: true)
        #expect(frame == CGRect(x: 812 - 16 - 300, y: 16, width: 300, height: 200))
    }

    @Test func aSmallAreaShrinksThePopupInsteadOfLeavingIt() {
        let landscape = LookupPopupPlacement.defaultFrame(in: CGRect(x: 0, y: 0, width: 250, height: 150), isLandscape: true)
        #expect(landscape == CGRect(x: 16, y: 16, width: 218, height: 118))
        let portrait = LookupPopupPlacement.defaultFrame(in: CGRect(x: 0, y: 0, width: 300, height: 200), isLandscape: false)
        #expect(portrait == CGRect(x: 16, y: 16, width: 268, height: 168))
        #expect(LookupPopupPlacement.defaultFrame(in: .zero, isLandscape: true).size == .zero)
    }

    // MARK: Lookup

    func fixtureURL(_ name: String) throws -> URL {
        // This file is <repo>/ios/ClipDeckTests/LookupPageTests.swift.
        let url = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
            .deletingLastPathComponent().appending(path: "scripts/fixtures/dictionaries/\(name).zip")
        try #require(FileManager.default.fileExists(atPath: url.path), "Missing fixture \(name).zip")
        return url
    }

    func makeModel() -> DictionaryManagerModel {
        DictionaryManagerModel(url: FileManager.default.temporaryDirectory
            .appending(path: "LookupPageTests-\(UUID().uuidString)", directoryHint: .isDirectory)
            .appending(path: "dictionaries.sqlite"))
    }

    @Test func anEmptyStoreSaysNoDictionariesYet() async {
        let state = await LookupPopupState.resolve(exact: "元気", with: makeModel())
        #expect(state == .noDictionaries)
    }

    @Test func aWordWithoutAnEntrySaysNoEntries() async throws {
        let model = makeModel()
        await model.importFile(try fixtureURL("words-v3"))
        let state = await LookupPopupState.resolve(exact: "zzz", with: model)
        #expect(state == .noEntries("zzz"))
    }

    @Test func anExactLookupFindsTheEntryWithItsFrequencyAndSections() async throws {
        let model = makeModel()
        for name in ["words-v3", "words-second", "frequency", "popup-frequency"] { await model.importFile(try fixtureURL(name)) }
        let state = await LookupPopupState.resolve(exact: "元気", with: model)
        guard case .entries(let found) = state, let top = found.entries.first else {
            Issue.record("Expected entries, got \(state)")
            return
        }
        #expect(LookupPage.summary(found) == "元気 げんき")
        #expect(top.frequencies.map(\.displayText) == ["1,234"])
        #expect(top.sections.map(\.dictionaryTitle) == ["Clip Test Words"])
        #expect(LookupPage.html(found, palette: palette).contains("<li>healthy</li>"))
    }
}
