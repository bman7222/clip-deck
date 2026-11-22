import Foundation
import UIKit

/// The font families the style can choose from. Japanese text always falls back to a fixed Hiragino face.
nonisolated enum SubtitleFont: String, Codable, CaseIterable, Sendable {
    case sans, rounded, serif

    /// Name shown in the style menu.
    var title: String {
        switch self {
        case .sans: return "Sans"
        case .rounded: return "Rounded"
        case .serif: return "Serif"
        }
    }
}

/// How the line on the video is drawn: font, weight, size and place. One global value, saved as JSON under
/// `player.subtitleStyle`. Steps are Ints so there is no floating-point drift. The default is today's look.
///
/// Decoding is tolerant: every field falls back to its default when missing or invalid, unknown fields are
/// ignored (a later build may add some), and every field is clamped to its range. A picked font that is no longer
/// installed is dropped on read and the style uses Sans.
/// Not `RawRepresentable` on purpose: a type that is both that and `Codable` recurses forever.
nonisolated struct SubtitleStyle: Codable, Equatable, Sendable {
    /// Size steps: scale = 1 + 0.1 x step, so 60% to 200%.
    static let sizeRange = -4...10
    /// Up steps, each 5% of the region height. 0 is the default bottom place; nothing goes lower.
    static let upRange = 0...18
    /// Sideways steps, each 5% of the region width. Negative is left.
    static let rightRange = -8...8
    /// The `UserDefaults.standard` key holding the JSON.
    static let storageKey = "player.subtitleStyle"
    /// The line is never smaller than this many points, however small the video area is.
    static let minimumPointSize: CGFloat = 12
    static let `default` = SubtitleStyle()

    var font: SubtitleFont
    var bold: Bool
    var sizeStep: Int
    var upSteps: Int
    var rightSteps: Int
    /// PostScript name of a font picked in the system font picker. When set it takes the place of `font`; picking a
    /// preset clears it. Not checked here (tests build styles with synthetic names); decoding and drawing check it.
    var pickedFontName: String?

    init(
        font: SubtitleFont = .sans, bold: Bool = true, sizeStep: Int = 0, upSteps: Int = 0, rightSteps: Int = 0,
        pickedFontName: String? = nil
    ) {
        self.pickedFontName = pickedFontName
        self.font = font
        self.bold = bold
        self.sizeStep = Self.clamp(sizeStep, to: Self.sizeRange)
        self.upSteps = Self.clamp(upSteps, to: Self.upRange)
        self.rightSteps = Self.clamp(rightSteps, to: Self.rightRange)
    }

    private enum CodingKeys: String, CodingKey {
        case font, bold, sizeStep, upSteps, rightSteps, pickedFontName
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let fallback = SubtitleStyle.default
        let savedName: String? = try? container.decodeIfPresent(String.self, forKey: .pickedFontName)
        // A picked font that is gone (for example a downloaded font that was deleted) is dropped and Sans is used.
        let installedName: String? = savedName.flatMap { Self.isInstalled($0) ? $0 : nil }
        let dropped = savedName != nil && installedName == nil
        let savedFont: SubtitleFont = (try? container.decodeIfPresent(SubtitleFont.self, forKey: .font)) ?? fallback.font
        self.init(
            font: dropped ? .sans : savedFont,
            bold: (try? container.decodeIfPresent(Bool.self, forKey: .bold)) ?? fallback.bold,
            sizeStep: (try? container.decodeIfPresent(Int.self, forKey: .sizeStep)) ?? fallback.sizeStep,
            upSteps: (try? container.decodeIfPresent(Int.self, forKey: .upSteps)) ?? fallback.upSteps,
            rightSteps: (try? container.decodeIfPresent(Int.self, forKey: .rightSteps)) ?? fallback.rightSteps,
            pickedFontName: installedName
        )
    }

    /// Whether a font with this PostScript name can be built right now.
    static func isInstalled(_ postScriptName: String) -> Bool {
        !postScriptName.isEmpty && UIFont(name: postScriptName, size: 12) != nil
    }

    static func clamp(_ value: Int, to range: ClosedRange<Int>) -> Int {
        min(max(value, range.lowerBound), range.upperBound)
    }

    /// The same style with every field inside its range (for a value built by setting the properties directly).
    func clamped() -> SubtitleStyle {
        SubtitleStyle(
            font: font, bold: bold, sizeStep: sizeStep, upSteps: upSteps, rightSteps: rightSteps,
            pickedFontName: pickedFontName
        )
    }

    /// The default style has no picked font.
    var isDefault: Bool { clamped() == SubtitleStyle.default }

    /// 0.6 ... 2.0.
    var scale: Double { Double(10 + Self.clamp(sizeStep, to: Self.sizeRange)) / 10 }

    // MARK: Steps

    /// Each mutator clamps and returns whether another step in the same direction is still possible
    /// (false at the limit, and for a delta of 0), so a menu can disable its button.
    @discardableResult
    mutating func stepSize(_ delta: Int) -> Bool {
        sizeStep = Self.clampedSum(sizeStep, delta, to: Self.sizeRange)
        return delta > 0 ? canSizeUp : (delta < 0 ? canSizeDown : false)
    }

    /// A positive delta moves the line up.
    @discardableResult
    mutating func stepUp(_ delta: Int) -> Bool {
        upSteps = Self.clampedSum(upSteps, delta, to: Self.upRange)
        return delta > 0 ? canMoveUp : (delta < 0 ? canMoveDown : false)
    }

    /// A positive delta moves the line right, a negative one left.
    @discardableResult
    mutating func stepRight(_ delta: Int) -> Bool {
        rightSteps = Self.clampedSum(rightSteps, delta, to: Self.rightRange)
        return delta > 0 ? canMoveRight : (delta < 0 ? canMoveLeft : false)
    }

    /// The value clamped first, then the delta added and clamped again, so a field set to Int.max or Int.min in
    /// code (or a huge delta) can't overflow and trap.
    static func clampedSum(_ value: Int, _ delta: Int, to range: ClosedRange<Int>) -> Int {
        let base = clamp(value, to: range)
        let (sum, overflow) = base.addingReportingOverflow(delta)
        if overflow { return delta > 0 ? range.upperBound : range.lowerBound }
        return clamp(sum, to: range)
    }

    var canSizeUp: Bool { sizeStep < Self.sizeRange.upperBound }
    var canSizeDown: Bool { sizeStep > Self.sizeRange.lowerBound }
    var canMoveUp: Bool { upSteps < Self.upRange.upperBound }
    var canMoveDown: Bool { upSteps > Self.upRange.lowerBound }
    var canMoveRight: Bool { rightSteps < Self.rightRange.upperBound }
    var canMoveLeft: Bool { rightSteps > Self.rightRange.lowerBound }

    // MARK: Saved form

    /// The JSON to save. Keys are sorted so the same style always gives the same text.
    var json: String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        guard let data = try? encoder.encode(clamped()) else { return "" }
        return String(data: data, encoding: .utf8) ?? ""
    }

    /// Reads a saved value. Nothing, garbage or a non-object gives the default; a partial or out-of-range
    /// object keeps what is valid and clamps the rest.
    static func decoded(from json: String?) -> SubtitleStyle {
        guard let json, let data = json.data(using: .utf8),
              let style = try? JSONDecoder().decode(SubtitleStyle.self, from: data)
        else { return .default }
        return style
    }

    /// A style for a UI-test seed. Like `decoded(from:)`, but a picked font name that isn't installed is kept in the
    /// saved text, so a test can prove the read drops it later.
    static func seeded(from json: String?) -> SubtitleStyle {
        var style = decoded(from: json)
        if style.pickedFontName == nil, let data = json?.data(using: .utf8),
           let object = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any],
           let name = object["pickedFontName"] as? String, !name.isEmpty {
            style.pickedFontName = name
        }
        return style
    }

    /// The value after `-uiTestingSubtitleStyle` in a launch argument list, or nil.
    static func seedJSON(in arguments: [String]) -> String? {
        guard let index = arguments.firstIndex(of: "-uiTestingSubtitleStyle"), index + 1 < arguments.count else {
            return nil
        }
        return arguments[index + 1]
    }

    // MARK: Font

    /// The Japanese fallback face for the font and weight, or nil when the system cascade is used (a preset Sans,
    /// which falls back to Hiragino Sans by itself). Hiragino Maru Gothic has one weight, so Rounded ignores Bold
    /// here. A picked font always gets an explicit face: its closest preset's Hiragino face.
    var japaneseFallbackName: String? {
        if let base = pickedBaseFont(size: Self.minimumPointSize) {
            return Self.hiraginoFace(for: Self.closestPreset(of: base), bold: bold)
        }
        let preset: SubtitleFont = pickedFontName == nil ? font : .sans
        switch preset {
        case .sans: return nil
        case .rounded: return Self.hiraginoFace(for: .rounded, bold: bold)
        case .serif: return Self.hiraginoFace(for: .serif, bold: bold)
        }
    }

    /// The fixed Hiragino face Japanese falls back to for a preset: W3, or W6 with Bold; Maru Gothic has only W4.
    static func hiraginoFace(for preset: SubtitleFont, bold: Bool) -> String {
        switch preset {
        case .sans: return bold ? "HiraginoSans-W6" : "HiraginoSans-W3"
        case .rounded: return "HiraMaruProN-W4"
        case .serif: return bold ? "HiraMinProN-W6" : "HiraMinProN-W3"
        }
    }

    /// The preset a picked font is closest to, from its names and symbolic traits. Pure, and the first match wins:
    /// "Mincho" or "Serif" in a name (and no "Sans") is Serif; "Rounded" or "Maru" is Rounded; a serif family class
    /// is Serif; anything else is Sans.
    static func closestPreset(
        familyName: String, fontName: String, traits: UIFontDescriptor.SymbolicTraits
    ) -> SubtitleFont {
        let names = [familyName, fontName].map { $0.lowercased() }
        func anyName(containing word: String) -> Bool { names.contains { $0.contains(word) } }
        if (anyName(containing: "mincho") || anyName(containing: "serif")) && !anyName(containing: "sans") {
            return .serif
        }
        if anyName(containing: "rounded") || anyName(containing: "maru") { return .rounded }
        let serifClasses: [UIFontDescriptor.SymbolicTraits] = [
            .classOldStyleSerifs, .classTransitionalSerifs, .classModernSerifs,
            .classClarendonSerifs, .classSlabSerifs, .classFreeformSerifs,
        ]
        if serifClasses.contains(traits.intersection(.classMask)) { return .serif }
        return .sans
    }

    static func closestPreset(of font: UIFont) -> SubtitleFont {
        closestPreset(familyName: font.familyName, fontName: font.fontName, traits: font.fontDescriptor.symbolicTraits)
    }

    /// The picked font at a size, or nil when none is picked or it is no longer installed.
    private func pickedBaseFont(size: CGFloat) -> UIFont? {
        guard let name = pickedFontName, !name.isEmpty else { return nil }
        return UIFont(name: name, size: size)
    }

    /// The picked font's family name for display, or nil when none is picked or it is gone.
    var pickedFamilyName: String? { pickedBaseFont(size: Self.minimumPointSize)?.familyName }

    /// The family's bold face, or nil when it has none. A font that is already bold is its own bold face. There is
    /// no faux bold: without a real bold face the regular one is drawn unchanged.
    private static func boldFace(of base: UIFont, size: CGFloat) -> UIFont? {
        if base.fontDescriptor.symbolicTraits.contains(.traitBold) { return base }
        guard let descriptor = base.fontDescriptor.withSymbolicTraits(.traitBold) else { return nil }
        let face = UIFont(descriptor: descriptor, size: size)
        guard face.fontDescriptor.symbolicTraits.contains(.traitBold), face.familyName == base.familyName else {
            return nil
        }
        return face
    }

    /// True when a picked font has a real bold face. False when none is picked or the font has no bold weight.
    var pickedFontHasBold: Bool {
        guard let base = pickedBaseFont(size: Self.minimumPointSize) else { return false }
        return Self.boldFace(of: base, size: Self.minimumPointSize) != nil
    }

    /// Point size for a text style: today's Dynamic Type size x the size scale, never more than a quarter of the
    /// region height (and never below `minimumPointSize`).
    func pointSize(textStyle: UIFont.TextStyle = .title3, regionHeight: CGFloat) -> CGFloat {
        let preferred = UIFont.preferredFont(forTextStyle: textStyle).pointSize
        let scaled = UIFontMetrics(forTextStyle: textStyle).scaledValue(for: preferred)
        return Self.cappedPointSize(scaled * CGFloat(scale), regionHeight: regionHeight)
    }

    static func cappedPointSize(_ size: CGFloat, regionHeight: CGFloat) -> CGFloat {
        min(size, max(minimumPointSize, regionHeight / 4))
    }

    /// The one place a style becomes a font. Weight is bold or regular. The default style gives the system bold
    /// font, as the line used before styles existed.
    func uiFont(pointSize: CGFloat) -> UIFont {
        if let base = pickedBaseFont(size: pointSize) {
            return pickedUIFont(base: base, pointSize: pointSize)
        }
        // A picked font that is gone leaves Sans.
        let preset: SubtitleFont = pickedFontName == nil ? font : .sans
        let weight: UIFont.Weight = bold ? .bold : .regular
        let system = UIFont.systemFont(ofSize: pointSize, weight: weight)
        let design: UIFontDescriptor.SystemDesign
        switch preset {
        case .sans: return system
        case .rounded: design = .rounded
        case .serif: design = .serif
        }
        var descriptor = system.fontDescriptor.withDesign(design) ?? system.fontDescriptor
        if let fallbackName = japaneseFallbackName {
            let fallback = UIFontDescriptor(fontAttributes: [.name: fallbackName])
            descriptor = descriptor.addingAttributes([.cascadeList: [fallback]])
        }
        return UIFont(descriptor: descriptor, size: pointSize)
    }

    /// A picked font: its bold face when Bold is on and it has one (otherwise the regular face, unchanged), with a
    /// cascade to the closest preset's Hiragino face for the Japanese glyphs it lacks.
    private func pickedUIFont(base: UIFont, pointSize: CGFloat) -> UIFont {
        let face = bold ? (Self.boldFace(of: base, size: pointSize) ?? base) : base
        let fallback = UIFontDescriptor(fontAttributes: [
            .name: Self.hiraginoFace(for: Self.closestPreset(of: base), bold: bold),
        ])
        let descriptor = face.fontDescriptor.addingAttributes([.cascadeList: [fallback]])
        return UIFont(descriptor: descriptor, size: pointSize)
    }

    func uiFont(textStyle: UIFont.TextStyle = .title3, regionHeight: CGFloat) -> UIFont {
        uiFont(pointSize: pointSize(textStyle: textStyle, regionHeight: regionHeight))
    }
}
