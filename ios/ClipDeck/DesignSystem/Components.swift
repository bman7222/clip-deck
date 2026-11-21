import SwiftUI
import UIKit

/// A glossy rounded-square tile, like an app icon on the 3DS home menu.
struct DeckTile: View {
    let glyph: String
    let hue: Color
    var size: CGFloat = 96

    var body: some View {
        RoundedRectangle(cornerRadius: Radius.tile * size / 96, style: .continuous)
            .fill(hue.gradient)
            .overlay(alignment: .top) {
                // The one bit of gloss in the app: a soft highlight across the top of each tile.
                RoundedRectangle(cornerRadius: Radius.tile * size / 96, style: .continuous)
                    .fill(LinearGradient(colors: [.white.opacity(0.45), .white.opacity(0)], startPoint: .top, endPoint: .center))
                    .padding(3)
            }
            .overlay {
                Text(glyph)
                    .font(.system(size: size * 0.46, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.18), radius: 2, y: 2)
                    .minimumScaleFactor(0.5)
                    .padding(size * 0.12)
            }
            .frame(width: size, height: size)
            .shadow(color: hue.opacity(0.35), radius: 8, y: 5)
            .accessibilityHidden(true)
    }

    /// First character of a name, for the tile's big glyph.
    static func glyph(for name: String) -> String {
        name.trimmingCharacters(in: .whitespaces).first.map { String($0).uppercased() } ?? "?"
    }
}

/// Large filled action (e.g. Make a Card, Sync).
struct DeckPrimaryButtonStyle: ButtonStyle {
    var tint: Color = Theme.accent

    func makeBody(configuration: Configuration) -> some View {
        StyledLabel(configuration: configuration, tint: tint)
    }

    private struct StyledLabel: View {
        let configuration: Configuration
        let tint: Color
        @Environment(\.isEnabled) private var isEnabled

        var body: some View {
            configuration.label
            .font(.deckHeadline)
            .foregroundStyle(.white)
            .padding(.horizontal, Spacing.l)
            .padding(.vertical, Spacing.m)
            .frame(minHeight: 48)
            .background(tint, in: RoundedRectangle(cornerRadius: Radius.control, style: .continuous))
            .saturation(isEnabled ? 1 : 0)
            .opacity(isEnabled ? 1 : 0.45)
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .animation(.spring(duration: 0.2), value: configuration.isPressed)
        }
    }
}

/// Small square icon button on a panel (player controls, toolbar).
struct DeckIconButtonStyle: ButtonStyle {
    var isActive = false

    func makeBody(configuration: Configuration) -> some View {
        StyledLabel(configuration: configuration, isActive: isActive)
    }

    /// A View so it can read the environment: a disabled button is dimmed to 0.45 (like `DeckPrimaryButtonStyle`),
    /// and the press-scale is skipped under Reduce Motion.
    private struct StyledLabel: View {
        let configuration: Configuration
        let isActive: Bool
        @Environment(\.isEnabled) private var isEnabled
        @Environment(\.accessibilityReduceMotion) private var reduceMotion

        var body: some View {
            configuration.label
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundStyle(isActive ? .white : Theme.ink)
                .frame(width: 44, height: 44)
                .background(
                    isActive ? AnyShapeStyle(Theme.accent) : AnyShapeStyle(Theme.shell),
                    in: RoundedRectangle(cornerRadius: Radius.chip, style: .continuous)
                )
                .opacity(isEnabled ? 1 : 0.45)
                .scaleEffect(configuration.isPressed && !reduceMotion ? 0.92 : 1)
                .animation(reduceMotion ? nil : .spring(duration: 0.2), value: configuration.isPressed)
        }
    }
}

/// Count bubble for "cards waiting to sync".
struct PendingBadge: View {
    let count: Int

    var body: some View {
        Text(count > 99 ? "99+" : "\(count)")
            .font(.deckCaption)
            .foregroundStyle(Theme.ink)
            .padding(.horizontal, 6)
            .frame(minWidth: 20, minHeight: 20)
            .background(Theme.pending, in: Capsule())
    }
}

/// Inline message for a problem the user can fix.
struct ErrorBanner: View {
    let message: String
    var actionTitle: String?
    var action: (() -> Void)?

    /// With an action, the message and the button are separate VoiceOver elements (inside one group that keeps the
    /// caller's identifier), so the button can be activated. Without one, the banner is a single element.
    private var hasAction: Bool { actionTitle != nil && action != nil }

    var body: some View {
        HStack(alignment: .top, spacing: Spacing.m) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(Theme.danger)
                .accessibilityHidden(hasAction)
            VStack(alignment: .leading, spacing: Spacing.s) {
                Text(message)
                    .font(.deckCallout)
                    .foregroundStyle(Theme.ink)
                    .fixedSize(horizontal: false, vertical: true)
                if let actionTitle, let action {
                    Button(actionTitle, action: action)
                        .font(.deckHeadline)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(Spacing.m)
        .background(Theme.danger.opacity(0.12), in: RoundedRectangle(cornerRadius: Radius.control, style: .continuous))
        .accessibilityElement(children: hasAction ? .contain : .combine)
    }
}

/// Short confirmation shown at the bottom of a screen.
struct Toast: View {
    let message: String

    var body: some View {
        Label(message, systemImage: "checkmark.circle.fill")
            .font(.deckCallout)
            .foregroundStyle(.white)
            .padding(.horizontal, Spacing.l)
            .padding(.vertical, Spacing.m)
            .background(Theme.ink.opacity(0.92), in: Capsule())
            .padding(.bottom, Spacing.xl)
            .accessibilityIdentifier("toast")
    }
}

/// Read-only text the user can select, so iOS "Look Up" (the built-in dictionary) works on it.
struct SelectableText: UIViewRepresentable {
    var text: String
    var textStyle: UIFont.TextStyle = .title3
    var weight: UIFont.Weight = .bold
    var color: UIColor = .label
    var outlined = false
    var alignment: NSTextAlignment = .center
    /// A ready-made font (the subtitle style's). When nil the system font at `textStyle` and `weight` is used.
    var font: UIFont?
    /// When true the view is only as wide as its text (up to the proposed width), so its frame is the frame
    /// of the visible text. Otherwise it takes the whole proposed width.
    var hugsWidth = false
    /// Set on the UITextView itself so UI tests can find it.
    var identifier: String?

    func makeUIView(context: Context) -> UITextView {
        let view = UITextView()
        view.isEditable = false
        view.isSelectable = true
        view.isScrollEnabled = false
        view.backgroundColor = .clear
        view.textContainerInset = .zero
        view.textContainer.lineFragmentPadding = 0
        view.adjustsFontForContentSizeCategory = true
        view.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        return view
    }

    private func attributedString() -> NSAttributedString {
        let resolvedFont: UIFont
        if let font {
            resolvedFont = font
        } else {
            let base = UIFont.systemFont(ofSize: UIFont.preferredFont(forTextStyle: textStyle).pointSize, weight: weight)
            resolvedFont = UIFontMetrics(forTextStyle: textStyle).scaledFont(for: base)
        }
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = alignment
        var attributes: [NSAttributedString.Key: Any] = [
            .font: resolvedFont,
            .foregroundColor: color,
            .paragraphStyle: paragraph,
        ]
        if outlined {
            // Negative stroke width = fill and stroke, so subtitles stay readable on any frame.
            attributes[.strokeColor] = UIColor.black
            attributes[.strokeWidth] = -3.0
        }
        return NSAttributedString(string: text, attributes: attributes)
    }

    func updateUIView(_ view: UITextView, context: Context) {
        view.attributedText = attributedString()
        view.accessibilityIdentifier = identifier
    }

    func sizeThatFits(_ proposal: ProposedViewSize, uiView: UITextView, context: Context) -> CGSize? {
        let proposed = proposal.width ?? 320
        var width = proposed
        if hugsWidth {
            // The widest line at the proposed width. Asking again at that width gives the same lines, so the
            // size is stable when SwiftUI proposes it back.
            let used = attributedString().boundingRect(
                with: CGSize(width: proposed, height: .greatestFiniteMagnitude),
                options: [.usesLineFragmentOrigin, .usesFontLeading],
                context: nil
            )
            width = min(proposed, ceil(used.width) + 1)
        }
        let fitted = uiView.sizeThatFits(CGSize(width: width, height: .greatestFiniteMagnitude))
        return CGSize(width: width, height: fitted.height)
    }
}
