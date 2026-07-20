import SwiftUI

public struct DSTagView: View {
    let text: String

    public init(text: String) {
        self.text = text
    }

    public var body: some View {
        Text(text)
            .typography(.uiRegular)
            .padding(.horizontal, DSConstant.small.value)
            .padding(.vertical, DSConstant.xSmall.value)
            .background(DSColor.Background.Layer.level1)
            .cornerRadius(DSConstant.xSmall.value)
    }
}
