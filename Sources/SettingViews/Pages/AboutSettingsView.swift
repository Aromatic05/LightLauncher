import SwiftUI

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
                            SettingsFeatureItem(icon: "magnifyingglass", text: "快速应用搜索和启动")
                            SettingsFeatureItem(icon: "keyboard", text: "支持自定义快捷键（包括左右修饰键）")
                            SettingsFeatureItem(icon: "textformat.abc", text: "智能缩写匹配")
                            SettingsFeatureItem(icon: "folder", text: "可配置搜索目录")
                            SettingsFeatureItem(icon: "doc.text", text: "YAML 配置文件管理")
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
