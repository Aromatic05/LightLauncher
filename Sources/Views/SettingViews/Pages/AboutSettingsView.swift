import SwiftUI

// MARK: - 关于设置视图
struct AboutSettingsView: View {
    @ObservedObject var configManager: ConfigManager
    @State private var showingConfigContent = false
    @State private var configContent = ""
    @State private var showingCleanConfirm = false

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
                                NSWorkspace.shared.selectFile(
                                    configManager.configURL.path, inFileViewerRootedAtPath: "")
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

                // 日志管理（放在关于页，提供快速操作）
                VStack(alignment: .leading, spacing: 12) {
                    Text("日志管理")
                        .font(.title2)
                        .fontWeight(.semibold)

                    VStack(alignment: .leading, spacing: 8) {
                        Toggle(isOn: Binding(
                            get: { configManager.config.logging.printToTerminal },
                            set: { new in
                                configManager.config.logging.printToTerminal = new
                                Task { @MainActor in
                                    configManager.saveConfig()
                                }
                                Logger.shared.apply(config: configManager.config.logging)
                            }
                        )) {
                            Text("在终端显示日志")
                        }

                        Toggle(isOn: Binding(
                            get: { configManager.config.logging.logToFile },
                            set: { new in
                                configManager.config.logging.logToFile = new
                                Task { @MainActor in
                                    configManager.saveConfig()
                                }
                                Logger.shared.apply(config: configManager.config.logging)
                            }
                        )) {
                            Text("写入日志文件（默认关闭）")
                        }

                        // 控制台日志等级
                        HStack {
                            Text("控制台日志等级：")
                            Spacer()
                            Picker("控制台日志等级", selection: Binding(
                                get: { configManager.config.logging.consoleLevel },
                                set: { new in
                                    configManager.config.logging.consoleLevel = new
                                    Task { @MainActor in
                                        configManager.saveConfig()
                                    }
                                    Logger.shared.apply(config: configManager.config.logging)
                                }
                            )) {
                                Text("Debug").tag(AppConfig.LoggingConfig.LogLevel.debug)
                                Text("Info").tag(AppConfig.LoggingConfig.LogLevel.info)
                                Text("Warn").tag(AppConfig.LoggingConfig.LogLevel.warning)
                                Text("Error").tag(AppConfig.LoggingConfig.LogLevel.error)
                            }
                            .pickerStyle(.menu)
                        }

                        // 文件日志等级（仅在启用文件写入时可选）
                        HStack {
                            Text("文件日志等级：")
                            Spacer()
                            Picker("文件日志等级", selection: Binding(
                                get: { configManager.config.logging.fileLevel },
                                set: { new in
                                    configManager.config.logging.fileLevel = new
                                    Task { @MainActor in
                                        configManager.saveConfig()
                                    }
                                    Logger.shared.apply(config: configManager.config.logging)
                                }
                            )) {
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
                    .background(Color(NSColor.controlBackgroundColor).opacity(0.3))
                    .cornerRadius(10)
                }

                Spacer()
            }
            .padding(32)
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
        do {
            configContent = try String(contentsOf: configManager.configURL, encoding: .utf8)
        } catch {
            configContent = "无法读取配置文件: \(error.localizedDescription)"
        }
    }

    // MARK: - Logs helpers
    private func logsDirectoryPath() -> String {
        if let custom = configManager.config.logging.customFilePath, !custom.isEmpty {
            return (custom as NSString).expandingTildeInPath
        }
        let cacheDir = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".cache/LightLauncher", isDirectory: true)
        return cacheDir.path
    }

    private func openLogsDirectory() {
        let path = logsDirectoryPath()
        let url = URL(fileURLWithPath: path, isDirectory: true)
        // If directory doesn't exist, open parent
        var target = url
        if !FileManager.default.fileExists(atPath: url.path) {
            target = url.deletingLastPathComponent()
        }
        NSWorkspace.shared.open(target)
    }

    private func cleanLogs() {
        let path = logsDirectoryPath()
        let url = URL(fileURLWithPath: path, isDirectory: true)
        Task {
            do {
                if FileManager.default.fileExists(atPath: url.path) {
                    let items = try FileManager.default.contentsOfDirectory(at: url, includingPropertiesForKeys: nil)
                    for item in items {
                        try FileManager.default.removeItem(at: item)
                    }
                    Logger.shared.info("已清理日志目录: \(url.path)")
                } else {
                    Logger.shared.info("日志目录不存在，无需清理: \(url.path)")
                }
            } catch {
                Logger.shared.error("清理日志失败: \(error.localizedDescription)")
            }
        }
    }
}
