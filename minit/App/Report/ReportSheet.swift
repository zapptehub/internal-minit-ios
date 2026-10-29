#if MINIT_SHAKE
import DesignSystem
import MessageUI
import SwiftUI
import UIKit

struct ShakeReportSheet: View {
    let address: String
    /// Dismisses the UIKit sheet. Cancel drops the draft with the view.
    let onClose: () -> Void
    @Environment(\.locale) private var locale
    @State private var draft = ""

    var body: some View {
        VStack(alignment: .leading, spacing: DSConstant.large.value) {
            Text(AppLocalizedString.string("shake.report.title", locale: locale))
                .typography(.headingMediumBold)
                .foregroundColor(DSColor.Text.heading)
                .accessibilityAddTraits(.isHeader)

            TextField(
                AppLocalizedString.string("shake.report.placeholder", locale: locale),
                text: $draft,
                axis: .vertical
            )
            .lineLimit(3...8)
            .typography(.paragraphRegular)

            if !MFMailComposeViewController.canSendMail() {
                Text(AppLocalizedString.string("shake.report.mailUnavailable", locale: locale))
                    .typography(.paragraphRegular)
                    .foregroundColor(DSColor.Text.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            DSButton(
                title: AppLocalizedString.string("shake.report.send", locale: locale),
                type: .primary
            ) {
                send()
            }

            Button(DesignSystemLocalizedString.string("common.alert.cancel", locale: locale)) {
                onClose()
            }
            .frame(maxWidth: .infinity)
        }
        .padding(DSConstant.large.value)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(DSColor.Background.Layer.level0.ignoresSafeArea())
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
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

/// Presents the report sheet on the top-most view controller.
///
/// The login sheet and Home's full-screen cover are already presented from the
/// root. A SwiftUI `.sheet` on `ContentView` is anchored there too, so it does
/// not stack on top of them. UIKit presentation from the current top controller
/// does. The sheet still uses the in-app locale passed in from `ContentView`.
enum ShakeReportSheetPresenter {
    private static var active: SheetSession?

    static var isPresented: Bool { active != nil }

    @discardableResult
    static func present(address: String, locale: Locale) -> Bool {
        guard active == nil, let presenter = shakeReportTopViewController() else { return false }
        let session = SheetSession()
        let host = ReportHostingController(
            rootView: ShakeReportSheet(address: address) { [weak session] in
                session?.close()
            }
            .environment(\.locale, locale)
        )
        host.onDidDismiss = { [weak session] in
            session?.end()
        }
        host.modalPresentationStyle = .pageSheet
        if let sheet = host.sheetPresentationController {
            sheet.detents = [.medium()]
            sheet.prefersGrabberVisible = true
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

        func close() {
            host?.dismiss(animated: true)
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

private func shakeReportTopViewController() -> UIViewController? {
    let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
    let window = scenes.flatMap(\.windows).first { $0.isKeyWindow } ?? scenes.first?.windows.first
    var controller = window?.rootViewController
    while let presented = controller?.presentedViewController {
        controller = presented
    }
    return controller
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
