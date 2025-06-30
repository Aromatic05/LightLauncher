#!/bin/bash

# LightLauncher 构建脚本

set -e

echo "🚀 开始构建 LightLauncher..."

# 清理之前的构建
echo "🧹 清理之前的构建..."
rm -rf .build
rm -rf LightLauncher.app

# 构建 release 版本
echo "🔨 构建 release 版本..."
swift build -c release

# 创建应用包结构
echo "📦 创建应用包..."
mkdir -p LightLauncher.app/Contents/MacOS
mkdir -p LightLauncher.app/Contents/Resources

# 复制可执行文件
cp .build/release/LightLauncher LightLauncher.app/Contents/MacOS/

# 复制应用图标（如果存在）
if [ -f "Sources/Resources/AppIcon.icns" ]; then
    echo "📱 复制应用图标..."
    cp Sources/Resources/AppIcon.icns LightLauncher.app/Contents/Resources/
else
    echo "⚠️  未找到应用图标，请运行 ./set_icon.sh 来设置图标"
fi

# 创建 Info.plist
cat > LightLauncher.app/Contents/Info.plist << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>zh_CN</string>
    <key>CFBundleDisplayName</key>
    <string>LightLauncher</string>
    <key>CFBundleExecutable</key>
    <string>LightLauncher</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>CFBundleIdentifier</key>
    <string>com.lightlauncher.app</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>LightLauncher</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0.0</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>LSMinimumSystemVersion</key>
    <string>12.0</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>NSHumanReadableCopyright</key>
    <string>Copyright © 2025 LightLauncher. All rights reserved.</string>
    <key>NSMainStoryboardFile</key>
    <string>Main</string>
    <key>NSPrincipalClass</key>
    <string>NSApplication</string>
    <key>NSSupportsAutomaticGraphicsSwitching</key>
    <true/>
</dict>
</plist>
EOF

# 创建简单的应用图标 (可选)
echo "🎨 创建应用图标..."
cat > LightLauncher.app/Contents/Resources/AppIcon.icns << 'EOF'
# 这里应该是实际的 .icns 文件内容
# 现在我们暂时跳过图标创建
EOF

# 设置可执行权限
chmod +x LightLauncher.app/Contents/MacOS/LightLauncher

echo "✅ 构建完成！"
echo "📱 应用包位置: $(pwd)/LightLauncher.app"
echo ""
echo "🎯 使用方法:"
echo "   1. 双击 LightLauncher.app 启动应用"
echo "   2. 使用 Option+Space 快捷键呼出启动器"
echo "   3. 右键点击菜单栏图标可以打开设置"
echo ""
echo "🔧 开发模式:"
echo "   swift run LightLauncher"
echo ""
echo "📦 安装到应用程序文件夹:"
echo "   cp -r LightLauncher.app /Applications/"
