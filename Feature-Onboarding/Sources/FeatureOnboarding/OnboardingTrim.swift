import Foundation

extension CharacterSet {
    /// Characters removed from both ends of an onboarding name or manual card code.
    ///
    /// Unicode whitespace (general category Zs, Zl, or Zp, plus TAB, LF, VT, FF,
    /// and CR) and every control (Cc: U+0000–U+001F and U+007F–U+009F). Cc includes
    /// U+0085 NEXT LINE and U+001C–U+001F. Interior characters are not removed.
    static let onboardingTrim: CharacterSet = {
        var set = CharacterSet()
        for codePoint in 0...0xFFFF {
            guard let scalar = Unicode.Scalar(codePoint) else { continue }
            switch scalar.properties.generalCategory {
            case .spaceSeparator, .lineSeparator, .paragraphSeparator, .control:
                set.insert(scalar)
            default:
                break
            }
        }
        return set
    }()
}

extension String {
    /// [CharacterSet.onboardingTrim] applied with `trimmingCharacters`, so only
    /// the two ends change. A value is blank when this is empty.
    var onboardingTrimmed: String {
        trimmingCharacters(in: .onboardingTrim)
    }
}
