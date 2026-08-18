import SwiftUI

/// Bold section title + trailing "see all" chevron, followed by a horizontally scrollable
/// row of circular avatars — each optionally flagged with a small pink circular badge, with
/// a label underneath. Generic enough for any "circle + optional badge + label" row (product
/// categories, promo tags, filters, etc.) — callers own the icon/image, label, and badge copy.
///
/// Tapping the chevron or any item shows the shared under-construction alert, same
/// placeholder pattern `DSBannerCarousel` uses — there's no real "see all"/item-tap
/// destination wired up yet.
public struct DSCircleItemList: View {
    /// One circle slot: an image, its label, and optional badge copy (e.g. `"%"` for a
    /// discount, `"New"` for a highlight — `nil` hides the badge entirely). Not `Hashable` —
    /// nothing here requires it (`ForEach` only needs `Identifiable`), same rationale as
    /// `DSBannerCarousel.Item`.
    public struct Item: Identifiable {
        public let id: Int
        public let image: DSImage
        public let label: String
        public let badgeText: String?

        public init(id: Int, image: DSImage, label: String, badgeText: String? = nil) {
            self.id = id
            self.image = image
            self.label = label
            self.badgeText = badgeText
        }
    }

    let title: String
    let items: [Item]

    @State private var showsUnderConstructionAlert = false
    @Environment(\.locale) private var locale

    private static let circleDiameter: CGFloat = 64
    private static let imageSize = CGSize(width: 40, height: 40)
    private static let badgeDiameter: CGFloat = 20
    private static let seeAllButtonDiameter: CGFloat = 32
    private static let seeAllChevronSize: CGFloat = 14
    private static let itemSpacing: CGFloat = DSConstant.large.value

    public init(title: String, items: [Item]) {
        self.title = title
        self.items = items
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: DSConstant.mediumLarge.value) {
            header
            itemRow
        }
        .featureUnderConstructionAlert(isPresented: $showsUnderConstructionAlert)
    }

    private var header: some View {
        HStack {
            Text(title)
                .typography(.headingMediumBold)
                .foregroundColor(DSColor.Text.heading)
            Spacer(minLength: 0)
            seeAllButton
        }
        .padding(.horizontal, DSConstant.mediumLarge.value)
    }

    /// Decorative-only besides the tap target — like `DSBannerCarousel`'s `arrowButton`,
    /// there's no real "see all" destination yet, just the shared under-construction alert.
    private var seeAllButton: some View {
        Button {
            showsUnderConstructionAlert = true
        } label: {
            Circle()
                .fill(DSColor.Background.Layer.level1)
                .frame(width: Self.seeAllButtonDiameter, height: Self.seeAllButtonDiameter)
                .overlay {
                    DSIconView(icon: .next, size: Self.seeAllChevronSize, color: DSColor.Icon.primary)
                }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(DesignSystemLocalizedString.string("common.a11y.seeAll", locale: locale))
    }

    private var itemRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(alignment: .top, spacing: Self.itemSpacing) {
                ForEach(items) { item in
                    circleItem(item)
                }
            }
            .padding(.horizontal, DSConstant.mediumLarge.value)
        }
    }

    private func circleItem(_ item: Item) -> some View {
        VStack(spacing: DSConstant.small.value) {
            ZStack(alignment: .topTrailing) {
                Circle()
                    .fill(DSColor.Background.Layer.level1)
                    .frame(width: Self.circleDiameter, height: Self.circleDiameter)
                    .overlay {
                        DSImageView(image: item.image, size: Self.imageSize, contentMode: .fit)
                    }

                if let badgeText = item.badgeText {
                    badge(text: badgeText)
                }
            }

            Text(item.label)
                .typography(.uiRegular)
                .foregroundColor(DSColor.Text.primary)
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .frame(width: Self.circleDiameter)
        }
        .contentShape(Rectangle())
        .onTapGesture {
            showsUnderConstructionAlert = true
        }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
    }

    /// Same brand pink as `LoyaltyCard`'s rank-progress ring / `DSColor.Background.pink` —
    /// no dedicated "badge" token in Figma to copy this round.
    private func badge(text: String) -> some View {
        Circle()
            .fill(DSColor.Background.pink)
            .frame(width: Self.badgeDiameter, height: Self.badgeDiameter)
            .overlay {
                Text(text)
                    .typography(.uiSmallSemibold)
                    .foregroundColor(.white)
            }
            .accessibilityHidden(true)
    }
}

#Preview("DSCircleItemList") {
    DSCircleItemList(
        title: "Produkty",
        items: [
            .init(id: 0, image: .mockPasteryImage5, label: "Mini"),
            .init(id: 1, image: .mockPasteryImage2, label: "Chleby", badgeText: "%"),
            .init(id: 2, image: .mockPasteryImage3, label: "Pagáče"),
            .init(id: 3, image: .mockPasteryImage4, label: "Pizza", badgeText: "%"),
            .init(id: 4, image: .mockPasteryImage1, label: "Croissanty")
        ]
    )
    .padding(.vertical)
    .background(Color(white: 1))
}

#Preview("DSCircleItemList — no badges") {
    DSCircleItemList(
        title: "Produkty",
        items: [
            .init(id: 0, image: .mockPasteryImage5, label: "Mini"),
            .init(id: 1, image: .mockPasteryImage2, label: "Chleby"),
            .init(id: 2, image: .mockPasteryImage3, label: "Pagáče")
        ]
    )
    .padding(.vertical)
    .background(Color(white: 1))
}
