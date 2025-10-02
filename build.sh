#!/bin/bash

# LightLauncher 构建脚本

set -e

echo "Building LightLauncher..."

# 清理之前的构建
echo "Cleaning previous build..."
# rm -rf .build
rm -rf LightLauncher.app

# 构建 release 版本
echo "构建 release 版本..."
swift build -c release

# 创建应用包结构
echo "创建应用包..."
mkdir -p LightLauncher.app/Contents/MacOS
mkdir -p LightLauncher.app/Contents/Resources

# 复制可执行文件
cp .build/release/LightLauncher LightLauncher.app/Contents/MacOS/
cp -r .build/release/LightLauncher_LightLauncher.bundle LightLauncher.app/

# 复制应用图标（如果存在）
if [ -f "Sources/Resources/AppIcon.icns" ]; then
    echo "复制应用图标..."
    cp Sources/Resources/AppIcon.icns LightLauncher.app/Contents/Resources/
    rm LightLauncher.app/LightLauncher_LightLauncher.bundle/AppIcon.icns
else
    echo "未找到应用图标，请运行 ./set_icon.sh 来设置图标"
fi

# cp Sources/Resources/*.png LightLauncher.app/Contents/Resources/
# echo "复制资源文件..."

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
    <!-- 权限声明 -->
    <key>NSSystemAdministrationUsageDescription</key>
    <string>需要完全磁盘访问权限以管理和搜索您的所有文件。</string>
    <key>NSAppleEventsUsageDescription</key>
    <string>用于自动化控制其他应用（如模拟输入、窗口切换等）</string>
    <key>NSDocumentsFolderUsageDescription</key>
    <string>用于访问和管理您的文档文件夹</string>
    <key>NSDownloadsFolderUsageDescription</key>
    <string>用于访问和管理您的下载文件夹</string>
    <key>NSDesktopFolderUsageDescription</key>
    <string>用于访问和管理您的桌面文件夹</string>
    <key>NSFileProviderDomainUsageDescription</key>
    <string>用于访问和管理您的文件提供者域</string>
    <key>NSNetworkVolumesUsageDescription</key>
    <string>用于访问和管理您的网络卷</string>
    <key>NSRemovableVolumesUsageDescription</key>
    <string>用于访问和管理您的可移动磁盘</string>
</dict>
</plist>
EOF

# 设置可执行权限
chmod +x LightLauncher.app/Contents/MacOS/LightLauncher

echo "构建完成！"
echo "应用包位置: $(pwd)/LightLauncher.app"
echo ""
echo "使用方法:"
echo "   1. 双击 LightLauncher.app 启动应用"
echo "   2. 使用 Option+Space 快捷键呼出启动器"
echo "   3. 右键点击菜单栏图标可以打开设置"
echo ""
echo "开发模式:"
echo "   swift run LightLauncher"
echo ""
echo "安装到应用程序文件夹:"
echo "   cp -r LightLauncher.app /Applications/"
