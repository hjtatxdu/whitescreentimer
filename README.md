# 白屏计时（WhiteScreenTimer）

一个极简 iOS 应用：打开后屏幕铺满设定的色调、亮度拉满，到设定时间后自动还原亮度并退出。

- 启动即生效：整屏纯色 + 亮度 100% + 关闭自动锁屏
- 默认 3 分钟后结束：还原用户原来的亮度 → 退出应用
- 设置项共两个：
  - **屏幕色调**：默认纯白，另有 7 个暖色预设（象牙白 / 奶油黄 / 浅杏 / 暖橙 / 琥珀 / 珊瑚粉 / 落日橙），并支持 RGB 自定义取色
  - **退出时间**：可选 1–10 分钟（默认 3）
- 进入设置的方式：**长按屏幕 1.2 秒**（界面保持纯色、不放任何按钮）
- 切到后台会先还原亮度，避免人离开时被锁在最亮；回到前台若还没到点，会重新拉满

## 目录结构

```
WhiteScreenTimer/
├── project.yml                       # XcodeGen 工程描述（用来生成 .xcodeproj）
├── build-ipa.sh                      # macOS 上一键出 ipa
├── .github/workflows/
│   └── build-unsigned-ipa.yml        # 无 Mac 方案：CI 编译出未签名 ipa
└── WhiteScreenTimer/
    ├── WhiteScreenTimerApp.swift     # App 入口 + 退出时还原亮度
    ├── ContentView.swift             # 整屏纯色 + 倒计时 + 到点退出
    ├── BrightnessController.swift    # 亮度拉满/还原
    ├── ColorTone.swift               # 颜色/Hex 互转 + 暖色预设
    ├── SettingsStore.swift           # 设置项（色调 + 时长）持久化
    ├── SettingsView.swift            # 设置页（色块 + ColorPicker + 时长）
    └── Info.plist                    # 竖屏、强制浅色、隐藏状态栏
```

## 方案 A：有 Mac + Xcode（推荐，能直接得到可安装的 ipa）

1. 安装工具：`brew install xcodegen`（或直接在 Xcode 里手动新建工程，把 `WhiteScreenTimer/` 下 7 个文件拖进去，Bundle ID 自定）
2. 在项目目录执行：

   ```bash
   chmod +x build-ipa.sh
   TEAM_ID=你的团队ID ./build-ipa.sh      # 不填 TEAM_ID 时 Xcode 会让你在弹窗里选
   ```

3. 产物：`build/ipa/WhiteScreenTimer.ipa`
4. 安装：Xcode → Window → Devices and Simulators 拖进去，或用 Apple Configurator。
   （免费 Apple ID 也可以，但签名只有 7 天有效期，到期需重签。）

## 方案 B：没有 Mac → 用 GitHub Actions 出未签名 ipa，再自签安装

1. 在 GitHub 建一个仓库，把本目录内容推上去（保持 `project.yml`、`WhiteScreenTimer/`、`.github/` 的目录结构）
2. push 到 `main` 后，Actions 会自动跑 `Build unsigned IPA`，几分钟后下载 artifact `WhiteScreenTimer-unsigned-ipa`
3. 在 Windows 上用 **Sideloadly**（或 AltStore /爱思助手的新版 IPA 签名功能）：
   - 把 ipa 拖进去，填自己的 Apple ID，连接 iPhone，点 Start
   - 首次安装后，到 iPhone「设置 → 通用 → VPN 与设备管理」信任开发者证书
   - iOS 16 以上需要在「设置 → 隐私与安全性 → 开发者模式」里打开开发者模式并重启
4. 免费账号签名的应用 **7 天失效**，到期用同一个工具重签一次即可

> 说明：未签名 ipa 不能直接双击安装，必须经过上面第 3 步的"重签名"环节，这是 iOS 的机制，不是工程的问题。

## 使用

- 打开 App：立刻铺满设定色调 + 最亮，开始倒计时
- 换色调：长按屏幕 1.2 秒 → 设置页 → 「屏幕色调」点选暖色色块，或在「自定义颜色（RGB）」的取色器里调色（取色器「滑块」标签下可分别调 R / G / B），选中即时生效，不影响正在跑的倒计时
- 改时长：同一页的「退出时间」可选 1–10 分钟，改完从当前时刻重新计时
- 到点：亮度还原 → 应用自动关闭，回到桌面

## 已知限制（都是 iOS 平台本身的约束）

| 现象 | 原因 |
| --- | --- |
| 应用"自己退出"不是官方推荐做法 | 代码里用的是 `exit(0)`。侧载/自用完全可用；若要上架 App Store，需去掉自动退出改成"回到空白待机页" |
| 从多任务里强行上滑杀掉 App，亮度可能留在最亮 | iOS 不会给被强杀的应用执行任何收尾代码。此时手动下拉控制中心调回即可；正常到点退出和切后台都已做了还原 |
| 免费 Apple ID 签名 7 天有效 | Apple 对免费开发者账号的限制，付费开发者账号为 1 年 |
| 亮度只能改"系统亮度" | iOS 没有给第三方应用单独调亮度的 API，改的就是控制中心那条亮度条 |
