import DesignSystem
import SwiftUI

struct MapScreen: View {
    var body: some View {
        VStack(spacing: DSConstant.medium.value) {
            Spacer()
            Text("Map")
                .typography(.headingMediumBold)
                .foregroundColor(DSColor.Text.heading)
            Text("This screen is under construction. Check back soon!")
                .typography(.paragraphRegular)
                .foregroundColor(DSColor.Text.secondary)
                .multilineTextAlignment(.center)
            Spacer()
        }
        .padding(DSConstant.xxLarge.value)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(DSColor.Background.Layer.level0.ignoresSafeArea())
    }
}
