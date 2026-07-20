import SwiftUI

// Figma: https://www.figma.com/design/XDtLIOc3QdetbZ8h5Q7QVz/Minit---Application?node-id=2110-977
//
// Shared styling primitives for `DSInputField` (and, loosely, the state-color logic
// reused by `DSCheckbox`/`DSRadioGroup`). Kept in its own file, separate from
// `DSInputField.swift`, because the metrics/color-resolution logic is reused across
// every input variant and is independent of any single variant's behavior.

/// Explicit validation outcome for a `DSInputField`. `.none` means "no validation result
/// yet" — visual state in that case is driven by focus and whether the binding is non-empty
/// (see `DSInputFieldColors`'s filled state).
///
/// Deliberately *not* used by `DSCheckbox`/`DSRadio`: their "Success" column in Figma means
/// checked/selected, not "passed validation" — those components take a plain `hasError: Bool`
/// instead. See `plans/ios-ds-form-components.md` for the reasoning.
public enum DSInputValidationState: Equatable {
    case none
    case error
    case success
}

/// Fixed layout constants for the bordered `DSInputField` container and its floating label.
/// Values confirmed against Figma Dev Mode ("Focus" state inspector, node `2110:977`) are
/// noted as such; everything else is still a screenshot-inferred placeholder — see the
/// "Figma parameters still needed" section of the plan.
enum DSInputFieldMetrics {
    /// Still a placeholder — Figma's radius is bound to a `border-radius/md` token whose
    /// literal px value hasn't been read yet (Dev Mode shows the token name, not its
    /// resolved value). Bumped from `DSConstant.small` (8) to `.medium` (12) per feedback
    /// that 8pt looked too small; still pending exact confirmation from the token itself.
    static let cornerRadius: CGFloat = DSConstant.medium.value
    /// Confirmed via direct feedback: border width is a constant 2pt across every state
    /// (Default/Focus/Error/Success/Disabled) — it does not thin out to 1pt at rest. Kept
    /// as a single named constant rather than per-state values now that they're all equal.
    static let borderWidth: CGFloat = 2
    /// Confirmed via Dev Mode inspector ("Padding Left/Right: 16px").
    static let horizontalPadding: CGFloat = DSConstant.mediumLarge.value
    /// NOTE: currently 16pt (`.mediumLarge`), matching `horizontalPadding` — this drifted
    /// from the originally-confirmed "Padding Top/Bottom: 12px" Dev Mode reading at some
    /// point; flagged for the next Figma pass rather than silently reverted, since it may
    /// have been an intentional visual tweak.
    static let verticalPadding: CGFloat = DSConstant.mediumLarge.value
    /// Confirmed via Dev Mode inspector ("Height: Fixed 48px") — was 52pt, corrected.
    static let fieldHeight: CGFloat = 48
    /// Confirmed via Dev Mode inspector ("Gap: 8px") — spacing between the value text and
    /// a trailing accessory (eye/calendar/suffix/counter). Not yet consumed until Phase 3
    /// implements those variants.
    static let trailingAccessorySpacing: CGFloat = DSConstant.small.value
    static let labelHorizontalInset: CGFloat = DSConstant.small.value
    /// Horizontal offset of the floating label from the container's leading edge —
    /// aligns the label's text with the content's leading padding.
    static let labelOffsetX: CGFloat = horizontalPadding - labelHorizontalInset
    /// Vertical offset that lifts the label up so it straddles the top border line.
    static let labelOffsetY: CGFloat = -DSConstant.small.value
    /// Bumped from `.xSmall` (4pt) — at 4pt the description read as glued to the field's
    /// bottom edge. Still a placeholder pending exact Figma confirmation.
    static let descriptionSpacing: CGFloat = DSConstant.small.value
    /// Placeholder — not yet confirmed via Figma. Screenshot suggests a multi-line box
    /// tall enough for a few lines of text plus the bottom-right character counter.
    static let textareaHeight: CGFloat = 120
    /// Placeholder — not yet confirmed via Figma. Screenshot suggests a small fixed circle
    /// for the `.number` variant.
    static let numberCircleDiameter: CGFloat = 44
}

/// Resolves the four state-dependent colors (border, label, value, description) plus border
/// width for a `DSInputField`, given its current flags. Centralizing this mirrors how
/// `DSButton` computes `labelColor`/`backgroundColor` from `isEnabled`/`isLoading`.
///
/// Priority when multiple flags apply: `disabled` > `error`/`success` > `focused` > `filled` >
/// default (empty).
struct DSInputFieldColors {
    let borderColor: Color
    let labelColor: Color
    let valueColor: Color
    let descriptionColor: Color
    let borderWidth: CGFloat

    init(isEnabled: Bool, isFocused: Bool, isFilled: Bool, validationState: DSInputValidationState) {
        // Confirmed directly against the Figma canvas: unlike the border/value color, the
        // "Label" text stays black across every *enabled* state (Default/Focus/Error/
        // Success) — it does not shift to red/green/grey with validation or focus. Only
        // `.disabled` fades it. Same fixed-regardless-of-state shape as `descriptionColor`
        // below (confirmed separately via Dev Mode on the description text layer: `text/body`
        // → #666666 → `Text.secondary`), just a different color.
        labelColor = isEnabled ? DSColor.Text.active : DSColor.Text.disabled
        descriptionColor = DSColor.Text.secondary
        // Confirmed: 2pt border width is constant across every state — it does not thin to
        // 1pt at rest and thicken only on focus, as originally (incorrectly) assumed.
        borderWidth = DSInputFieldMetrics.borderWidth

        guard isEnabled else {
            // Disabled fields with user-entered text keep the filled black border (e.g. the
            // read-only email on Create Account) — only empty disabled fields fade out fully.
            borderColor = isFilled ? DSColor.Text.active : DSColor.Border.disabled
            valueColor = isFilled ? DSColor.Text.primary : DSColor.Text.disabled
            return
        }

        // Confirmed directly from Figma: border and value-text use *different* shades per
        // state, not a shared color (e.g. Error border #F23A3A vs. Error text #900909 — the
        // border is the brighter/more saturated tone, the text a darker, more readable one).
        // `Border.active`/`Text.tertiary` were re-pointed to these confirmed hex values —
        // see the "Colors to add" table in the plan for the full before/after.
        switch validationState {
        case .error:
            borderColor = DSColor.Border.error
            valueColor = DSColor.Text.error
        case .success:
            borderColor = DSColor.Border.success
            valueColor = DSColor.Text.success
        case .none where isFocused:
            // Border.active = #999999, Text.secondary = #666666 — focus does NOT turn the
            // border or value text black; only `Label` stays black (handled above).
            borderColor = DSColor.Border.active
            valueColor = DSColor.Text.secondary
        case .none where isFilled:
            // Filled — user has entered text but the field is no longer focused. Black border
            // (`Text.active` / #1A1A1A) and primary value text. Placeholder alone does not
            // count as filled — `isFilled` is derived from a non-empty binding, not placeholder.
            borderColor = DSColor.Text.active
            valueColor = DSColor.Text.primary
        case .none:
            // Empty and unfocused — default resting state with placeholder-toned value text.
            borderColor = DSColor.Border.default
            valueColor = DSColor.Text.tertiary
        }
    }
}

/// The floating "notch" label that overlaps the top border of a bordered input field. Its
/// background matches the surrounding page/sheet layer so it visually cuts the border line.
struct DSFloatingLabel: View {
    let text: String
    let color: Color

    var body: some View {
        Text(text)
            .typography(.uiSmallSemibold)
            .foregroundColor(color)
            .padding(.horizontal, DSInputFieldMetrics.labelHorizontalInset)
            .background(DSColor.Background.Layer.level0)
    }
}

/// Rounded-rect bordered container shared by every non-circular `DSInputField` variant
/// (text, password, date, unit, textarea). Renders the border, the floating label overlay,
/// and the field's own content (passed in via `content`).
///
/// Fills available horizontal width and uses a fixed height, matching Figma's Dev Mode
/// spec for this component ("Width: Fill", "Height: Fixed 48px") — single-line variants
/// share this container as-is; `.textarea` overrides the height (see Phase 3).
struct DSInputBorderedContainer<Content: View>: View {
    let label: String?
    let colors: DSInputFieldColors
    var height: CGFloat = DSInputFieldMetrics.fieldHeight
    @ViewBuilder let content: () -> Content

    var body: some View {
        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: DSInputFieldMetrics.cornerRadius)
                .strokeBorder(colors.borderColor, lineWidth: colors.borderWidth)

            content()
                .padding(.horizontal, DSInputFieldMetrics.horizontalPadding)
                .padding(.vertical, DSInputFieldMetrics.verticalPadding)

            if let label {
                DSFloatingLabel(text: label, color: colors.labelColor)
                    .offset(x: DSInputFieldMetrics.labelOffsetX, y: DSInputFieldMetrics.labelOffsetY)
            }
        }
        // Figma specifies "Height: Fixed", not a minimum — using an exact height (rather
        // than `minHeight`) also lets `.textarea`'s counter pin to the bottom via a `Spacer`.
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .frame(height: height)
    }
}

/// Helper text rendered below a `DSInputField`'s bordered container.
struct DSInputDescription: View {
    let text: String
    let color: Color

    var body: some View {
        Text(text)
            .typography(.uiRegular)
            .foregroundColor(color)
    }
}

#Preview("DSInputField shared styling — state matrix") {
    let states: [(String, Bool, Bool, Bool, DSInputValidationState)] = [
        ("Default", true, false, false, .none),
        ("Focus", true, true, false, .none),
        ("Filled", true, false, true, .none),
        ("Error", true, false, false, .error),
        ("Success", true, false, false, .success),
        ("Disabled", false, false, false, .none),
        ("Disabled — filled", false, false, true, .none)
    ]

    return ScrollView {
        VStack(alignment: .leading, spacing: DSConstant.large.value) {
            ForEach(states, id: \.0) { name, isEnabled, isFocused, isFilled, validationState in
                let colors = DSInputFieldColors(
                    isEnabled: isEnabled,
                    isFocused: isFocused,
                    isFilled: isFilled,
                    validationState: validationState
                )

                VStack(alignment: .leading, spacing: DSInputFieldMetrics.descriptionSpacing) {
                    DSInputBorderedContainer(label: "Label", colors: colors) {
                        Text("Value")
                            .typography(.uiLargeRegular)
                            .foregroundColor(colors.valueColor)
                    }

                    DSInputDescription(text: "Input description — \(name)", color: colors.descriptionColor)
                }
            }
        }
        .padding(DSConstant.large.value)
    }
    .background(DSColor.Background.Layer.level0)
}
