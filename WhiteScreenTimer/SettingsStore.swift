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

    /// 模式：只记录用户选择，不再改写「常亮」
    @Published var mode: ScreenMode {
        didSet {
            UserDefaults.standard.set(mode.rawValue, forKey: Key.mode)
        }
    }

    /// 摩斯信号是否同时用手机闪光灯：false = 仅屏幕闪，true = 屏幕 + 闪光灯同时闪
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

    // MARK: - 常亮
    // 夜灯有自己的常亮开关；警灯 / 摩斯求救固定常亮。
    // 两者分开存，切模式互不干扰。

    /// 夜灯模式的「常亮」开关（持久化，仅夜灯模式可改）
    @Published var nightAlwaysOn: Bool {
        didSet {
            UserDefaults.standard.set(nightAlwaysOn, forKey: Key.alwaysOn)
        }
    }

    /// 当前模式实际的常亮状态：应急模式恒为 true，夜灯模式看用户开关
    var alwaysOn: Bool { mode.forcesAlwaysOn || nightAlwaysOn }

    init() {
        let storedMinutes = UserDefaults.standard.integer(forKey: Key.minutes)   // 未设置时为 0
        self.minutes = Self.range.contains(storedMinutes) ? storedMinutes : Self.defaultMinutes

        let storedTone = UserDefaults.standard.string(forKey: Key.tone)
        let validTone = storedTone.flatMap { Self.isValidHex($0) ? $0.uppercased() : nil }
        self.toneHex = validTone ?? ScreenTone.pureWhite

        let storedMode = ScreenMode(rawValue: UserDefaults.standard.string(forKey: Key.mode) ?? "")
        self.mode = storedMode ?? .nightLight
        self.morseTorch = UserDefaults.standard.bool(forKey: Key.morseTorch)
        self.nightAlwaysOn = UserDefaults.standard.bool(forKey: Key.alwaysOn)
    }

    private static func isValidHex(_ hex: String) -> Bool {
        var s = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if s.hasPrefix("#") { s.removeFirst() }
        guard s.count == 6 else { return false }
        return s.allSatisfy { $0.isHexDigit }
    }
}
