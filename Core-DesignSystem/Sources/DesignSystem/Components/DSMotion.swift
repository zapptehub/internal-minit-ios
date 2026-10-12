import SwiftUI

/// How motion effects honor `@Environment(\.accessibilityReduceMotion)`.
///
/// When Reduce Motion is on, the resolved animation is `nil`, so SwiftUI snaps to
/// the end state instead of interpolating. Callers that loop (the loader) should
/// also skip starting the effect and hold the resting frame.
public enum DSMotion {
    /// `true` when the effect should play. Reduce Motion snaps instead.
    public static func animates(reduceMotion: Bool) -> Bool {
        !reduceMotion
    }

    /// `animation` while motion is allowed, otherwise `nil` so the change snaps
    /// to its end state.
    public static func animation(_ animation: Animation?, reduceMotion: Bool) -> Animation? {
        animates(reduceMotion: reduceMotion) ? animation : nil
    }

    /// Page-indicator fill. Reduce Motion shows the completed fill (the countdown's
    /// end state) instead of playing the grow. The fraction is unchanged otherwise.
    static func indicatorProgress(reduceMotion: Bool, animated: Double) -> Double {
        animates(reduceMotion: reduceMotion) ? animated : 1
    }

    /// Runs `changes` inside `withAnimation`, or with animations disabled when
    /// Reduce Motion is on so the update lands on its end state.
    public static func perform(
        _ animation: Animation? = .default,
        reduceMotion: Bool,
        _ changes: () -> Void
    ) {
        if let animation = animation, animates(reduceMotion: reduceMotion) {
            withAnimation(animation, changes)
        } else {
            var transaction = Transaction(animation: nil)
            transaction.disablesAnimations = true
            withTransaction(transaction, changes)
        }
    }
}
