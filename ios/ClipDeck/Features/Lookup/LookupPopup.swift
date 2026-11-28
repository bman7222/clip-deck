import SwiftUI
import WebKit

/// What the popup shows.
enum LookupPopupState: Equatable {
    case loading
    case entries(LookupResult)
    case noEntries(String)
    case noDictionaries
    case failed(String)

    /// An exact lookup of `text` in the installed dictionaries. Offline: the engine reads only the local store.
    static func resolve(exact text: String, with dictionaries: DictionaryManagerModel) async -> LookupPopupState {
        await dictionaries.reload()
        guard let engine = dictionaries.makeEngine() else {
            return .failed(dictionaries.errorMessage ?? "The dictionaries couldn't be opened.")
        }
        if dictionaries.dictionaries.isEmpty { return .noDictionaries }
        do {
            return try await engine.lookup(exact: text).map(LookupPopupState.entries) ?? .noEntries(text)
        } catch {
            return .failed(error.localizedDescription)
        }
    }
}

/// The dictionary popup over the player: a native top row (Use for a card when a handler is given, and ✕) over one
/// scrolling web view that shows every entry. Where it sits is the host's job (`LookupPopupPlacement`).
struct LookupPopupView: View {
    let state: LookupPopupState
    /// The spoken name of the popup.
    var label = "Dictionary"
    let onClose: () -> Void
    /// Nil hides the button; T-030b gives it one.
    var onUseForCard: (() -> Void)?

    @Environment(\.self) private var environment

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: Spacing.s) {
                Spacer(minLength: 0)
                if let onUseForCard {
                    Button("Use for a card", action: onUseForCard)
                        .font(.deckCallout)
                        .foregroundStyle(Theme.accent)
                        .frame(minHeight: 44)
                        .accessibilityIdentifier("lookup.popup.useForCard")
                }
                Button(action: onClose) { Image(systemName: "xmark") }
                    .buttonStyle(DeckIconButtonStyle())
                    .accessibilityLabel("Close dictionary")
                    .accessibilityIdentifier("lookup.popup.close")
            }
            .padding([.top, .horizontal], Spacing.xs)
            content
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.panel, in: RoundedRectangle(cornerRadius: Radius.panel, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: Radius.panel, style: .continuous).strokeBorder(Theme.inkSoft.opacity(0.3)))
        .shadow(color: .black.opacity(0.25), radius: 8, y: 2)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(label)
        .accessibilityIdentifier("lookup.popup")
        .accessibilityValue(spokenValue)
    }

    @ViewBuilder private var content: some View {
        switch state {
        case .loading:
            ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
        case .entries(let result):
            LookupWebView(html: LookupPage.html(result, palette: palette))
                .clipShape(UnevenRoundedRectangle(bottomLeadingRadius: Radius.panel, bottomTrailingRadius: Radius.panel))
        case .noEntries(let text):
            message("No entries for \(text)", detail: nil)
        case .noDictionaries:
            message("No dictionaries yet", detail: "Add one with the Dictionaries button in the Library.")
        case .failed(let reason):
            message("The lookup failed", detail: reason)
        }
    }

    private func message(_ title: String, detail: String?) -> some View {
        VStack(spacing: Spacing.xs) {
            Text(title)
                .font(.deckHeadline)
                .foregroundStyle(Theme.ink)
                .lineLimit(3)
                .accessibilityIdentifier("lookup.popup.message")
            if let detail {
                Text(detail)
                    .font(.deckCaption)
                    .foregroundStyle(Theme.inkSoft)
                    .lineLimit(4)
            }
        }
        .multilineTextAlignment(.center)
        .padding(.horizontal, Spacing.m)
        .padding(.bottom, Spacing.m)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var spokenValue: String {
        switch state {
        case .loading: "Looking up"
        case .entries(let result): LookupPage.summary(result) ?? ""
        case .noEntries(let text): "No entries for \(text)"
        case .noDictionaries: "No dictionaries yet"
        case .failed(let reason): reason
        }
    }

    private var palette: LookupPage.Palette {
        func hex(_ color: Color) -> String {
            let resolved = color.resolve(in: environment)
            func byte(_ value: Float) -> UInt32 { UInt32((min(max(value, 0), 1) * 255).rounded()) }
            return String(format: "#%02X%02X%02X", byte(resolved.red), byte(resolved.green), byte(resolved.blue))
        }
        return LookupPage.Palette(ink: hex(Theme.ink), inkSoft: hex(Theme.inkSoft), accent: hex(Theme.accent), shell: hex(Theme.shell))
    }
}

/// The popup body: one WKWebView with no way out. JavaScript is off, the data store keeps nothing, the page's
/// Content-Security-Policy allows inline styles only, and every navigation but the first inline load (about:blank) is cancelled.
struct LookupWebView: UIViewRepresentable {
    let html: String

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = .nonPersistent()
        configuration.defaultWebpagePreferences.allowsContentJavaScript = false
        let view = WKWebView(frame: .zero, configuration: configuration)
        view.navigationDelegate = context.coordinator
        view.isOpaque = false
        view.backgroundColor = .clear
        view.scrollView.backgroundColor = .clear
        view.scrollView.contentInsetAdjustmentBehavior = .never
        view.accessibilityIdentifier = "lookup.popup.web"
        return view
    }

    func updateUIView(_ view: WKWebView, context: Context) {
        guard context.coordinator.loaded != html else { return }
        context.coordinator.loaded = html
        view.loadHTMLString(html, baseURL: nil)
    }

    final class Coordinator: NSObject, WKNavigationDelegate {
        var loaded = ""

        func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction) async -> WKNavigationActionPolicy {
            navigationAction.request.url?.absoluteString == "about:blank" ? .allow : .cancel
        }
    }
}
