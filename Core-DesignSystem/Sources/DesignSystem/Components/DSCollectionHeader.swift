import SwiftUI

/// Bold section title + trailing circular "see all" chevron button — the header row shared
/// by every horizontally scrollable collection (`DSCircleItemList`, `DSChallengesCardList`,
/// `DSMediaCardList`). Pulled out so a Figma tweak to this row (spacing, button size, colors)
/// only needs to change here instead of in every list component that repeats it.
///
/// Internal, not `public` — it's an implementation detail of the DS's own list components,
/// not something app code composes directly.
struct DSCollectionHeader: View {
    let title: String
    /// Called for taps on the chevron button. Callers pass their own alert/navigation
    /// trigger — there's no real "see all" destination wired up in any list component yet.
    let onSeeAllTapped: () -> Void

    @Environment(\.locale) private var locale

    private static let seeAllButtonDiameter: CGFloat = 24
    private static let seeAllChevronSize: CGFloat = 14

    var body: some View {
        HStack {
            Text(title)
                .typography(.headingMediumBold)
                .foregroundColor(DSColor.Text.heading)
            Spacer(minLength: 0)
            seeAllButton
        }
        .padding(.horizontal, DSConstant.mediumLarge.value)
    }

    private var seeAllButton: some View {
        Button(action: onSeeAllTapped) {
            Circle()
                .fill(DSColor.Background.Layer.level1)
                .frame(width: Self.seeAllButtonDiameter, height: Self.seeAllButtonDiameter)
                .overlay {
                    DSIconView(icon: .chevronRight, size: Self.seeAllChevronSize, color: DSColor.Icon.primary)
                }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(DesignSystemLocalizedString.string("common.a11y.seeAll", locale: locale))
    }
}

#Preview("DSCollectionHeader") {
    DSCollectionHeader(title: "Section title", onSeeAllTapped: {})
        .padding(.vertical)
        .background(Color(white: 1))
}
