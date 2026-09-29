/// Color values retained from the existing product palette because the Mode 1
/// design export has no matching primitive for them.
internal enum DSPlatformColorExtension {
    static let controlSelected = DSColorToken(
        rgb: 0x12B76A,
        sourceID: "platform:legacy:control-selected"
    )
    static let iconBackgroundLoading = DSColorToken(
        rgb: 0xEDEDED,
        sourceID: "platform:legacy:icon-background-loading"
    )
    static let loyaltyButtonBorder = DSColorToken(
        rgb: 0xDFDFDF,
        sourceID: "platform:legacy:loyalty-button-border"
    )
    /// Figma loyalty-card rank subtitle `#A3A3A3`. No Mode 1 primitive matches
    /// (nearest greys are `#B3B3B3` and `#999999`).
    static let loyaltyRankSubtitle = DSColorToken(
        rgb: 0xA3A3A3,
        sourceID: "platform:figma:loyalty-rank-subtitle"
    )
    static let backgroundGradientTop = DSColorToken(
        rgb: 0xFF8300,
        sourceID: "platform:legacy:background-gradient-top"
    )
    static let backgroundGradientPeach = DSColorToken(
        rgb: 0xFFC78F,
        sourceID: "platform:legacy:background-gradient-peach"
    )
    static let backgroundGradientCream = DSColorToken(
        rgb: 0xFFF1E0,
        sourceID: "platform:legacy:background-gradient-cream"
    )
}
