#!/bin/bash
# 在 macOS 上运行：生成工程 -> 编译 -> 导出 ipa
# 用法：
#   ./build-ipa.sh                    # 用 Development 证书导出（真机调试/自用）
#   TEAM_ID=ABCDE12345 ./build-ipa.sh # 指定你的 Apple 开发者团队 ID
set -euo pipefail

cd "$(dirname "$0")"

APP_NAME="WhiteScreenTimer"
SCHEME="WhiteScreenTimer"
BUNDLE_ID="${BUNDLE_ID:-com.example.whitescreentimer}"

if ! command -v xcodebuild >/dev/null 2>&1; then
  echo "❌ 没找到 xcodebuild，请在 macOS 上安装 Xcode 后重试。"
  exit 1
fi

# 1. 生成 .xcodeproj
if command -v xcodegen >/dev/null 2>&1; then
  echo "▶︎ 用 xcodegen 生成工程…"
  xcodegen generate
elif [ -d "$APP_NAME.xcodeproj" ]; then
  echo "▶︎ 已存在 $APP_NAME.xcodeproj，直接使用。"
else
  echo "❌ 未安装 xcodegen，也没有现成的 .xcodeproj。请先执行： brew install xcodegen"
  exit 1
fi

# 2. 归档
echo "▶︎ 归档（Release）…"
rm -rf build
xcodebuild \
  -project "$APP_NAME.xcodeproj" \
  -scheme "$SCHEME" \
  -configuration Release \
  -destination 'generic/platform=iOS' \
  -archivePath "build/$APP_NAME.xcarchive" \
  -allowProvisioningUpdates \
  ${TEAM_ID:+DEVELOPMENT_TEAM=$TEAM_ID} \
  archive

# 3. 导出 ipa
echo "▶︎ 导出 ipa…"
cat > build/ExportOptions.plist <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>method</key>
  <string>${METHOD:-development}</string>
  <key>signingStyle</key>
  <string>automatic</string>
  <key>stripSwiftSymbols</key>
  <true/>
  <key>compileBitcode</key>
  <false/>
  <key>destination</key>
  <string>export</string>
</dict>
</plist>
EOF

xcodebuild -exportArchive \
  -archivePath "build/$APP_NAME.xcarchive" \
  -exportOptionsPlist build/ExportOptions.plist \
  -exportPath build/ipa \
  -allowProvisioningUpdates

echo "✅ 完成：build/ipa/$APP_NAME.ipa"
