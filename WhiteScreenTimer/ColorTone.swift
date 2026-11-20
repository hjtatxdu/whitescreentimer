import SwiftUI
import UIKit

// MARK: - 颜色与十六进制互转

extension Color {

    init(hex: String) {
        var s = hex.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        if s.hasPrefix("#") { s.removeFirst() }
        if s.count == 3 { s = s.map { "\($0)\($0)" }.joined() }
        let value = UInt64(s, radix: 16) ?? 0xFFFFFF
        let r = Double((value >> 16) & 0xFF) / 255.0
        let g = Double((value >> 8) & 0xFF) / 255.0
        let b = Double(value & 0xFF) / 255.0
        self = Color(.sRGB, red: r, green: g, blue: b, opacity: 1)
    }

    /// 转成 "#RRGGBB"，用于持久化
    var hexString: String {
        let ui = UIColor(self)
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        ui.getRed(&r, green: &g, blue: &b, alpha: &a)
        let ri = Int(round(min(max(r, 0), 1) * 255))
        let gi = Int(round(min(max(g, 0), 1) * 255))
        let bi = Int(round(min(max(b, 0), 1) * 255))
        return String(format: "#%02X%02X%02X", ri, gi, bi)
    }

    /// 相对亮度，用来决定提示文字该用黑还是白
    var isLightBackground: Bool {
        let ui = UIColor(self)
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        ui.getRed(&r, green: &g, blue: &b, alpha: &a)
        let luminance = 0.2126 * r + 0.7152 * g + 0.0722 * b
        return luminance > 0.55
    }
}

// MARK: - 屏幕色调预设

struct ScreenTone: Identifiable, Hashable {
    let name: String
    let hex: String
    var id: String { hex }

    static let pureWhite = "#FFFFFF"

    /// 默认：纯白
    static let defaultTone = ScreenTone(name: "纯白", hex: pureWhite)

    static let presets: [ScreenTone] = [
        ScreenTone(name: "纯白", hex: "#FFFFFF"),
        ScreenTone(name: "象牙白", hex: "#FFF6E5"),
        ScreenTone(name: "奶油黄", hex: "#FFF0C9"),
        ScreenTone(name: "浅杏色", hex: "#FFE3C2"),
        ScreenTone(name: "暖橙色", hex: "#FFD08A"),
        ScreenTone(name: "琥珀色", hex: "#FFC15E"),
        ScreenTone(name: "珊瑚粉", hex: "#FFD9D0"),
        ScreenTone(name: "落日橙", hex: "#FF9E5E")
    ]

    /// 按 hex 找预设名称，找不到就返回"自定义"
    static func name(for hex: String) -> String {
        let target = hex.uppercased()
        return presets.first { $0.hex.uppercased() == target }?.name ?? "自定义"
    }
}
