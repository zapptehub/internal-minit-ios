import Foundation

/// `en` plus optional `sk` and `hu` from a home document.
///
/// `hu` and `sk` use those copies when present. A missing translation, and any
/// other language code, uses English. The view reads this at render time.
struct HomeLocalizedText: Equatable, Sendable, Decodable {
    var en: String
    var sk: String?
    var hu: String?

    init(en: String, sk: String? = nil, hu: String? = nil) {
        self.en = en
        self.sk = sk
        self.hu = hu
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        en = try container.decode(String.self, forKey: .en)
        sk = try container.decodeIfPresent(String.self, forKey: .sk)
        hu = try container.decodeIfPresent(String.self, forKey: .hu)
    }

    func resolved(locale: Locale) -> String {
        switch HomeLanguage.code(locale) {
        case "hu": return hu ?? en
        case "sk": return sk ?? en
        default: return en
        }
    }

    private enum CodingKeys: String, CodingKey {
        case en, sk, hu
    }
}

/// Catalog copy. Firebase keeps an xcstrings key. HTTP keeps the `{en,sk,hu}` object.
enum HomeCopy: Equatable, Sendable {
    case key(String)
    case text(HomeLocalizedText)

    func resolved(locale: Locale) -> String {
        switch self {
        case .key(let key):
            return HomeLocalizedString.string(key, locale: locale)
        case .text(let text):
            return text.resolved(locale: locale)
        }
    }
}

enum HomeLanguage {
    /// Language code of the in-app locale. `hu_HU` and `sk-SK` are `hu` and `sk`.
    static func code(_ locale: Locale) -> String {
        if let code = locale.language.languageCode?.identifier, !code.isEmpty {
            return code
        }
        let identifier = locale.identifier
        if let separator = identifier.firstIndex(where: { $0 == "_" || $0 == "-" }) {
            return String(identifier[..<separator])
        }
        return identifier
    }
}

enum HomeFill: Equatable, Sendable {
    case pink, brown, green, orange

    init?(token: String?) {
        switch token {
        case "pink": self = .pink
        case "brown": self = .brown
        case "green": self = .green
        case "orange": self = .orange
        default: return nil
        }
    }
}

enum HomeRunStyle: Equatable, Sendable {
    case inverse, accent

    init?(token: String?) {
        switch token {
        case "inverse": self = .inverse
        case "accent": self = .accent
        default: return nil
        }
    }
}

struct HomeTitleRun: Equatable, Sendable {
    var text: HomeCopy
    var style: HomeRunStyle
}

enum HomeAsset: Equatable, Sendable {
    case pastry1, pastry2, pastry3, pastry4, pastry5
    case gulas, pinsa
}

enum HomeImageResolution: Equatable {
    case none
    case known(HomeAsset)
    case unknown

    static func resolve(_ key: String?) -> HomeImageResolution {
        switch key {
        case nil:
            return .none
        case "home/pastry-1.png":
            return .known(.pastry1)
        case "home/pastry-2.png":
            return .known(.pastry2)
        case "home/pastry-3.png":
            return .known(.pastry3)
        case "home/pastry-4.png":
            return .known(.pastry4)
        case "home/pastry-5.png":
            return .known(.pastry5)
        case "home/news/gulas.png":
            return .known(.gulas)
        case "home/news/pinsa.png":
            return .known(.pinsa)
        default:
            return .unknown
        }
    }
}

enum HomeIconAsset: Equatable, Sendable {
    case qrScanLine, croissant, coffeeCup, baguette, bretzel

    static func resolve(_ key: String) -> HomeIconAsset? {
        switch key {
        case "qrScanLine": return .qrScanLine
        case "croissant": return .croissant
        case "coffeeCup": return .coffeeCup
        case "minitIcBaguette": return .baguette
        case "minitIcBretzel": return .bretzel
        default: return nil
        }
    }
}

enum HomeNotificationSection: Equatable, Sendable {
    case today, history

    init?(token: String) {
        switch token {
        case "today": self = .today
        case "history": self = .history
        default: return nil
        }
    }
}
