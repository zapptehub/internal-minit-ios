import SwiftUI

/// Coordinate space `CreateCardScreen` tests read frames in.
enum OnboardingFrameSpace {
    static let createCard = "createCardScreen"
}

enum OnboardingFrameID {
    static let header = 1
    static let bottomBar = 2
    static let statusCard = 3
}

struct OnboardingFramePreferenceKey: PreferenceKey {
    static var defaultValue: [Int: CGRect] = [:]

    static func reduce(value: inout [Int: CGRect], nextValue: () -> [Int: CGRect]) {
        value.merge(nextValue(), uniquingKeysWith: { _, new in new })
    }
}

/// Reports the modified view's frame. A clear background, so it does not change layout.
struct OnboardingFrameReader: View {
    let id: Int

    var body: some View {
        GeometryReader { geo in
            Color.clear
                .accessibilityHidden(true)
                .allowsHitTesting(false)
                .preference(
                    key: OnboardingFramePreferenceKey.self,
                    value: [id: geo.frame(in: .named(OnboardingFrameSpace.createCard))]
                )
        }
        .allowsHitTesting(false)
    }
}
