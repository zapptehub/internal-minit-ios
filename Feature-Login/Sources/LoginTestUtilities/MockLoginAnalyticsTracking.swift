import FeatureLogin

public final class MockLoginAnalyticsTracking: LoginAnalyticsTracking {
    public var trackLoginAttemptCalled = false
    public var trackLoginSuccessCalled = false
    public var trackLoginFailedCalled = false
    public var trackLoginFailedReason: String?
    public var trackAppleSignInTappedCalled = false
    public var trackGoogleSignInTappedCalled = false
    public var trackForgotPasswordRequestedCalled = false
    public var trackPasswordResetCompletedCalled = false
    public var trackEmailContinueTappedCalled = false
    public var trackForgotPasswordLinkTappedCalled = false
    public var trackSignUpAttemptCalled = false
    public var trackSignUpSuccessCalled = false
    public var trackSignUpFailedCalled = false
    public var trackSignUpFailedReason: String?
    public var trackVerificationCodeResentCalled = false
    public var trackPasswordChangedBackToLoginTappedCalled = false

    public init() {}

    public func trackLoginAttempt(file: String = #fileID) { trackLoginAttemptCalled = true }
    public func trackLoginSuccess(file: String = #fileID) { trackLoginSuccessCalled = true }
    public func trackLoginFailed(reason: String, file: String = #fileID) {
        trackLoginFailedCalled = true
        trackLoginFailedReason = reason
    }
    public func trackAppleSignInTapped(file: String = #fileID) { trackAppleSignInTappedCalled = true }
    public func trackGoogleSignInTapped(file: String = #fileID) { trackGoogleSignInTappedCalled = true }
    public func trackForgotPasswordRequested(file: String = #fileID) { trackForgotPasswordRequestedCalled = true }
    public func trackPasswordResetCompleted(file: String = #fileID) { trackPasswordResetCompletedCalled = true }
    public func trackEmailContinueTapped(file: String = #fileID) { trackEmailContinueTappedCalled = true }
    public func trackForgotPasswordLinkTapped(file: String = #fileID) { trackForgotPasswordLinkTappedCalled = true }
    public func trackSignUpAttempt(file: String = #fileID) { trackSignUpAttemptCalled = true }
    public func trackSignUpSuccess(file: String = #fileID) { trackSignUpSuccessCalled = true }
    public func trackSignUpFailed(reason: String, file: String = #fileID) {
        trackSignUpFailedCalled = true
        trackSignUpFailedReason = reason
    }
    public func trackVerificationCodeResent(file: String = #fileID) { trackVerificationCodeResentCalled = true }
    public func trackPasswordChangedBackToLoginTapped(file: String = #fileID) {
        trackPasswordChangedBackToLoginTappedCalled = true
    }
}
