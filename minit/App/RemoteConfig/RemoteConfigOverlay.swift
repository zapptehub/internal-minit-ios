import DesignSystem
import SwiftUI
import UIKit

enum RemoteConfigCopy {
    static let blockingTitle = "remoteConfig.maintenance.blocking.title"
    static let blockingFallback = "remoteConfig.maintenance.blocking.fallback"
    static let forceTitle = "remoteConfig.update.force.title"
    static let forceReleaseBody = "remoteConfig.update.force.releaseBody"
    static let softTitle = "remoteConfig.update.soft.title"
    static let softReleaseBody = "remoteConfig.update.soft.releaseBody"
    static let softTesterBody = "remoteConfig.update.soft.testerBody"
    static let testerBody = "remoteConfig.update.testerBody"
    static let updateButton = "remoteConfig.update.update"
    static let dismissBanner = "remoteConfig.banner.dismiss"
    static let downtimeTitle = "remoteConfig.banner.downtimeTitle"
    static let alertTitle = "remoteConfig.update.testerAlert.title"
    static let alertMessage = "remoteConfig.update.testerAlert.message"
    static let openMail = "remoteConfig.update.openMail"
    static let requestVersion = "remoteConfig.update.requestVersion"
    static let alertCancel = "remoteConfig.update.alertCancel"
    static let requestSubject = "remoteConfig.update.requestSubject"
    static let requestBody = "remoteConfig.update.requestBody"
}

/// Hosts downtime and soft banners above every screen, and presents blocking
/// maintenance and force update as a non-dismissable sheet in the same window
/// so they stay above Start, login, onboarding, and home.
struct RemoteConfigWindowAnchor: UIViewRepresentable {
    @ObservedObject var gate: RemoteConfigGate
    var locale: Locale

    func makeUIView(context: Context) -> UIView {
        let view = UIView(frame: .zero)
        view.isUserInteractionEnabled = false
        view.backgroundColor = .clear
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        context.coordinator.sync(gate: gate, locale: locale)
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    final class Coordinator {
        private var window: OverlayWindow?
        private var host: UIHostingController<RemoteConfigChrome>?
        private var hostHeight: NSLayoutConstraint?
        private var sceneRetries = 0
        private var appliedLocale: Locale?
        private var didResignForSheet = false

        func sync(gate: RemoteConfigGate, locale: Locale) {
            guard ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] == nil else { return }
            guard let scene = OverlayWindow.foregroundScene else {
                guard sceneRetries < 8 else { return }
                sceneRetries += 1
                Task { @MainActor in
                    try? await Task.sleep(for: .milliseconds(150))
                    self.sync(gate: gate, locale: locale)
                }
                return
            }
            sceneRetries = 0
            let window = self.window(for: scene)
            let decision = displayedDecision(gate: gate, locale: locale)
            let showsChrome = decision.coversApp || decision.softBanner != nil || decision.downtimeBanner != nil
            guard let root = window.rootViewController as? OverlayRootController else { return }
            root.blocksTouches = decision.coversApp

            if host == nil || appliedLocale != locale {
                let chromeHost = host ?? makeHost(in: window)
                chromeHost.rootView = RemoteConfigChrome(gate: gate, locale: locale)
                host = chromeHost
                appliedLocale = locale
            }

            window.isHidden = !showsChrome
            if decision.coversApp {
                if !window.isKeyWindow {
                    window.makeKeyAndVisible()
                }
                if !didResignForSheet {
                    didResignForSheet = true
                    UIApplication.shared.sendAction(
                        #selector(UIResponder.resignFirstResponder),
                        to: nil,
                        from: nil,
                        for: nil
                    )
                }
            } else {
                didResignForSheet = false
                releaseKeyWindow(window)
            }
            // The sheet is presented beside this root. Marking the root modal hides that sheet from VoiceOver.
            if let host, showsChrome {
                resizeHost(host, in: window)
            }
        }

        private func window(for scene: UIWindowScene) -> OverlayWindow {
            if let window, window.windowScene === scene { return window }
            let window = OverlayWindow(windowScene: scene)
            window.windowLevel = .alert
            window.backgroundColor = .clear
            let root = OverlayRootController()
            window.rootViewController = root
            self.window = window
            host = nil
            hostHeight = nil
            appliedLocale = nil
            return window
        }

        private func makeHost(in window: OverlayWindow) -> UIHostingController<RemoteConfigChrome> {
            let host = UIHostingController(
                rootView: RemoteConfigChrome(gate: RemoteConfigGate.shared, locale: .current)
            )
            host.view.backgroundColor = .clear
            host.view.isOpaque = false
            host.sizingOptions = .intrinsicContentSize
            let height = host.view.heightAnchor.constraint(equalToConstant: 1)
            height.priority = .defaultHigh
            guard let parent = window.rootViewController else { return host }
            parent.addChild(host)
            host.view.translatesAutoresizingMaskIntoConstraints = false
            parent.view.addSubview(host.view)
            NSLayoutConstraint.activate([
                host.view.leadingAnchor.constraint(equalTo: parent.view.leadingAnchor),
                host.view.trailingAnchor.constraint(equalTo: parent.view.trailingAnchor),
                host.view.topAnchor.constraint(equalTo: parent.view.safeAreaLayoutGuide.topAnchor),
                height,
            ])
            host.didMove(toParent: parent)
            hostHeight = height
            self.host = host
            return host
        }

        private func resizeHost(_ host: UIHostingController<RemoteConfigChrome>, in window: OverlayWindow) {
            let width = window.bounds.width > 1 ? window.bounds.width : (window.windowScene?.screen.bounds.width ?? 0)
            let fitting = host.sizeThatFits(in: CGSize(width: width, height: .greatestFiniteMagnitude))
            hostHeight?.constant = max(fitting.height, 1)
        }

        private func releaseKeyWindow(_ window: OverlayWindow) {
            guard window.isKeyWindow else { return }
            let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
            let appWindow = scenes.flatMap(\.windows).first { candidate in
                candidate !== window && !candidate.isHidden && candidate.windowLevel == .normal
            }
            appWindow?.makeKey()
        }
    }
}

private func displayedDecision(gate: RemoteConfigGate, locale: Locale) -> AppVersionPolicy.Decision {
    gate.decision(languageCode: RemoteConfigLanguage.code(from: locale))
}

private final class OverlayWindow: UIWindow {
    static var foregroundScene: UIWindowScene? {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        return scenes.first { $0.activationState == .foregroundActive } ?? scenes.first
    }
}

private final class OverlayRootController: UIViewController {
    var blocksTouches = false {
        didSet { (view as? PassThroughRootView)?.blocksTouches = blocksTouches }
    }

    override func loadView() {
        view = PassThroughRootView()
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .clear
    }
}

private final class PassThroughRootView: UIView {
    var blocksTouches = false

    override func point(inside point: CGPoint, with event: UIEvent?) -> Bool {
        if blocksTouches { return bounds.contains(point) }
        return subviews.contains { subview in
            guard !subview.isHidden, subview.alpha > 0.01, subview.isUserInteractionEnabled else { return false }
            return subview.point(inside: convert(point, to: subview), with: event)
        }
    }
}

struct RemoteConfigChrome: View {
    @ObservedObject var gate: RemoteConfigGate
    var locale: Locale

    var body: some View {
        let decision = displayedDecision(gate: gate, locale: locale)
        VStack(spacing: DSConstant.medium.value) {
            if !decision.coversApp {
                if let downtime = decision.downtimeBanner {
                    RemoteConfigBannerCard(
                        title: AppLocalizedString.string(RemoteConfigCopy.downtimeTitle, locale: locale),
                        bodyText: downtime.message,
                        dismissLabel: AppLocalizedString.string(RemoteConfigCopy.dismissBanner, locale: locale),
                        onClose: { gate.dismissBanner(identity: downtime.identity) }
                    )
                }
                if let soft = decision.softBanner {
                    RemoteConfigBannerCard(
                        title: AppLocalizedString.string(RemoteConfigCopy.softTitle, locale: locale),
                        bodyText: softBody(soft),
                        dismissLabel: AppLocalizedString.string(RemoteConfigCopy.dismissBanner, locale: locale),
                        onClose: { gate.dismissSoftUpdate(threshold: soft.threshold) }
                    )
                }
            }
        }
        .padding(.horizontal, DSConstant.mediumLarge.value)
        .padding(.vertical, showsBanner(decision) ? DSConstant.small.value : 0)
        .frame(maxWidth: .infinity, alignment: .top)
        .frame(minHeight: showsBanner(decision) ? nil : 1)
        .fixedSize(horizontal: false, vertical: true)
        .background(Color.clear)
        .sheet(isPresented: Binding(
            get: { decision.coversApp },
            set: { _ in }
        )) {
            RemoteConfigGateSheet(gate: gate, locale: locale)
        }
        .environment(\.locale, locale)
    }

    private func showsBanner(_ decision: AppVersionPolicy.Decision) -> Bool {
        !decision.coversApp && (decision.downtimeBanner != nil || decision.softBanner != nil)
    }

    private func softBody(_ soft: AppVersionPolicy.SoftBanner) -> String {
        let key = soft.usesTesterCopy ? RemoteConfigCopy.softTesterBody : RemoteConfigCopy.softReleaseBody
        return AppLocalizedString.string(key, locale: locale)
    }
}

/// Warning banner shared by downtime and the soft update. Corner radius is the Home
/// loyalty-card radius (`LoyaltyCard` / `DSConstant.cardCornerRadius`, 20).
struct RemoteConfigBannerCard: View {
    var title: String
    var bodyText: String
    var dismissLabel: String
    var onClose: () -> Void

    private var cornerRadius: CGFloat { DSConstant.cardCornerRadius.value }

    var body: some View {
        HStack(alignment: .top, spacing: DSConstant.medium.value) {
            DSIconView(icon: .info, size: DSConstant.large.value, color: DSColor.Text.link)
                .padding(.top, 2)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: DSConstant.xSmall.value) {
                Text(title)
                    .typography(.paragraphBold)
                    .foregroundStyle(DSColor.Text.primary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text(bodyText)
                    .typography(.paragraphRegular)
                    .foregroundStyle(DSColor.Text.secondary)
                    .lineLimit(3)
                    .truncationMode(.tail)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.top, 2)
            Button(action: onClose) {
                CloseMark(color: DSColor.Text.secondary)
                    .padding(.top, 2)
                    .frame(width: 48, height: 48, alignment: .top)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(dismissLabel)
        }
        .padding(.leading, DSConstant.mediumLarge.value)
        .padding(.top, DSConstant.medium.value)
        .padding(.trailing, DSConstant.xSmall.value)
        .padding(.bottom, DSConstant.mediumLarge.value)
        .frame(maxWidth: .infinity, minHeight: 116, alignment: .top)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .dsCardShadow()
    }
}

private struct CloseMark: View {
    var color: Color

    var body: some View {
        Canvas { context, size in
            var path = Path()
            path.move(to: .zero)
            path.addLine(to: CGPoint(x: size.width, y: size.height))
            path.move(to: CGPoint(x: size.width, y: 0))
            path.addLine(to: CGPoint(x: 0, y: size.height))
            context.stroke(
                path,
                with: .color(color),
                style: StrokeStyle(lineWidth: 2, lineCap: .round)
            )
        }
        .frame(width: 16, height: 16)
        .accessibilityHidden(true)
    }
}

struct RemoteConfigGateSheet: View {
    @ObservedObject var gate: RemoteConfigGate
    var locale: Locale
    @State private var contentHeight: CGFloat = 520
    @State private var topInset: CGFloat = 16
    @State private var bottomInset: CGFloat = 34
    @State private var showTesterAlert = false

    /// Same display box as the Home loyalty-card illustration.
    private let illustrationSize = CGSize(width: 127, height: 158)

    var body: some View {
        let decision = displayedDecision(gate: gate, locale: locale)
        ScrollView {
            VStack(spacing: DSConstant.mediumLarge.value) {
                DSImageView(image: .minitCardPerson, size: illustrationSize, contentMode: .fit)
                    .accessibilityHidden(true)
                if let blocking = decision.blocking {
                    sheetTitle(AppLocalizedString.string(RemoteConfigCopy.blockingTitle, locale: locale))
                    sheetBody(blockingBody(blocking))
                } else if let force = decision.force {
                    sheetTitle(AppLocalizedString.string(RemoteConfigCopy.forceTitle, locale: locale))
                    sheetBody(forceBody(force))
                    updateButton(force)
                }
            }
            .padding(.horizontal, DSConstant.large.value)
            .padding(.top, DSConstant.mediumLarge.value)
            .padding(.bottom, DSConstant.large.value)
            .frame(maxWidth: .infinity)
            .fixedSize(horizontal: false, vertical: true)
            .onGeometryChange(for: CGFloat.self) { proxy in
                proxy.size.height
            } action: { height in
                guard height > 1, abs(height - contentHeight) > 0.5 else { return }
                contentHeight = height
            }
        }
        .scrollBounceBehavior(.basedOnSize, axes: .vertical)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Color.white)
        .interactiveDismissDisabled(true)
        .presentationDetents([.height(max(contentHeight + topInset + bottomInset, 1))])
        .presentationDragIndicator(.visible)
        .presentationBackground(Color.white)
        .presentationBackgroundInteraction(.disabled)
        .background(WhiteSheetChrome(topInset: $topInset, bottomInset: $bottomInset))
        .background(
            TesterAlertPresenter(
                isPresented: showTesterAlert,
                title: AppLocalizedString.string(RemoteConfigCopy.alertTitle, locale: locale),
                message: AppLocalizedString.string(RemoteConfigCopy.alertMessage, locale: locale),
                openMailTitle: AppLocalizedString.string(RemoteConfigCopy.openMail, locale: locale),
                requestTitle: AppLocalizedString.string(RemoteConfigCopy.requestVersion, locale: locale),
                cancelTitle: AppLocalizedString.string(RemoteConfigCopy.alertCancel, locale: locale),
                onOpenMail: {
                    showTesterAlert = false
                    RemoteConfigMailOpener.openMailApp()
                },
                onRequestVersion: {
                    showTesterAlert = false
                    let subject = AppLocalizedString.string(RemoteConfigCopy.requestSubject, locale: locale)
                    let template = AppLocalizedString.string(RemoteConfigCopy.requestBody, locale: locale)
                    let body = RemoteConfigTesterMail.requestBody(
                        template: template,
                        installedVersion: gate.installedMarketingVersion
                    )
                    RemoteConfigMailOpener.openInvite(subject: subject, body: body)
                },
                onCancel: { showTesterAlert = false }
            )
        )
        .onAppear {
            UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        }
        .environment(\.locale, locale)
    }

    private func blockingBody(_ blocking: AppVersionPolicy.Blocking) -> String {
        switch blocking.body {
        case .remote(let text):
            return text
        case .catalogFallback:
            return AppLocalizedString.string(RemoteConfigCopy.blockingFallback, locale: locale)
        }
    }

    private func forceBody(_ force: AppVersionPolicy.Force) -> String {
        let key = force.usesTesterCopy ? RemoteConfigCopy.testerBody : RemoteConfigCopy.forceReleaseBody
        return AppLocalizedString.string(key, locale: locale)
    }

    private func sheetTitle(_ text: String) -> some View {
        Text(text)
            .typography(.headingMediumBold)
            .foregroundStyle(DSColor.Text.heading)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
            .accessibilityAddTraits(.isHeader)
    }

    private func sheetBody(_ text: String) -> some View {
        Text(linkedBody(text))
            .typography(.paragraphRegular)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
    }

    private func linkedBody(_ text: String) -> AttributedString {
        var attributed = AttributedString(text)
        attributed.foregroundColor = DSColor.Text.secondary
        let email = RemoteConfigTesterMail.email
        if let range = attributed.range(of: email), let url = RemoteConfigTesterMail.addressURL() {
            attributed[range].link = url
            attributed[range].foregroundColor = DSColor.Text.link
            attributed[range].underlineStyle = .single
        }
        return attributed
    }

    @ViewBuilder
    private func updateButton(_ force: AppVersionPolicy.Force) -> some View {
        switch force.action {
        case .openStore(let url):
            DSButton(
                title: AppLocalizedString.string(RemoteConfigCopy.updateButton, locale: locale),
                type: .primary
            ) {
                RemoteConfigMailOpener.openUpdate(url)
            }
        case .testerAlert:
            DSButton(
                title: AppLocalizedString.string(RemoteConfigCopy.updateButton, locale: locale),
                type: .primary
            ) {
                showTesterAlert = true
            }
        case .unavailable:
            EmptyView()
        }
    }
}

/// Keeps the sheet white and non-dismissable on iOS 26+, where the system sheet is glass.
private struct WhiteSheetChrome: UIViewControllerRepresentable {
    @Binding var topInset: CGFloat
    @Binding var bottomInset: CGFloat

    func makeUIViewController(context: Context) -> Controller {
        Controller()
    }

    func updateUIViewController(_ controller: Controller, context: Context) {
        controller.onInsets = { top, bottom in
            if abs(top - topInset) > 0.5 { topInset = top }
            if abs(bottom - bottomInset) > 0.5 { bottomInset = bottom }
        }
        controller.apply()
    }

    final class Controller: UIViewController {
        var onInsets: (CGFloat, CGFloat) -> Void = { _, _ in }

        override func viewDidLoad() {
            super.viewDidLoad()
            view.isUserInteractionEnabled = false
            view.backgroundColor = .clear
        }

        override func viewDidLayoutSubviews() {
            super.viewDidLayoutSubviews()
            apply()
        }

        func apply() {
            guard let sheetController = presentedSheetController else { return }
            sheetController.isModalInPresentation = true
            sheetController.view.backgroundColor = .white
            if #available(iOS 26.1, *) {
                let solid = UIVisualEffect()
                sheetController.sheetPresentationController?.backgroundEffect = solid
            }
            let top = sheetController.view.safeAreaInsets.top
            let bottom = sheetController.view.safeAreaInsets.bottom
            guard top > 0 || bottom > 0 else { return }
            DispatchQueue.main.async {
                self.onInsets(top, bottom)
            }
        }

        private var presentedSheetController: UIViewController? {
            var current: UIViewController? = self
            while let controller = current {
                if controller.sheetPresentationController != nil, controller.presentingViewController != nil {
                    return controller
                }
                current = controller.parent
            }
            return nil
        }
    }
}

/// Native alert with Minit-orange actions, same tint treatment as the shake alert.
private struct TesterAlertPresenter: UIViewControllerRepresentable {
    var isPresented: Bool
    var title: String
    var message: String
    var openMailTitle: String
    var requestTitle: String
    var cancelTitle: String
    var onOpenMail: () -> Void
    var onRequestVersion: () -> Void
    var onCancel: () -> Void

    func makeUIViewController(context: Context) -> UIViewController {
        let controller = UIViewController()
        controller.view.isUserInteractionEnabled = false
        controller.view.backgroundColor = .clear
        return controller
    }

    func updateUIViewController(_ controller: UIViewController, context: Context) {
        context.coordinator.sync(
            isPresented: isPresented,
            title: title,
            message: message,
            openMailTitle: openMailTitle,
            requestTitle: requestTitle,
            cancelTitle: cancelTitle,
            onOpenMail: onOpenMail,
            onRequestVersion: onRequestVersion,
            onCancel: onCancel,
            from: controller
        )
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    final class Coordinator {
        private var alert: RemoteConfigAlertController?

        func sync(
            isPresented: Bool,
            title: String,
            message: String,
            openMailTitle: String,
            requestTitle: String,
            cancelTitle: String,
            onOpenMail: @escaping () -> Void,
            onRequestVersion: @escaping () -> Void,
            onCancel: @escaping () -> Void,
            from controller: UIViewController
        ) {
            if !isPresented {
                alert = nil
                return
            }
            if let alert, alert.presentingViewController != nil || alert.isBeingPresented {
                return
            }
            alert = nil
            guard let presenter = sheetPresenter(from: controller) else { return }
            guard presenter.presentedViewController == nil else { return }
            let alert = RemoteConfigAlertController(title: title, message: message, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: openMailTitle, style: .default) { [weak self] _ in
                self?.alert = nil
                onOpenMail()
            })
            alert.addAction(UIAlertAction(title: requestTitle, style: .default) { [weak self] _ in
                self?.alert = nil
                onRequestVersion()
            })
            alert.addAction(UIAlertAction(title: cancelTitle, style: .cancel) { [weak self] _ in
                self?.alert = nil
                onCancel()
            })
            self.alert = alert
            presenter.present(alert, animated: true)
        }

        private func sheetPresenter(from controller: UIViewController) -> UIViewController? {
            var current: UIViewController? = controller
            while let candidate = current {
                if candidate.presentingViewController != nil { return candidate }
                current = candidate.parent
            }
            return nil
        }
    }
}

/// Keeps every alert action Minit orange (`#FF9A31`), matching `ShakeReportAlertController`.
/// iOS 26 draws alert actions as filled capsules and ignores the controller tint for their
/// labels, so the action titles are colored directly once the alert has laid out.
private final class RemoteConfigAlertController: UIAlertController {
    private var orange: UIColor { UIColor(DSColor.Background.Button.primary) }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        view.tintColor = orange
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        applyOrange(in: view)
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.applyOrange(in: self.view)
        }
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        applyOrange(in: view)
    }

    private func applyOrange(in view: UIView) {
        let titles = Set(actions.compactMap { $0.title?.trimmingCharacters(in: .whitespacesAndNewlines) })
        if let label = view as? UILabel {
            let text = (label.attributedText?.string ?? label.text ?? "")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            if titles.contains(text) {
                let font = label.font ?? .boldSystemFont(ofSize: 17)
                let attributed = NSMutableAttributedString(string: text)
                let range = NSRange(location: 0, length: attributed.length)
                attributed.addAttribute(.foregroundColor, value: orange, range: range)
                attributed.addAttribute(.font, value: font, range: range)
                label.attributedText = attributed
                label.textColor = orange
            }
        }
        if let button = view as? UIButton {
            button.tintColor = orange
            button.setTitleColor(orange, for: .normal)
            if var configuration = button.configuration {
                configuration.baseForegroundColor = orange
                button.configuration = configuration
            }
        }
        for subview in view.subviews {
            applyOrange(in: subview)
        }
    }
}

private enum RemoteConfigMailOpener {
    static func openUpdate(_ url: URL) {
        guard let scheme = url.scheme?.lowercased(), scheme == "https" || scheme == "itms-apps" else { return }
        UIApplication.shared.open(url)
    }

    static func openMailApp() {
        guard let inbox = URL(string: "message://") else { return }
        UIApplication.shared.open(inbox, options: [:]) { opened in
            guard !opened, let compose = URL(string: "mailto:") else { return }
            UIApplication.shared.open(compose)
        }
    }

    static func openInvite(subject: String, body: String) {
        guard let url = RemoteConfigTesterMail.requestInviteURL(subject: subject, body: body) else { return }
        UIApplication.shared.open(url)
    }
}
