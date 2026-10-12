import SwiftUI
import UIKit

/// Scales a string just enough that its longest word fits `width`.
///
/// `1` when every word already fits, including at the default content size.
/// Accessibility sizes can make one Sharp Grotesk word wider than the screen;
/// shrinking that face keeps the word whole and lets the rest wrap, instead of
/// drawing an ellipsis.
enum DynamicTypeWordFitting {
    static func uiFont(for type: FontType, dynamicTypeSize: DynamicTypeSize) -> UIFont {
        let traits = UITraitCollection(preferredContentSizeCategory: dynamicTypeSize.uiContentSizeCategory)
        let metrics = UIFontMetrics(forTextStyle: .body)
        let scaled = metrics.scaledValue(for: type.designPointSize, compatibleWith: traits)
        if let spec = type.systemFontSpec {
            return UIFont.systemFont(ofSize: scaled, weight: spec.weight.uiFontWeight)
        }
        _ = DSFont.heading(size: 1)
        return UIFont(name: "SharpGroteskSmBold20-Regular", size: scaled)
            ?? .systemFont(ofSize: scaled, weight: .bold)
    }

    static func scale(for text: String, font: UIFont, width: CGFloat) -> CGFloat {
        guard width > 1 else { return 1 }
        let words = text.split { $0.isWhitespace || $0.isNewline }.map(String.init)
        let samples = words.isEmpty ? [text] : words
        let longest = samples
            .map { ($0 as NSString).size(withAttributes: [.font: font]).width }
            .max() ?? 0
        guard longest > width else { return 1 }
        return width / longest
    }
}

private extension Font.Weight {
    var uiFontWeight: UIFont.Weight {
        if self == .ultraLight { return .ultraLight }
        if self == .thin { return .thin }
        if self == .light { return .light }
        if self == .medium { return .medium }
        if self == .semibold { return .semibold }
        if self == .bold { return .bold }
        if self == .heavy { return .heavy }
        if self == .black { return .black }
        return .regular
    }
}

/// A typography label that stays on `.typography(_:)` at the default content size.
///
/// Above `.large`, a word wider than the line is drawn smaller until it fits, and
/// the label keeps its wrapped height so a parent can scroll instead of clipping it.
public struct DSGrowingText: View {
    private let text: String
    private let accentText: String
    private let type: FontType
    private let color: Color
    private let accentColor: Color
    private let alignment: TextAlignment

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var width: CGFloat = 0

    public init(
        text: String,
        type: FontType,
        color: Color,
        accentText: String = "",
        accentColor: Color = .clear,
        alignment: TextAlignment = .leading
    ) {
        self.text = text
        self.accentText = accentText
        self.type = type
        self.color = color
        self.accentColor = accentColor
        self.alignment = alignment
    }

    public var body: some View {
        if dynamicTypeSize <= .large {
            styled
                .typography(type)
                .multilineTextAlignment(alignment)
        } else {
            fitted
                .multilineTextAlignment(alignment)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: frameAlignment)
                .background {
                    GeometryReader { geo in
                        Color.clear
                            .onAppear { width = geo.size.width }
                            .onChange(of: geo.size.width) { _, newValue in
                                width = newValue
                            }
                    }
                }
        }
    }

    private var frameAlignment: Alignment {
        switch alignment {
        case .center: return .center
        case .trailing: return .trailing
        default: return .leading
        }
    }

    private var measured: String { text + accentText }

    @ViewBuilder
    private var styled: some View {
        if accentText.isEmpty {
            Text(text).foregroundColor(color)
        } else {
            Text(text).foregroundColor(color) + Text(accentText).foregroundColor(accentColor)
        }
    }

    @ViewBuilder
    private var fitted: some View {
        let font = DynamicTypeWordFitting.uiFont(for: type, dynamicTypeSize: dynamicTypeSize)
        let fitScale = DynamicTypeWordFitting.scale(for: measured, font: font, width: width)
        if fitScale >= 0.999 || width <= 1 {
            styled.typography(type)
        } else if let spec = type.systemFontSpec {
            styled
                .font(.system(size: font.pointSize * fitScale, weight: spec.weight))
                .tracking(type.tracking)
        } else {
            styled
                .font(DSFont.heading(size: type.designPointSize * fitScale))
                .tracking(type.tracking)
                .modifier(FittedLineBox(type: type, fitScale: fitScale))
        }
    }
}

/// Line box for a heading whose size was reduced so its longest word fits.
private struct FittedLineBox: ViewModifier {
    let type: FontType
    let fitScale: CGFloat
    @ScaledMetric private var lineSpacing: CGFloat
    @ScaledMetric private var halfLeading: CGFloat

    init(type: FontType, fitScale: CGFloat) {
        self.type = type
        self.fitScale = fitScale
        let lineBox = type.figmaLineBox
        _lineSpacing = ScaledMetric(wrappedValue: lineBox?.lineSpacing ?? 0, relativeTo: .body)
        _halfLeading = ScaledMetric(wrappedValue: lineBox?.halfLeading ?? 0, relativeTo: .body)
    }

    func body(content: Content) -> some View {
        content
            .lineSpacing(lineSpacing * fitScale)
            .padding(.vertical, halfLeading * fitScale)
    }
}

public extension View {
    /// Keeps the view's wrapped height once Dynamic Type is above the default size.
    @ViewBuilder
    func uncompressedWhenTextIsLarge() -> some View {
        modifier(UncompressedWhenTextIsLarge())
    }
}

private struct UncompressedWhenTextIsLarge: ViewModifier {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    func body(content: Content) -> some View {
        if dynamicTypeSize > .large {
            content.fixedSize(horizontal: false, vertical: true)
        } else {
            content
        }
    }
}
