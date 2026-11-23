import UIKit

/// 亮度控制：支持"渐变"到目标亮度（启动 1.5 秒升到最亮、退出 5 秒降回原亮度）。
/// 所有 UIKit 调用都在主线程执行。
final class BrightnessController {

    static let shared = BrightnessController()

    /// 进入应用前的原始亮度，nil 表示还没记录过
    private var originalBrightness: CGFloat?
    private var rampTimer: Timer?
    private var dimTaskId: UIBackgroundTaskIdentifier = .invalid

    private init() {}

    // MARK: - 对外接口

    /// 渐增到最亮（启动、回到前台时用）
    func brighten(duration: TimeInterval) {
        onMain {
            if self.originalBrightness == nil {
                self.originalBrightness = UIScreen.main.brightness
            }
            UIApplication.shared.isIdleTimerDisabled = true
            self.ramp(to: 1.0, duration: duration, completion: nil)
        }
    }

    /// 渐降回原始亮度（自动退出时用）
    func dim(duration: TimeInterval, completion: (() -> Void)? = nil) {
        onMain {
            guard let original = self.originalBrightness else {
                UIApplication.shared.isIdleTimerDisabled = false
                completion?()
                return
            }
            self.ramp(to: original, duration: duration) {
                UIApplication.shared.isIdleTimerDisabled = false
                completion?()
            }
        }
    }

    /// 切到后台时：申请后台执行时间，把亮度用 5 秒降回去；系统回收后台时间就立即兜底还原
    func dimInBackground(duration: TimeInterval) {
        onMain {
            self.endDimTask()
            self.dimTaskId = UIApplication.shared.beginBackgroundTask(withName: "AutoNightLight.dim") { [weak self] in
                // 系统给的后台时间用尽：直接还原，避免亮度停在半路
                self?.dimNow()
            }
            self.dim(duration: duration) { [weak self] in
                self?.endDimTask()
            }
        }
    }

    /// 立即还原（兜底：应用被终止、出现异常时）
    func dimNow() {
        onMain {
            self.rampTimer?.invalidate()
            self.rampTimer = nil
            if let original = self.originalBrightness {
                UIScreen.main.brightness = original
            }
            UIApplication.shared.isIdleTimerDisabled = false
            self.endDimTask()
        }
    }

    // MARK: - 渐变实现

    private func ramp(to target: CGFloat, duration: TimeInterval, completion: (() -> Void)?) {
        rampTimer?.invalidate()
        rampTimer = nil

        let screen = UIScreen.main
        let from = screen.brightness

        guard duration > 0, abs(target - from) > 0.005 else {
            screen.brightness = target
            completion?()
            return
        }

        let steps = max(1, Int(duration * 30))
        var step = 0
        let timer = Timer(timeInterval: 1.0 / 30.0, repeats: true) { [weak self] t in
            step += 1
            let progress = min(1.0, Double(step) / Double(steps))
            let eased = CGFloat(0.5 - 0.5 * cos(progress * Double.pi))   // 缓入缓出，不突兀
            screen.brightness = from + (target - from) * eased
            if progress >= 1.0 {
                t.invalidate()
                screen.brightness = target
                self?.rampTimer = nil
                completion?()
            }
        }
        rampTimer = timer
        RunLoop.main.add(timer, forMode: .common)
    }

    private func endDimTask() {
        if dimTaskId != .invalid {
            UIApplication.shared.endBackgroundTask(dimTaskId)
            dimTaskId = .invalid
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
