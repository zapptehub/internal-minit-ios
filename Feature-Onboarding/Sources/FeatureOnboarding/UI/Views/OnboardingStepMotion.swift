import SwiftUI
import DesignSystem

/// Step change on `OnboardingFlowScreen`. Reduce Motion shows the incoming step
/// in place (the slide's end state) instead of pushing it on from the side.
enum OnboardingStepMotion: Equatable {
    case snap
    case slideForward
    case slideBackward

    static let duration: Double = 0.32

    static func resolve(direction: OnboardingStepDirection, reduceMotion: Bool) -> Self {
        guard DSMotion.animates(reduceMotion: reduceMotion) else { return .snap }
        switch direction {
        case .forward:
            return .slideForward
        case .backward:
            return .slideBackward
        }
    }

    var animation: Animation? {
        switch self {
        case .snap:
            return nil
        case .slideForward, .slideBackward:
            return .easeInOut(duration: Self.duration)
        }
    }

    var transition: AnyTransition {
        switch self {
        case .snap:
            return .identity
        case .slideForward:
            return .asymmetric(insertion: .move(edge: .trailing), removal: .move(edge: .leading))
        case .slideBackward:
            return .asymmetric(insertion: .move(edge: .leading), removal: .move(edge: .trailing))
        }
    }
}
