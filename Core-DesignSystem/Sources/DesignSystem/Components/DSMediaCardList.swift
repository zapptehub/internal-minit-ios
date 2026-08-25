import SwiftUI

/// Bold section title + trailing "see all" chevron, followed by a horizontally scrollable
/// row of photo cards — an image on top, a bold title in a plain surface below. Generic
/// enough for any "photo + title" row (news, recipes, articles, etc.) — callers own the
/// image and title.
///
/// Tapping the chevron or any card shows the shared under-construction alert, same
/// placeholder pattern `DSCircleItemList`/`DSChallengesCardList` use — there's no real
/// "see all"/card-tap destination wired up yet.
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

    @State private var showsUnderConstructionAlert = false

    private static let cardSize = CGSize(width: 280, height: 230)
    private static let imageHeight: CGFloat = 160
    private static let cornerRadius: CGFloat = DSConstant.cardCornerRadius.value
    /// Gap between the card's own edge and the photo — the photo floats inset inside
    /// the card on all sides, it isn't clipped flush to the card's top corners.
    private static let imageMargin: CGFloat = DSConstant.xSmall.value
    /// Gap between the photo's bottom edge and the title below it — spaced differently
    /// than `imageMargin`'s other 3 sides, per Figma.
    private static let imageToTitleSpacing: CGFloat = 14
    private static let imageCornerRadius: CGFloat = DSConstant.mediumLarge.value
    private static let itemSpacing: CGFloat = DSConstant.medium.value

    public init(title: String, items: [Item]) {
        self.title = title
        self.items = items
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: DSConstant.medium.value) {
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
                    card(item)
                }
            }
            .padding(.horizontal, DSConstant.mediumLarge.value)
        }
    }

    private func card(_ item: Item) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            DSImageView(
                image: item.image,
                size: CGSize(
                    width: Self.cardSize.width - Self.imageMargin * 2,
                    height: Self.imageHeight
                ),
                contentMode: .fill,
                // Crops the top/bottom overflow rather than splitting it evenly, so
                // a subject near the top of a portrait-ish photo (e.g. a face) survives
                // the crop instead of getting cut along with the bottom.
                alignment: .top
            )
            .clipShape(RoundedRectangle(cornerRadius: Self.imageCornerRadius, style: .continuous))
            .padding(.top, Self.imageMargin)
            .padding(.horizontal, Self.imageMargin)
            .padding(.bottom, Self.imageToTitleSpacing)

            Text(item.title)
                .typography(.paragraphBold)
                .foregroundColor(DSColor.Text.heading)
                .lineLimit(2)
                .multilineTextAlignment(.leading)
                .padding(.horizontal, DSConstant.mediumLarge.value + DSConstant.xSmall.value)
                .padding(.bottom, DSConstant.mediumLarge.value)

            Spacer(minLength: 0)
        }
        .frame(width: Self.cardSize.width, height: Self.cardSize.height, alignment: .top)
        .background(DSColor.Background.Layer.level1)
        .clipShape(RoundedRectangle(cornerRadius: Self.cornerRadius, style: .continuous))
        .contentShape(Rectangle())
        .onTapGesture {
            showsUnderConstructionAlert = true
        }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
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
