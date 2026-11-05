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
    static let testerBody = "remoteConfig.update.testerBody"
    static let updateButton = "remoteConfig.update.update"
    static let laterButton = "remoteConfig.update.later"
    static let dismissBanner = "remoteConfig.banner.dismiss"
}

/// Hosts the maintenance and update UI above every screen, including sheets.
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
        private var fullScreenHost: UIHostingController<RemoteConfigFullScreen>?
        private var bannerHost: UIHostingController<RemoteConfigBannerBar>?
        private var bannerHeight: NSLayoutConstraint?
        private var sceneRetries = 0
        private var blockingUnderlyingApp = false

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
            let languageCode = RemoteConfigLanguage.code(from: locale)
            let decision = gate.decision(languageCode: languageCode)
            let showsFullScreen = decision.blocking != nil || decision.update != nil
            let bannerOnly = decision.banner != nil && !showsFullScreen

            if showsFullScreen {
                let host = fullScreenHost ?? makeFullScreenHost(in: window)
                host.rootView = RemoteConfigFullScreen(gate: gate, locale: locale)
                host.view.isHidden = false
            } else {
                fullScreenHost?.view.isHidden = true
            }

            if bannerOnly {
                let host = bannerHost ?? makeBannerHost(in: window)
                host.rootView = RemoteConfigBannerBar(
                    message: decision.banner?.message ?? "",
                    dismissTitle: AppLocalizedString.string(RemoteConfigCopy.dismissBanner, locale: locale),
                    onDismiss: {
                        if let identity = decision.banner?.identity {
                            gate.dismissBanner(identity: identity)
                        }
                    }
                )
                host.view.isHidden = false
                resizeBanner(host, in: window)
            } else {
                bannerHost?.view.isHidden = true
            }

            window.isHidden = !showsFullScreen && !bannerOnly
            applyBlockingAccessibility(on: window, decision: decision)
        }

        /// Blocking and force cover the app. The overlay root is modal for VoiceOver, and the
        /// underlying first responder is resigned so a hardware keyboard cannot keep typing there.
        private func applyBlockingAccessibility(on window: OverlayWindow, decision: AppVersionPolicy.Decision) {
            let blocksUnderlyingApp = decision.blocking != nil || {
                if case .force = decision.update { return true }
                return false
            }()
            let rootView = window.rootViewController?.view
            let becameBlocking = blocksUnderlyingApp && (rootView?.accessibilityViewIsModal != true || !blockingUnderlyingApp)
            rootView?.accessibilityViewIsModal = blocksUnderlyingApp
            if becameBlocking {
                UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
            }
            blockingUnderlyingApp = blocksUnderlyingApp
        }

        private func window(for scene: UIWindowScene) -> OverlayWindow {
            if let window, window.windowScene === scene { return window }
            let window = OverlayWindow(windowScene: scene)
            window.windowLevel = .alert
            window.backgroundColor = .clear
            let root = OverlayRootController()
            window.rootViewController = root
            self.window = window
            fullScreenHost = nil
            bannerHost = nil
            bannerHeight = nil
            return window
        }

        private func makeFullScreenHost(in window: OverlayWindow) -> UIHostingController<RemoteConfigFullScreen> {
            let host = UIHostingController(rootView: RemoteConfigFullScreen(gate: RemoteConfigGate.shared, locale: .current))
            host.view.backgroundColor = .clear
            embed(host, in: window) { parent in
                [
                    host.view.leadingAnchor.constraint(equalTo: parent.leadingAnchor),
                    host.view.trailingAnchor.constraint(equalTo: parent.trailingAnchor),
                    host.view.topAnchor.constraint(equalTo: parent.topAnchor),
                    host.view.bottomAnchor.constraint(equalTo: parent.bottomAnchor),
                ]
            }
            fullScreenHost = host
            return host
        }

        private func makeBannerHost(in window: OverlayWindow) -> UIHostingController<RemoteConfigBannerBar> {
            let host = UIHostingController(
                rootView: RemoteConfigBannerBar(message: "", dismissTitle: "", onDismiss: {})
            )
            host.view.backgroundColor = .clear
            host.sizingOptions = .intrinsicContentSize
            let height = host.view.heightAnchor.constraint(equalToConstant: 1)
            height.priority = .defaultHigh
            embed(host, in: window) { parent in
                [
                    host.view.leadingAnchor.constraint(equalTo: parent.leadingAnchor),
                    host.view.trailingAnchor.constraint(equalTo: parent.trailingAnchor),
                    host.view.topAnchor.constraint(equalTo: parent.safeAreaLayoutGuide.topAnchor),
                    height,
                ]
            }
            bannerHeight = height
            bannerHost = host
            return host
        }

        private func embed(
            _ host: UIViewController,
            in window: OverlayWindow,
            constraints: (UIView) -> [NSLayoutConstraint]
        ) {
            guard let parent = window.rootViewController else { return }
            parent.addChild(host)
            host.view.translatesAutoresizingMaskIntoConstraints = false
            parent.view.addSubview(host.view)
            NSLayoutConstraint.activate(constraints(parent.view))
            host.didMove(toParent: parent)
        }

        private func resizeBanner(_ host: UIHostingController<RemoteConfigBannerBar>, in window: OverlayWindow) {
            let width = window.bounds.width > 1 ? window.bounds.width : (window.windowScene?.screen.bounds.width ?? 0)
            let fitting = host.sizeThatFits(in: CGSize(width: width, height: .greatestFiniteMagnitude))
            bannerHeight?.constant = max(fitting.height, 1)
        }
    }
}

private final class OverlayWindow: UIWindow {
    static var foregroundScene: UIWindowScene? {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        return scenes.first { $0.activationState == .foregroundActive } ?? scenes.first
    }
}

private final class OverlayRootController: UIViewController {
    override func loadView() {
        view = PassThroughRootView()
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .clear
    }
}

private final class PassThroughRootView: UIView {
    override func point(inside point: CGPoint, with event: UIEvent?) -> Bool {
        subviews.contains { subview in
            guard !subview.isHidden, subview.alpha > 0.01, subview.isUserInteractionEnabled else { return false }
            return subview.point(inside: convert(point, to: subview), with: event)
        }
    }
}

struct RemoteConfigFullScreen: View {
    @ObservedObject var gate: RemoteConfigGate
    var locale: Locale

    var body: some View {
        let decision = gate.decision(languageCode: RemoteConfigLanguage.code(from: locale))
        ZStack {
            if let blocking = decision.blocking {
                messageColumn(
                    title: AppLocalizedString.string(RemoteConfigCopy.blockingTitle, locale: locale),
                    body: blockingBody(blocking),
                    prompt: nil
                )
                .background(DSColor.Background.Layer.level0.ignoresSafeArea())
            } else if case .force(let prompt) = decision.update {
                messageColumn(
                    title: AppLocalizedString.string(RemoteConfigCopy.forceTitle, locale: locale),
                    body: updateBody(prompt, kind: .force),
                    prompt: prompt
                )
                .background(DSColor.Background.Layer.level0.ignoresSafeArea())
            } else if case .soft(let prompt) = decision.update {
                Color.black.opacity(0.45).ignoresSafeArea()
                softCard(prompt)
                if let banner = decision.banner {
                    RemoteConfigBannerBar(
                        message: banner.message,
                        dismissTitle: AppLocalizedString.string(RemoteConfigCopy.dismissBanner, locale: locale),
                        onDismiss: { gate.dismissBanner(identity: banner.identity) }
                    )
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .contentShape(Rectangle())
        .environment(\.locale, locale)
        .accessibilityAddTraits(.isModal)
    }

    private func blockingBody(_ blocking: AppVersionPolicy.Blocking) -> String {
        switch blocking.body {
        case .remote(let text):
            return text
        case .catalogFallback:
            return AppLocalizedString.string(RemoteConfigCopy.blockingFallback, locale: locale)
        }
    }

    private func updateBody(_ prompt: AppVersionPolicy.Prompt, kind: UpdateKind) -> String {
        if prompt.usesTesterCopy {
            return AppLocalizedString.string(RemoteConfigCopy.testerBody, locale: locale)
        }
        switch kind {
        case .force:
            return AppLocalizedString.string(RemoteConfigCopy.forceReleaseBody, locale: locale)
        case .soft:
            return AppLocalizedString.string(RemoteConfigCopy.softReleaseBody, locale: locale)
        }
    }

    private func messageColumn(
        title: String,
        body: String,
        prompt: AppVersionPolicy.Prompt?
    ) -> some View {
        VStack(spacing: DSConstant.medium.value) {
            Text(title)
                .typography(.headingMediumBold)
                .foregroundColor(DSColor.Text.heading)
                .multilineTextAlignment(.center)
                .accessibilityAddTraits(.isHeader)
            Text(body)
                .typography(.paragraphRegular)
                .foregroundColor(DSColor.Text.secondary)
                .multilineTextAlignment(.center)
            if let url = prompt?.updateURL {
                DSButton(
                    title: AppLocalizedString.string(RemoteConfigCopy.updateButton, locale: locale),
                    type: .primary
                ) {
                    UIApplication.shared.open(url)
                }
            }
        }
        .padding(DSConstant.large.value)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .contentShape(Rectangle())
    }

    private func softCard(_ prompt: AppVersionPolicy.Prompt) -> some View {
        VStack(spacing: DSConstant.medium.value) {
            Text(AppLocalizedString.string(RemoteConfigCopy.softTitle, locale: locale))
                .typography(.headingMediumBold)
                .foregroundColor(DSColor.Text.heading)
                .multilineTextAlignment(.center)
                .accessibilityAddTraits(.isHeader)
            Text(updateBody(prompt, kind: .soft))
                .typography(.paragraphRegular)
                .foregroundColor(DSColor.Text.secondary)
                .multilineTextAlignment(.center)
            if let url = prompt.updateURL {
                DSButton(
                    title: AppLocalizedString.string(RemoteConfigCopy.updateButton, locale: locale),
                    type: .primary
                ) {
                    UIApplication.shared.open(url)
                }
            }
            DSButton(
                title: AppLocalizedString.string(RemoteConfigCopy.laterButton, locale: locale),
                type: .tertiary
            ) {
                if let threshold = prompt.softThreshold {
                    gate.dismissSoftUpdate(threshold: threshold)
                }
            }
        }
        .padding(DSConstant.large.value)
        .frame(maxWidth: 420)
        .background(DSColor.Background.Layer.level1)
        .clipShape(RoundedRectangle(cornerRadius: DSConstant.cardCornerRadius.value))
        .padding(DSConstant.large.value)
    }

    private enum UpdateKind {
        case force
        case soft
    }
}

struct RemoteConfigBannerBar: View {
    var message: String
    var dismissTitle: String
    var onDismiss: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: DSConstant.small.value) {
            DSIcon.warningTriangle.image
                .foregroundColor(DSColor.Border.error)
                .accessibilityHidden(true)
            Text(message)
                .typography(.paragraphRegular)
                .foregroundColor(DSColor.Text.primary)
                .frame(maxWidth: .infinity, alignment: .leading)
            Button(action: onDismiss) {
                Text(dismissTitle)
                    .typography(.paragraphRegular)
                    .foregroundColor(DSColor.Text.accent)
            }
            .accessibilityLabel(dismissTitle)
        }
        .padding(DSConstant.medium.value)
        .background(DSColor.Background.Layer.level1)
        .clipShape(RoundedRectangle(cornerRadius: DSConstant.small.value))
        .padding(.horizontal, DSConstant.mediumLarge.value)
        .padding(.top, DSConstant.small.value)
        .padding(.bottom, DSConstant.small.value)
    }
}
