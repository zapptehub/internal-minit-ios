import SwiftUI

/// Bold section title + trailing "see all" chevron, followed by a horizontally scrollable
/// row of circular avatars — each optionally flagged with a small pink circular badge, with
/// a label underneath. Generic enough for any "circle + optional badge + label" row (product
/// categories, promo tags, filters, etc.) — callers own the icon/image, label, and badge copy.
///
/// Tapping the chevron or any item shows the shared under-construction alert, same
/// placeholder pattern `DSBannerCarousel` uses — there's no real "see all"/item-tap
/// destination wired up yet. Pass `onItemTap` and `onSeeAllTap` together when the
/// caller presents that alert itself; leaving both `nil` keeps the alert here.
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
    /// When set, an item tap calls this instead of the built-in alert.
    let onItemTap: (() -> Void)?
    /// When set, the see-all chevron calls this instead of the built-in alert.
    let onSeeAllTap: (() -> Void)?

    @State private var showsUnderConstructionAlert = false

    static let circleDiameter: CGFloat = 56
    private static let imageSize = CGSize(width: 49, height: 49)
    static let badgeDiameter: CGFloat = 20
    static let badgeBorderWidth: CGFloat = 3
    /// Figma (Products, node 6154:1940): the 20pt pink badge sits level with the
    /// circle's top and hangs 9.5pt past its right edge. These offsets place the
    /// badge *with* its 3pt white ring from the circle's top-trailing corner, so the
    /// pink disc lands there: right 9.5 + 3, up 0 + 3.
    static let badgeTrailingOffset: CGFloat = 9.5 + badgeBorderWidth
    static let badgeTopOffset: CGFloat = badgeBorderWidth
    /// Space above the circle row. Figma has 12pt from the 24pt title row to the
    /// circles (header center to circle top 24, same as Challenges): the VStack's
    /// `small` (8) spacing plus this 4. It is also more than `badgeTopOffset`, so the
    /// badge's white ring isn't clipped by the horizontal scroll view.
    static let rowTopInset: CGFloat = 4
    private static let itemSpacing: CGFloat = DSConstant.large.value

    public init(
        title: String,
        items: [Item],
        onItemTap: (() -> Void)? = nil,
        onSeeAllTap: (() -> Void)? = nil
    ) {
        self.title = title
        self.items = items
        self.onItemTap = onItemTap
        self.onSeeAllTap = onSeeAllTap
    }

    public var body: some View {
        list
    }

    @ViewBuilder
    private var list: some View {
        // Both callbacks together mean the caller owns the alert. One or none
        // still needs the built-in alert for whichever tap was not replaced.
        if onItemTap == nil || onSeeAllTap == nil {
            listColumn.featureUnderConstructionAlert(isPresented: $showsUnderConstructionAlert)
        } else {
            listColumn
        }
    }

    private var listColumn: some View {
        VStack(alignment: .leading, spacing: DSConstant.small.value) {
            header
            itemRow
        }
    }

    private var header: some View {
        DSCollectionHeader(title: title) {
            if let onSeeAllTap {
                onSeeAllTap()
            } else {
                showsUnderConstructionAlert = true
            }
        }
    }

    private var itemRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(alignment: .top, spacing: Self.itemSpacing) {
                ForEach(items) { item in
                    circleItem(item)
                }
            }
            .padding(.horizontal, DSCollectionHeader.horizontalInset)
            .padding(.top, Self.rowTopInset)
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
                            .offset(x: Self.badgeTrailingOffset, y: -Self.badgeTopOffset)
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
            if let onItemTap {
                onItemTap()
            } else {
                showsUnderConstructionAlert = true
            }
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
