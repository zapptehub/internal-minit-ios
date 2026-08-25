import CoreText
import SwiftUI

/// Central access point for the bundled "Sharp Grotesk SmBold 20" heading typeface —
/// the font behind every `FontType` heading case (Figma's `Heading/H1`/`H2`/`H3`), plus
/// any one-off heading sizes that don't have a dedicated `FontType` case yet (e.g.
/// `NotificationsScreen`'s 30pt title).
public enum DSFont {
    /// PostScript name baked into `SharpGroteskSmBold20-Regular.ttf`'s own name table
    /// (verified via `strings` on the font binary) — not something we get to choose.
    private static let headingFontName = "SharpGroteskSmBold20-Regular"

    /// `Core-DesignSystem` is an SPM resource bundle, not the app's main bundle, so the
    /// usual Info.plist `UIAppFonts` auto-load never runs for it — the font has to be
    /// registered with Core Text ourselves. A `static let` guarantees this runs exactly
    /// once per process, and completes before the first `heading(size:)` call returns
    /// (Swift evaluates it synchronously on first access).
    private static let didRegister: Bool = {
        // No `subdirectory:` — Xcode's SPM resource copy step flattens `Resources/Fonts/`
        // and places the `.ttf` at the compiled bundle's root alongside `Assets.car`, etc.
        guard let url = Bundle.module.url(forResource: headingFontName, withExtension: "ttf") else {
            assertionFailure("Missing \(headingFontName).ttf in DesignSystem resources")
            return false
        }

        var error: Unmanaged<CFError>?
        let didRegister = CTFontManagerRegisterFontsForURL(url as CFURL, .process, &error)
        if !didRegister, let error {
            assertionFailure("Failed to register \(headingFontName): \(error.takeUnretainedValue())")
        }
        return didRegister
    }()

    /// The only weight/style Sharp Type has provided so far — every heading size (H1/H2/H3
    /// in Figma, and one-off sizes like `NotificationsScreen`'s 30pt title) renders with
    /// this same "SmBold" cut rather than distinct Semibold/Bold faces per Figma, until
    /// those additional weight files are added to the project.
    public static func heading(size: CGFloat) -> Font {
        _ = didRegister
        return .custom(headingFontName, size: size)
    }
}
