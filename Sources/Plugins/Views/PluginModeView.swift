import SwiftUI

// MARK: - 插件模式视图
struct PluginModeView: View {
    @ObservedObject var viewModel: LauncherViewModel
    
    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(spacing: 4) {
                    if viewModel.pluginItems.isEmpty {
                        // 空状态视图
                        PluginEmptyStateView(viewModel: viewModel)
                    } else {
                        // 插件结果列表
                        ForEach(Array(viewModel.pluginItems.enumerated()), id: \.offset) { index, item in
                            PluginItemRowView(
                                item: item,
                                isSelected: index == viewModel.selectedIndex,
                                index: index
                            )
                            .id(index)
                            .onTapGesture {
                                viewModel.selectedIndex = index
                                if viewModel.executeSelectedAction() {
                                    // 插件动作执行后可能需要隐藏窗口
                                    NotificationCenter.default.post(name: .hideWindow, object: nil)
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
            .onChange(of: viewModel.selectedIndex) { newIndex in
                withAnimation(.easeInOut(duration: 0.2)) {
                    proxy.scrollTo(newIndex, anchor: .center)
                }
            }
        }
    }
}

// MARK: - 插件空状态视图
struct PluginEmptyStateView: View {
    @ObservedObject var viewModel: LauncherViewModel
    
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "puzzlepiece.extension")
                .font(.system(size: 40))
                .foregroundColor(.secondary.opacity(0.6))
            
            Text(emptyStateTitle)
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.secondary)
            
            if let plugin = viewModel.getActivePlugin() {
                Text("Plugin: \(plugin.displayName)")
                    .font(.system(size: 14))
                    .foregroundColor(.secondary.opacity(0.8))
            }
            
            VStack(spacing: 4) {
                Text("Start typing to search...")
                    .font(.system(size: 14))
                    .foregroundColor(.secondary.opacity(0.7))
                
                if !viewModel.searchText.isEmpty {
                    Text("Plugin is processing your query")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary.opacity(0.6))
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
    }
    
    private var emptyStateTitle: String {
        if viewModel.searchText.isEmpty {
            return "Plugin Ready"
        } else {
            return "No results found"
        }
    }
}

// MARK: - 预览
struct PluginModeView_Previews: PreviewProvider {
    static var previews: some View {
        // 创建模拟的 AppScanner 和 LauncherViewModel
        let appScanner = AppScanner()
        let viewModel = LauncherViewModel(appScanner: appScanner)
        
        // 设置模拟数据
        viewModel.mode = .plugin
        viewModel.selectedIndex = 0
        viewModel.pluginItems = [
            PluginItem(
                title: "Add new todo...",
                subtitle: "Type 'add <task>' to create a new todo",
                icon: "plus.circle",
                action: "add_new"
            ),
            PluginItem(
                title: "✅ Learn JavaScript",
                subtitle: "Completed",
                icon: "checkmark.circle.fill",
                action: "toggle_1"
            ),
            PluginItem(
                title: "⭕ Build a plugin system",
                subtitle: "Todo",
                icon: "circle",
                action: "toggle_2"
            ),
            PluginItem(
                title: "⭕ Test the plugin",
                subtitle: "Todo",
                icon: "circle",
                action: "toggle_3"
            )
        ]
        
        return PluginModeView(viewModel: viewModel)
            .frame(width: 700, height: 400)
            .background(Color(NSColor.windowBackgroundColor))
    }
}
