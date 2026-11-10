import SwiftUI

/// Design tokens. See docs/DESIGN.md for the reasoning.
enum Theme {
    /// Console-grey background of every screen (the "shell").
    static let shell = Color("Shell")
    /// Raised surfaces: the player's bottom screen, sheets, rows.
    static let panel = Color("Panel")
    static let ink = Color("Ink")
    static let inkSoft = Color("InkSoft")
    /// Aqua: current subtitle, selection, primary actions.
    static let accent = Color.accentColor
    /// Sunflower: reserved for "waiting to sync".
    static let pending = Color("Pending")
    static let danger = Color("Danger")

    /// One bright hue per show tile, like the colourful icons on a 3DS home menu.
    static let tileHues: [Color] = [
        Color(red: 0.95, green: 0.40, blue: 0.37), // coral
        Color(red: 0.96, green: 0.62, blue: 0.18), // tangerine
        Color(red: 0.29, green: 0.72, blue: 0.36), // leaf
        Color(red: 0.12, green: 0.64, blue: 0.84), // aqua
        Color(red: 0.54, green: 0.39, blue: 0.82), // grape
        Color(red: 0.89, green: 0.36, blue: 0.61), // rose
    ]

    static func hue(_ index: Int) -> Color {
        let count = tileHues.count
        return tileHues[((index % count) + count) % count]
    }
}

extension Font {
    static let deckLargeTitle = Font.system(.largeTitle, design: .rounded, weight: .heavy)
    static let deckTitle = Font.system(.title2, design: .rounded, weight: .bold)
    static let deckHeadline = Font.system(.headline, design: .rounded, weight: .bold)
    static let deckBody = Font.system(.body, design: .rounded)
    static let deckCallout = Font.system(.callout, design: .rounded, weight: .medium)
    static let deckCaption = Font.system(.caption, design: .rounded, weight: .semibold)
    static let deckTime = Font.system(.caption, design: .rounded, weight: .semibold).monospacedDigit()
}

enum Spacing {
    static let xs: CGFloat = 4
    static let s: CGFloat = 8
    static let m: CGFloat = 12
    static let l: CGFloat = 16
    static let xl: CGFloat = 24
}

/// Corner radii by hierarchy: big tiles are the roundest, small controls the least.
enum Radius {
    static let tile: CGFloat = 26
    static let panel: CGFloat = 22
    static let control: CGFloat = 14
    static let chip: CGFloat = 10
}
