import SwiftUI
import UIKit

/// 设置页：屏幕色调（暖色预设 + RGB 自定义）、退出时间（1–10 分钟，默认 3）
struct SettingsView: View {

    @EnvironmentObject private var store: SettingsStore
    @Environment(\.dismiss) private var dismiss

    /// ColorPicker 需要 Color 类型，这里和 toneHex 双向同步
    private var colorBinding: Binding<Color> {
        Binding(
            get: { Color(hex: store.toneHex) },
            set: { newColor in
                store.toneHex = newColor.hexString
            }
        )
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    LazyVGrid(
                        columns: [GridItem(.adaptive(minimum: 74), spacing: 12)],
                        spacing: 16
                    ) {
                        ForEach(ScreenTone.presets) { tone in
                            Button {
                                store.toneHex = tone.hex
                                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            } label: {
                                ToneSwatch(tone: tone, isSelected: isSelected(tone))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.vertical, 6)
                } header: {
                    Text("屏幕色调")
                } footer: {
                    Text("默认纯白。暖色可以减轻夜间刺眼感，选中后立即生效。")
                }

                Section {
                    ColorPicker("自定义颜色（RGB）", selection: colorBinding, supportsOpacity: false)
                    HStack {
                        Text("当前颜色")
                        Spacer()
                        Text("\(ScreenTone.name(for: store.toneHex))  \(store.toneHex)")
                            .font(.footnote.monospaced())
                            .foregroundStyle(.secondary)
                    }
                } header: {
                    Text("自定义")
                } footer: {
                    Text("点右侧色块进入取色器，可在「滑块」标签下按 R / G / B 精确调色。")
                }

                Section {
                    Picker("退出时间", selection: $store.minutes) {
                        ForEach(Array(SettingsStore.range), id: \.self) { minute in
                            Text(minute == SettingsStore.defaultMinutes ? "\(minute) 分钟（默认）" : "\(minute) 分钟")
                                .tag(minute)
                        }
                    }
                    .pickerStyle(.wheel)
                    .frame(height: 130)
                } header: {
                    Text("退出时间")
                } footer: {
                    Text("启动后屏幕保持设定的色调与最高亮度，到达设定时长后自动还原亮度并退出应用。")
                }
            }
            .navigationTitle("设置")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") { dismiss() }
                }
            }
        }
    }

    private func isSelected(_ tone: ScreenTone) -> Bool {
        tone.hex.uppercased() == store.toneHex.uppercased()
    }
}

// MARK: - 色块

private struct ToneSwatch: View {
    let tone: ScreenTone
    let isSelected: Bool

    var body: some View {
        VStack(spacing: 6) {
            ZStack {
                Circle()
                    .fill(Color(hex: tone.hex))
                    .frame(width: 46, height: 46)
                    .overlay(
                        Circle().strokeBorder(Color.black.opacity(0.12), lineWidth: 0.8)
                    )
                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(Color(hex: tone.hex).isLightBackground ? .black : .white)
                }
            }
            .overlay(
                Circle()
                    .strokeBorder(isSelected ? Color.accentColor : Color.clear, lineWidth: 2.5)
                    .frame(width: 52, height: 52)
            )
            Text(tone.name)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }
}
