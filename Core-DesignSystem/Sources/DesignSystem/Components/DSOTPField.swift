import SwiftUI

/// A row of single-digit `DSInputField(type: .number)` boxes composed together to behave
/// like one verification-code field: typing a digit advances focus to the next box, and
/// deleting a digit moves focus back to the previous box. Reuses `DSInputField`'s existing
/// `.number` circle rather than introducing new visuals — see
/// `plans/ios-auth-flow-multi-step.md`.
///
/// Each box's visual state (border/value color) is driven by whether it's *filled*, not by
/// actual keyboard focus — a filled box keeps looking "focused" even after focus moves to
/// the next box, and an empty box looks like the plain default state even while it's the
/// one actually focused. See `DSInputField`'s `isFocusedOverride`.
public struct DSOTPField: View {
    private let label: String
    private let code: Binding<String>
    private let length: Int

    // Not `@FocusState`: each box now manages its own UIKit first-responder state manually
    // (see `DSInputField`'s `isFocusedBinding`/`onDeleteBackwardOnEmpty`), so `OTPFieldModel`
    // just tracks plain state driving those boxes' derived `Binding<Bool>`s rather than real
    // SwiftUI focus. The digit-parsing/auto-advance/backspace-cascade logic itself lives there
    // (not here) so it can be unit tested as a plain value type.
    @State private var model: OTPFieldModel
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    /// Same body-relative scale as `DSInputField`'s number circle, so the
    /// two-row height matches the boxes that are actually drawn.
    @ScaledMetric(relativeTo: .body) private var circleDiameter = DSInputFieldMetrics.numberCircleDiameter
    @State private var rowWidth: CGFloat = 0

    /// - Parameters:
    ///   - label: Base accessibility label for each box (e.g. "Verification code digit") —
    ///     the box's 1-based position is appended by the component. `.number`'s circle has
    ///     no room for a visible label, same precedent as `DSInputField`.
    ///   - code: The full code as a single string, kept in sync with the per-box digits.
    ///   - length: Number of digit boxes. Defaults to 4 to match the current designs.
    public init(label: String, code: Binding<String>, length: Int = 4) {
        self.label = label
        self.code = code
        self.length = length
        self._model = State(initialValue: OTPFieldModel(code: code.wrappedValue, length: length))
    }

    public var body: some View {
        Group {
            if dynamicTypeSize > .large {
                // Scaled circles no longer share one row. A second row keeps each
                // digit at its text size instead of overlapping or leaving the screen.
                // The row's own `sizeThatFits` can report a single line when its
                // width proposal is unbounded, and the second row then draws
                // through the button. The explicit height reserves both rows.
                OTPWrappingRow(spacing: DSConstant.medium.value) {
                    digitBoxes
                }
                .frame(maxWidth: .infinity)
                .frame(height: wrappedRowHeight, alignment: .top)
                .background {
                    GeometryReader { geo in
                        Color.clear.preference(key: OTPRowWidthKey.self, value: geo.size.width)
                    }
                }
                .onPreferenceChange(OTPRowWidthKey.self) { rowWidth = $0 }
            } else {
                HStack(spacing: DSConstant.medium.value) {
                    digitBoxes
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .center)
        .onAppear {
            model.focusFirstBoxIfNeeded()
        }
        // Keeps the boxes in sync if the caller resets `code` externally (e.g. clearing it
        // when the screen re-appears) — guarded so it doesn't fight the boxes' own edits.
        .onChange(of: code.wrappedValue) { _, newValue in
            model.syncExternalCode(newValue)
        }
    }

    /// One row when four circles fit the measured width, otherwise two.
    private var wrappedRowHeight: CGFloat {
        let spacing = DSConstant.medium.value
        let oneRow = circleDiameter * CGFloat(length) + spacing * CGFloat(max(0, length - 1))
        let available = rowWidth > 1 ? rowWidth : 320
        if oneRow <= available + 0.5 {
            return circleDiameter
        }
        return circleDiameter * 2 + spacing
    }

    private var digitBoxes: some View {
        ForEach(0..<length, id: \.self) { index in
            DSInputField(
                label: "\(label) \(index + 1)",
                text: digitBinding(at: index),
                type: .number,
                // A filled box should look "focused" even after keyboard focus moves
                // to the next box — and an empty box should look like the plain
                // default state even while it's the one actually focused.
                isFocusedOverride: !model.digits[index].isEmpty,
                isFocusedBinding: isFocusedBinding(at: index),
                onDeleteBackwardOnEmpty: {
                    model.handleDeleteBackwardOnEmpty(at: index)
                    code.wrappedValue = model.code
                }
            )
        }
    }

    private func digitBinding(at index: Int) -> Binding<String> {
        Binding(
            get: { model.digits[index] },
            // One digit per box is already enforced at the UIKit level (see
            // `DSNumberBoxTextField`'s delegate) — this is just the plain apply path.
            set: { newValue in
                model.applyDigit(String(newValue.filter(\.isNumber).suffix(1)), at: index)
                code.wrappedValue = model.code
            }
        )
    }

    /// Derives this box's actual-keyboard-focus as a plain `Binding<Bool>` from the shared
    /// `model.focusedIndex`, for `DSInputField`'s `isFocusedBinding` (see its doc comment for
    /// why a plain binding is needed here instead of `.focused($focusedIndex, equals: index)`).
    private func isFocusedBinding(at index: Int) -> Binding<Bool> {
        Binding(
            get: { model.focusedIndex == index },
            set: { isFocused in
                if isFocused {
                    model.focusedIndex = index
                } else if model.focusedIndex == index {
                    model.focusedIndex = nil
                }
            }
        )
    }
}

private struct OTPRowWidthKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

/// One row when the circles fit; otherwise two centered rows of the same boxes.
private struct OTPWrappingRow: Layout {
    var spacing: CGFloat

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let sizes = subviews.map { $0.sizeThatFits(.unspecified) }
        let width = proposal.width ?? sizes.reduce(0) { $0 + $1.width } + spacing * CGFloat(max(0, sizes.count - 1))
        let rows = rowRanges(sizes: sizes, width: width)
        var height: CGFloat = 0
        for range in rows {
            let rowHeight = sizes[range].map(\.height).max() ?? 0
            height += rowHeight
        }
        if rows.count > 1 {
            height += spacing * CGFloat(rows.count - 1)
        }
        return CGSize(width: width, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let sizes = subviews.map { $0.sizeThatFits(.unspecified) }
        let rows = rowRanges(sizes: sizes, width: bounds.width)
        var y = bounds.minY
        for range in rows {
            let rowHeight = sizes[range].map(\.height).max() ?? 0
            let rowWidth = sizes[range].reduce(0) { $0 + $1.width } + spacing * CGFloat(max(0, range.count - 1))
            var x = bounds.minX + (bounds.width - rowWidth) / 2
            for index in range {
                let size = sizes[index]
                subviews[index].place(
                    at: CGPoint(x: x, y: y + (rowHeight - size.height) / 2),
                    proposal: ProposedViewSize(size)
                )
                x += size.width + spacing
            }
            y += rowHeight + spacing
        }
    }

    private func rowRanges(sizes: [CGSize], width: CGFloat) -> [Range<Int>] {
        guard !sizes.isEmpty else { return [] }
        let rowWidth = sizes.reduce(0) { $0 + $1.width } + spacing * CGFloat(max(0, sizes.count - 1))
        if rowWidth <= width + 0.5 {
            return [0..<sizes.count]
        }
        let midpoint = sizes.count / 2
        return [0..<midpoint, midpoint..<sizes.count]
    }
}

#Preview("DSOTPField") {
    DSOTPFieldPreview()
}

private struct DSOTPFieldPreview: View {
    @State private var code = ""

    var body: some View {
        VStack(spacing: DSConstant.large.value) {
            DSOTPField(label: "Verification code digit", code: $code)
            Text("Code: \(code)")
                .typography(.paragraphRegular)
                .foregroundColor(DSColor.Text.secondary)
        }
        .padding(DSConstant.large.value)
        .background(DSColor.Background.Layer.level0)
    }
}
