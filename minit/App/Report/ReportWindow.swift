#if MINIT_SHAKE
import ObjectiveC
import UIKit

enum ShakeReportWindow {
    static let didShake = Notification.Name("minit.deviceShake")

    static func disableShakeToEdit() {
        UIApplication.shared.applicationSupportsShakeToEdit = false
    }
}

extension UIWindow {
    open override func motionEnded(_ motion: UIEvent.EventSubtype, with event: UIEvent?) {
        super.motionEnded(motion, with: event)
        guard motion == .motionShake else { return }
        NotificationCenter.default.post(name: ShakeReportWindow.didShake, object: nil)
    }

    /// Installed in place of `sendEvent`. After the exchange, this name calls UIKit's implementation.
    @objc(minit_sendEvent:)
    func minit_sendEvent(_ event: UIEvent) {
        guard event.type == .touches else {
            minit_sendEvent(event)
            return
        }
        ShakeReportTouches.deliver(event, in: self) {
            minit_sendEvent(event)
        }
    }
}

extension UINavigationController {
    /// Installed in place of `popViewControllerAnimated:`. Calls UIKit's implementation after the exchange.
    @objc(minit_popViewControllerAnimated:)
    func minit_popViewController(animated: Bool) -> UIViewController? {
        let popped = minit_popViewController(animated: animated)
        if popped != nil {
            ShakeReportTouches.considerPop(on: self)
        }
        return popped
    }

    @objc(minit_popToRootViewControllerAnimated:)
    func minit_popToRootViewController(animated: Bool) -> [UIViewController]? {
        let popped = minit_popToRootViewController(animated: animated)
        if let popped, !popped.isEmpty {
            ShakeReportTouches.considerPop(on: self)
        }
        return popped
    }

    @objc(minit_popToViewController:animated:)
    func minit_popToViewController(_ viewController: UIViewController, animated: Bool) -> [UIViewController]? {
        let popped = minit_popToViewController(viewController, animated: animated)
        if let popped, !popped.isEmpty {
            ShakeReportTouches.considerPop(on: self)
        }
        return popped
    }

    @objc(minit_pushViewController:animated:)
    func minit_pushViewController(_ viewController: UIViewController, animated: Bool) {
        minit_pushViewController(viewController, animated: animated)
        ShakeReportPopWatcher.shared.attach(to: self)
    }
}

/// Hears the interactive pop gesture. Attached once the navigation stack can pop.
final class ShakeReportPopWatcher: NSObject {
    static let shared = ShakeReportPopWatcher()
    private static var attachedKey: UInt8 = 0
    private let counts = NSMapTable<UINavigationController, NSNumber>.weakToStrongObjects()

    func attach(to nav: UINavigationController) {
        guard let gesture = nav.interactivePopGestureRecognizer else { return }
        if objc_getAssociatedObject(nav, &Self.attachedKey) != nil { return }
        objc_setAssociatedObject(nav, &Self.attachedKey, true as NSNumber, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        gesture.addTarget(self, action: #selector(changed(_:)))
    }

    @objc private func changed(_ gesture: UIGestureRecognizer) {
        guard let nav = navigationController(for: gesture) else { return }
        switch gesture.state {
        case .began:
            counts.setObject(NSNumber(value: nav.viewControllers.count), forKey: nav)
        case .cancelled, .failed:
            counts.removeObject(forKey: nav)
            ShakeReportTouches.cancelInteractiveBack()
        case .ended:
            let before = counts.object(forKey: nav)?.intValue
            counts.removeObject(forKey: nav)
            ShakeReportTouches.interactivePopEnded(on: nav, countAtBegan: before)
        default:
            break
        }
    }

    private func navigationController(for gesture: UIGestureRecognizer) -> UINavigationController? {
        var responder: UIResponder? = gesture.view
        while let current = responder {
            if let nav = current as? UINavigationController { return nav }
            responder = current.next
        }
        return nil
    }
}

enum ShakeReportHooks {
    private static var didSend = false
    private static var didPop = false
    private static var didPopRoot = false
    private static var didPopTo = false
    private static var didPush = false

    /// SwiftUI owns `UIWindow` and `UINavigationController`, and these entry points are not
    /// overridable from an extension in this language mode. Exchange each one once.
    /// Only call this when internal reporting is on: every touch then enters the hook.
    static func install() {
        if !didSend {
            didSend = swizzle(UIWindow.self, "sendEvent:", "minit_sendEvent:")
        }
        if !didPop {
            didPop = swizzle(UINavigationController.self, "popViewControllerAnimated:", "minit_popViewControllerAnimated:")
        }
        if !didPopRoot {
            didPopRoot = swizzle(
                UINavigationController.self,
                "popToRootViewControllerAnimated:",
                "minit_popToRootViewControllerAnimated:"
            )
        }
        if !didPopTo {
            didPopTo = swizzle(
                UINavigationController.self,
                "popToViewController:animated:",
                "minit_popToViewController:animated:"
            )
        }
        if !didPush {
            didPush = swizzle(UINavigationController.self, "pushViewController:animated:", "minit_pushViewController:animated:")
        }
    }

    /// Exchanges a method only when `cls` implements it. An inherited implementation belongs
    /// to the superclass, and swapping that would change every subclass.
    private static func swizzle(_ cls: AnyClass, _ original: String, _ replacement: String) -> Bool {
        let originalSelector = NSSelectorFromString(original)
        let replacementSelector = NSSelectorFromString(replacement)
        guard
            let originalMethod = ownMethod(cls, originalSelector),
            let replacementMethod = class_getInstanceMethod(cls, replacementSelector)
        else { return false }
        method_exchangeImplementations(originalMethod, replacementMethod)
        return true
    }

    private static func ownMethod(_ cls: AnyClass, _ selector: Selector) -> Method? {
        guard let method = class_getInstanceMethod(cls, selector) else { return nil }
        if let superclass = class_getSuperclass(cls),
           let inherited = class_getInstanceMethod(superclass, selector),
           method == inherited {
            return nil
        }
        return method
    }
}
#endif
