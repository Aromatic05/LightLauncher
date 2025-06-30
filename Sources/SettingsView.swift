import SwiftUI
import Carbon

enum SettingsTab {
    case general
    case directories
    case abbreviations
    case about
}

struct SettingsView: View {
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
                    TabButton(
                        title: "通用",
                        icon: "gear",
                        isSelected: selectedTab == .general
                    ) {
                        selectedTab = .general
                    }
                    
                    TabButton(
                        title: "搜索目录",
                        icon: "folder",
                        isSelected: selectedTab == .directories
                    ) {
                        selectedTab = .directories
                    }
                    
                    TabButton(
                        title: "缩写匹配",
                        icon: "textformat.abc",
                        isSelected: selectedTab == .abbreviations
                    ) {
                        selectedTab = .abbreviations
                    }
                    
                    TabButton(
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

// MARK: - 选项卡按钮
struct TabButton: View {
    let title: String
    let icon: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .medium))
                    .frame(width: 20)
                    .foregroundColor(isSelected ? .white : .accentColor)
                Text(title)
                    .font(.system(size: 14, weight: .medium))
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isSelected ? Color.accentColor : Color.clear)
            )
            .foregroundColor(isSelected ? .white : .primary)
        }
        .buttonStyle(PlainButtonStyle())
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(isSelected ? Color.clear : Color.secondary.opacity(0.2), lineWidth: 1)
        )
    }
}

// MARK: - 通用设置视图
struct GeneralSettingsView: View {
    @ObservedObject var settingsManager: SettingsManager
    @ObservedObject var configManager: ConfigManager
    @Binding var isRecordingHotKey: Bool
    @Binding var tempHotKeyDescription: String
    @Binding var globalMonitor: Any?
    @Binding var localMonitor: Any?
    @Binding var currentModifiers: UInt32
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 32) {
                // 标题
                VStack(alignment: .leading, spacing: 8) {
                    Text("通用设置")
                        .font(.title)
                        .fontWeight(.bold)
                    Text("基础应用配置和快捷键设置")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                // 设置组
                VStack(spacing: 32) {
                    // 开机自启动
                    SettingRow(
                        icon: "power",
                        iconColor: .green,
                        title: "开机自启动",
                        description: "启动时自动运行 LightLauncher",
                        isToggle: true,
                        toggleValue: $settingsManager.isAutoStartEnabled
                    ) {
                        settingsManager.toggleAutoStart()
                    }
                    
                    Divider()
                    
                    // 快捷键设置
                    VStack(alignment: .leading, spacing: 20) {
                        HStack {
                            Image(systemName: "keyboard")
                                .foregroundColor(.blue)
                            Text("全局快捷键")
                                .font(.title2)
                                .fontWeight(.semibold)
                        }
                        
                        Text("设置全局快捷键来显示/隐藏启动器，在任何应用中都可以使用")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        HStack(spacing: 16) {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("当前快捷键")
                                    .font(.headline)
                                Text("点击按钮来修改")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                            
                            Button(action: {
                                startRecordingHotKey()
                            }) {
                                HStack(spacing: 8) {
                                    if isRecordingHotKey {
                                        ProgressView()
                                            .scaleEffect(0.8)
                                        Text("按下新的快捷键...")
                                            .font(.system(size: 14, design: .monospaced))
                                    } else {
                                        Image(systemName: "keyboard")
                                        Text(configManager.getHotKeyDescription())
                                            .font(.system(size: 16, weight: .semibold, design: .monospaced))
                                    }
                                }
                                .padding(.horizontal, 20)
                                .padding(.vertical, 12)
                                .background(isRecordingHotKey ? Color.blue.opacity(0.1) : Color(NSColor.controlBackgroundColor))
                                .foregroundColor(isRecordingHotKey ? .blue : .primary)
                                .cornerRadius(10)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 10)
                                        .stroke(isRecordingHotKey ? Color.blue : Color.secondary.opacity(0.3), lineWidth: 2)
                                )
                            }
                            .buttonStyle(PlainButtonStyle())
                            .disabled(isRecordingHotKey)
                            
                            if isRecordingHotKey {
                                Button("取消") {
                                    cancelRecordingHotKey()
                                }
                                .buttonStyle(.bordered)
                            } else {
                                Button("重置") {
                                    resetToDefaults()
                                }
                                .buttonStyle(.bordered)
                                .foregroundColor(.orange)
                            }
                        }
                        .padding(20)
                        .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
                        .cornerRadius(12)
                    }
                    
                    Divider()
                    
                    // 快捷键说明 - 横向布局
                    VStack(alignment: .leading, spacing: 16) {
                        HStack {
                            Image(systemName: "info.circle")
                                .foregroundColor(.blue)
                            Text("支持的快捷键类型")
                                .font(.title2)
                                .fontWeight(.semibold)
                        }
                        
                        // 横向排列的快捷键类型
                        HStack(alignment: .top, spacing: 20) {
                            HotKeyInfoCard(
                                title: "修饰键组合",
                                icon: "command",
                                iconColor: .blue,
                                examples: ["⌘ + 字母", "⌥ + 数字", "⌃ + 功能键", "多键组合"]
                            )
                            
                            HotKeyInfoCard(
                                title: "单独修饰键",
                                icon: "option",
                                iconColor: .purple,
                                examples: ["右 Command", "右 Option", "左/右 Control", "Shift 键"]
                            )
                            
                            HotKeyInfoCard(
                                title: "功能键",
                                icon: "f.cursive",
                                iconColor: .orange,
                                examples: ["F1 - F12", "Space", "Return", "Escape"]
                            )
                        }
                    }
                    
                    Divider()
                    
                    // 性能优化说明
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Image(systemName: "bolt")
                                .foregroundColor(.orange)
                            Text("性能提示")
                                .font(.headline)
                        }
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Text("• 应用会自动缓存搜索结果以提升性能")
                            Text("• 可在搜索目录设置中添加或移除扫描路径")
                            Text("• 缩写匹配功能帮助快速定位应用")
                        }
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    }
                    .padding(16)
                    .background(Color(NSColor.controlBackgroundColor))
                    .cornerRadius(12)
                }
                
                Spacer()
            }
            .padding(32)
        }
    }
    
    // MARK: - 热键录制方法
    private func startRecordingHotKey() {
        isRecordingHotKey = true
        tempHotKeyDescription = "按下新的快捷键..."
        currentModifiers = 0
        
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.keyDown, .flagsChanged]) { event in
            handleHotKeyEvent(event)
        }
        
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .flagsChanged]) { event in
            handleHotKeyEvent(event)
            return event
        }
    }
    
    private func handleHotKeyEvent(_ event: NSEvent) {
        guard isRecordingHotKey else { return }
        
        if event.type == .keyDown {
            let keyCode = UInt32(event.keyCode)
            let modifiers = event.modifierFlags
            
            let validKeys: [UInt32] = [
                UInt32(kVK_Space), UInt32(kVK_Return), UInt32(kVK_Escape), UInt32(kVK_Tab),
                UInt32(kVK_F1), UInt32(kVK_F2), UInt32(kVK_F3), UInt32(kVK_F4),
                UInt32(kVK_F5), UInt32(kVK_F6), UInt32(kVK_F7), UInt32(kVK_F8),
                UInt32(kVK_F9), UInt32(kVK_F10), UInt32(kVK_F11), UInt32(kVK_F12),
                UInt32(kVK_ANSI_A), UInt32(kVK_ANSI_B), UInt32(kVK_ANSI_C), UInt32(kVK_ANSI_D),
                UInt32(kVK_ANSI_E), UInt32(kVK_ANSI_F), UInt32(kVK_ANSI_G), UInt32(kVK_ANSI_H),
                UInt32(kVK_ANSI_I), UInt32(kVK_ANSI_J), UInt32(kVK_ANSI_K), UInt32(kVK_ANSI_L),
                UInt32(kVK_ANSI_M), UInt32(kVK_ANSI_N), UInt32(kVK_ANSI_O), UInt32(kVK_ANSI_P),
                UInt32(kVK_ANSI_Q), UInt32(kVK_ANSI_R), UInt32(kVK_ANSI_S), UInt32(kVK_ANSI_T),
                UInt32(kVK_ANSI_U), UInt32(kVK_ANSI_V), UInt32(kVK_ANSI_W), UInt32(kVK_ANSI_X),
                UInt32(kVK_ANSI_Y), UInt32(kVK_ANSI_Z)
            ]
            
            if validKeys.contains(keyCode) || (modifiers.rawValue != 0) {
                let carbonModifiers = carbonModifiersFromCocoaModifiers(modifiers)
                configManager.updateHotKey(modifiers: carbonModifiers, keyCode: keyCode)
                stopRecordingHotKey()
            }
        } else if event.type == .flagsChanged {
            // 处理单独修饰键
            let modifiers = event.modifierFlags
            currentModifiers = carbonModifiersFromCocoaModifiers(modifiers)
            
            // 检查是否为单独的右 Command 或右 Option
            if modifiers.contains(.command) && event.keyCode == 54 { // 右 Command
                configManager.updateHotKey(modifiers: 0x100010, keyCode: 0)
                stopRecordingHotKey()
            } else if modifiers.contains(.option) && event.keyCode == 61 { // 右 Option
                configManager.updateHotKey(modifiers: 0x100040, keyCode: 0)
                stopRecordingHotKey()
            }
        }
    }
    
    private func carbonModifiersFromCocoaModifiers(_ modifiers: NSEvent.ModifierFlags) -> UInt32 {
        var carbonModifiers: UInt32 = 0
        
        if modifiers.contains(.command) {
            carbonModifiers |= UInt32(cmdKey)
        }
        if modifiers.contains(.option) {
            carbonModifiers |= UInt32(optionKey)
        }
        if modifiers.contains(.control) {
            carbonModifiers |= UInt32(controlKey)
        }
        if modifiers.contains(.shift) {
            carbonModifiers |= UInt32(shiftKey)
        }
        
        return carbonModifiers
    }
    
    private func stopRecordingHotKey() {
        isRecordingHotKey = false
        
        if let monitor = globalMonitor {
            NSEvent.removeMonitor(monitor)
            globalMonitor = nil
        }
        
        if let monitor = localMonitor {
            NSEvent.removeMonitor(monitor)
            localMonitor = nil
        }
    }
    
    private func cancelRecordingHotKey() {
        stopRecordingHotKey()
    }
    
    private func resetToDefaults() {
        configManager.updateHotKey(modifiers: UInt32(optionKey), keyCode: UInt32(kVK_Space))
    }
}

// MARK: - 快捷键信息卡片
struct HotKeyInfoCard: View {
    let title: String
    let icon: String
    let iconColor: Color
    let examples: [String]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .foregroundColor(iconColor)
                    .font(.title3)
                Text(title)
                    .font(.headline)
                    .fontWeight(.semibold)
            }
            
            VStack(alignment: .leading, spacing: 6) {
                ForEach(examples, id: \.self) { example in
                    HStack(spacing: 6) {
                        Circle()
                            .fill(iconColor.opacity(0.6))
                            .frame(width: 4, height: 4)
                        Text(example)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .padding(16)
        .background(Color(NSColor.controlBackgroundColor).opacity(0.3))
        .cornerRadius(12)
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }
}
struct SettingRow: View {
    let icon: String
    let iconColor: Color
    let title: String
    let description: String
    let isToggle: Bool
    @Binding var toggleValue: Bool
    let action: () -> Void
    
    init(icon: String, iconColor: Color = .accentColor, title: String, description: String, 
         isToggle: Bool = false, toggleValue: Binding<Bool> = .constant(false), action: @escaping () -> Void = {}) {
        self.icon = icon
        self.iconColor = iconColor
        self.title = title
        self.description = description
        self.isToggle = isToggle
        self._toggleValue = toggleValue
        self.action = action
    }
    
    var body: some View {
        HStack(spacing: 16) {
            // 图标
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(iconColor.opacity(0.15))
                    .frame(width: 40, height: 40)
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(iconColor)
            }
            
            // 文本内容
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                Text(description)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            // 控件
            if isToggle {
                Toggle("", isOn: $toggleValue)
                    .onChange(of: toggleValue) { _ in
                        action()
                    }
                    .scaleEffect(1.1)
            }
        }
        .padding(.vertical, 8)
    }
}

// MARK: - 搜索目录设置视图
struct DirectorySettingsView: View {
    @ObservedObject var configManager: ConfigManager
    @State private var newDirectory = ""
    @State private var showingDirectoryPicker = false
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 32) {
                // 标题
                VStack(alignment: .leading, spacing: 8) {
                    Text("搜索目录")
                        .font(.title)
                        .fontWeight(.bold)
                    Text("配置应用程序搜索目录，支持 ~ 符号表示用户主目录")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                // 添加新目录
                VStack(alignment: .leading, spacing: 16) {
                    Text("添加搜索目录")
                        .font(.title2)
                        .fontWeight(.semibold)
                    
                    HStack(spacing: 12) {
                        TextField("输入目录路径 (如: ~/Applications)", text: $newDirectory)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                        
                        Button("浏览") {
                            showingDirectoryPicker = true
                        }
                        .buttonStyle(.bordered)
                        
                        Button("添加") {
                            addDirectory()
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(newDirectory.isEmpty)
                    }
                    .padding(16)
                    .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
                    .cornerRadius(12)
                }
                
                // 目录列表
                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        Text("当前搜索目录")
                            .font(.title2)
                            .fontWeight(.semibold)
                        Spacer()
                        Text("\(configManager.config.searchDirectories.count) 个目录")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    LazyVStack(spacing: 8) {
                        ForEach(Array(configManager.config.searchDirectories.enumerated()), id: \.offset) { index, directory in
                            DirectoryRow(directory: directory) {
                                removeDirectory(at: index)
                            }
                        }
                    }
                }
                
                Spacer()
            }
            .padding(32)
        }
        .fileImporter(
            isPresented: $showingDirectoryPicker,
            allowedContentTypes: [.folder],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                if let url = urls.first {
                    newDirectory = url.path
                }
            case .failure(let error):
                print("选择目录失败: \(error)")
            }
        }
    }
    
    private func addDirectory() {
        guard !newDirectory.isEmpty else { return }
        configManager.addSearchDirectory(newDirectory)
        newDirectory = ""
    }
    
    private func removeDirectory(at index: Int) {
        let directory = configManager.config.searchDirectories[index]
        configManager.removeSearchDirectory(directory)
    }
}

// MARK: - 目录行组件
struct DirectoryRow: View {
    let directory: String
    let onDelete: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "folder")
                .foregroundColor(.blue)
                .font(.title3)
            
            Text(directory)
                .font(.system(.body, design: .monospaced))
                .frame(maxWidth: .infinity, alignment: .leading)
            
            Button("删除") {
                onDelete()
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .foregroundColor(.red)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
        .cornerRadius(10)
    }
}

// MARK: - 缩写匹配设置视图
struct AbbreviationSettingsView: View {
    @ObservedObject var configManager: ConfigManager
    @State private var newAbbreviation = ""
    @State private var newMatchWords = ""
    @State private var editingKey: String?
    @State private var editingValues: String = ""
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 32) {
                // 标题
                VStack(alignment: .leading, spacing: 8) {
                    Text("缩写匹配")
                        .font(.title)
                        .fontWeight(.bold)
                    Text("配置应用程序缩写匹配规则，提高搜索效率")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                // 添加新缩写
                VStack(alignment: .leading, spacing: 16) {
                    Text("添加新缩写")
                        .font(.title2)
                        .fontWeight(.semibold)
                    
                    VStack(spacing: 12) {
                        HStack(spacing: 12) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("缩写")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                TextField("如: ps", text: $newAbbreviation)
                                    .textFieldStyle(RoundedBorderTextFieldStyle())
                                    .frame(width: 120)
                            }
                            
                            Image(systemName: "arrow.right")
                                .foregroundColor(.secondary)
                                .padding(.top, 16)
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text("匹配词 (用逗号分隔)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                TextField("如: photoshop, adobe photoshop", text: $newMatchWords)
                                    .textFieldStyle(RoundedBorderTextFieldStyle())
                            }
                            
                            Button("添加") {
                                addAbbreviation()
                            }
                            .buttonStyle(.borderedProminent)
                            .disabled(newAbbreviation.isEmpty || newMatchWords.isEmpty)
                            .padding(.top, 16)
                        }
                    }
                    .padding(16)
                    .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
                    .cornerRadius(12)
                }
                
                // 缩写列表
                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        Text("当前缩写规则")
                            .font(.title2)
                            .fontWeight(.semibold)
                        Spacer()
                        Text("\(configManager.config.commonAbbreviations.count) 项")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    LazyVStack(spacing: 8) {
                        ForEach(Array(configManager.config.commonAbbreviations.keys.sorted()), id: \.self) { key in
                            AbbreviationRow(
                                key: key,
                                values: configManager.config.commonAbbreviations[key] ?? [],
                                isEditing: editingKey == key,
                                editingValues: $editingValues,
                                onEdit: {
                                    startEditing(key: key)
                                },
                                onSave: {
                                    saveEdit(key: key)
                                },
                                onCancel: {
                                    cancelEdit()
                                },
                                onDelete: {
                                    deleteAbbreviation(key: key)
                                }
                            )
                        }
                    }
                }
                
                Spacer()
            }
            .padding(32)
        }
    }
    
    private func addAbbreviation() {
        guard !newAbbreviation.isEmpty && !newMatchWords.isEmpty else { return }
        let words = newMatchWords.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
        configManager.addAbbreviation(key: newAbbreviation.lowercased(), values: words)
        newAbbreviation = ""
        newMatchWords = ""
    }
    
    private func startEditing(key: String) {
        editingKey = key
        editingValues = (configManager.config.commonAbbreviations[key] ?? []).joined(separator: ", ")
    }
    
    private func saveEdit(key: String) {
        let words = editingValues.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
        configManager.addAbbreviation(key: key, values: words)
        cancelEdit()
    }
    
    private func cancelEdit() {
        editingKey = nil
        editingValues = ""
    }
    
    private func deleteAbbreviation(key: String) {
        configManager.removeAbbreviation(key: key)
    }
}

// MARK: - 缩写行组件
struct AbbreviationRow: View {
    let key: String
    let values: [String]
    let isEditing: Bool
    @Binding var editingValues: String
    let onEdit: () -> Void
    let onSave: () -> Void
    let onCancel: () -> Void
    let onDelete: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            // 缩写键
            Text(key)
                .font(.system(.body, design: .monospaced))
                .fontWeight(.semibold)
                .foregroundColor(.accentColor)
                .frame(width: 60, alignment: .leading)
            
            Image(systemName: "arrow.right")
                .foregroundColor(.secondary)
                .font(.caption)
            
            // 匹配值
            if isEditing {
                TextField("编辑匹配词", text: $editingValues)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                
                HStack(spacing: 8) {
                    Button("保存") {
                        onSave()
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                    
                    Button("取消") {
                        onCancel()
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
            } else {
                Text(values.joined(separator: ", "))
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                
                HStack(spacing: 8) {
                    Button("编辑") {
                        onEdit()
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    
                    Button("删除") {
                        onDelete()
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .foregroundColor(.red)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
        .cornerRadius(10)
    }
}

// MARK: - 关于设置视图
struct AboutSettingsView: View {
    @ObservedObject var configManager: ConfigManager
    @State private var showingConfigContent = false
    @State private var configContent = ""
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 32) {
                // 标题
                VStack(alignment: .leading, spacing: 8) {
                    Text("关于 LightLauncher")
                        .font(.title)
                        .fontWeight(.bold)
                    Text("轻量级应用启动器")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                // 应用信息
                VStack(alignment: .leading, spacing: 20) {
                    HStack {
                        Image(systemName: "rocket.fill")
                            .font(.system(size: 64))
                            .foregroundColor(.accentColor)
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Text("LightLauncher")
                                .font(.largeTitle)
                                .fontWeight(.bold)
                            Text("版本 1.0.0")
                                .font(.title3)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                    }
                    .padding(24)
                    .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
                    .cornerRadius(16)
                    
                    VStack(alignment: .leading, spacing: 16) {
                        Text("功能特性")
                            .font(.title2)
                            .fontWeight(.semibold)
                        
                        VStack(alignment: .leading, spacing: 8) {
                            FeatureItem(icon: "magnifyingglass", text: "快速应用搜索和启动")
                            FeatureItem(icon: "keyboard", text: "支持自定义快捷键（包括左右修饰键）")
                            FeatureItem(icon: "textformat.abc", text: "智能缩写匹配")
                            FeatureItem(icon: "folder", text: "可配置搜索目录")
                            FeatureItem(icon: "doc.text", text: "YAML 配置文件管理")
                        }
                    }
                    .padding(20)
                    .background(Color(NSColor.controlBackgroundColor).opacity(0.3))
                    .cornerRadius(12)
                }
                
                // 配置文件管理
                VStack(alignment: .leading, spacing: 16) {
                    Text("配置文件管理")
                        .font(.title2)
                        .fontWeight(.semibold)
                    
                    VStack(spacing: 12) {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("配置文件位置")
                                    .font(.headline)
                                Text(configManager.configURL.path)
                                    .font(.system(.caption, design: .monospaced))
                                    .foregroundColor(.secondary)
                                    .textSelection(.enabled)
                            }
                            Spacer()
                            Button("打开文件夹") {
                                NSWorkspace.shared.selectFile(configManager.configURL.path, inFileViewerRootedAtPath: "")
                            }
                            .buttonStyle(.bordered)
                        }
                        .padding(16)
                        .background(Color(NSColor.controlBackgroundColor).opacity(0.3))
                        .cornerRadius(10)
                        
                        HStack(spacing: 12) {
                            Button("查看配置内容") {
                                loadConfigContent()
                                showingConfigContent = true
                            }
                            .buttonStyle(.bordered)
                            
                            Button("重新加载配置") {
                                configManager.reloadConfig()
                            }
                            .buttonStyle(.bordered)
                            
                            Button("重置为默认") {
                                configManager.resetToDefaults()
                            }
                            .buttonStyle(.bordered)
                            .foregroundColor(.orange)
                        }
                    }
                }
                
                Spacer()
            }
            .padding(32)
        }
        .sheet(isPresented: $showingConfigContent) {
            ConfigContentView(content: configContent)
        }
    }
    
    private func loadConfigContent() {
        do {
            configContent = try String(contentsOf: configManager.configURL, encoding: .utf8)
        } catch {
            configContent = "无法读取配置文件: \(error.localizedDescription)"
        }
    }
}

// MARK: - 功能项组件
struct FeatureItem: View {
    let icon: String
    let text: String
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(.accentColor)
                .font(.title3)
                .frame(width: 24)
            Text(text)
                .font(.subheadline)
        }
    }
}

// MARK: - 配置文件内容查看器
struct ConfigContentView: View {
    let content: String
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("配置文件内容")
                    .font(.title2)
                    .fontWeight(.semibold)
                Spacer()
                Button("关闭") {
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
            }
            
            ScrollView {
                Text(content)
                    .font(.system(.body, design: .monospaced))
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(16)
            }
            .background(Color(NSColor.textBackgroundColor))
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.secondary.opacity(0.3), lineWidth: 1)
            )
        }
        .padding(24)
        .frame(width: 700, height: 600)
    }
}
