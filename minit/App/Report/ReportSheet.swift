#if MINIT_SHAKE
import CoreLogging
import DesignSystem
import MessageUI
import SwiftUI
import UIKit

struct ShakeReportSheet: View {
    let address: String
    /// Dismisses the UIKit sheet. Cancel drops the draft with the view.
    let onClose: () -> Void
    var onFieldFocus: (Bool) -> Void = { _ in }
    @Environment(\.locale) private var locale
    @State private var draft = ""
    @FocusState private var fieldFocused: Bool

    private var canSendMail: Bool {
        MFMailComposeViewController.canSendMail()
    }

    var body: some View {
        let placeholder = AppLocalizedString.string("shake.report.placeholder", locale: locale)
        VStack(alignment: .leading, spacing: 16) {
            Text(AppLocalizedString.string("shake.report.title", locale: locale))
                .font(.title2.bold())
                .accessibilityAddTraits(.isHeader)

            TextField("", text: $draft, prompt: Text(placeholder), axis: .vertical)
                .accessibilityLabel(placeholder)
                .lineLimit(3...6)
                .focused($fieldFocused)

            if !canSendMail {
                Text(AppLocalizedString.string("shake.report.mailUnavailable", locale: locale))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Button {
                send()
            } label: {
                Text(AppLocalizedString.string("shake.report.send", locale: locale))
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .tint(DSColor.Background.Button.primary)

            Button {
                onClose()
            } label: {
                Text(DesignSystemLocalizedString.string("common.alert.cancel", locale: locale))
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .controlSize(.large)
        }
        .padding(.horizontal, 20)
        .padding(.top, 16)
        .padding(.bottom, 16)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .onChange(of: fieldFocused) { _, focused in
            onFieldFocus(focused)
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
        let fallback = MFMailComposeViewController.canSendMail()
            ? nil
            : AppLocalizedString.string("shake.report.mailUnavailable", locale: locale)
        ShakeReportLog.shared.beginExternalPresentation()
        let presented = ShakeReportMailer.present(
            address: address,
            subject: subject,
            text: text,
            fallback: fallback
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
/// Detents are set here: SwiftUI `.presentationDetents` do not apply to this present.
enum ShakeReportSheetPresenter {
    private static var active: SheetSession?

    static var isPresented: Bool { active != nil }

    @discardableResult
    static func present(address: String, locale: Locale) -> Bool {
        guard active == nil, let presenter = shakeReportTopViewController() else { return false }
        let session = SheetSession()
        let host = ReportHostingController(
            rootView: ShakeReportSheet(
                address: address,
                onClose: { [weak session] in
                    session?.close()
                },
                onFieldFocus: { [weak session] focused in
                    session?.setFieldFocused(focused)
                }
            )
            .environment(\.locale, locale)
        )
        host.onDidDismiss = { [weak session] in
            session?.end()
        }
        host.modalPresentationStyle = .pageSheet
        if let sheet = host.sheetPresentationController {
            sheet.detents = [.medium(), .large()]
            sheet.prefersGrabberVisible = true
            sheet.selectedDetentIdentifier = .medium
        }
        host.presentationController?.delegate = session
        session.host = host
        active = session
        presenter.present(host, animated: true)
        host.presentationController?.delegate = session
        guard presenter.presentedViewController === host else {
            active = nil
            session.host = nil
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
        var host: UIViewController?
        private var ended = false
        /// True only after focus selects the large detent. A large detent the
        /// user dragged to stays where they left it when focus ends.
        private var expandedForFocus = false

        func close() {
            host?.dismiss(animated: true)
        }

        func setFieldFocused(_ focused: Bool) {
            guard let sheet = host?.sheetPresentationController else { return }
            if focused {
                guard sheet.selectedDetentIdentifier != .large else { return }
                expandedForFocus = true
                sheet.animateChanges {
                    sheet.selectedDetentIdentifier = .large
                }
                return
            }
            guard expandedForFocus else { return }
            expandedForFocus = false
            guard sheet.selectedDetentIdentifier == .large else { return }
            sheet.animateChanges {
                sheet.selectedDetentIdentifier = .medium
            }
        }

        func end() {
            guard !ended else { return }
            ended = true
            host = nil
            ShakeReportSheetPresenter.end(self)
        }

        func presentationControllerDidDismiss(_ presentationController: UIPresentationController) {
            end()
        }
    }
}

/// Clears the open flag when this sheet is the controller being dismissed.
/// A mail composer or share sheet covering it does not.
private final class ReportHostingController<Content: View>: UIHostingController<Content> {
    var onDidDismiss: () -> Void = {}

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
        fallback: String?,
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
            var items: [Any] = [url]
            if let fallback {
                items.append(fallback)
            }
            let activity = UIActivityViewController(activityItems: items, applicationActivities: nil)
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
