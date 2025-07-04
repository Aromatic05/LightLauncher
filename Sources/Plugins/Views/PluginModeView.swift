import SwiftUI

// MARK: - 插件模式视图
struct PluginModeView: View {
    @ObservedObject var viewModel: LauncherViewModel
    
    var body: some View {
        let pluginController = viewModel.controllers[.plugin] as? PluginStateController
        let pluginItems = pluginController?.pluginItems ?? []
        let isEmpty = pluginItems.isEmpty
        
        return ScrollViewReader { proxy in
            ScrollView {
                VStack(spacing: 4) {
                    if isEmpty {
                        // 空状态视图
                        PluginEmptyStateView(viewModel: viewModel, pluginController: pluginController)
                    } else {
                        // 插件结果列表
                        ForEach(Array(pluginItems.enumerated()), id: \.offset) { index, item in
                            PluginItemRowView(
                                item: item,
                                isSelected: index == viewModel.selectedIndex,
                                index: index
                            )
                            .id(index)
                            .onTapGesture {
                                viewModel.selectedIndex = index
                                if viewModel.executeSelectedAction() {
                                    if pluginController?.getPluginShouldHideWindowAfterAction() == true {
                                        NotificationCenter.default.post(name: .hideWindow, object: nil)
                                    }
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
    let pluginController: PluginStateController?
    
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "puzzlepiece.extension")
                .font(.system(size: 40))
                .foregroundColor(.secondary.opacity(0.6))
            
            Text(emptyStateTitle)
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.secondary)
            
            if let plugin = pluginController?.getActivePlugin() {
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
