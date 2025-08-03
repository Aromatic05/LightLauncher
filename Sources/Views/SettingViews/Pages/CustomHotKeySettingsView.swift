import SwiftUI
import Carbon

// MARK: - 自定义快捷键设置视图
struct CustomHotKeySettingsView: View {
    @ObservedObject var configManager: ConfigManager
    @State private var showingAddSheet = false
    @State private var editingHotKey: CustomHotKeyConfig?
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 32) {
                // 标题
                VStack(alignment: .leading, spacing: 8) {
                    Text("自定义快捷键")
                        .font(.title)
                        .fontWeight(.bold)
                    Text("设置全局快捷键来快速输入文本或执行命令")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                // 说明卡片
                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        Image(systemName: "command")
                            .foregroundColor(.purple)
                        Text("快捷键功能")
                            .font(.headline)
                            .fontWeight(.semibold)
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("功能说明：")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        Text("• 设置全局快捷键来快速输入预设文本")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text("• 可用于邮箱地址、常用短语、代码片段等")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text("• 在任何应用中都可以使用")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.leading, 20)
                }
                .padding(20)
                .background(Color(NSColor.controlBackgroundColor))
                .cornerRadius(12)
                
                Divider()
                
                // 快捷键列表
                VStack(alignment: .leading, spacing: 20) {
                    HStack {
                        Text("快捷键配置")
                            .font(.title2)
                            .fontWeight(.semibold)
                        
                        Spacer()
                        
                        Button(action: {
                            showingAddSheet = true
                        }) {
                            HStack(spacing: 6) {
                                Image(systemName: "plus")
                                Text("添加快捷键")
                            }
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    
                    if configManager.config.customHotKeys.isEmpty {
                        VStack(spacing: 12) {
                            Image(systemName: "command.circle")
                                .font(.system(size: 40))
                                .foregroundColor(.secondary)
                            Text("暂无自定义快捷键")
                                .font(.headline)
                                .foregroundColor(.secondary)
                            Text("点击\"添加快捷键\"按钮创建您的第一个自定义快捷键")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 40)
                    } else {
                        LazyVStack(spacing: 12) {
                            ForEach(configManager.config.customHotKeys) { hotKey in
                                CustomHotKeyRow(
                                    hotKey: hotKey,
                                    onEdit: {
                                        editingHotKey = hotKey
                                    },
                                    onDelete: {
                                        removeCustomHotKey(hotKey)
                                    }
                                )
                            }
                        }
                    }
                }
            }
            .padding(32)
        }
        .sheet(isPresented: $showingAddSheet) {
            CustomHotKeyEditView(
                hotKey: nil,
                existingHotKeys: configManager.config.customHotKeys,
                onSave: { newHotKey in
                    addCustomHotKey(newHotKey)
                }
            )
        }
        .sheet(item: $editingHotKey) { hotKey in
            CustomHotKeyEditView(
                hotKey: hotKey,
                existingHotKeys: configManager.config.customHotKeys.filter { $0.id != hotKey.id },
                onSave: { updatedHotKey in
                    updateCustomHotKey(updatedHotKey)
                }
            )
        }
    }
    
    private func addCustomHotKey(_ hotKey: CustomHotKeyConfig) {
        var config = configManager.config
        config.customHotKeys.append(hotKey)
        configManager.config = config
        configManager.saveConfig()
    }
    
    private func updateCustomHotKey(_ updatedHotKey: CustomHotKeyConfig) {
        var config = configManager.config
        if let index = config.customHotKeys.firstIndex(where: { $0.id == updatedHotKey.id }) {
            config.customHotKeys[index] = updatedHotKey
            configManager.config = config
            configManager.saveConfig()
        }
    }
    
    private func removeCustomHotKey(_ hotKey: CustomHotKeyConfig) {
        var config = configManager.config
        config.customHotKeys.removeAll { $0.id == hotKey.id }
        configManager.config = config
        configManager.saveConfig()
    }
}

// MARK: - 自定义快捷键行视图
struct CustomHotKeyRow: View {
    let hotKey: CustomHotKeyConfig
    let onEdit: () -> Void
    let onDelete: () -> Void
    
    var body: some View {
        HStack(spacing: 16) {
            // 快捷键显示
            HStack(spacing: 4) {
                ForEach(getModifierStrings(), id: \.self) { modifier in
                    Text(modifier)
                        .font(.caption)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.purple.opacity(0.1))
                        .foregroundColor(.purple)
                        .cornerRadius(4)
                }
                
                Text(getKeyCodeString())
                    .font(.caption)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.purple.opacity(0.1))
                    .foregroundColor(.purple)
                    .cornerRadius(4)
            }
            .frame(width: 120, alignment: .leading)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(hotKey.name)
                    .font(.headline)
                
                Text(hotKey.text.count > 50 ? String(hotKey.text.prefix(50)) + "..." : hotKey.text)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }
            
            Spacer()
            
            HStack(spacing: 8) {
                Button(action: onEdit) {
                    Image(systemName: "pencil")
                        .foregroundColor(.blue)
                }
                .buttonStyle(PlainButtonStyle())
                
                Button(action: onDelete) {
                    Image(systemName: "trash")
                        .foregroundColor(.red)
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .padding(16)
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(12)
    }
    
    private func getModifierStrings() -> [String] {
        var modifiers: [String] = []
        
        if hotKey.modifiers & UInt32(controlKey) != 0 {
            modifiers.append("⌃")
        }
        if hotKey.modifiers & UInt32(optionKey) != 0 {
            modifiers.append("⌥")
        }
        if hotKey.modifiers & UInt32(shiftKey) != 0 {
            modifiers.append("⇧")
        }
        if hotKey.modifiers & UInt32(cmdKey) != 0 {
            modifiers.append("⌘")
        }
        
        return modifiers
    }
    
    private func getKeyCodeString() -> String {
        // 简化的按键码转换，实际项目中可能需要更完整的映射
        switch hotKey.keyCode {
        case UInt32(kVK_Space): return "Space"
        case UInt32(kVK_Return): return "Return"
        case UInt32(kVK_Tab): return "Tab"
        case UInt32(kVK_Delete): return "Delete"
        case UInt32(kVK_Escape): return "Esc"
        case UInt32(kVK_ANSI_A): return "A"
        case UInt32(kVK_ANSI_B): return "B"
        case UInt32(kVK_ANSI_C): return "C"
        case UInt32(kVK_ANSI_D): return "D"
        case UInt32(kVK_ANSI_E): return "E"
        case UInt32(kVK_ANSI_F): return "F"
        case UInt32(kVK_ANSI_G): return "G"
        case UInt32(kVK_ANSI_H): return "H"
        case UInt32(kVK_ANSI_I): return "I"
        case UInt32(kVK_ANSI_J): return "J"
        case UInt32(kVK_ANSI_K): return "K"
        case UInt32(kVK_ANSI_L): return "L"
        case UInt32(kVK_ANSI_M): return "M"
        case UInt32(kVK_ANSI_N): return "N"
        case UInt32(kVK_ANSI_O): return "O"
        case UInt32(kVK_ANSI_P): return "P"
        case UInt32(kVK_ANSI_Q): return "Q"
        case UInt32(kVK_ANSI_R): return "R"
        case UInt32(kVK_ANSI_S): return "S"
        case UInt32(kVK_ANSI_T): return "T"
        case UInt32(kVK_ANSI_U): return "U"
        case UInt32(kVK_ANSI_V): return "V"
        case UInt32(kVK_ANSI_W): return "W"
        case UInt32(kVK_ANSI_X): return "X"
        case UInt32(kVK_ANSI_Y): return "Y"
        case UInt32(kVK_ANSI_Z): return "Z"
        case UInt32(kVK_ANSI_1): return "1"
        case UInt32(kVK_ANSI_2): return "2"
        case UInt32(kVK_ANSI_3): return "3"
        case UInt32(kVK_ANSI_4): return "4"
        case UInt32(kVK_ANSI_5): return "5"
        case UInt32(kVK_ANSI_6): return "6"
        case UInt32(kVK_ANSI_7): return "7"
        case UInt32(kVK_ANSI_8): return "8"
        case UInt32(kVK_ANSI_9): return "9"
        case UInt32(kVK_ANSI_0): return "0"
        default: return "Key(\(hotKey.keyCode))"
        }
    }
}

// MARK: - 自定义快捷键编辑视图
struct CustomHotKeyEditView: View {
    let hotKey: CustomHotKeyConfig?
    let existingHotKeys: [CustomHotKeyConfig]
    let onSave: (CustomHotKeyConfig) -> Void
    
    @State private var name: String
    @State private var text: String
    @State private var isRecordingHotKey = false
    @State private var modifiers: UInt32
    @State private var keyCode: UInt32
    @State private var globalMonitor: Any?
    @State private var localMonitor: Any?
    @State private var currentModifiers: UInt32 = 0
    
    @Environment(\.dismiss) private var dismiss
    
    init(hotKey: CustomHotKeyConfig?, existingHotKeys: [CustomHotKeyConfig], onSave: @escaping (CustomHotKeyConfig) -> Void) {
        self.hotKey = hotKey
        self.existingHotKeys = existingHotKeys
        self.onSave = onSave
        self._name = State(initialValue: hotKey?.name ?? "")
        self._text = State(initialValue: hotKey?.text ?? "")
        self._modifiers = State(initialValue: hotKey?.modifiers ?? UInt32(optionKey))
        self._keyCode = State(initialValue: hotKey?.keyCode ?? UInt32(kVK_Space))
    }
    
    var isValid: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    var hasConflict: Bool {
        existingHotKeys.contains { existing in
            existing.modifiers == modifiers && existing.keyCode == keyCode
        }
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("基本信息")) {
                    TextField("快捷键名称", text: $name)
                        .help("为这个快捷键起一个描述性的名字")
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("快捷输入文本")
                            .font(.headline)
                        TextEditor(text: $text)
                            .frame(minHeight: 80)
                            .help("按下快捷键时要输入的文本内容")
                    }
                }
                
                Section(header: Text("快捷键设置")) {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("当前快捷键")
                                .font(.headline)
                            
                            Spacer()
                            
                            if hasConflict {
                                Text("快捷键冲突")
                                    .font(.caption)
                                    .foregroundColor(.red)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Color.red.opacity(0.1))
                                    .cornerRadius(6)
                            }
                        }
                        
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
                                    Text(getHotKeyDescription())
                                        .font(.system(size: 16, weight: .semibold, design: .monospaced))
                                }
                            }
                            .padding(.horizontal, 20)
                            .padding(.vertical, 12)
                            .background(isRecordingHotKey ? Color.purple.opacity(0.1) : Color(NSColor.controlBackgroundColor))
                            .foregroundColor(isRecordingHotKey ? .purple : .primary)
                            .cornerRadius(10)
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(
                                        hasConflict ? Color.red : (isRecordingHotKey ? Color.purple : Color.secondary.opacity(0.3)),
                                        lineWidth: 2
                                    )
                            )
                        }
                        .buttonStyle(PlainButtonStyle())
                        .disabled(isRecordingHotKey)
                        
                        if isRecordingHotKey {
                            Button("取消") {
                                cancelRecordingHotKey()
                            }
                            .buttonStyle(.bordered)
                        }
                    }
                }
                
                Section(header: Text("预览")) {
                    if isValid {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("快捷键: \(getHotKeyDescription())")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            Text("输入内容:")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            Text(text)
                                .font(.caption)
                                .padding(8)
                                .background(Color.secondary.opacity(0.1))
                                .cornerRadius(6)
                        }
                    } else {
                        Text("请填写完整信息")
                            .foregroundColor(.secondary)
                            .font(.caption)
                    }
                }
            }
            .navigationTitle(hotKey == nil ? "添加快捷键" : "编辑快捷键")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        let newHotKey = CustomHotKeyConfig(
                            name: name.trimmingCharacters(in: .whitespacesAndNewlines),
                            modifiers: modifiers,
                            keyCode: keyCode,
                            text: text
                        )
                        onSave(newHotKey)
                        dismiss()
                    }
                    .disabled(!isValid || hasConflict)
                }
            }
        }
        .frame(width: 500, height: 600)
        .onDisappear {
            cancelRecordingHotKey()
        }
    }
    
    private func getHotKeyDescription() -> String {
        var description = ""
        
        if modifiers & UInt32(controlKey) != 0 {
            description += "⌃"
        }
        if modifiers & UInt32(optionKey) != 0 {
            description += "⌥"
        }
        if modifiers & UInt32(shiftKey) != 0 {
            description += "⇧"
        }
        if modifiers & UInt32(cmdKey) != 0 {
            description += "⌘"
        }
        
        // 添加按键描述（复用 CustomHotKeyRow 中的逻辑）
        switch keyCode {
        case UInt32(kVK_Space): description += "Space"
        case UInt32(kVK_Return): description += "Return"
        case UInt32(kVK_Tab): description += "Tab"
        case UInt32(kVK_Delete): description += "Delete"
        case UInt32(kVK_Escape): description += "Esc"
        case UInt32(kVK_ANSI_A): description += "A"
        case UInt32(kVK_ANSI_B): description += "B"
        case UInt32(kVK_ANSI_C): description += "C"
        case UInt32(kVK_ANSI_D): description += "D"
        case UInt32(kVK_ANSI_E): description += "E"
        case UInt32(kVK_ANSI_F): description += "F"
        case UInt32(kVK_ANSI_G): description += "G"
        case UInt32(kVK_ANSI_H): description += "H"
        case UInt32(kVK_ANSI_I): description += "I"
        case UInt32(kVK_ANSI_J): description += "J"
        case UInt32(kVK_ANSI_K): description += "K"
        case UInt32(kVK_ANSI_L): description += "L"
        case UInt32(kVK_ANSI_M): description += "M"
        case UInt32(kVK_ANSI_N): description += "N"
        case UInt32(kVK_ANSI_O): description += "O"
        case UInt32(kVK_ANSI_P): description += "P"
        case UInt32(kVK_ANSI_Q): description += "Q"
        case UInt32(kVK_ANSI_R): description += "R"
        case UInt32(kVK_ANSI_S): description += "S"
        case UInt32(kVK_ANSI_T): description += "T"
        case UInt32(kVK_ANSI_U): description += "U"
        case UInt32(kVK_ANSI_V): description += "V"
        case UInt32(kVK_ANSI_W): description += "W"
        case UInt32(kVK_ANSI_X): description += "X"
        case UInt32(kVK_ANSI_Y): description += "Y"
        case UInt32(kVK_ANSI_Z): description += "Z"
        case UInt32(kVK_ANSI_1): description += "1"
        case UInt32(kVK_ANSI_2): description += "2"
        case UInt32(kVK_ANSI_3): description += "3"
        case UInt32(kVK_ANSI_4): description += "4"
        case UInt32(kVK_ANSI_5): description += "5"
        case UInt32(kVK_ANSI_6): description += "6"
        case UInt32(kVK_ANSI_7): description += "7"
        case UInt32(kVK_ANSI_8): description += "8"
        case UInt32(kVK_ANSI_9): description += "9"
        case UInt32(kVK_ANSI_0): description += "0"
        default: description += "Key(\(keyCode))"
        }
        
        return description
    }
    
    private func startRecordingHotKey() {
        isRecordingHotKey = true
        currentModifiers = 0
        
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.keyDown, .flagsChanged]) { event in
            handleKeyEvent(event)
        }
        
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .flagsChanged]) { event in
            handleKeyEvent(event)
            return nil
        }
    }
    
    private func cancelRecordingHotKey() {
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
    
    private func handleKeyEvent(_ event: NSEvent) {
        if event.type == .flagsChanged {
            currentModifiers = UInt32(event.modifierFlags.rawValue & 0xFFFF0000)
        } else if event.type == .keyDown {
            let newModifiers = UInt32(event.modifierFlags.rawValue & 0xFFFF0000)
            let newKeyCode = UInt32(event.keyCode)
            
            // 确保有修饰键
            if newModifiers != 0 {
                modifiers = newModifiers
                keyCode = newKeyCode
                cancelRecordingHotKey()
            }
        }
    }
}
