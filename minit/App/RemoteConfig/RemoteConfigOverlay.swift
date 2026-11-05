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
    static let reloadButton = "remoteConfig.maintenance.reload"
    static let stillUnavailableMessage = "remoteConfig.maintenance.stillUnavailable.message"
    static let stillUnavailableOK = "remoteConfig.maintenance.stillUnavailable.ok"
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
    @State private var showTesterAlert = false

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
                        updateTitle: softUpdateTitle(soft),
                        onUpdate: softUpdateAction(soft),
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
        .background(
            RemoteConfigTesterUpdateAlert(
                isPresented: showTesterAlert,
                locale: locale,
                installedVersion: gate.installedMarketingVersion,
                dismiss: { showTesterAlert = false }
            )
        )
        .environment(\.locale, locale)
    }

    /// Release with no usable URL (`.unavailable`) hides Update, same as the force sheet.
    private func softUpdateTitle(_ soft: AppVersionPolicy.SoftBanner) -> String? {
        if case .unavailable = soft.action { return nil }
        return AppLocalizedString.string(RemoteConfigCopy.updateButton, locale: locale)
    }

    private func softUpdateAction(_ soft: AppVersionPolicy.SoftBanner) -> (() -> Void)? {
        if case .unavailable = soft.action { return nil }
        return {
            RemoteConfigUpdateTrigger.run(soft.action) { showTesterAlert = true }
        }
    }

    private func showsBanner(_ decision: AppVersionPolicy.Decision) -> Bool {
        !decision.coversApp && (decision.downtimeBanner != nil || decision.softBanner != nil)
    }

    private func softBody(_ soft: AppVersionPolicy.SoftBanner) -> String {
        let key = soft.usesTesterCopy ? RemoteConfigCopy.softTesterBody : RemoteConfigCopy.softReleaseBody
        return AppLocalizedString.string(key, locale: locale)
    }
}

/// Warning banner shared by downtime and the soft update.
/// Solid white, 20 pt corners (the Home loyalty-card radius), a hairline border, and the card shadow.
struct RemoteConfigBannerCard: View {
    var title: String
    var bodyText: String
    var dismissLabel: String
    var updateTitle: String?
    var onUpdate: (() -> Void)?
    var onClose: () -> Void

    /// `DSConstant.cardCornerRadius` is 20.
    private var cornerRadius: CGFloat { DSConstant.cardCornerRadius.value }
    private var shape: RoundedRectangle {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
    }

    var body: some View {
        HStack(alignment: .top, spacing: DSConstant.medium.value) {
            DSIconView(icon: .info, size: DSConstant.large.value, color: DSColor.Text.link)
                .padding(.top, 2)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: DSConstant.medium.value) {
                VStack(alignment: .leading, spacing: DSConstant.xSmall.value) {
                    // Title and body stay fully visible. The card grows with the copy.
                    Text(title)
                        .typography(.paragraphBold)
                        .foregroundStyle(DSColor.Text.primary)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Text(bodyText)
                        .typography(.paragraphRegular)
                        .foregroundStyle(DSColor.Text.secondary)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityElement(children: .combine)
                .accessibilityAddTraits(.isHeader)
                if let updateTitle, let onUpdate {
                    // Same horizontal span as the title and body. Stops before the close control.
                    DSButton(title: updateTitle, type: .primary, widthStyle: .expanded, action: onUpdate)
                }
            }
            .padding(.top, 2)
            .frame(maxWidth: .infinity, alignment: .leading)
            Button(action: onClose) {
                CloseMark(color: DSColor.Text.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                    .padding(.top, 2)
                    .frame(width: RemoteConfigBannerMetrics.closeTarget, height: RemoteConfigBannerMetrics.closeTarget)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("\(dismissLabel) \(title)")
        }
        .padding(.leading, DSConstant.mediumLarge.value)
        .padding(.top, DSConstant.medium.value)
        .padding(.trailing, DSConstant.xSmall.value)
        .padding(.bottom, DSConstant.mediumLarge.value)
        .fixedSize(horizontal: false, vertical: true)
        .frame(maxWidth: .infinity, minHeight: 116, alignment: .top)
        // Light-only app (`UIUserInterfaceStyle` = Light): the banner stays white.
        .background(Color.white)
        .clipShape(shape)
        .overlay(shape.strokeBorder(DSColor.Border.default, lineWidth: 1))
        .dsCardShadow()
    }
}

private enum RemoteConfigBannerMetrics {
    /// Drawn X. The control around it is the touch target.
    static let closeGlyph: CGFloat = 13
    /// iOS minimum. The glyph stays inside this target.
    static let closeTarget: CGFloat = 44
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
                style: StrokeStyle(lineWidth: 1.5, lineCap: .round)
            )
        }
        .frame(width: RemoteConfigBannerMetrics.closeGlyph, height: RemoteConfigBannerMetrics.closeGlyph)
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
    /// Blocking maintenance only. Force update keeps the loyalty-card illustration.
    private let maintenanceWarningIconSize: CGFloat = 72
    /// Extra air under the sheet top. The grabber is hidden, so this is the gap above the triangle.
    private let maintenanceWarningTopSpacing = DSConstant.xLarge.value

    var body: some View {
        let decision = displayedDecision(gate: gate, locale: locale)
        ScrollView {
            VStack(spacing: DSConstant.mediumLarge.value) {
                if decision.blocking != nil {
                    DSIconView(
                        icon: .warningTriangle,
                        size: maintenanceWarningIconSize,
                        color: DSColor.Background.Button.primary
                    )
                    .padding(.top, maintenanceWarningTopSpacing)
                    .accessibilityHidden(true)
                } else {
                    DSImageView(image: .minitCardPerson, size: illustrationSize, contentMode: .fit)
                        .accessibilityHidden(true)
                }
                if let blocking = decision.blocking {
                    sheetTitle(AppLocalizedString.string(RemoteConfigCopy.blockingTitle, locale: locale))
                    sheetBody(blockingBody(blocking))
                    reloadButton
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
        // Light-only app (`UIUserInterfaceStyle` = Light): the sheet stays white.
        .background(Color.white)
        .interactiveDismissDisabled(true)
        .presentationDetents([.height(max(contentHeight + topInset + bottomInset, 1))])
        .presentationDragIndicator(.hidden)
        .presentationBackground(Color.white)
        .presentationBackgroundInteraction(.disabled)
        .background(WhiteSheetChrome(topInset: $topInset, bottomInset: $bottomInset))
        .background(
            RemoteConfigTesterUpdateAlert(
                isPresented: showTesterAlert,
                locale: locale,
                installedVersion: gate.installedMarketingVersion,
                dismiss: { showTesterAlert = false }
            )
        )
        .background(
            RemoteConfigNativeAlert(
                isPresented: gate.showsMaintenanceStillUnavailableAlert,
                title: AppLocalizedString.string(RemoteConfigCopy.blockingTitle, locale: locale),
                message: AppLocalizedString.string(RemoteConfigCopy.stillUnavailableMessage, locale: locale),
                actions: [
                    RemoteConfigNativeAlertAction(
                        title: AppLocalizedString.string(RemoteConfigCopy.stillUnavailableOK, locale: locale),
                        style: .default,
                        handler: { gate.acknowledgeMaintenanceStillUnavailable() }
                    ),
                ]
            )
        )
        .onAppear {
            UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        }
        .onDisappear {
            gate.acknowledgeMaintenanceStillUnavailable()
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

    private var reloadButton: some View {
        DSButton(
            title: AppLocalizedString.string(RemoteConfigCopy.reloadButton, locale: locale),
            type: .primary,
            isLoading: gate.isReloadingMaintenance
        ) {
            gate.reloadMaintenance()
        }
    }

    @ViewBuilder
    private func updateButton(_ force: AppVersionPolicy.Force) -> some View {
        if case .unavailable = force.action {
            EmptyView()
        } else {
            DSButton(
                title: AppLocalizedString.string(RemoteConfigCopy.updateButton, locale: locale),
                type: .primary
            ) {
                RemoteConfigUpdateTrigger.run(force.action) { showTesterAlert = true }
            }
        }
    }
}

private enum RemoteConfigUpdateTrigger {
    static func run(_ action: AppVersionPolicy.UpdateAction, presentTesterAlert: () -> Void) {
        switch action {
        case .openStore(let url):
            RemoteConfigMailOpener.openUpdate(url)
        case .testerAlert:
            presentTesterAlert()
        case .unavailable:
            break
        }
    }
}

/// Internal/dev Update alert. Open mail is the emphasised action.
private struct RemoteConfigTesterUpdateAlert: View {
    var isPresented: Bool
    var locale: Locale
    var installedVersion: String
    var dismiss: () -> Void

    var body: some View {
        RemoteConfigNativeAlert(
            isPresented: isPresented,
            title: AppLocalizedString.string(RemoteConfigCopy.alertTitle, locale: locale),
            message: AppLocalizedString.string(RemoteConfigCopy.alertMessage, locale: locale),
            actions: actions
        )
    }

    private var actions: [RemoteConfigNativeAlertAction] {
        [
            RemoteConfigNativeAlertAction(
                title: AppLocalizedString.string(RemoteConfigCopy.openMail, locale: locale),
                style: .default,
                emphasised: true,
                handler: {
                    dismiss()
                    RemoteConfigMailOpener.openMailApp()
                }
            ),
            RemoteConfigNativeAlertAction(
                title: AppLocalizedString.string(RemoteConfigCopy.requestVersion, locale: locale),
                style: .default,
                handler: {
                    dismiss()
                    let subject = AppLocalizedString.string(RemoteConfigCopy.requestSubject, locale: locale)
                    let template = AppLocalizedString.string(RemoteConfigCopy.requestBody, locale: locale)
                    let body = RemoteConfigTesterMail.requestBody(
                        template: template,
                        installedVersion: installedVersion
                    )
                    RemoteConfigMailOpener.openInvite(subject: subject, body: body)
                }
            ),
            RemoteConfigNativeAlertAction(
                title: AppLocalizedString.string(RemoteConfigCopy.alertCancel, locale: locale),
                style: .cancel,
                handler: dismiss
            ),
        ]
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
            sheetController.sheetPresentationController?.prefersGrabberVisible = false
            // Light-only app (`UIUserInterfaceStyle` = Light): the system sheet surface stays white.
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

private struct RemoteConfigNativeAlertAction {
    var title: String
    var style: UIAlertAction.Style
    /// Native `preferredAction`. That title is white on the black capsule. Other titles stay black.
    var emphasised: Bool = false
    var handler: () -> Void
}

/// Native alert. Action titles are black. An emphasised action is the preferred black capsule.
private struct RemoteConfigNativeAlert: UIViewControllerRepresentable {
    var isPresented: Bool
    var title: String
    var message: String
    var actions: [RemoteConfigNativeAlertAction]

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
            actions: actions,
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
            actions: [RemoteConfigNativeAlertAction],
            from controller: UIViewController
        ) {
            if !isPresented {
                if let alert {
                    let onScreen = alert.presentingViewController != nil || alert.isBeingPresented
                    if onScreen, !alert.isBeingDismissed {
                        alert.dismiss(animated: false)
                    }
                    self.alert = nil
                }
                return
            }
            if let alert, alert.presentingViewController != nil || alert.isBeingPresented {
                return
            }
            alert = nil
            guard let presenter = sheetPresenter(from: controller) else { return }
            guard presenter.presentedViewController == nil else { return }
            let alert = RemoteConfigAlertController(title: title, message: message, preferredStyle: .alert)
            alert.emphasisedTitles = Set(
                actions.filter(\.emphasised).map { $0.title.trimmingCharacters(in: .whitespacesAndNewlines) }
            )
            var preferred: UIAlertAction?
            for action in actions {
                let uiAction = UIAlertAction(title: action.title, style: action.style) { [weak self] _ in
                    self?.alert = nil
                    action.handler()
                }
                alert.addAction(uiAction)
                if action.emphasised { preferred = uiAction }
            }
            alert.preferredAction = preferred
            self.alert = alert
            presenter.present(alert, animated: true)
        }

        /// The force sheet presents above itself. A banner presents from the overlay window root.
        private func sheetPresenter(from controller: UIViewController) -> UIViewController? {
            var current: UIViewController? = controller
            while let candidate = current {
                if candidate.presentingViewController != nil { return candidate }
                current = candidate.parent
            }
            return controller.view.window?.rootViewController
        }
    }
}

/// Action titles are black so they stay readable on the light buttons.
/// Open mail is `preferredAction`. iOS 26+ draws that action as a filled capsule from the
/// controller tint, and `UIAlertAction` has no per-action tint, so the tint is black
/// and that title is painted white and bold. Every other title is painted black after layout.
private final class RemoteConfigAlertController: UIAlertController {
    var emphasisedTitles: Set<String> = []

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        applyActionColors(in: view)
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.applyActionColors(in: self.view)
        }
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        // Layout pass covers iOS resetting the tint. A lone OK stays black text; the preferred capsule fills black.
        view.tintColor = .black
        applyActionColors(in: view)
    }

    private func applyActionColors(in view: UIView) {
        let titles = Set(actions.compactMap { $0.title?.trimmingCharacters(in: .whitespacesAndNewlines) })
        applyActionColors(in: view, titles: titles)
    }

    private func applyActionColors(in view: UIView, titles: Set<String>) {
        if let label = view as? UILabel {
            let text = (label.attributedText?.string ?? label.text ?? "")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            if titles.contains(text) {
                let emphasised = emphasisedTitles.contains(text)
                // White on the black preferred capsule. Black text disappears into that fill.
                // Every other action stays black on the light system button.
                let color: UIColor = emphasised ? .white : .black
                let font = emphasised ? Self.emphasisedFont(from: label.font) : (label.font ?? .systemFont(ofSize: 17))
                let attributed = NSMutableAttributedString(string: text)
                let range = NSRange(location: 0, length: attributed.length)
                attributed.addAttribute(.foregroundColor, value: color, range: range)
                attributed.addAttribute(.font, value: font, range: range)
                label.attributedText = attributed
                label.textColor = color
            }
        }
        if let button = view as? UIButton {
            let title = Self.buttonTitle(button)
            if titles.contains(title) {
                let emphasised = emphasisedTitles.contains(title)
                // White on the black preferred capsule. Black text disappears into that fill.
                // Every other action stays black on the light system button.
                let color: UIColor = emphasised ? .white : .black
                button.tintColor = color
                button.setTitleColor(color, for: .normal)
                button.setTitleColor(color, for: .highlighted)
                if var configuration = button.configuration {
                    configuration.baseForegroundColor = color
                    configuration.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { incoming in
                        var outgoing = incoming
                        outgoing.foregroundColor = color
                        if emphasised {
                            outgoing.font = Self.emphasisedFont(from: incoming.font)
                        }
                        return outgoing
                    }
                    button.configuration = configuration
                }
                if emphasised {
                    button.titleLabel?.font = Self.emphasisedFont(from: button.titleLabel?.font)
                }
            }
        }
        for subview in view.subviews {
            applyActionColors(in: subview, titles: titles)
        }
    }

    private static func buttonTitle(_ button: UIButton) -> String {
        let title = button.configuration?.title ?? button.currentTitle ?? button.titleLabel?.text ?? ""
        return title.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func emphasisedFont(from font: UIFont?) -> UIFont {
        let base = font ?? .systemFont(ofSize: 17)
        let traits = base.fontDescriptor.symbolicTraits.union(.traitBold)
        if let descriptor = base.fontDescriptor.withSymbolicTraits(traits) {
            return UIFont(descriptor: descriptor, size: base.pointSize)
        }
        return .boldSystemFont(ofSize: base.pointSize)
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
