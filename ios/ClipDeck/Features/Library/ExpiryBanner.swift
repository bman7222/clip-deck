import SwiftUI

/// Sunflower reminder at the top of the library: the sideloaded install is about to stop opening.
/// Dismisses with the X or a horizontal swipe (slide out; fade with Reduce Motion).
struct ExpiryBanner: View {
    let expiry: Date
    let now: Date
    let onDismiss: () -> Void

    @Environment(\.openURL) private var openURL
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var dragX: CGFloat = 0
    @State private var fade = false
    @State private var openFailed = false

    @Environment(\.dynamicTypeSize) private var typeSize
    @ScaledMetric(relativeTo: .body) private var closeGlyph: CGFloat = 16

    private var icon: some View {
        Image(systemName: "calendar.badge.exclamationmark")
            .font(.system(.title3, design: .rounded, weight: .bold))
            .foregroundStyle(Theme.ink)
            .accessibilityHidden(true)
    }

    private var closeButton: some View {
        Button(action: { dismiss(direction: 1) }) {
            Image(systemName: "xmark")
                .font(.system(size: closeGlyph, weight: .bold, design: .rounded))
                .foregroundStyle(Theme.ink)
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
        .accessibilityLabel("Dismiss until tomorrow")
        .accessibilityIdentifier("library.expiryBanner.dismiss")
    }

    private var message: some View {
        VStack(alignment: .leading, spacing: Spacing.s) {
            Text(InstallExpiry.bannerText(expiry: expiry, now: now))
                .font(.deckCallout)
                .foregroundStyle(Theme.ink)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("library.expiryBanner.text")
            Button {
                openURL(InstallExpiry.sideStoreURL) { accepted in
                    openFailed = !accepted
                }
            } label: {
                Text("Open SideStore")
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.vertical, Spacing.s)
                    .padding(.horizontal, Spacing.m)
                    .frame(minHeight: 44)
            }
            .font(.deckHeadline)
            .foregroundStyle(Theme.ink)
            .background(Theme.ink.opacity(0.12), in: RoundedRectangle(cornerRadius: Radius.chip, style: .continuous))
            .accessibilityIdentifier("library.expiryBanner.openSideStore")
            if openFailed {
                Text("SideStore isn't installed on this iPhone. Open it from the Home Screen instead.")
                    .font(.deckCaption)
                    .foregroundStyle(Theme.ink)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("library.expiryBanner.openError")
            }
        }
    }

    var body: some View {
        Group {
            if typeSize.isAccessibilitySize {
                // Icon and X share a top row so the message gets the full width.
                VStack(alignment: .leading, spacing: 0) {
                    HStack(alignment: .center) {
                        icon
                        Spacer(minLength: 0)
                        closeButton
                    }
                    message.padding(.trailing, Spacing.m)
                }
            } else {
                HStack(alignment: .top, spacing: Spacing.m) {
                    icon.padding(.top, Spacing.m)
                    message.padding(.top, Spacing.s)
                    Spacer(minLength: 0)
                    closeButton
                }
            }
        }
        .padding(.leading, Spacing.m)
        .padding(.bottom, Spacing.s)
        .background(Theme.pending, in: RoundedRectangle(cornerRadius: Radius.control, style: .continuous))
        .padding(.horizontal, Spacing.l)
        .padding(.bottom, Spacing.s)
        .offset(x: dragX)
        .opacity(fade ? 0 : 1)
        .gesture(
            DragGesture(minimumDistance: 24)
                .onChanged { value in
                    guard abs(value.translation.width) > abs(value.translation.height) else { return }
                    if !reduceMotion { dragX = value.translation.width }
                }
                .onEnded { value in
                    if abs(value.translation.width) > 80, abs(value.translation.width) > abs(value.translation.height) {
                        dismiss(direction: value.translation.width < 0 ? -1 : 1)
                    } else {
                        withAnimation(.spring(duration: 0.2)) { dragX = 0 }
                    }
                }
        )
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("library.expiryBanner")
        .accessibilityAction(named: "Dismiss until tomorrow") { dismiss(direction: 1) }
    }

    private func dismiss(direction: CGFloat) {
        withAnimation(.easeOut(duration: 0.22)) {
            if !reduceMotion { dragX = direction * 500 }
            fade = true
        } completion: {
            onDismiss()
        }
    }
}
