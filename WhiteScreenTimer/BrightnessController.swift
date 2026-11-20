import UIKit

/// 负责把屏幕亮度拉到最亮，并在结束时还原成用户原来的亮度。
/// 注意：所有 UIKit 调用都在主线程执行。
final class BrightnessController {

    static let shared = BrightnessController()

    /// 进入应用前的原始亮度，nil 表示当前不在"最亮"状态
    private var originalBrightness: CGFloat?

    private init() {}

    /// 拉到最亮，同时禁止自动锁屏
    func boost() {
        onMain {
            guard self.originalBrightness == nil else {
                UIScreen.main.brightness = 1.0
                return
            }
            let screen = UIScreen.main
            self.originalBrightness = screen.brightness
            screen.brightness = 1.0
            UIApplication.shared.isIdleTimerDisabled = true
        }
    }

    /// 还原原始亮度，恢复自动锁屏
    func restore() {
        onMain {
            if let original = self.originalBrightness {
                UIScreen.main.brightness = original
                self.originalBrightness = nil
            }
            UIApplication.shared.isIdleTimerDisabled = false
        }
    }

    private func onMain(_ work: @escaping () -> Void) {
        if Thread.isMainThread {
            work()
        } else {
            DispatchQueue.main.async(execute: work)
        }
    }
}
