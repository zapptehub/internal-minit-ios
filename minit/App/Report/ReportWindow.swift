#if MINIT_SHAKE
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
}
#endif
