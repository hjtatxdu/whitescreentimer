import Foundation
import Combine

/// 设置项：屏幕色调、退出时间（分钟，默认 3，范围 1...10）、常亮（不自动退出）
final class SettingsStore: ObservableObject {

    private enum Key {
        static let minutes  = "exitMinutes"
        static let tone     = "screenToneHex"
        static let alwaysOn = "alwaysOn"
    }

    static let defaultMinutes = 3
    static let range = 1...10

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

        self.alwaysOn = UserDefaults.standard.bool(forKey: Key.alwaysOn)        // 默认 false
    }

    private static func isValidHex(_ hex: String) -> Bool {
        var s = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if s.hasPrefix("#") { s.removeFirst() }
        guard s.count == 6 else { return false }
        return s.allSatisfy { $0.isHexDigit }
    }
}
