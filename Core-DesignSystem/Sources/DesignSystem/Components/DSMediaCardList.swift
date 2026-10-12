import SwiftUI

/// Bold section title + trailing "see all" chevron, followed by a horizontally scrollable
/// row of photo cards — an image on top, a bold title in a plain surface below. Generic
/// enough for any "photo + title" row (news, recipes, articles, etc.) — callers own the
/// image and title.
///
/// Tapping the chevron or any card shows the shared under-construction alert, same
/// placeholder pattern `DSCircleItemList`/`DSChallengesCardList` use — there's no real
/// "see all"/card-tap destination wired up yet. Pass `onItemTap` and `onSeeAllTap`
/// together when the caller presents that alert itself; leaving both `nil` keeps it here.
public struct DSMediaCardList: View {
    /// One card slot: a photo and its title. Not `Hashable` — nothing here requires it
    /// (`ForEach` only needs `Identifiable`), same rationale as `DSCircleItemList.Item`.
    public struct Item: Identifiable {
        public let id: Int
        public let image: DSImage
        public let title: String

        public init(id: Int, image: DSImage, title: String) {
            self.id = id
            self.image = image
            self.title = title
        }
    }

    let title: String
    let items: [Item]
    /// When set, a card tap calls this instead of the built-in alert.
    let onItemTap: (() -> Void)?
    /// When set, the see-all chevron calls this instead of the built-in alert.
    let onSeeAllTap: (() -> Void)?

    @State private var showsUnderConstructionAlert = false

    /// Figma "Recept News" Article (6154:2043): 280 wide, and 4 + 160 + 16 + two title lines
    /// (cap + 18) + 16 + 4 = 228 tall (was 230). The height is a minimum: at a large Dynamic
    /// Type size the title grows and the card grows with it instead of clipping it.
    static let cardSize = CGSize(width: 280, height: 228)
    static let imageHeight: CGFloat = 160
    /// Figma Article corner radius 16 (was the shared 20pt `DSRadius.card`, which stays 20
    /// for every other card).
    static let cornerRadius = DSPrimitiveScale.step400.value
    /// Gap between the card's own edge and the photo — the photo floats inset inside
    /// the card on all sides, it isn't clipped flush to the card's top corners.
    static let imageMargin: CGFloat = DSConstant.xSmall.value
    /// Photo bottom to the title's cap height: Figma Content padding 16 (was 14 to the
    /// untrimmed text box).
    static let imageToTitleSpacing: CGFloat = DSPrimitiveScale.step400.value
    /// Figma Image corner radius 12 (was 16).
    static let imageCornerRadius: CGFloat = DSPrimitiveScale.step300.value
    /// Card edge to the title: Article padding 4 + Content padding 16.
    static let titleHorizontalPadding: CGFloat = DSConstant.xSmall.value + DSPrimitiveScale.step400.value
    /// Title's last baseline to the card bottom: Content 16 + Article 4 (was 16 below the
    /// untrimmed text box). Descenders of the last line paint into it.
    static let titleFollowingGap: CGFloat = DSPrimitiveScale.step400.value + DSConstant.xSmall.value
    /// Figma "Heading/H4": Sharp Grotesk SmBold 20, 14pt, line height 18, `#331A00`, trimmed
    /// to cap height and last baseline (was SF 15 bold `paragraphBold`, untrimmed).
    static let titleStyle = FontType.headingH4
    static let titlePointSize: CGFloat = 14
    static let titleLineHeight: CGFloat = 18
    /// `.lineSpacing` that turns the 14pt line box into Figma's 18pt line height.
    static let titleLineSpacing: CGFloat = titleLineHeight - titlePointSize
    /// Figma Articles gap 8 (was 12).
    static let itemSpacing: CGFloat = DSConstant.small.value
    /// Figma section: 24pt title row, 12 to the cards.
    static let headerSpacing: CGFloat = DSConstant.medium.value

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
        if onItemTap == nil || onSeeAllTap == nil {
            listColumn.featureUnderConstructionAlert(isPresented: $showsUnderConstructionAlert)
        } else {
            listColumn
        }
    }

    private var listColumn: some View {
        VStack(alignment: .leading, spacing: Self.headerSpacing) {
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
                    card(item)
                }
            }
            .padding(.horizontal, DSCollectionHeader.horizontalInset)
        }
    }

    private func card(_ item: Item) -> some View {
        DSMediaCard(item: item)
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
}

/// One News & Recipes card: inset photo on top, cap-trimmed Sharp Grotesk title below.
/// Split out of `DSMediaCardList` so its layout can be measured in tests.
struct DSMediaCard: View {
    let item: DSMediaCardList.Item

    /// `Font.custom(_:size:)` scales with the body text style, so the extra leading scales
    /// the same way: baseline-to-baseline stays 18/14 of the size.
    @ScaledMetric(relativeTo: .body) private var titleLineSpacing = DSMediaCardList.titleLineSpacing
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            DSImageView(
                image: item.image,
                size: CGSize(
                    width: DSMediaCardList.cardSize.width - DSMediaCardList.imageMargin * 2,
                    height: DSMediaCardList.imageHeight
                ),
                contentMode: .fill,
                // Crops the top/bottom overflow rather than splitting it evenly, so
                // a subject near the top of a portrait-ish photo (e.g. a face) survives
                // the crop instead of getting cut along with the bottom.
                alignment: .top
            )
            .clipShape(RoundedRectangle(cornerRadius: DSMediaCardList.imageCornerRadius, style: .continuous))
            .padding(.top, DSMediaCardList.imageMargin)
            .padding(.horizontal, DSMediaCardList.imageMargin)
            .padding(.bottom, DSMediaCardList.imageToTitleSpacing)

            SharpGroteskCapTrim(followingGap: DSMediaCardList.titleFollowingGap) {
                Text(item.title)
                    .typography(DSMediaCardList.titleStyle)
                    .lineSpacing(titleLineSpacing)
                    .foregroundColor(DSColor.Text.heading)
                    .lineLimit(dynamicTypeSize > .large ? nil : 2)
                    .multilineTextAlignment(.leading)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, DSMediaCardList.titleHorizontalPadding)
            .padding(.bottom, DSMediaCardList.titleFollowingGap)
        }
        .frame(width: DSMediaCardList.cardSize.width, alignment: .topLeading)
        // A minimum, not a fixed height: a two-line title at a large Dynamic Type size
        // makes the card taller instead of being clipped.
        .frame(minHeight: DSMediaCardList.cardSize.height, alignment: .top)
        .background(DSColor.Background.Layer.level1)
        .clipShape(RoundedRectangle(cornerRadius: DSMediaCardList.cornerRadius, style: .continuous))
    }
}

#Preview("DSMediaCardList") {
    DSMediaCardList(
        title: "News & Recipes",
        items: [
            .init(
                id: 0,
                image: .mockRecipe1,
                title: "Guláš á la Kukučka s kváskovým chlebom Ďuro Truľo"
            ),
            .init(
                id: 1,
                image: .mockRecipe2,
                title: "MINIT PINSA - Kvalita, ktorá sa stretáva s dokonalou chuťou"
            )
        ]
    )
    .padding(.vertical)
    .background(Color(white: 1))
}
