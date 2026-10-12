import SwiftUI

// Figma: https://www.figma.com/design/XDtLIOc3QdetbZ8h5Q7QVz/Minit---Application?node-id=2110-977

/// A single rounded-square checkbox with a trailing label. The whole row is tappable, not
/// just the box (`Button` wraps both), matching `DSCheckbox`'s proposed API in
/// `plans/ios-ds-form-components.md`.
public struct DSCheckbox: View {
    private let label: String
    private let isChecked: Binding<Bool>
    private let hasError: Bool
    private let isEnabled: Bool
    @Environment(\.locale) private var locale

    public init(
        label: String,
        isChecked: Binding<Bool>,
        hasError: Bool = false,
        isEnabled: Bool = true
    ) {
        self.label = label
        self.isChecked = isChecked
        self.hasError = hasError
        self.isEnabled = isEnabled
    }

    public var body: some View {
        let colors = DSSelectionControlColors(isEnabled: isEnabled, isSelected: isChecked.wrappedValue, hasError: hasError)

        Button {
            isChecked.wrappedValue.toggle()
        } label: {
            HStack(spacing: DSSelectionControlMetrics.labelSpacing) {
                ZStack {
                    RoundedRectangle(cornerRadius: DSSelectionControlMetrics.checkboxCornerRadius)
                        .fill(colors.fillColor ?? .clear)
                    RoundedRectangle(cornerRadius: DSSelectionControlMetrics.checkboxCornerRadius)
                        .strokeBorder(colors.borderColor, lineWidth: DSSelectionControlMetrics.borderWidth)

                    if colors.fillColor != nil {
                        DSIconView(
                            icon: .checkmark,
                            size: DSSelectionControlMetrics.checkmarkSize,
                            color: colors.indicatorColor
                        )
                    }
                }
                .frame(width: DSSelectionControlMetrics.controlSize, height: DSSelectionControlMetrics.controlSize)

                Text(label)
                    .typography(.paragraphRegular)
                    .foregroundColor(isEnabled ? DSColor.Text.secondary : DSColor.Text.disabled)
            }
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(isChecked.wrappedValue ? [.isSelected] : [])
        .dsAccessibilityHint(
            isEnabled && hasError
                ? DesignSystemA11y.text("common.a11y.selectionError", locale: locale)
                : nil
        )
    }
}

#Preview("DSCheckbox — states") {
    DSCheckboxStatesPreview()
}

/// Wrapper view so each state can hold its own `@State` binding (`#Preview` closures can't
/// declare `@State` directly).
private struct DSCheckboxStatesPreview: View {
    @State private var defaultChecked = false
    @State private var selected = true
    @State private var errorChecked = false

    var body: some View {
        VStack(alignment: .leading, spacing: DSConstant.large.value) {
            DSCheckbox(label: "Default", isChecked: $defaultChecked)
            DSCheckbox(label: "Checked", isChecked: $selected)
            DSCheckbox(label: "Error", isChecked: $errorChecked, hasError: true)
            DSCheckbox(label: "Disabled", isChecked: .constant(false), isEnabled: false)
            DSCheckbox(label: "Disabled — checked", isChecked: .constant(true), isEnabled: false)
        }
        .padding(DSConstant.large.value)
        .background(DSColor.Background.Layer.level0)
    }
}
