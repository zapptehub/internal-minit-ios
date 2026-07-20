import SwiftUI
@_exported import DataAuth

public enum FeatureLogin {
    @MainActor
    public static func createScreen(
        authRepository: AuthRepository,
        analytics: LoginAnalyticsTracking,
        onLoginSuccess: @escaping (AuthData) -> Void,
        onPasswordResetCompleted: @escaping () -> Void
    ) -> some View {
        LoginFlowContainer(
            authRepository: authRepository,
            analytics: analytics,
            onLoginSuccess: onLoginSuccess,
            onPasswordResetCompleted: onPasswordResetCompleted
        )
    }

    /// Standalone success screen presented in its own sheet after `onPasswordResetCompleted`
    /// fires and the login sheet has fully dismissed — see
    /// `plans/password_changed_second_sheet_9f2e404f.plan.md`.
    @MainActor
    public static func createPasswordChangedScreen(
        analytics: LoginAnalyticsTracking,
        onBackToLogin: @escaping () -> Void
    ) -> some View {
        PasswordChangedScreen(analytics: analytics, onBackToLogin: onBackToLogin)
    }
}

/// A genuine `View` (not a static-function value) so its `@State private var viewModel`
/// keeps the SAME `LoginViewModel` instance across repeated body re-evaluations of the
/// presenting screen (e.g. keyboard show/hide triggering `ContentView.body` to re-run its
/// `.sheet(item:)` content closure). If `createScreen` constructed a fresh `LoginViewModel`
/// directly and chained `.onChange` onto the returned value every call, each re-evaluation
/// would attach the `.onChange` handlers to a brand-new, throwaway view model while
/// `LoginScreen`'s own `@State` kept silently using the original one — so mutations on the
/// live instance would never be observed. See
/// `plans/password_changed_second_sheet_9f2e404f.plan.md`.
private struct LoginFlowContainer: View {
    @State private var viewModel: LoginViewModel
    let analytics: LoginAnalyticsTracking
    let onLoginSuccess: (AuthData) -> Void
    let onPasswordResetCompleted: () -> Void

    init(
        authRepository: AuthRepository,
        analytics: LoginAnalyticsTracking,
        onLoginSuccess: @escaping (AuthData) -> Void,
        onPasswordResetCompleted: @escaping () -> Void
    ) {
        _viewModel = State(initialValue: LoginViewModel(authRepository: authRepository))
        self.analytics = analytics
        self.onLoginSuccess = onLoginSuccess
        self.onPasswordResetCompleted = onPasswordResetCompleted
    }

    var body: some View {
        LoginScreen(viewModel: viewModel, analytics: analytics)
            .onChange(of: viewModel.state) { _, newState in
                if let data = newState.authData {
                    onLoginSuccess(data)
                }
            }
            .onChange(of: viewModel.passwordResetCompleted) { _, completed in
                if completed {
                    onPasswordResetCompleted()
                }
            }
    }
}
