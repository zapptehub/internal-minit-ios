#if MINIT_SHAKE
import CoreLogging
import DesignSystem
import MessageUI
import Observation
import SwiftUI
import UIKit

struct ShakeReportSheet: View {
    let address: String
    /// Dismisses the UIKit sheet. Cancel drops the draft with the view.
    let onClose: () -> Void
    /// Shared with the UIKit presenter, which owns the fitted detent.
    fileprivate let fit: ReportSheetFit
    @Environment(\.locale) private var locale
    @State private var draft = ""
    @FocusState private var fieldFocused: Bool

    /// Android `ShakeReportSheet` spacing (dp as pt) and Material 3 field/button metrics.
    /// Top padding is the distance from the sheet's top edge to the title. Android's
    /// 8dp sits under a drag handle that already clears the title; the system grabber
    /// does not, so the title needs about 30pt.
    private enum Metrics {
        static let sidePadding: CGFloat = 24
        static let topPadding: CGFloat = 30
        static let bottomPadding: CGFloat = 24
        static let spacing: CGFloat = 16
        static let fieldPadding: CGFloat = 16
        static let fieldCornerRadius: CGFloat = 4
        static let borderWidth: CGFloat = 1
        static let focusedBorderWidth: CGFloat = 2
        static let buttonHeight: CGFloat = 40
        static let buttonTouchHeight: CGFloat = 48
        static let buttonLabelSize: CGFloat = 17
    }

    var body: some View {
        let placeholder = AppLocalizedString.string("shake.report.placeholder", locale: locale)
        ScrollView {
            VStack(alignment: .leading, spacing: Metrics.spacing) {
                Text(AppLocalizedString.string("shake.report.title", locale: locale))
                    .typography(.headingMediumBold)
                    .foregroundStyle(DSColor.Text.primary)
                    .accessibilityAddTraits(.isHeader)

                TextField(
                    "",
                    text: $draft,
                    prompt: Text(placeholder).foregroundStyle(DSColor.Text.secondary),
                    axis: .vertical
                )
                .textFieldStyle(.plain)
                .typography(.paragraphLargeRegular)
                .foregroundStyle(DSColor.Text.primary)
                .tint(DSColor.Background.Button.primary)
                .lineLimit(3...6)
                .focused($fieldFocused)
                .padding(Metrics.fieldPadding)
                .background {
                    // The padding sits outside the field. Taps there focus it; taps on
                    // the text still land on the field so the caret can be placed.
                    Color.clear
                        .contentShape(Rectangle())
                        .onTapGesture { fieldFocused = true }
                }
                .overlay {
                    RoundedRectangle(cornerRadius: Metrics.fieldCornerRadius, style: .circular)
                        .strokeBorder(
                            fieldFocused ? DSColor.Background.Button.primary : DSColor.Border.active,
                            lineWidth: fieldFocused ? Metrics.focusedBorderWidth : Metrics.borderWidth
                        )
                        .allowsHitTesting(false)
                }
                .accessibilityLabel(placeholder)

                Button {
                    send()
                } label: {
                    Text(AppLocalizedString.string("shake.report.send", locale: locale))
                        .font(.system(size: Metrics.buttonLabelSize, weight: .bold))
                        .foregroundStyle(DSColor.Text.onColorButton)
                        .frame(maxWidth: .infinity)
                        .frame(height: Metrics.buttonHeight)
                        .background(DSColor.Background.Button.primary, in: Capsule())
                        .frame(height: Metrics.buttonTouchHeight)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                Button {
                    onClose()
                } label: {
                    Text(DesignSystemLocalizedString.string("common.alert.cancel", locale: locale))
                        .font(.system(size: Metrics.buttonLabelSize, weight: .bold))
                        .foregroundStyle(DSColor.Background.Button.primary)
                        .frame(maxWidth: .infinity)
                        .frame(height: Metrics.buttonTouchHeight)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, Metrics.sidePadding)
            .padding(.top, Metrics.topPadding)
            .padding(.bottom, Metrics.bottomPadding)
            .fixedSize(horizontal: false, vertical: true)
            .onGeometryChange(for: CGSize.self) { proxy in
                proxy.size
            } action: { size in
                // A zero-width pass before the sheet has a real width reports a
                // nonsense height and would open the detent at full screen.
                guard size.width > 200 else { return }
                fit.noteContentHeight(size.height)
            }
        }
        .scrollBounceBehavior(.basedOnSize, axes: .vertical)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Color(.systemBackground))
        .onChange(of: fieldFocused) { _, focused in
            fit.noteFieldFocused(focused)
        }
    }

    private func send() {
        let language = locale.language.languageCode?.identifier ?? "en"
        let (context, identity) = ShakeReportContext.live(languageCode: language)
        let text = ShakeReportLog.shared.render(
            description: draft,
            context: context,
            identity: identity
        )
        let subject = "Minit report iOS \(context.version) \(context.environment)"
        ShakeReportLog.shared.beginExternalPresentation()
        let presented = ShakeReportMailer.present(
            address: address,
            subject: subject,
            text: text
        ) {
            ShakeReportLog.shared.endExternalPresentation()
            onClose()
        }
        if !presented {
            ShakeReportLog.shared.endExternalPresentation()
        }
    }
}

/// System alert shown before the report sheet. A SwiftUI `.alert` on `ContentView`
/// sits under the login sheet and the Home covers, same as a SwiftUI sheet would.
enum ShakeReportAlertPresenter {
    private static let logger = AppLogger(subsystem: "com.minit.app", category: "ShakeReport")
    /// Covers the alert `present` and the Report handler's sheet `present`, and is
    /// cleared before either call returns. The alert stays busy by remaining in the
    /// presented chain, so dismissing an ancestor cannot leave this stuck.
    private static var promptBusy = false

    /// True while the alert is up, during the gap before the sheet, or while the
    /// sheet (including Mail or the share sheet on top of it) is up.
    static var isBusy: Bool {
        promptBusy || ShakeReportSheetPresenter.isPresented || shakeReportAlertIsPresented()
    }

    @discardableResult
    static func present(address: String, locale: Locale) -> Bool {
        guard !isBusy, let presenter = shakeReportTopViewController() else { return false }
        let handoff = ShakeReportHandoff { report in
            guard report else { return }
            promptBusy = true
            defer { promptBusy = false }
            guard ShakeReportSheetPresenter.present(address: address, locale: locale) else {
                logger.error("Shake report sheet failed to present")
                return
            }
        }
        let alert = ShakeReportAlertController(
            title: AppLocalizedString.string("shake.report.prompt.title", locale: locale),
            message: AppLocalizedString.string("shake.report.prompt.message", locale: locale),
            preferredStyle: .alert
        )
        let cancel = UIAlertAction(
            title: DesignSystemLocalizedString.string("common.alert.cancel", locale: locale),
            style: .cancel
        ) { _ in
            handoff.resolve(report: false)
        }
        let report = UIAlertAction(
            title: AppLocalizedString.string("shake.report.prompt.report", locale: locale),
            style: .default
        ) { _ in
            handoff.resolve(report: true)
        }
        alert.addAction(cancel)
        alert.addAction(report)
        alert.preferredAction = report
        promptBusy = true
        defer { promptBusy = false }
        presenter.present(alert, animated: true)
        return presenter.presentedViewController === alert
    }
}

/// Resolves the alert once. Each action calls this from its own handler.
/// UIKit has already dismissed the alert by then, so Report presents the sheet directly.
private final class ShakeReportHandoff {
    private var resolved = false
    private let onResolved: (Bool) -> Void

    init(onResolved: @escaping (Bool) -> Void) {
        self.onResolved = onResolved
    }

    func resolve(report: Bool) {
        guard !resolved else { return }
        resolved = true
        onResolved(report)
    }
}

/// Keeps Cancel and Report Minit orange (#FF9A31) once the alert loads its view.
/// Applied here so `alert.view` is not touched before the actions exist.
private final class ShakeReportAlertController: UIAlertController {
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        view.tintColor = UIColor(DSColor.Background.Button.primary)
    }
}

/// Presents the report sheet on the top-most view controller.
///
/// The login sheet and Home's full-screen cover are already presented from the
/// root. A SwiftUI `.sheet` on `ContentView` is anchored there too, so it does
/// not stack on top of them. UIKit presentation from the current top controller
/// does. The sheet still uses the in-app locale passed in from `ContentView`.
/// The fitted detent and the solid sheet background are applied here. SwiftUI
/// presentation modifiers do not drive a UIKit `present`. A regular-width iPad
/// page sheet is a centred card, so that size class keeps the system sheet.
enum ShakeReportSheetPresenter {
    private static var active: SheetSession?
    private static let fittedDetentID = UISheetPresentationController.Detent.Identifier("fitted")

    static var isPresented: Bool { active != nil }

    /// Fitted height is for iPhone and compact iPad. A regular-width iPad page sheet ignores detents.
    private static func usesFittedDetent(_ traits: UITraitCollection) -> Bool {
        if traits.userInterfaceIdiom == .pad, traits.horizontalSizeClass == .regular {
            return false
        }
        return true
    }

    @discardableResult
    static func present(address: String, locale: Locale) -> Bool {
        guard active == nil, let presenter = shakeReportTopViewController() else { return false }
        let session = SheetSession(usesFittedDetent: usesFittedDetent(presenter.traitCollection))
        session.fit.homeIndicatorInset = presenter.view.window?.safeAreaInsets.bottom ?? 0
        let host = ReportHostingController(
            rootView: ShakeReportSheet(
                address: address,
                onClose: { [weak session] in
                    session?.close()
                },
                fit: session.fit
            )
            .environment(\.locale, locale)
        )
        host.onDidDismiss = { [weak session] in
            session?.end()
        }
        host.onSafeAreaTop = { [weak session] top in
            session?.fit.noteTopChrome(top)
        }
        // Keyboard avoidance would pad the form by the IME as well as growing the
        // sheet. The detent lift keeps Send above the keyboard; the 24pt bottom
        // padding stays the only space under Cancel.
        host.safeAreaRegions = .container
        host.modalPresentationStyle = .pageSheet
        if let sheet = host.sheetPresentationController {
            sheet.prefersGrabberVisible = true
            if session.usesFittedDetent {
                let detent = UISheetPresentationController.Detent.custom(identifier: fittedDetentID) { [weak session] context in
                    let height = session?.fit.detentHeight ?? ReportSheetFit.fallbackContentHeight
                    return min(height, context.maximumDetentValue)
                }
                if #available(iOS 26.1, *) {
                    let solid = UIVisualEffect()
                    detent.backgroundEffect = solid
                    sheet.backgroundEffect = solid
                }
                sheet.detents = [detent]
                sheet.selectedDetentIdentifier = fittedDetentID
            } else if #available(iOS 26.1, *) {
                sheet.backgroundEffect = UIVisualEffect()
            }
        }
        host.presentationController?.delegate = session
        session.host = host
        active = session
        if session.usesFittedDetent {
            session.startKeyboardObservation()
        }
        presenter.present(host, animated: true)
        host.presentationController?.delegate = session
        guard presenter.presentedViewController === host else {
            session.end()
            return false
        }
        return true
    }

    private static func end(_ session: SheetSession) {
        guard active === session else { return }
        active = nil
    }

    /// One presented sheet. Swipe dismissal and `close()` both end it once.
    private final class SheetSession: NSObject, UIAdaptivePresentationControllerDelegate {
        let fit = ReportSheetFit()
        let usesFittedDetent: Bool
        var host: UIViewController?
        private var ended = false
        private var invalidatingDetent = false
        private var detentNeedsAnotherPass = false
        private var keyboardObserver: NSObjectProtocol?
        private var lastKeyboardEndFrame: CGRect?

        init(usesFittedDetent: Bool) {
            self.usesFittedDetent = usesFittedDetent
            super.init()
            fit.onChange = { [weak self] animated in
                self?.invalidateFittedDetent(animated: animated)
            }
            fit.onFieldFocus = { [weak self] _ in
                self?.publishKeyboardLift()
            }
        }

        func close() {
            host?.dismiss(animated: true)
        }

        func startKeyboardObservation() {
            guard usesFittedDetent, keyboardObserver == nil else { return }
            keyboardObserver = NotificationCenter.default.addObserver(
                forName: UIResponder.keyboardWillChangeFrameNotification,
                object: nil,
                queue: .main
            ) { [weak self] notification in
                // `Notification` is not Sendable. Read the frame here, then
                // enter the main actor without capturing the notification.
                let endFrame = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect
                let session = self
                MainActor.assumeIsolated {
                    session?.applyKeyboard(endFrame: endFrame)
                }
            }
        }

        func end() {
            guard !ended else { return }
            ended = true
            if let keyboardObserver {
                NotificationCenter.default.removeObserver(keyboardObserver)
                self.keyboardObserver = nil
            }
            host = nil
            ShakeReportSheetPresenter.end(self)
        }

        func presentationControllerDidDismiss(_ presentationController: UIPresentationController) {
            end()
        }

        private func applyKeyboard(endFrame: CGRect?) {
            guard !ended, usesFittedDetent else { return }
            lastKeyboardEndFrame = endFrame
            publishKeyboardLift()
        }

        /// Lift only while this sheet's field is focused, so another keyboard
        /// (Mail, an undocked iPad keyboard) cannot resize the detent.
        private func publishKeyboardLift() {
            guard !ended, usesFittedDetent else { return }
            let lift: CGFloat
            if fit.fieldFocused, let frame = lastKeyboardEndFrame {
                lift = keyboardLift(from: frame)
            } else {
                lift = 0
            }
            fit.noteKeyboardLift(lift)
        }

        private func keyboardLift(from frame: CGRect) -> CGFloat {
            guard let window = host?.view.window else { return 0 }
            let keyboard = window.convert(frame, from: window.screen.coordinateSpace)
            let overlap = window.bounds.intersection(keyboard).height
            // The custom detent already adds the home-indicator inset back onto
            // the sheet. Subtract it so the keyboard does not lift the form twice.
            return max(0, overlap - fit.homeIndicatorInset)
        }

        private func invalidateFittedDetent(animated: Bool) {
            guard usesFittedDetent, !ended, let sheet = host?.sheetPresentationController else { return }
            if invalidatingDetent {
                detentNeedsAnotherPass = true
                return
            }
            invalidatingDetent = true
            let changes = {
                sheet.invalidateDetents()
            }
            if animated {
                sheet.animateChanges(changes)
            } else {
                changes()
            }
            invalidatingDetent = false
            if detentNeedsAnotherPass {
                detentNeedsAnotherPass = false
                invalidateFittedDetent(animated: animated)
            }
        }
    }
}

/// Content height, grabber inset, and keyboard lift for one presented report sheet.
@Observable
private final class ReportSheetFit {
    /// Resting height used until the form reports its measured height.
    /// Includes the 30pt top padding (was 320 when that padding was 8).
    static let fallbackContentHeight: CGFloat = 342

    @ObservationIgnored
    var onChange: (_ animated: Bool) -> Void = { _ in }
    @ObservationIgnored
    var onFieldFocus: (Bool) -> Void = { _ in }
    @ObservationIgnored
    private(set) var fieldFocused = false
    private(set) var contentHeight: CGFloat = 0
    private(set) var keyboardLift: CGFloat = 0
    private(set) var topChrome: CGFloat = 0
    @ObservationIgnored
    var homeIndicatorInset: CGFloat = 0

    /// Height passed to the custom detent. The system adds the bottom safe area.
    var detentHeight: CGFloat {
        let content = contentHeight > 0 ? contentHeight : Self.fallbackContentHeight
        return max(content + topChrome + keyboardLift, 1)
    }

    func noteContentHeight(_ height: CGFloat) {
        guard height > 1, abs(height - contentHeight) > 0.5 else { return }
        let first = contentHeight == 0
        contentHeight = height
        onChange(!first)
    }

    func noteKeyboardLift(_ lift: CGFloat) {
        guard abs(lift - keyboardLift) > 0.5 else { return }
        keyboardLift = lift
        onChange(true)
    }

    func noteTopChrome(_ top: CGFloat) {
        guard abs(top - topChrome) > 0.5 else { return }
        topChrome = top
        onChange(false)
    }

    func noteFieldFocused(_ focused: Bool) {
        guard fieldFocused != focused else { return }
        fieldFocused = focused
        onFieldFocus(focused)
    }
}

/// Clears the open flag when this sheet is the controller being dismissed.
/// A mail composer or share sheet covering it does not.
private final class ReportHostingController<Content: View>: UIHostingController<Content> {
    var onDidDismiss: () -> Void = {}
    var onSafeAreaTop: (CGFloat) -> Void = { _ in }
    private var reportedTop: CGFloat = -1

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        let top = view.safeAreaInsets.top
        guard abs(top - reportedTop) > 0.5 else { return }
        reportedTop = top
        let report = onSafeAreaTop
        DispatchQueue.main.async {
            report(top)
        }
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        guard isBeingDismissed else { return }
        onDidDismiss()
    }
}

private func shakeReportRootViewController() -> UIViewController? {
    let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
    let window = scenes.flatMap(\.windows).first { $0.isKeyWindow } ?? scenes.first?.windows.first
    return window?.rootViewController
}

private func shakeReportTopViewController() -> UIViewController? {
    var controller = shakeReportRootViewController()
    while let presented = controller?.presentedViewController {
        controller = presented
    }
    return controller
}

private func shakeReportAlertIsPresented() -> Bool {
    var controller = shakeReportRootViewController()
    while let current = controller {
        if current is ShakeReportAlertController { return true }
        controller = current.presentedViewController
    }
    return false
}

/// Hands the report to Mail, or to the share sheet when Mail has no account.
/// The temp file exists only for that handoff. The buffer itself stays in memory.
enum ShakeReportMailer {
    private static var delegateBox: MailDelegate?

    @discardableResult
    static func present(
        address: String,
        subject: String,
        text: String,
        onFinish: @escaping () -> Void
    ) -> Bool {
        guard let presenter = shakeReportTopViewController() else { return false }
        if MFMailComposeViewController.canSendMail() {
            let mail = MFMailComposeViewController()
            let box = MailDelegate(onFinish: onFinish)
            delegateBox = box
            mail.mailComposeDelegate = box
            mail.setToRecipients([address])
            mail.setSubject(subject)
            mail.addAttachmentData(Data(text.utf8), mimeType: "text/plain", fileName: "minit-report.txt")
            presenter.present(mail, animated: true)
            return true
        }
        do {
            let url = FileManager.default.temporaryDirectory
                .appendingPathComponent("minit-report-\(UUID().uuidString).txt")
            try Data(text.utf8).write(to: url, options: .atomic)
            let activity = UIActivityViewController(activityItems: [url], applicationActivities: nil)
            if let popover = activity.popoverPresentationController {
                popover.sourceView = presenter.view
                popover.sourceRect = CGRect(
                    x: presenter.view.bounds.midX,
                    y: presenter.view.bounds.midY,
                    width: 1,
                    height: 1
                )
                popover.permittedArrowDirections = []
            }
            activity.completionWithItemsHandler = { _, _, _, _ in
                try? FileManager.default.removeItem(at: url)
                onFinish()
            }
            presenter.present(activity, animated: true)
            return true
        } catch {
            return false
        }
    }

    private final class MailDelegate: NSObject, MFMailComposeViewControllerDelegate {
        let onFinish: () -> Void

        init(onFinish: @escaping () -> Void) {
            self.onFinish = onFinish
        }

        func mailComposeController(
            _ controller: MFMailComposeViewController,
            didFinishWith result: MFMailComposeResult,
            error: Error?
        ) {
            let finish = onFinish
            controller.dismiss(animated: true) {
                ShakeReportMailer.delegateBox = nil
                finish()
            }
        }
    }
}
#endif
