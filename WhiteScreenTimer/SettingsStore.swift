import Foundation
import Combine

/// 设置项：模式（夜灯 / 警灯 / 摩斯求救）、屏幕色调、摩斯输出方式、常亮、退出时间
final class SettingsStore: ObservableObject {

    private enum Key {
        static let minutes    = "exitMinutes"
        static let tone       = "screenToneHex"
        static let alwaysOn   = "alwaysOn"
        static let mode       = "screenMode"
        static let morseTorch = "morseUsesTorch"
    }

    static let defaultMinutes = 3
    static let range = 1...10

    // MARK: - 模式（警灯 / 摩斯默认常亮）

    @Published var mode: ScreenMode {
        didSet {
            UserDefaults.standard.set(mode.rawValue, forKey: Key.mode)
            if mode.forcesAlwaysOn && !alwaysOn {
                alwaysOn = true          // 应急模式默认常亮
            }
        }
    }

    /// 摩斯信号的输出方式：false = 屏幕闪烁，true = 手机闪光灯
    @Published var morseTorch: Bool {
        didSet {
            UserDefaults.standard.set(morseTorch, forKey: Key.morseTorch)
        }
    }

    // MARK: - 退出时间

    @Published var minutes: Int {
        didSet {
            let clamped = min(max(minutes, Self.range.lowerBound), Self.range.upperBound)
            if clamped != minutes {
                minutes = clamped          // 触发下一次 didSet，由它完成保存
                return
            }
            UserDefaults.standard.set(minutes, forKey: Key.minutes)
        }
    }

    // MARK: - 屏幕色调（"#RRGGBB"）

    @Published var toneHex: String {
        didSet {
            UserDefaults.standard.set(toneHex, forKey: Key.tone)
        }
    }

    // MARK: - 常亮（开启后不自动退出）

    @Published var alwaysOn: Bool {
        didSet {
            UserDefaults.standard.set(alwaysOn, forKey: Key.alwaysOn)
        }
    }

    init() {
        let storedMinutes = UserDefaults.standard.integer(forKey: Key.minutes)   // 未设置时为 0
        self.minutes = Self.range.contains(storedMinutes) ? storedMinutes : Self.defaultMinutes

        let storedTone = UserDefaults.standard.string(forKey: Key.tone)
        let validTone = storedTone.flatMap { Self.isValidHex($0) ? $0.uppercased() : nil }
        self.toneHex = validTone ?? ScreenTone.pureWhite

        let storedMode = ScreenMode(rawValue: UserDefaults.standard.string(forKey: Key.mode) ?? "")
        let resolvedMode = storedMode ?? .nightLight
        self.mode = resolvedMode
        self.morseTorch = UserDefaults.standard.bool(forKey: Key.morseTorch)

        // 应急模式必须常亮；夜灯模式沿用上次的选择
        self.alwaysOn = resolvedMode.forcesAlwaysOn ? true : UserDefaults.standard.bool(forKey: Key.alwaysOn)
    }

    private static func isValidHex(_ hex: String) -> Bool {
        var s = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if s.hasPrefix("#") { s.removeFirst() }
        guard s.count == 6 else { return false }
        return s.allSatisfy { $0.isHexDigit }
    }
}
