import SwiftUI

/// A vertical group of mutually-exclusive full-width selectable rows — orange fill +
/// trailing checkmark when selected, translucent cream fill + empty ring when not.
///
/// Visually distinct from `DSRadioGroup` (which is leading-circle / no row fill / green
/// selected). Use this for "pick one option from a list of cards" surfaces such as
/// onboarding language and loyalty-branch choices.
public struct DSSelectableRowGroup<Value: Hashable>: View {
    public struct Option {
        public let value: Value
        public let label: String

        public init(value: Value, label: String) {
            self.value = value
            self.label = label
        }
    }

    private let options: [Option]
    private let selection: Binding<Value>
    private let isEnabled: Bool

    public init(
        options: [Option],
        selection: Binding<Value>,
        isEnabled: Bool = true
    ) {
        self.options = options
        self.selection = selection
        self.isEnabled = isEnabled
    }

    public var body: some View {
        VStack(spacing: DSConstant.small.value) {
            ForEach(options, id: \.value) { option in
                DSSelectableRow(
                    label: option.label,
                    isSelected: option.value == selection.wrappedValue,
                    isEnabled: isEnabled,
                    onTap: { selection.wrappedValue = option.value }
                )
            }
        }
    }
}

/// Single full-width selectable row. Not public — use `DSSelectableRowGroup` so mutual
/// exclusion stays owned by the group (same pattern as `DSRadio` / `DSRadioGroup`).
struct DSSelectableRow: View {
    let label: String
    let isSelected: Bool
    let isEnabled: Bool
    let onTap: () -> Void

    private static let indicatorSize = DSComponentMetric.SelectionControl.controlSize
    private static let checkmarkSize = DSComponentMetric.SelectionControl.checkmarkSize
    private static let height = DSComponentMetric.SelectableRow.height
    /// Unselected row fill — flat black scrim at 6% opacity over whatever's behind it
    /// (gradient background or otherwise).
    private static let unselectedFill = Color.black.opacity(0.06)

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: DSConstant.medium.value) {
                Text(label)
                    .typography(.uiLargeBold)
                    .foregroundColor(isSelected ? DSColor.Text.inverse : DSColor.Text.heading)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)

                ZStack {
                    if isSelected {
                        Circle()
                            .fill(DSColor.Text.inverse)
                            .overlay {
                                DSIconView(
                                    icon: .checkmark,
                                    size: Self.checkmarkSize,
                                    color: DSColor.Text.heading
                                )
                            }
                    } else {
                        Circle()
                            .strokeBorder(
                                DSColor.Text.heading.opacity(0.15),
                                lineWidth: DSBorderWidth.selectableIndicator
                            )
                    }
                }
                .frame(width: Self.indicatorSize, height: Self.indicatorSize)
            }
            .padding(.horizontal, DSConstant.large.value)
            .frame(height: Self.height)
            .background(rowBackground)
            .clipShape(Capsule(style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .opacity(isEnabled ? 1 : 0.5)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }

    @ViewBuilder
    private var rowBackground: some View {
        if isSelected {
            DSColor.Background.Button.accent
        } else {
            Self.unselectedFill
        }
    }
}

#Preview("DSSelectableRowGroup") {
    DSSelectableRowGroupPreview()
}

private enum DSSelectablePreviewOption: Hashable {
    case slovak, hungarian, english
}

private struct DSSelectableRowGroupPreview: View {
    @State private var selection: DSSelectablePreviewOption = .english

    var body: some View {
        VStack {
            DSSelectableRowGroup(
                options: [
                    .init(value: .slovak, label: "Slovak"),
                    .init(value: .hungarian, label: "Hungarian"),
                    .init(value: .english, label: "English")
                ],
                selection: $selection
            )
            .padding(DSConstant.large.value)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            LinearGradient(
                colors: [DSColor.Background.Button.primary, Color.white],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
        )
    }
}
