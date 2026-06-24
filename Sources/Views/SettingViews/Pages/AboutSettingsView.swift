import SwiftUI

// MARK: - 关于设置视图
struct AboutSettingsView: View {
    @ObservedObject var configManager: ConfigManager
    @State private var showingConfigContent = false
    @State private var configContent = ""
    @State private var showingCleanConfirm = false
    private let fileAccess = FileAccessService.shared

    private func loggingBinding<Value>(
        _ keyPath: WritableKeyPath<AppConfig.LoggingConfig, Value>
    ) -> Binding<Value> {
        Binding(
            get: { configManager.config.logging[keyPath: keyPath] },
            set: { newValue in
                configManager.config.logging[keyPath: keyPath] = newValue
                configManager.saveConfig()
                Logger.shared.apply(config: configManager.config.logging)
            }
        )
    }

    var body: some View {
        SettingsPage {
            PageHeader(title: "关于 LightLauncher", subtitle: "轻量级应用启动器")

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
                .settingsCard(opacity: 0.5, cornerRadius: 16)

                VStack(alignment: .leading, spacing: 16) {
                    SectionHeader(title: "功能特性")

                    VStack(alignment: .leading, spacing: 8) {
                        FeatureItem(icon: "magnifyingglass", text: "快速应用搜索和启动")
                        FeatureItem(icon: "keyboard", text: "支持自定义快捷键（包括左右修饰键）")
                        FeatureItem(icon: "textformat.abc", text: "智能缩写匹配")
                        FeatureItem(icon: "folder", text: "可配置搜索目录")
                        FeatureItem(icon: "doc.text", text: "YAML 配置文件管理")
                    }
                }
                .padding(20)
                .settingsCard()
            }

            VStack(alignment: .leading, spacing: 16) {
                SectionHeader(title: "配置文件管理")

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
                            NSWorkspace.shared.selectFile(
                                configManager.configURL.path, inFileViewerRootedAtPath: "")
                        }
                        .buttonStyle(.bordered)
                    }
                    .padding(16)
                    .settingsCard(cornerRadius: 10)

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

            VStack(alignment: .leading, spacing: 12) {
                SectionHeader(title: "日志管理")

                VStack(alignment: .leading, spacing: 8) {
                    Toggle(
                        isOn: loggingBinding(\.printToTerminal)
                    ) {
                        Text("在终端显示日志")
                    }

                    Toggle(
                        isOn: loggingBinding(\.logToFile)
                    ) {
                        Text("写入日志文件（默认关闭）")
                    }

                    HStack {
                        Text("控制台日志等级：")
                        Spacer()
                        Picker(
                            "控制台日志等级",
                            selection: loggingBinding(\.consoleLevel)
                        ) {
                            Text("Debug").tag(AppConfig.LoggingConfig.LogLevel.debug)
                            Text("Info").tag(AppConfig.LoggingConfig.LogLevel.info)
                            Text("Warn").tag(AppConfig.LoggingConfig.LogLevel.warning)
                            Text("Error").tag(AppConfig.LoggingConfig.LogLevel.error)
                        }
                        .pickerStyle(.menu)
                    }

                    HStack {
                        Text("文件日志等级：")
                        Spacer()
                        Picker(
                            "文件日志等级",
                            selection: loggingBinding(\.fileLevel)
                        ) {
                            Text("Debug").tag(AppConfig.LoggingConfig.LogLevel.debug)
                            Text("Info").tag(AppConfig.LoggingConfig.LogLevel.info)
                            Text("Warn").tag(AppConfig.LoggingConfig.LogLevel.warning)
                            Text("Error").tag(AppConfig.LoggingConfig.LogLevel.error)
                        }
                        .pickerStyle(.menu)
                        .disabled(!configManager.config.logging.logToFile)
                    }

                    HStack {
                        Text("当前日志目录：")
                        Spacer()
                        Text(logsDirectoryPath())
                            .font(.system(.caption, design: .monospaced))
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                            .textSelection(.enabled)
                    }

                    HStack(spacing: 12) {
                        Button("打开日志文件夹") {
                            openLogsDirectory()
                        }
                        .buttonStyle(.bordered)

                        Button("清理日志") {
                            showingCleanConfirm = true
                        }
                        .buttonStyle(.bordered)
                        .foregroundColor(.red)
                    }
                }
                .padding(12)
                .settingsCard(cornerRadius: 10)
            }
        }
        .sheet(isPresented: $showingConfigContent) {
            ConfigContentView(content: configContent)
        }
        .alert("确认清理日志？", isPresented: $showingCleanConfirm) {
            Button("清理", role: .destructive) {
                cleanLogs()
            }
            Button("取消", role: .cancel) {}
        } message: {
            Text("此操作会删除 LightLauncher 的所有日志文件（位于 ~/.cache/LightLauncher 或自定义路径），该操作不可撤销。")
        }
    }

    private func loadConfigContent() {
        configContent =
            (try? fileAccess.readString(from: configManager.configURL))
            ?? "无法读取配置文件"
    }

    // MARK: - Logs helpers
    private func logsDirectoryPath() -> String {
        if let custom = configManager.config.logging.customFilePath, !custom.isEmpty { return (custom as NSString).expandingTildeInPath }
        return fileAccess.homeDirectory.appendingPathComponent(".cache/LightLauncher", isDirectory: true).path
    }

    private func openLogsDirectory() {
        let url = URL(fileURLWithPath: logsDirectoryPath(), isDirectory: true)
        NSWorkspace.shared.open(fileAccess.fileExists(at: url) ? url : url.deletingLastPathComponent())
    }

    private func cleanLogs() {
        let url = URL(fileURLWithPath: logsDirectoryPath(), isDirectory: true)
        do {
            if fileAccess.directoryExists(at: url) {
                try fileAccess.clearDirectoryContents(at: url)
                Logger.shared.info("已清理日志目录: \(url.path)")
            } else {
                Logger.shared.info("日志目录不存在，无需清理: \(url.path)")
            }
        } catch {
            Logger.shared.error("清理日志失败: \(error.localizedDescription)")
        }
    }
}
