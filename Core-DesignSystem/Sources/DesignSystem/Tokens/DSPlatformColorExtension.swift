/// Named colours that are not Mode 1 semantic roles: legacy values with no matching
/// primitive, and one-offs that alias a primitive without a Figma role.
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
    /// `DSButtonType.darkOrange` label. Aliases `Minit.tone600` (`#CE6900`).
    /// No semantic text role — the darkest semantic orange is `Text.accent` (tone400).
    static let darkOrangeButtonLabel = DSPrimitiveColor.Minit.tone600
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
