/// In-memory-only holder for the demo session's bearer token.
///
/// Deliberately never backed by `UserDefaults`, disk, or Keychain — a demo session must
/// not survive a process relaunch. `DemoAwareTokenProvider` reads this before falling
/// back to Firebase, so every API call made while a demo session is active carries this
/// token. The App target sets it after `POST /v1/demo/session` succeeds and clears it on
/// logout and when starting an email login (see `AppFlowViewModel`).
public actor DemoSessionTokenStore {
    private var token: String?

    public init() {}

    public func set(_ token: String?) {
        self.token = token
    }

    public func current() -> String? { token }
}
