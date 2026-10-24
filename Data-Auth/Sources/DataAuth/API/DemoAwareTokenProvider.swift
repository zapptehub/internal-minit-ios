import CoreNetworking

/// Wraps the Firebase `TokenProvider` so an active demo session's in-memory token wins
/// over Firebase on every request — the one place `currentToken` is asked to pick
/// between the two. `DemoSessionTokenStore` is never persisted, so after a relaunch this
/// always falls through to Firebase (which itself returns `nil` when there is no
/// `currentUser` either), which is what sends a cold start back to the login screen.
public struct DemoAwareTokenProvider: TokenProvider {
    private let demoSessionStore: DemoSessionTokenStore
    private let firebaseTokenProvider: TokenProvider

    public init(demoSessionStore: DemoSessionTokenStore, firebaseTokenProvider: TokenProvider) {
        self.demoSessionStore = demoSessionStore
        self.firebaseTokenProvider = firebaseTokenProvider
    }

    public func currentToken(forceRefresh: Bool) async -> String? {
        if let demoToken = await demoSessionStore.current() {
            // The backend mints a 12h token with no refresh — a forced refresh during a
            // demo session just returns the same token rather than re-minting one.
            return demoToken
        }
        return await firebaseTokenProvider.currentToken(forceRefresh: forceRefresh)
    }
}
