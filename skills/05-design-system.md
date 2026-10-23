# Design System

---

## Core principle

> Before writing any UI code, check Figma. Before building a new component, check if it already exists in the Design System.

The Design System lives in `Core-DesignSystem`. Every visual element — color, spacing, typography, component — is defined there and must be used consistently across all Feature modules.

---

## Platform and UI constraints

- **SwiftUI only** — no UIKit unless bridging a third-party component that has no SwiftUI equivalent
- **Dynamic Type** — all text must scale with the user’s preferred font size; never fix font sizes with `.font(.system(size:))`; use `.typography(FontType)` which handles scaling automatically
- **Landscape** — layouts should work in landscape; keep in mind when using fixed heights or full-width assumptions
- **Dark mode** — the project must be ready for dark mode from day one; always use `DSColor.*` semantic tokens (never raw colors); when the designer provides dark mode colors they are added to the token layer — no code changes needed
- **Contrast** — colour contrast ratios are the designer’s responsibility; implementation uses the provided tokens as-is
- **VoiceOver** — not required at project start; do not block on it, but avoid patterns that would make it impossible to add later (e.g. decorative images should use `.accessibilityHidden(true)`)

---

## Figma MCP workflow

Every Design System component file has a Figma link in its header:

```swift
// Figma: https://www.figma.com/design/xdUqsvhEqqt6Fnz4HQQwu3/T-fresh---Developer-handoff?node-id=10274-24516&m=dev
```

**Before implementing any screen or component:**
1. Extract the `node-id` from the file header comment (or ask for it)
2. Call Figma MCP with that node-id to retrieve exact specs (padding, colors, font styles, corner radii, icon names)
3. Map Figma tokens to the `DSColor`, `DSConstant`, and `FontType` equivalents
4. Only build a new component if Figma shows it and it doesn't yet exist in `Core-DesignSystem`

---

## Colors — `DSColor`

Always use semantic color tokens. Never use raw hex, `Color(red:green:blue:)`, or system `.primary`/`.secondary`.

```swift
// ✅ Correct
Text("Hello").foregroundColor(DSColor.Text.primary)
Rectangle().fill(DSColor.Background.Layer.level0)
Image("icon").tint(DSColor.Icon.primary)

// ❌ Wrong
Text("Hello").foregroundColor(.black)
Rectangle().fill(Color(hex: "#F5F5F5"))
```

### Color namespaces

```
DSColor.Text.*           primary, secondary, tertiary, active, disabled, inverse, error, success
DSColor.Background.*     Layer.level0, BottomSheet.level100/200, Button.*, Banner.*, Control.selected
DSColor.Icon.*           primary, secondary, active, disabled
DSColor.Border.*         default, active, error, success, disabled
```

The app forces light mode with `UIUserInterfaceStyle` = `Light` in `Config/minit-Info.plist`. There is no `.preferredColorScheme` at the app root. Never branch on `colorScheme` to pick colors manually.

---

## Spacing — `DSConstant`

All spacing values come from the `DSConstant` enum. Never use raw numbers.

```swift
public enum DSConstant: Int {
    case xSmall = 4
    case smallMedium = 6
    case small = 8
    case medium = 12
    case mediumLarge = 16
    case large = 24       // also defaultSidePadding
    case xLarge = 32
}
```

```swift
// ✅ Correct
.padding(.all, DSConstant.mediumLarge.value)
.padding(.horizontal, DSConstant.large.value)
.spacing(DSConstant.medium.value)

// Convenience modifiers
.defaultSidePadding()           // .padding(.horizontal, 24)

// ❌ Wrong
.padding(16)
.padding(.horizontal, 24)       // use .defaultSidePadding() instead
```

---

## Typography — `.typography(FontType)`

Never use `.font()`. Always use the `.typography()` modifier with a `FontType`.

```swift
// ✅ Correct
Text("Title").typography(.headingMediumBold)
Text("Body").typography(.paragraphRegular)
Text("Label").typography(.uiLargeBold)

// ❌ Wrong
Text("Title").font(.title)
Text("Title").font(.system(size: 20, weight: .bold))
```

### Common `FontType` values

```
.headingMediumBold      section headers
.paragraphLargeRegular  body text, descriptions
.paragraphRegular       smaller body text
.uiLargeBold            card titles, primary labels
.uiLargeRegular         secondary card content
.uiRegular              captions, footnotes
```

---

## Components — use before building

Check these components in `Core-DesignSystem/Components/` before building anything custom:

| Component | Use for |
|-----------|---------|
| `DSButton` | All interactive buttons (primary, secondary, text style) |
| `DSIconView` | All icons with consistent sizing and color |
| `DSWarningMessage` | Inline warning/info banners |
| `DSSpacer` | Vertical spacers with design-token heights |
| `DSInputField` | Text entry — `.text`, `.password`, `.date`, `.unit(suffix:)`, `.textarea(maxLength:)`, `.number` variants, all with floating label + Default/Focus/Filled/Error/Success/Disabled states |
| `DSCheckbox` | Single boolean option, tappable row (box + label) |
| `DSRadioGroup` | Mutually-exclusive option list (box + label per row); never use the internal `DSRadio` row directly |

### `DSButton` usage

```swift
DSButton(title: "Continue", type: .primary) { viewModel.continue() }
DSButton(title: "Cancel", type: .secondary) { viewModel.cancel() }
DSButton(title: "Reset Password", type: .tertiary) { viewModel.resetPassword() }
DSButton(title: "Learn more", type: .textStyle(textColor: DSColor.Text.active, typography: .uiLargeBold)) { }

// Compact height for inline use
DSButton(title: "Verify", type: .primary, heightStyle: .compact, widthStyle: .compact) { }

// Disabled state — background/text automatically switch to disabled tokens
DSButton(title: "Continue", type: .primary, isEnabled: viewModel.canContinue) { viewModel.continue() }

// Icon-only circular button — pass an icon and use widthStyle: .icon
DSButton(title: "", type: .primary, icon: .storefront, widthStyle: .icon) { viewModel.openStore() }

// Loading state — label content swaps for a tinted ProgressView; taps are ignored until it clears
DSButton(title: "Continue", type: .primary, isLoading: viewModel.isSubmitting) { viewModel.continue() }
```

`DSButtonType` values: `.primary`, `.secondary`, `.tertiary`, `.textStyle(textColor:typography:)` — all solid types render white text (`DSColor.Text.onColorButton`) and always render as a pill (`Capsule()`), regardless of height.

### `DSInputField` usage

```swift
DSInputField(label: "Email", text: $viewModel.email)

DSInputField(label: "Password", text: $viewModel.password, type: .password)

DSInputField(
    label: "Date of birth",
    text: $viewModel.dateOfBirth,
    type: .date,
    onCalendarTap: { viewModel.presentDatePicker() }
)

DSInputField(label: "Weight", text: $viewModel.weight, type: .unit(suffix: "kg"))

DSInputField(label: "Notes", text: $viewModel.notes, type: .textarea(maxLength: 200))

// `label` is optional — `.number` boxes composed into something like `DSOTPField` typically
// skip it (or pass a per-box accessibility label) rather than showing a floating label.
DSInputField(text: $viewModel.digit, type: .number)

// Validation state + helper text — colors resolve automatically, never hardcode them
DSInputField(
    label: "Email",
    text: $viewModel.email,
    description: viewModel.emailError,
    validationState: viewModel.emailError == nil ? .none : .error
)

DSInputField(label: "Email", text: $viewModel.email, isEnabled: false)
```

Binding is always `String` for every type, including `.date`/`.number` — the component owns appearance only; formatting/parsing (e.g. `Date` → `"DD/MM/YYYY"`, clamping digits) is the caller's responsibility.

### `DSCheckbox` / `DSRadioGroup` usage

```swift
DSCheckbox(label: "I agree to the terms", isChecked: $viewModel.acceptedTerms)
DSCheckbox(label: "Required", isChecked: $viewModel.acceptedTerms, hasError: !viewModel.acceptedTerms && viewModel.didSubmit)

DSRadioGroup(
    options: [
        .init(value: PaymentMethod.card, label: "Card"),
        .init(value: PaymentMethod.invoice, label: "Invoice")
    ],
    selection: $viewModel.paymentMethod
)
```

`DSRadioGroup`'s "Success" column in Figma means selected, not "passed validation" — pass `hasError: Bool` for the red-border state, not a validation enum.

---

## DRY rule for UI

> A visual pattern that appears in **2 or more** Feature modules must be extracted to `Core-DesignSystem`.

Examples:
- `ErrorAlertModifier` — currently duplicated per feature; candidate for `Core-DesignSystem/Components/Alerts/`
- A custom section header used in both two features → extract to DS

When extracting:
1. Create the component in `Core-DesignSystem/Sources/DesignSystem/Components/<Category>/`
2. Add a Figma link in the file header if the component exists in Figma
3. Add a `#Preview` block showing all variants
4. Remove the duplicated code from each Feature module

---

## Single responsibility for DS components

Each Design System component owns **only its visual appearance**. Business logic, data fetching, and navigation belong in the ViewModel or View, not in the component.

```swift
// ✅ Component owns appearance only
TiaCard(
    title: item.title,
    details: item.labels,
    rightIcon: .next,
    action: { onItemTap(item) }     // callback passed in from View
)

// ❌ Component shouldn't own logic
struct SupportItemCard: View {
    let item: SupportItem
    @EnvironmentObject var viewModel: SupportViewModel   // don't do this

    var body: some View {
        DSButton(title: item.title) { viewModel.handleTap(item) }
    }
}
```

---

## Theming and dark mode

- The app forces light mode with `UIUserInterfaceStyle` = `Light` in `Config/minit-Info.plist`
- There is no `.preferredColorScheme` at the app root
- Never conditionally pick colors based on `@Environment(\.colorScheme)`
- Screens must respect safe areas by default — use SwiftUI's built-in safe area handling (`.safeAreaInset`, `ignoresSafeArea` only where intentional). Never add manual bottom padding to compensate for safe area.

---

## Checklist before submitting UI code

- [ ] SwiftUI only — no UIKit unless unavoidable
- [ ] All colors use `DSColor.*` tokens
- [ ] All spacing uses `DSConstant.*` values
- [ ] All text uses `.typography(FontType)` modifier (scales with Dynamic Type)
- [ ] Layout tested in landscape
- [ ] Figma has been consulted for the component/screen
- [ ] No new custom component that duplicates an existing DS component
- [ ] Repeated pattern extracted to DS if it appears ≥2 times
- [ ] `#Preview` added for any new DS component showing all variants
- [ ] Decorative images marked `.accessibilityHidden(true)`
