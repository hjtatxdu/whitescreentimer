import SwiftUI
import UIKit

struct ContentView: View {

    /// 启动：1.5 秒渐变到最亮
    private let boostDuration: TimeInterval = 1.5
    /// 退出：5 秒渐变回原亮度
    private let dimDuration: TimeInterval = 5.0

    @EnvironmentObject private var store: SettingsStore
    @Environment(\.scenePhase) private var scenePhase

    /// 到点时间（绝对时间）。nil 表示没有正在进行的倒计时（例如"常亮"模式）
    @State private var deadline: Date?
    @State private var showSettings = false
    @State private var finished = false
    @State private var hintOpacity: Double = 1

    @AppStorage("didShowSettingsHint") private var didShowHint = false

    private let ticker = Timer.publish(every: 0.25, on: .main, in: .common).autoconnect()

    private var screenColor: Color { Color(hex: store.toneHex) }

    private var hintColor: Color {
        screenColor.isLightBackground
            ? Color.black.opacity(0.22 * hintOpacity)
            : Color.white.opacity(0.45 * hintOpacity)
    }

    var body: some View {
        screenColor
            .ignoresSafeArea()
            .contentShape(Rectangle())
            // 界面保持纯色、不放任何按钮；长按 1.2 秒呼出设置
            .onLongPressGesture(minimumDuration: 1.2) {
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                showSettings = true
            }
            .overlay {
                if !didShowHint {
                    Text("长按屏幕进入设置")
                        .font(.footnote)
                        .foregroundStyle(hintColor)
                        .allowsHitTesting(false)
                }
            }
            .onAppear {
                start()
                revealHintOnceIfNeeded()
            }
            .onReceive(ticker) { _ in
                checkDeadline()
            }
            .onChange(of: scenePhase) { newPhase in
                switch newPhase {
                case .active:
                    resume()
                case .background:
                    // 离开 App：用 5 秒把亮度降回原值
                    BrightnessController.shared.dimInBackground(duration: dimDuration)
                case .inactive:
                    break        // 下拉控制中心等场景不处理，避免亮度来回跳
                default:
                    break
                }
            }
            .onChange(of: store.minutes) { _ in
                guard !finished, !store.alwaysOn else { return }
                start()      // 改了时长，从当前时刻重新计时
            }
            .onChange(of: store.alwaysOn) { _ in
                guard !finished else { return }
                start()      // 常亮开关切换后立即生效（清空或重建倒计时）
            }
            .sheet(isPresented: $showSettings) {
                SettingsView()
                    .presentationDetents([.large])
                    .presentationDragIndicator(.visible)
            }
            .statusBarHidden(true)
            .persistentSystemOverlays(.hidden)
    }

    // MARK: - 计时控制

    private func start() {
        finished = false
        BrightnessController.shared.brighten(duration: boostDuration)

        if store.alwaysOn {
            deadline = nil          // 常亮：不安排退出
        } else {
            deadline = Date().addingTimeInterval(TimeInterval(store.minutes * 60))
        }
    }

    private func checkDeadline() {
        guard !finished, let deadline else { return }
        if Date() >= deadline {
            finish()
        }
    }

    /// 回到前台：没到点就重新渐变到最亮，已过点就立即结束
    private func resume() {
        guard !finished else { return }
        if let deadline, Date() >= deadline {
            finish()
        } else {
            BrightnessController.shared.brighten(duration: boostDuration)
        }
    }

    /// 到点：5 秒渐变回原亮度 -> 退出应用
    private func finish() {
        guard !finished else { return }
        finished = true
        deadline = nil
        BrightnessController.shared.dim(duration: dimDuration) {
            // 渐变结束后再退出，确保亮度已经完全落地
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                exit(0)
            }
        }
    }

    /// 仅首次启动时显示一次操作提示，2 秒后淡出
    private func revealHintOnceIfNeeded() {
        guard !didShowHint else { return }
        didShowHint = true
        withAnimation(.easeOut(duration: 1.0).delay(1.5)) {
            hintOpacity = 0
        }
    }
}
