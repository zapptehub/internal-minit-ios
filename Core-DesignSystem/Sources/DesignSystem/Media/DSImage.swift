import SwiftUI

/// Single source of truth for every bundled (non-icon) image used in the
/// app, mirroring `DSIcon`. There is no system-symbol equivalent for
/// images, so every case maps to a bundled asset.
public enum DSImage {
    case minitLogo
    case startHero
    /// Decorative line-art illustration on the onboarding loyalty-card preview
    /// ("Rank Up" card, name/language → loyalty-decision screens).
    case minitCashPerson
    /// Placeholder avatar for the Home header profile button.
    case mockUserProfile
    /// Placeholder QR artwork for the full-screen "My loyalty card" detail view.
    case mockQrCode
    /// Full-bleed Daily Offer promo art for Notifications (text + imagery baked in).
    /// Temporary mock until a real pressable banner component lands.
    case mockBannerDailyOffer

    public var image: Image {
        switch self {
        case .minitLogo: return Image("Image/MinitLogo", bundle: .module)
        case .startHero: return Image("Image/StartHero", bundle: .module)
        case .minitCashPerson: return Image("Image/minitCashPersonImage", bundle: .module)
        case .mockUserProfile: return Image("Image/mockUserProfile", bundle: .module)
        case .mockQrCode: return Image("Image/mockQrCode", bundle: .module)
        case .mockBannerDailyOffer: return Image("Image/mockBannerDailyOffer", bundle: .module)
        }
    }
}

/// Fixed-size convenience wrapper for images used at a known display size
/// (e.g. a logo). Full-bleed backgrounds that need custom
/// `GeometryReader`-driven framing (e.g. `.startHero`) should call
/// `DSImage.startHero.image` directly instead of going through this view.
public struct DSImageView: View {
    let image: DSImage
    let size: CGSize
    public var contentMode: ContentMode

    public init(image: DSImage, size: CGSize, contentMode: ContentMode = .fit) {
        self.image = image
        self.size = size
        self.contentMode = contentMode
    }

    public var body: some View {
        image.image
            .resizable()
            .aspectRatio(contentMode: contentMode)
            .frame(width: size.width, height: size.height)
            // No-op for `.fit` (which never overflows its frame); required for `.fill`
            // so an asset whose native aspect ratio doesn't match `size` (e.g. a crop
            // like `minitCashPerson`'s 226x147 display box vs. its 197:169 source) is
            // trimmed to the requested box instead of bleeding past it.
            .clipped()
    }
}

#Preview {
    VStack {
        DSImageView(image: .minitLogo, size: CGSize(width: 105.238, height: 105.238))
        DSImageView(image: .minitCashPerson, size: CGSize(width: 120, height: 120))
    }
    .padding()
}
