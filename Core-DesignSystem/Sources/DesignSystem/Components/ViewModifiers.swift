import SwiftUI

public extension View {
    func defaultSidePadding() -> some View {
        padding(.horizontal, DSConstant.large.value)
    }

    func defaultCornerRadius() -> some View {
        cornerRadius(DSConstant.large.value)
    }
}
