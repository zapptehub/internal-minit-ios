import SwiftUI

public struct DSCard: View {
    let title: String
    let details: [String]
    let leftIcon: DSIcon?
    let rightIcon: DSIcon?
    let tag: DSCardTag?
    let action: (() -> Void)?
    let bottomContent: AnyView?

    public init(
        title: String,
        details: [String] = [],
        leftIcon: DSIcon? = nil,
        rightIcon: DSIcon? = nil,
        tag: DSCardTag? = nil,
        action: (() -> Void)? = nil
    ) {
        self.title = title
        self.details = details
        self.leftIcon = leftIcon
        self.rightIcon = rightIcon
        self.tag = tag
        self.action = action
        self.bottomContent = nil
    }

    public init<BottomContent: View>(
        title: String,
        details: [String] = [],
        leftIcon: DSIcon? = nil,
        rightIcon: DSIcon? = nil,
        tag: DSCardTag? = nil,
        action: (() -> Void)? = nil,
        @ViewBuilder bottomContent: () -> BottomContent
    ) {
        self.title = title
        self.details = details
        self.leftIcon = leftIcon
        self.rightIcon = rightIcon
        self.tag = tag
        self.action = action
        self.bottomContent = AnyView(bottomContent())
    }

    public var body: some View {
        Button {
            action?()
        } label: {
            VStack(alignment: .leading, spacing: DSConstant.small.value) {
                HStack {
                    leftIcon?.image.resizable().frame(width: 24, height: 24)
                    Text(title).typography(.uiLargeBold)
                    Spacer()
                    rightIcon?.image.resizable().frame(width: 16, height: 16)
                }
                ForEach(details, id: \.self) { detail in
                    Text(detail).typography(.paragraphRegular).foregroundColor(DSColor.Text.secondary)
                }
                if let tag {
                    DSTagView(text: tag.text)
                }
                if let bottomContent {
                    bottomContent
                }
            }
            .padding(DSConstant.mediumLarge.value)
            .background(DSColor.Background.Layer.level1)
            .cornerRadius(DSConstant.medium.value)
        }
        .buttonStyle(.plain)
    }
}

public struct DSCardTag {
    public let text: String

    public init(text: String) {
        self.text = text
    }
}

public struct DSCardBottomExtra<Content: View>: View {
    let content: Content

    public init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: DSConstant.small.value) {
            content
        }
        .padding(.top, DSConstant.small.value)
    }
}
