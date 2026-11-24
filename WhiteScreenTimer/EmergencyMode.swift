import SwiftUI
import UIKit
import AVFoundation
import QuartzCore

// MARK: - 屏幕模式

enum ScreenMode: String, CaseIterable, Identifiable {
    case nightLight = "light"
    case police     = "police"
    case sos        = "sos"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .nightLight: return "夜灯"
        case .police:     return "警灯"
        case .sos:        return "摩斯求救"
        }
    }

    /// 应急模式默认常亮（不自动退出）
    var forcesAlwaysOn: Bool { self != .nightLight }
}

// MARK: - 闪光灯控制

final class TorchController {

    static let shared = TorchController()

    private let device = AVCaptureDevice.default(for: .video)
    private var currentState: Bool?

    private init() {}

    var isAvailable: Bool { device?.hasTorch == true }

    /// 提前申请相机权限（闪光灯属于 AVCaptureDevice）
    static func requestPermission(completion: @escaping (Bool) -> Void) {
        AVCaptureDevice.requestAccess(for: .video) { granted in
            DispatchQueue.main.async { completion(granted) }
        }
    }

    func set(on: Bool) {
        guard let device, device.hasTorch, currentState != on else { return }
        currentState = on
        do {
            try device.lockForConfiguration()
            if device.isTorchModeSupported(on ? .on : .off) {
                device.torchMode = on ? .on : .off
            }
            device.unlockForConfiguration()
        } catch {
            // 无法控制闪光灯时静默降级到屏幕闪烁
        }
    }

    func turnOff() { set(on: false) }
}

// MARK: - 信号引擎（警灯 / 摩斯）

/// 用 CADisplayLink 按时间轴驱动：警灯红蓝爆闪、SOS 摩斯电码（三短三长三短）。
final class SignalEngine: ObservableObject {

    private struct Segment {
        let isOn: Bool
        let duration: TimeInterval
        let color: Color
    }

    /// nil 表示"不接管屏幕颜色"，用设置里的色调
    @Published private(set) var screenColor: Color?
    @Published private(set) var torchOn: Bool = false

    static let policeRed  = Color(red: 1.0,  green: 0.06, blue: 0.06)
    static let policeBlue = Color(red: 0.03, green: 0.18, blue: 1.0)
    static let sosWhite   = Color.white

    private var displayLink: CADisplayLink?
    private var startTime: CFTimeInterval = 0
    private var segments: [Segment] = []
    private var cycleDuration: TimeInterval = 0
    private var usesTorch = false
    private var running = false
    private var lastAppliedOn: Bool?

    // MARK: 启停

    func start(mode: ScreenMode, useTorch: Bool) {
        stop()

        switch mode {
        case .nightLight:
            return
        case .police:
            segments = Self.policeSegments
            usesTorch = false          // 警灯效果始终画在屏幕上
        case .sos:
            segments = Self.sosSegments
            usesTorch = useTorch && TorchController.shared.isAvailable
        }

        cycleDuration = segments.reduce(0) { $0 + $1.duration }
        guard cycleDuration > 0 else { return }

        running = true
        startTime = CACurrentMediaTime()
        lastAppliedOn = nil

        let link = CADisplayLink(target: self, selector: #selector(step))
        link.preferredFramesPerSecond = 30
        link.add(to: .main, forMode: .common)
        displayLink = link
    }

    func stop() {
        running = false
        displayLink?.invalidate()
        displayLink = nil
        screenColor = nil
        torchOn = false
        TorchController.shared.turnOff()
        lastAppliedOn = nil
    }

    // MARK: 时间轴驱动

    @objc private func step() {
        guard running, cycleDuration > 0 else { return }
        let elapsed = CACurrentMediaTime() - startTime
        let t = elapsed.truncatingRemainder(dividingBy: cycleDuration)

        var cursor: TimeInterval = 0
        for seg in segments {
            if t < cursor + seg.duration {
                apply(segment: seg)
                return
            }
            cursor += seg.duration
        }
        if let last = segments.last { apply(segment: last) }
    }

    private func apply(segment: Segment) {
        if usesTorch {
            screenColor = nil                       // 闪光灯模式下屏幕保持设定色调
        } else {
            screenColor = segment.isOn ? segment.color : Color.black
        }

        if lastAppliedOn != segment.isOn {
            lastAppliedOn = segment.isOn
            torchOn = segment.isOn
            TorchController.shared.set(on: segment.isOn)
        }
    }

    // MARK: 图案定义

    /// 警灯：红红-蓝蓝 爆闪，1 秒一个循环
    private static let policeSegments: [Segment] = {
        let dark = Color.black
        func seg(_ on: Bool, _ d: TimeInterval, _ c: Color) -> Segment {
            Segment(isOn: on, duration: d, color: c)
        }
        return [
            seg(true,  0.16, policeRed),  seg(false, 0.07, dark),
            seg(true,  0.16, policeRed),  seg(false, 0.16, dark),
            seg(true,  0.16, policeBlue), seg(false, 0.07, dark),
            seg(true,  0.16, policeBlue), seg(false, 0.22, dark)
        ]
    }()

    /// SOS：三短 / 三长 / 三短，单位 0.2 秒，末尾留 7 单位间隔循环
    private static let sosSegments: [Segment] = {
        let unit: TimeInterval = 0.2
        var list: [Segment] = []

        func letter(_ marks: Int, duration: TimeInterval) {
            for i in 0..<marks {
                if i > 0 { list.append(Segment(isOn: false, duration: unit, color: .black)) }
                list.append(Segment(isOn: true, duration: duration, color: sosWhite))
            }
        }

        letter(3, duration: unit)          // S: 三短
        list.append(Segment(isOn: false, duration: unit * 3, color: .black))
        letter(3, duration: unit * 3)      // O: 三长
        list.append(Segment(isOn: false, duration: unit * 3, color: .black))
        letter(3, duration: unit)          // S: 三短
        list.append(Segment(isOn: false, duration: unit * 7, color: .black))
        return list
    }()
}
