import SwiftUI

// Figma: https://www.figma.com/design/XDtLIOc3QdetbZ8h5Q7QVz/Minit---Application?node-id=2110-977
//
// Shared styling primitives for `DSCheckbox` and `DSRadio`/`DSRadioGroup`. Both controls
// share the exact same state-color logic and metrics — only the shape (rounded square vs.
// circle) and inner indicator (checkmark vs. dot) differ — so it's centralized here rather
// than duplicated, mirroring how `DSInputFieldStyle.swift` centralizes `DSInputField`'s
// shared styling.

/// Fixed layout constants for `DSCheckbox`/`DSRadio`. All still screenshot-inferred
/// placeholders — see the "Figma parameters still needed" section of
/// `plans/ios-ds-form-components.md`; none of these have been Dev-Mode-confirmed yet.
enum DSSelectionControlMetrics {
    /// Placeholder — screenshot suggests roughly 20–24pt square/circle.
    static let controlSize: CGFloat = 20
    /// Placeholder — small rounded corners on the checkbox square.
    static let checkboxCornerRadius: CGFloat = 4
    /// Assumed to match `DSInputFieldMetrics.borderWidth` for visual consistency across
    /// every DS form control; not separately confirmed for checkbox/radio specifically.
    static let borderWidth: CGFloat = 2
    /// Gap between the control and its trailing label. Assumption, not inspected.
    static let labelSpacing: CGFloat = DSConstant.small.value
    /// Inner checkmark glyph size inside a checked `DSCheckbox`.
    static let checkmarkSize: CGFloat = 12
    /// Inner solid dot diameter inside a selected `DSRadio`.
    static let radioDotSize: CGFloat = 8
    /// Vertical gap between stacked options inside a `DSRadioGroup`.
    static let optionSpacing: CGFloat = DSConstant.medium.value
}

/// Resolves the state-dependent colors for `DSCheckbox`/`DSRadio`, given `isEnabled`,
/// `isSelected` (checked/selected), and `hasError`.
///
/// Unlike `DSInputFieldColors`, there is no `.success` validation state here — Figma's
/// "Success" column for these controls means checked/selected, not "passed validation",
/// so it's folded directly into `isSelected`. See `plans/ios-ds-form-components.md` for the
/// reasoning.
///
/// Priority when multiple flags apply: `disabled` > `error` > `selected` > default.
struct DSSelectionControlColors {
    let borderColor: Color
    /// `nil` means "unfilled" (stroke-only against the surrounding layer background) —
    /// there is no `Background.Control.default` token to fall back to.
    let fillColor: Color?
    /// Color of the inner checkmark/dot. Only rendered when `fillColor != nil`.
    let indicatorColor: Color
    let labelColor: Color

    init(isEnabled: Bool, isSelected: Bool, hasError: Bool) {
        labelColor = isEnabled ? DSColor.Text.primary : DSColor.Text.disabled
        // White checkmark/dot regardless of state — it only ever sits on the solid
        // `Background.Control.selected` green fill.
        indicatorColor = DSColor.Text.inverse

        guard isEnabled else {
            borderColor = DSColor.Border.disabled
            // Disabled+selected isn't shown in the screenshot; keep the same selected fill
            // rather than inventing a separate dimmed token, since disabling already reads
            // clearly via the faded border/label.
            fillColor = isSelected ? DSColor.Background.Control.selected : nil
            return
        }

        if hasError {
            // Screenshot only shows Error as unchecked/unselected — no checked+error combo.
            borderColor = DSColor.Border.error
            fillColor = nil
        } else if isSelected {
            borderColor = DSColor.Border.success
            fillColor = DSColor.Background.Control.selected
        } else {
            borderColor = DSColor.Border.default
            fillColor = nil
        }
    }
}

#Preview("DSSelectionControl shared styling — state matrix") {
    let states: [(String, Bool, Bool, Bool)] = [
        ("Default", true, false, false),
        ("Selected", true, true, false),
        ("Error", true, false, true),
        ("Disabled", false, false, false),
        ("Disabled — selected", false, true, false)
    ]

    return VStack(alignment: .leading, spacing: DSConstant.medium.value) {
        ForEach(states, id: \.0) { name, isEnabled, isSelected, hasError in
            let colors = DSSelectionControlColors(isEnabled: isEnabled, isSelected: isSelected, hasError: hasError)

            HStack(spacing: DSSelectionControlMetrics.labelSpacing) {
                ZStack {
                    RoundedRectangle(cornerRadius: DSSelectionControlMetrics.checkboxCornerRadius)
                        .fill(colors.fillColor ?? .clear)
                    RoundedRectangle(cornerRadius: DSSelectionControlMetrics.checkboxCornerRadius)
                        .strokeBorder(colors.borderColor, lineWidth: DSSelectionControlMetrics.borderWidth)
                    if colors.fillColor != nil {
                        DSIconView(icon: .checkmark, size: DSSelectionControlMetrics.checkmarkSize, color: colors.indicatorColor)
                    }
                }
                .frame(width: DSSelectionControlMetrics.controlSize, height: DSSelectionControlMetrics.controlSize)

                Text(name)
                    .typography(.paragraphRegular)
                    .foregroundColor(colors.labelColor)
            }
        }
    }
    .padding(DSConstant.large.value)
    .background(DSColor.Background.Layer.level0)
}
