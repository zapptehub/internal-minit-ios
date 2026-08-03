import SwiftUI

public extension LinearGradient {
    /// Full-bleed orange→cream brand background used by onboarding and Home.
    ///
    /// Tuned to the mockups: hot orange held through the header, then a long warm
    /// peach fade that reaches solid white by ~75% (so lower chrome can sit on
    /// clean white, not cream).
    static var minitBackground: LinearGradient {
        let top = Color(red: 1.0, green: 0.51, blue: 0.0) // #FF8300 — hotter than brand primary
        let mid = DSColor.Background.Button.primary // #FF9A31
        let peach = Color(red: 1.0, green: 0.78, blue: 0.56) // #FFC78F
        let cream = Color(red: 1.0, green: 0.945, blue: 0.88) // #FFF1E0
        return LinearGradient(
            stops: [
                .init(color: top, location: 0),
                .init(color: top, location: 0.12),
                .init(color: mid, location: 0.28),
                .init(color: peach, location: 0.48),
                .init(color: cream, location: 0.65),
                .init(color: .white, location: 0.78),
                .init(color: .white, location: 1)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }
}
