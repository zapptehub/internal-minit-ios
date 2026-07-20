import SwiftUI

public struct DSSpacer: View {
    let height: DSConstant

    public init(_ height: DSConstant = .medium) {
        self.height = height
    }

    public var body: some View {
        Spacer().frame(height: height.value)
    }
}
