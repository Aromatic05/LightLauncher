import SwiftUI

// MARK: - 自定义快捷键设置视图
struct CustomHotKeySettingsView: View {
    @ObservedObject var configManager: ConfigManager
    @State private var showingAddSheet = false
    @State private var editingHotKey: CustomHotKeyConfig?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 32) {
                headerView
                CustomHotKeyInfoCard()
                Divider()
                hotKeysSection
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

    private var headerView: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("自定义快捷键")
                .font(.title)
                .fontWeight(.bold)
            Text("设置全局快捷键来快速输入文本或执行命令")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
    }

    private var hotKeysSection: some View {
        VStack(alignment: .leading, spacing: 20) {
            CustomHotKeyListHeader {
                showingAddSheet = true
            }

            if configManager.config.customHotKeys.isEmpty {
                CustomHotKeyEmptyView()
            } else {
                hotKeysList
            }
        }
    }

    private var hotKeysList: some View {
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

// MARK: - 自定义快捷键编辑视图
struct CustomHotKeyEditView: View {
    let hotKey: CustomHotKeyConfig?
    let existingHotKeys: [CustomHotKeyConfig]
    let onSave: (CustomHotKeyConfig) -> Void

    @State private var name: String
    @State private var type: String
    @State private var text: String
    @State private var isRecordingHotKey = false
    @State private var modifiers: UInt32
    @State private var keyCode: UInt32
    @State private var globalMonitor: Any?
    @State private var localMonitor: Any?
    @State private var currentModifiers: UInt32 = 0

    @Environment(\.dismiss) private var dismiss

    init(
        hotKey: CustomHotKeyConfig?, existingHotKeys: [CustomHotKeyConfig],
        onSave: @escaping (CustomHotKeyConfig) -> Void
    ) {
        self.hotKey = hotKey
        self.existingHotKeys = existingHotKeys
        self.onSave = onSave
        self._name = State(initialValue: hotKey?.name ?? "")
        self._type = State(initialValue: hotKey?.type ?? "query")
        self._text = State(initialValue: hotKey?.text ?? "")
        self._modifiers = State(initialValue: hotKey?.modifiers ?? UInt32(optionKey))
        self._keyCode = State(initialValue: hotKey?.keyCode ?? 49)
    }

    var isValid: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var hasConflict: Bool {
        existingHotKeys.contains { existing in
            existing.modifiers == modifiers && existing.keyCode == keyCode
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            headerView
            Divider()
            contentView
        }
        .frame(width: 600, height: 700)
        .background(Color(NSColor.windowBackgroundColor))
        .onDisappear {
            cancelRecordingHotKey()
        }
    }

    private var headerView: some View {
        HStack {
            Text(hotKey == nil ? "添加快捷键" : "编辑快捷键")
                .font(.title2)
                .fontWeight(.semibold)

            Spacer()

            Button("取消") {
                dismiss()
            }
            .buttonStyle(.bordered)

            Button("保存") {
                saveHotKey()
            }
            .disabled(!isValid || hasConflict)
            .buttonStyle(.borderedProminent)
        }
        .padding(20)
        .background(Color(NSColor.windowBackgroundColor))
    }

    private var contentView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                HotKeyBasicInfoForm(name: $name, type: $type, text: $text)

                HotKeySettingsCard(
                    isRecording: $isRecordingHotKey,
                    modifiers: $modifiers,
                    keyCode: $keyCode,
                    hasConflict: hasConflict,
                    onStartRecording: startRecordingHotKey,
                    onCancelRecording: cancelRecordingHotKey
                )

                HotKeyPreviewCard(
                    isValid: isValid,
                    modifiers: modifiers,
                    keyCode: keyCode,
                    text: text
                )
            }
            .padding(20)
        }
    }

    private func saveHotKey() {
        let newHotKey = CustomHotKeyConfig(
            name: name.trimmingCharacters(in: .whitespacesAndNewlines),
            modifiers: modifiers,
            keyCode: keyCode,
            type: type,
            text: text
        )
        onSave(newHotKey)
        dismiss()
    }

    private func startRecordingHotKey() {
        isRecordingHotKey = true
        currentModifiers = 0

        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.keyDown, .flagsChanged]) {
            event in
            handleKeyEvent(event)
        }

        localMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .flagsChanged]) {
            event in
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
        guard isRecordingHotKey else { return }
        if event.type == .keyDown {
            let keyCode = UInt32(event.keyCode)
            let modifiers = event.modifierFlags
            let validKeys: [UInt32] = [
                49, 36, 53, 48,
                122, 120, 99, 118,
                96, 97, 98, 100,
                101, 109, 103, 111,
                0, 11, 8, 2,
                14, 3, 5, 4,
                34, 38, 40, 37,
                46, 45, 31, 35,
                12, 15, 1, 17,
                32, 9, 13, 7,
                16, 6,
            ]
            if validKeys.contains(keyCode) || (modifiers.rawValue != 0) {
                let carbonModifiers = carbonModifiersFromCocoaModifiers(modifiers)
                self.modifiers = carbonModifiers
                self.keyCode = keyCode
                cancelRecordingHotKey()
            }
        } else if event.type == .flagsChanged {
            let modifiers = event.modifierFlags
            currentModifiers = carbonModifiersFromCocoaModifiers(modifiers)
            // 检查是否为单独的右 Command 或右 Option
            if modifiers.contains(.command) && event.keyCode == 54 {  // 右 Command
                self.modifiers = 0x100010
                self.keyCode = 0
                cancelRecordingHotKey()
            } else if modifiers.contains(.option) && event.keyCode == 61 {  // 右 Option
                self.modifiers = 0x100040
                self.keyCode = 0
                cancelRecordingHotKey()
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
}
