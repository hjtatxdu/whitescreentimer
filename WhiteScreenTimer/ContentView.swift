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
    @State private var fadeOpacity: Double = 0

    @StateObject private var engine = SignalEngine()

    @AppStorage("didShowSettingsHint") private var didShowHint = false

    private let ticker = Timer.publish(every: 0.25, on: .main, in: .common).autoconnect()

    /// 设置里的色调
    private var baseColor: Color { Color(hex: store.toneHex) }

    /// 引擎接管时用引擎给的颜色（警灯红蓝 / 摩斯黑白），否则用设置色调
    private var screenColor: Color { engine.screenColor ?? baseColor }

    private var hintColor: Color {
        baseColor.isLightBackground
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
            .overlay {
                // 退出时的画面压暗：即使系统亮度接口没响应，也能看到满 5 秒的过渡
                Color.black
                    .opacity(fadeOpacity)
                    .ignoresSafeArea()
                    .allowsHitTesting(false)
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
                    // 离开 App：先停掉闪光灯，并兜底立即还原亮度
                    engine.stop()
                    BrightnessController.shared.dimNow()
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
            .onChange(of: store.mode) { _ in
                guard !finished else { return }
                start()      // 切换模式：重开倒计时并重启信号
            }
            .onChange(of: store.morseTorch) { _ in
                guard !finished else { return }
                restartSignal()   // 摩斯输出方式切换：屏幕 <-> 闪光灯
            }
            .sheet(isPresented: $showSettings) {
                SettingsView()
                    .presentationDetents([.large])
                    .presentationDragIndicator(.visible)
            }
            .statusBarHidden(true)
            .persistentSystemOverlays(.hidden)
    }

    // MARK: - 计时与信号控制

    private func start() {
        finished = false
        BrightnessController.shared.brighten(duration: boostDuration)

        if store.alwaysOn {
            deadline = nil          // 常亮：不安排退出
        } else {
            deadline = Date().addingTimeInterval(TimeInterval(store.minutes * 60))
        }

        restartSignal()
    }

    /// 按当前模式启动/重启信号引擎（警灯、摩斯）
    private func restartSignal() {
        engine.start(mode: store.mode, useTorch: store.morseTorch)
    }

    private func checkDeadline() {
        guard !finished, let deadline else { return }
        if Date() >= deadline {
            finish()
        }
    }

    /// 回到前台：没到点就重新渐变到最亮并恢复信号，已过点就立即结束
    private func resume() {
        guard !finished else { return }
        if let deadline, Date() >= deadline {
            finish()
        } else {
            BrightnessController.shared.brighten(duration: boostDuration)
            restartSignal()
        }
    }

    /// 到点：满 5 秒的过渡（亮度渐变 + 画面压暗）-> 退出应用
    private func finish() {
        guard !finished else { return }
        finished = true
        deadline = nil

        // 先停掉警灯 / 闪光灯
        engine.stop()

        // 1) 系统亮度：5 秒渐变回原值（系统允许时生效）
        BrightnessController.shared.dim(duration: dimDuration)

        // 2) 画面压暗：即使亮度接口没响应，也保证能看见完整的 5 秒过渡
        withAnimation(.easeInOut(duration: dimDuration)) {
            fadeOpacity = 0.22
        }

        // 3) 固定等满 5 秒再退出，不受亮度接口行为影响
        DispatchQueue.main.asyncAfter(deadline: .now() + dimDuration + 0.25) {
            exit(0)
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
