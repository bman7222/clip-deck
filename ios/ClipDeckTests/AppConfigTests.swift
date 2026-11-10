import Testing
@testable import ClipDeck

@MainActor
struct AppConfigTests {
    @Test func missingKeyReturnsNil() {
        #expect(AppConfig.value(for: "KEY_THAT_DOES_NOT_EXIST") == nil)
        #expect(AppConfig.url(for: "KEY_THAT_DOES_NOT_EXIST") == nil)
    }

    @Test func displayNameIsConfigured() {
        #expect(AppConfig.value(for: "CFBundleDisplayName") == "Clip Deck")
    }
}
