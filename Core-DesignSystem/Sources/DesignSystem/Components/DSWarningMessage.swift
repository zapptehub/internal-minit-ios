import SwiftUI

public struct DSWarningMessage: View {
    let message: String

    public init(message: String) {
        self.message = message
    }

    public var body: some View {
        HStack(spacing: DSConstant.small.value) {
            DSIcon.warningTriangle.image
                .foregroundColor(DSColor.Border.error)
            Text(message)
                .typography(.paragraphRegular)
                .foregroundColor(DSColor.Text.primary)
        }
        .padding(DSConstant.medium.value)
        .background(DSColor.Background.Layer.level1)
        .cornerRadius(DSConstant.small.value)
    }
}
