import SwiftUI

// Figma: https://www.figma.com/design/XDtLIOc3QdetbZ8h5Q7QVz/Minit---Application?node-id=2110-977
//
// `DSRadioGroup` is the only public entry point — a lone radio button with no group isn't a
// real use case (radios are inherently mutually-exclusive-among-siblings), so the per-row
// `DSRadio` view stays `internal`. This keeps the mutual-exclusion invariant baked into the
// API instead of leaving callers to wire up `selection` comparisons by hand and risk
// getting it wrong. See `plans/ios-ds-form-components.md` for the reasoning.

/// A vertical group of mutually-exclusive radio options.
public struct DSRadioGroup<Value: Hashable>: View {
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
    private let hasError: Bool
    private let isEnabled: Bool

    public init(
        options: [Option],
        selection: Binding<Value>,
        hasError: Bool = false,
        isEnabled: Bool = true
    ) {
        self.options = options
        self.selection = selection
        self.hasError = hasError
        self.isEnabled = isEnabled
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: DSSelectionControlMetrics.optionSpacing) {
            ForEach(options, id: \.value) { option in
                DSRadio(
                    label: option.label,
                    isSelected: option.value == selection.wrappedValue,
                    hasError: hasError,
                    isEnabled: isEnabled,
                    onTap: { selection.wrappedValue = option.value }
                )
            }
        }
    }
}

/// A single circular radio row + trailing label. Not exposed publicly — see the file-level
/// comment above for why `DSRadioGroup` is the only supported entry point.
///
/// Deliberately not generic over `Value` — a row only ever needs to know whether *it* is
/// selected, not the group's value type; `DSRadioGroup` does the `Value` comparison before
/// constructing each row.
struct DSRadio: View {
    let label: String
    let isSelected: Bool
    let hasError: Bool
    let isEnabled: Bool
    let onTap: () -> Void

    var body: some View {
        let colors = DSSelectionControlColors(isEnabled: isEnabled, isSelected: isSelected, hasError: hasError)

        Button(action: onTap) {
            HStack(spacing: DSSelectionControlMetrics.labelSpacing) {
                ZStack {
                    Circle()
                        .fill(colors.fillColor ?? .clear)
                    Circle()
                        .strokeBorder(colors.borderColor, lineWidth: DSSelectionControlMetrics.borderWidth)

                    if colors.fillColor != nil {
                        Circle()
                            .fill(colors.indicatorColor)
                            .frame(width: DSSelectionControlMetrics.radioDotSize, height: DSSelectionControlMetrics.radioDotSize)
                    }
                }
                .frame(width: DSSelectionControlMetrics.controlSize, height: DSSelectionControlMetrics.controlSize)

                Text(label)
                    .typography(.paragraphRegular)
                    .foregroundColor(colors.labelColor)
            }
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }
}

#Preview("DSRadioGroup — states") {
    DSRadioGroupStatesPreview()
}

private enum DSRadioPreviewOption: Hashable {
    case first, second, third
}

/// Wrapper view so each state can hold its own `@State` selection (`#Preview` closures
/// can't declare `@State` directly).
private struct DSRadioGroupStatesPreview: View {
    @State private var selection: DSRadioPreviewOption = .first

    var body: some View {
        let defaultOptions: [DSRadioGroup<DSRadioPreviewOption>.Option] = [
            .init(value: .first, label: "Selected"),
            .init(value: .second, label: "Unselected"),
            .init(value: .third, label: "Unselected")
        ]
        let errorOptions: [DSRadioGroup<DSRadioPreviewOption>.Option] = [
            .init(value: .first, label: "Error")
        ]
        let disabledOptions: [DSRadioGroup<DSRadioPreviewOption>.Option] = [
            .init(value: .first, label: "Disabled — selected"),
            .init(value: .second, label: "Disabled — unselected")
        ]

        VStack(alignment: .leading, spacing: DSConstant.xLarge.value) {
            DSRadioGroup(options: defaultOptions, selection: $selection)
            DSRadioGroup(options: errorOptions, selection: .constant(.first), hasError: true)
            DSRadioGroup(options: disabledOptions, selection: .constant(.first), isEnabled: false)
        }
        .padding(DSConstant.large.value)
        .background(DSColor.Background.Layer.level0)
    }
}
