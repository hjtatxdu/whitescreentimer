import UIKit
import QuartzCore

/// 亮度控制：启动 1.5 秒渐变到最亮，退出 5 秒渐变回原亮度。
/// 用 CADisplayLink 逐帧推进（比 Timer 稳定，不会被系统节流）。
final class BrightnessController {

    static let shared = BrightnessController()

    /// 进入应用前的原始亮度，nil 表示还没记录过
    private var originalBrightness: CGFloat?

    // 渐变状态
    private var displayLink: CADisplayLink?
    private var rampStart: CFTimeInterval = 0
    private var rampFrom: CGFloat = 1
    private var rampTo: CGFloat = 1
    private var rampDuration: Double = 0
    private var rampCompletion: (() -> Void)?

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

    /// 渐降回原始亮度（到点退出时用）
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

    /// 立即还原（兜底：应用被终止、出现异常、切到后台时）
    func dimNow() {
        onMain {
            self.stopRamp()
            if let original = self.originalBrightness {
                UIScreen.main.brightness = original
            }
            UIApplication.shared.isIdleTimerDisabled = false
        }
    }

    // MARK: - 渐变实现

    private func ramp(to target: CGFloat, duration: TimeInterval, completion: (() -> Void)?) {
        stopRamp()

        let screen = UIScreen.main
        let from = screen.brightness

        guard duration > 0, abs(target - from) > 0.005 else {
            screen.brightness = target
            completion?()
            return
        }

        rampFrom = from
        rampTo = target
        rampDuration = max(0.05, duration)
        rampCompletion = completion
        rampStart = CACurrentMediaTime()

        let link = CADisplayLink(target: self, selector: #selector(step))
        link.preferredFramesPerSecond = 30
        link.add(to: .main, forMode: .common)
        displayLink = link
    }

    @objc private func step() {
        let elapsed = CACurrentMediaTime() - rampStart
        let rawProgress = min(1.0, max(0.0, elapsed / rampDuration))
        let eased = CGFloat(0.5 - 0.5 * cos(rawProgress * Double.pi))   // 缓入缓出

        UIScreen.main.brightness = rampFrom + (rampTo - rampFrom) * eased

        if rawProgress >= 1.0 {
            UIScreen.main.brightness = rampTo
            let completion = rampCompletion
            stopRamp()
            completion?()
        }
    }

    private func stopRamp() {
        displayLink?.invalidate()
        displayLink = nil
        rampCompletion = nil
    }

    private func onMain(_ work: @escaping () -> Void) {
        if Thread.isMainThread {
            work()
        } else {
            DispatchQueue.main.async(execute: work)
        }
    }
}
