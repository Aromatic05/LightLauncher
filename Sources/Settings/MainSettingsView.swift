import SwiftUI
import Carbon

// MARK: - 设置选项卡枚举
enum SettingsTab {
    case general
    case modes
    case directories
    case abbreviations
    case about
}

// MARK: - 主设置视图
struct MainSettingsView: View {
    @ObservedObject var settingsManager = SettingsManager.shared
    @ObservedObject var configManager = ConfigManager.shared
    @State private var selectedTab: SettingsTab = .general
    @State private var isRecordingHotKey = false
    @State private var tempHotKeyDescription = ""
    @State private var globalMonitor: Any?
    @State private var localMonitor: Any?
    @State private var currentModifiers: UInt32 = 0
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        HStack(spacing: 0) {
            // 左侧选项卡
            VStack(spacing: 0) {
                // 标题
                HStack {
                    Image(systemName: "rocket")
                        .font(.title2)
                        .foregroundColor(.accentColor)
                    VStack(alignment: .leading, spacing: 1) {
                        Text("LightLauncher")
                            .font(.headline)
                            .fontWeight(.bold)
                        Text("设置")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.top, 20)
                .padding(.bottom, 24)
                
                // 选项卡列表
                VStack(spacing: 4) {
                    SettingsTabButton(
                        title: "通用",
                        icon: "gear",
                        isSelected: selectedTab == .general
                    ) {
                        selectedTab = .general
                    }
                    
                    SettingsTabButton(
                        title: "功能模式",
                        icon: "slider.horizontal.3",
                        isSelected: selectedTab == .modes
                    ) {
                        selectedTab = .modes
                    }
                    
                    SettingsTabButton(
                        title: "搜索目录",
                        icon: "folder",
                        isSelected: selectedTab == .directories
                    ) {
                        selectedTab = .directories
                    }
                    
                    SettingsTabButton(
                        title: "缩写匹配",
                        icon: "textformat.abc",
                        isSelected: selectedTab == .abbreviations
                    ) {
                        selectedTab = .abbreviations
                    }
                    
                    SettingsTabButton(
                        title: "关于",
                        icon: "info.circle",
                        isSelected: selectedTab == .about
                    ) {
                        selectedTab = .about
                    }
                }
                .padding(.horizontal, 12)
                
                Spacer()
                
                Divider()
                    .padding(.horizontal, 12)
                    .padding(.vertical, 16)
                
                // 底部操作按钮
                VStack(spacing: 12) {
                    HStack(spacing: 8) {
                        Button(action: {
                            configManager.reloadConfig()
                        }) {
                            HStack(spacing: 4) {
                                Image(systemName: "arrow.clockwise")
                                Text("重新加载")
                            }
                        }
                        .font(.caption)
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        
                        Button(action: {
                            NSWorkspace.shared.selectFile(configManager.configURL.path, inFileViewerRootedAtPath: "")
                        }) {
                            HStack(spacing: 4) {
                                Image(systemName: "folder")
                                Text("打开文件夹")
                            }
                        }
                        .font(.caption)
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }
                    
                    Button("重置为默认") {
                        configManager.resetToDefaults()
                    }
                    .font(.caption)
                    .foregroundColor(.orange)
                    
                    Button("完成") {
                        dismiss()
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.regular)
                    
                    Button("退出应用") {
                        NSApplication.shared.terminate(nil)
                    }
                    .foregroundColor(.red)
                    .font(.caption)
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 20)
            }
            .frame(width: 220)
            .background(Color(NSColor.controlBackgroundColor))
            
            Divider()
            
            // 右侧内容区域
            switch selectedTab {
            case .general:
                GeneralSettingsView(
                    settingsManager: settingsManager,
                    configManager: configManager,
                    isRecordingHotKey: $isRecordingHotKey,
                    tempHotKeyDescription: $tempHotKeyDescription,
                    globalMonitor: $globalMonitor,
                    localMonitor: $localMonitor,
                    currentModifiers: $currentModifiers
                )
            case .modes:
                ModeSettingsView(
                    settingsManager: settingsManager,
                    configManager: configManager
                )
            case .directories:
                DirectorySettingsView(configManager: configManager)
            case .abbreviations:
                AbbreviationSettingsView(configManager: configManager)
            case .about:
                AboutSettingsView(configManager: configManager)
            }
        }
        .frame(width: 960, height: 740)
        .onAppear {
            settingsManager.checkAutoStartStatus()
        }
    }
}
