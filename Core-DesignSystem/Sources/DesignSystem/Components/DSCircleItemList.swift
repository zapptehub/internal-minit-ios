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
    /// One circle slot: an image, its label, and whether to show the small pink "%"
    /// discount badge. Not `Hashable` — nothing here requires it (`ForEach` only needs
    /// `Identifiable`), same rationale as `DSBannerCarousel.Item`.
    public struct Item: Identifiable {
        public let id: Int
        public let image: DSImage
        public let label: String
        public let showDiscount: Bool

        public init(id: Int, image: DSImage, label: String, showDiscount: Bool = false) {
            self.id = id
            self.image = image
            self.label = label
            self.showDiscount = showDiscount
        }
    }

    let title: String
    let items: [Item]

    @State private var showsUnderConstructionAlert = false

    private static let circleDiameter: CGFloat = 56
    private static let imageSize = CGSize(width: 49, height: 49)
    private static let badgeDiameter: CGFloat = 20
    private static let badgeBorderWidth: CGFloat = 3
    /// Extra nudge past the grey circle's corner so most of the badge hangs outside,
    /// matching Figma. Combined with centering the badge on that corner.
    private static let badgeOutsideExtra: CGFloat = 8
    /// How far the badge extends above the grey circle — used as top inset on the row
    /// so the outward-hanging badge isn't clipped by the horizontal scroll view.
    private static let badgeVisualRadius: CGFloat = (badgeDiameter / 2) + badgeBorderWidth + badgeOutsideExtra
    private static let itemSpacing: CGFloat = DSConstant.large.value

    public init(title: String, items: [Item]) {
        self.title = title
        self.items = items
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: DSConstant.small.value) {
            header
            itemRow
        }
        .featureUnderConstructionAlert(isPresented: $showsUnderConstructionAlert)
    }

    private var header: some View {
        DSCollectionHeader(title: title) {
            showsUnderConstructionAlert = true
        }
    }

    private var itemRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(alignment: .top, spacing: Self.itemSpacing) {
                ForEach(items) { item in
                    circleItem(item)
                }
            }
            .padding(.horizontal, DSConstant.mediumLarge.value)
            .padding(.top, Self.badgeVisualRadius)
        }
    }

    private func circleItem(_ item: Item) -> some View {
        VStack(spacing: DSConstant.small.value) {
            Circle()
                .fill(DSColor.Background.Layer.level1)
                .frame(width: Self.circleDiameter, height: Self.circleDiameter)
                .overlay {
                    DSImageView(image: item.image, size: Self.imageSize, contentMode: .fit)
                }
                .overlay(alignment: .topTrailing) {
                    if item.showDiscount {
                        discountBadge
                            .alignmentGuide(.trailing) { $0[HorizontalAlignment.center] }
                            .alignmentGuide(.top) { $0[VerticalAlignment.center] }
                            .offset(x: Self.badgeOutsideExtra, y: -Self.badgeOutsideExtra)
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
    private var discountBadge: some View {
        Circle()
            .fill(DSColor.Background.pink)
            .frame(width: Self.badgeDiameter, height: Self.badgeDiameter)
            .overlay {
                Text("%")
                    .typography(.uiSmallSemibold)
                    .foregroundColor(.white)
            }
            .padding(Self.badgeBorderWidth)
            .background {
                Circle().fill(Color.white)
            }
            .accessibilityHidden(true)
    }
}

#Preview("DSCircleItemList") {
    DSCircleItemList(
        title: "Produkty",
        items: [
            .init(id: 0, image: .mockPasteryImage5, label: "Chleby"),
            .init(id: 1, image: .mockPasteryImage2, label: "Chleby", showDiscount: true),
            .init(id: 2, image: .mockPasteryImage3, label: "Pagáče"),
            .init(id: 3, image: .mockPasteryImage4, label: "Pizza", showDiscount: true),
            .init(id: 4, image: .mockPasteryImage1, label: "Mini")
        ]
    )
    .padding(.vertical)
    .background(Color(white: 1))
}

#Preview("DSCircleItemList — no badges") {
    DSCircleItemList(
        title: "Produkty",
        items: [
            .init(id: 0, image: .mockPasteryImage5, label: "Chleby"),
            .init(id: 1, image: .mockPasteryImage2, label: "Chleby"),
            .init(id: 2, image: .mockPasteryImage3, label: "Pagáče")
        ]
    )
    .padding(.vertical)
    .background(Color(white: 1))
}
