import SwiftUI
import UIKit

/// Branded replacement for the system `ProgressView()` circular spinner: a filled
/// neutral-gray circle (`Background/Icon/Loading`, `#EDEDED`) with the `miniLoader`
/// glyph centered inside it, continuously rotating 360° while visible. Defaults
/// (48pt circle / 24pt glyph) match the reference screenshot exactly and mirror
/// `DSStatusCard`'s success composition (filled circle + centered glyph, just gray
/// instead of green and spinning instead of a static checkmark).
///
/// The appear/disappear-driven state toggle (rather than attaching a `repeatForever`
/// animation directly at init) is the standard SwiftUI pattern for animations that must
/// restart correctly if the view is removed and re-added to the hierarchy.
///
/// Reduce Motion holds the glyph on its resting frame instead of spinning.
///
/// The disc and the glyph are one fixed-size component. Neither measurement
/// follows Dynamic Type: both stay the caller's point sizes (48 / 24 by
/// default). Above the default content size the status card is in a scroll
/// view, and SwiftUI's repeating rotation is drawn on the title instead of
/// the disc. That size uses one UIKit view so the glyph keeps spinning around
/// the disc's centre. At `.large` the SwiftUI composition is unchanged.
public struct DSProgressView: View {
    @State private var isRotating = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    public var diameter: CGFloat
    public var iconSize: CGFloat
    public var backgroundColor: Color
    public var iconColor: Color

    /// Full rotation duration — deliberately slow/calm, not a fast "busy" spin.
    private static let rotationDuration: Double = 1.6
    public static let defaultDiameter = DSComponentMetric.Progress.diameter
    public static let defaultIconSize = DSComponentMetric.Progress.iconSize

    public init(
        diameter: CGFloat = DSProgressView.defaultDiameter,
        iconSize: CGFloat = DSProgressView.defaultIconSize,
        backgroundColor: Color = DSColor.Background.Icon.loading,
        iconColor: Color = DSColor.Icon.primary
    ) {
        self.diameter = diameter
        self.iconSize = iconSize
        self.backgroundColor = backgroundColor
        self.iconColor = iconColor
    }

    public var body: some View {
        disc
            .onAppear(perform: syncRotation)
            .onDisappear { isRotating = false }
            .onChange(of: reduceMotion) { syncRotation() }
            .accessibilityHidden(true)
    }

    @ViewBuilder
    private var disc: some View {
        if dynamicTypeSize > .large {
            FixedProgressDisc(
                iconSize: iconSize,
                backgroundColor: UIColor(backgroundColor),
                iconColor: UIColor(iconColor),
                animating: isRotating && DSMotion.animates(reduceMotion: reduceMotion),
                duration: Self.rotationDuration
            )
            .frame(width: diameter, height: diameter)
        } else {
            Circle()
                .fill(backgroundColor)
                .frame(width: diameter, height: diameter)
                .overlay {
                    DSIconView(icon: .miniLoader, size: iconSize, color: iconColor)
                        .rotationEffect(.degrees(rotationDegrees))
                        .animation(rotationAnimation, value: isRotating)
                }
        }
    }

    /// Resting frame while Reduce Motion is on, otherwise a full turn once spinning.
    private var rotationDegrees: Double {
        DSMotion.animates(reduceMotion: reduceMotion) && isRotating ? 360 : 0
    }

    private var rotationAnimation: Animation? {
        guard DSMotion.animates(reduceMotion: reduceMotion), isRotating else { return nil }
        return .linear(duration: Self.rotationDuration).repeatForever(autoreverses: false)
    }

    private func syncRotation() {
        isRotating = DSMotion.animates(reduceMotion: reduceMotion)
    }
}

/// Grey disc and `miniLoader` in one view. The glyph rotates about its own
/// centre, so a scroll view cannot draw it on a sibling title. Point sizes
/// stay the values passed in — they do not follow Dynamic Type.
private struct FixedProgressDisc: UIViewRepresentable {
    var iconSize: CGFloat
    var backgroundColor: UIColor
    var iconColor: UIColor
    var animating: Bool
    var duration: Double

    func makeUIView(context: Context) -> ProgressDiscView {
        let view = ProgressDiscView()
        view.isUserInteractionEnabled = false
        view.backgroundColor = .clear
        view.traitOverrides.preferredContentSizeCategory = .large
        return view
    }

    func updateUIView(_ uiView: ProgressDiscView, context: Context) {
        uiView.apply(
            iconSize: iconSize,
            backgroundColor: backgroundColor,
            iconColor: iconColor,
            animating: animating,
            duration: duration
        )
    }
}

private final class ProgressDiscView: UIView {
    private let disc = UIView()
    private let glyph = UIImageView()
    private var glyphWidth: NSLayoutConstraint?
    private var glyphHeight: NSLayoutConstraint?

    override init(frame: CGRect) {
        super.init(frame: frame)
        disc.translatesAutoresizingMaskIntoConstraints = false
        disc.isUserInteractionEnabled = false
        glyph.translatesAutoresizingMaskIntoConstraints = false
        glyph.contentMode = .scaleAspectFit
        glyph.adjustsImageSizeForAccessibilityContentSizeCategory = false
        glyph.isUserInteractionEnabled = false
        glyph.image = UIImage(named: "Icon/miniLoader", in: .module, compatibleWith: nil)?
            .withRenderingMode(.alwaysTemplate)
        addSubview(disc)
        addSubview(glyph)
        let width = glyph.widthAnchor.constraint(equalToConstant: 24)
        let height = glyph.heightAnchor.constraint(equalToConstant: 24)
        glyphWidth = width
        glyphHeight = height
        NSLayoutConstraint.activate([
            disc.leadingAnchor.constraint(equalTo: leadingAnchor),
            disc.trailingAnchor.constraint(equalTo: trailingAnchor),
            disc.topAnchor.constraint(equalTo: topAnchor),
            disc.bottomAnchor.constraint(equalTo: bottomAnchor),
            glyph.centerXAnchor.constraint(equalTo: centerXAnchor),
            glyph.centerYAnchor.constraint(equalTo: centerYAnchor),
            width,
            height
        ])
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        disc.layer.cornerRadius = min(disc.bounds.width, disc.bounds.height) / 2
    }

    func apply(
        iconSize: CGFloat,
        backgroundColor: UIColor,
        iconColor: UIColor,
        animating: Bool,
        duration: Double
    ) {
        disc.backgroundColor = backgroundColor
        glyph.tintColor = iconColor
        glyphWidth?.constant = iconSize
        glyphHeight?.constant = iconSize
        traitOverrides.preferredContentSizeCategory = .large
        if animating {
            guard glyph.layer.animation(forKey: "spin") == nil else { return }
            let spin = CABasicAnimation(keyPath: "transform.rotation.z")
            spin.fromValue = 0
            spin.toValue = CGFloat.pi * 2
            spin.duration = duration
            spin.repeatCount = .infinity
            spin.isRemovedOnCompletion = false
            spin.timingFunction = CAMediaTimingFunction(name: .linear)
            glyph.layer.add(spin, forKey: "spin")
        } else {
            glyph.layer.removeAnimation(forKey: "spin")
        }
    }
}

#Preview("DSProgressView") {
    VStack(spacing: DSConstant.large.value) {
        DSProgressView()
        DSProgressView(diameter: 72, iconSize: 36)
    }
    .padding()
}
