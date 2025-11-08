import SwiftUI

// MARK: - 自定义快捷键编辑视图
struct CustomHotKeyEditView: View {
    let hotKey: CustomHotKeyConfig?
    let existingHotKeys: [CustomHotKeyConfig]
    let onSave: (CustomHotKeyConfig) -> Void

    @State private var name: String
    @State private var type: String
    @State private var text: String
    @State private var hotkey: HotKey
    @StateObject private var hotKeyRecorder = HotKeyRecorder()

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
        self._hotkey = State(
            initialValue: hotKey?.hotkey ?? HotKey(keyCode: UInt32(kVK_Space), option: true))
    }

    var isValid: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var hasConflict: Bool {
        existingHotKeys.contains { existing in
            // 排除当前编辑项（按 name）
            if existing.name == name { return false }
            return existing.hotkey.rawValue == hotkey.rawValue
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
            hotKeyRecorder.stopRecording()
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
                    recorder: hotKeyRecorder,
                    hotkey: $hotkey,
                    hasConflict: hasConflict,
                    onKeyRecorded: { newHotKey in
                        hotkey = newHotKey
                    }
                )

                HotKeyPreviewCard(
                    isValid: isValid,
                    hotkey: hotkey,
                    text: text
                )
            }
            .padding(20)
        }
    }

    private func saveHotKey() {
        let newHotKey = CustomHotKeyConfig(
            name: name.trimmingCharacters(in: .whitespacesAndNewlines),
            hotkey: hotkey,
            type: type,
            text: text
        )
        onSave(newHotKey)
        dismiss()
    }
}
