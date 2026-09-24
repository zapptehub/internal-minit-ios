import SwiftUI

public extension LinearGradient {
    /// Full-bleed orange→cream brand background used by onboarding and Home.
    ///
    /// Tuned to the mockups: hot orange held through the header, then a long warm
    /// peach fade that reaches solid white by ~75% (so lower chrome can sit on
    /// clean white, not cream).
    static var minitBackground: LinearGradient {
        let top = DSPlatformColorExtension.backgroundGradientTop.color
        let mid = DSColor.Background.Button.primary
        let peach = DSPlatformColorExtension.backgroundGradientPeach.color
        let cream = DSPlatformColorExtension.backgroundGradientCream.color
        let page = DSColor.Background.Layer.level0
        return LinearGradient(
            stops: [
                .init(color: top, location: 0),
                .init(color: top, location: 0.12),
                .init(color: mid, location: 0.28),
                .init(color: peach, location: 0.48),
                .init(color: cream, location: 0.65),
                .init(color: page, location: 0.78),
                .init(color: page, location: 1)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }
}
