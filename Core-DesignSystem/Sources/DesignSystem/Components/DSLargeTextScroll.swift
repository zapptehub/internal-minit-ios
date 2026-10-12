import SwiftUI

/// Scrolls `content` in the space left above `bottom`.
///
/// A `ScrollView` reports its content height as its ideal height. Inside a
/// stack that is taller than the screen, that ideal size centers the stack
/// and the pinned actions draw through the text. Measuring `bottom` and
/// giving the scroll view the remaining height keeps the actions on screen
/// and lets the text scroll clear of them.
public struct DSLargeTextScroll<Content: View, Bottom: View>: View {
    private let spacing: CGFloat
    private let content: Content
    private let bottom: Bottom
    @State private var bottomHeight: CGFloat = 0

    public init(
        spacing: CGFloat = 0,
        @ViewBuilder content: () -> Content,
        @ViewBuilder bottom: () -> Bottom
    ) {
        self.spacing = spacing
        self.content = content()
        self.bottom = bottom()
    }

    public var body: some View {
        GeometryReader { geo in
            let scrollHeight = max(0, geo.size.height - bottomHeight - spacing)
            VStack(spacing: spacing) {
                ScrollView {
                    content
                        .frame(maxWidth: .infinity, alignment: .topLeading)
                }
                .frame(width: geo.size.width, height: scrollHeight, alignment: .top)
                .clipped()

                bottom
                    .fixedSize(horizontal: false, vertical: true)
                    .background {
                        GeometryReader { bottomGeo in
                            Color.clear.preference(
                                key: LargeTextBottomHeightKey.self,
                                value: bottomGeo.size.height
                            )
                        }
                    }
            }
            .frame(width: geo.size.width, height: geo.size.height, alignment: .top)
        }
        .onPreferenceChange(LargeTextBottomHeightKey.self) { bottomHeight = $0 }
    }
}

private struct LargeTextBottomHeightKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}
