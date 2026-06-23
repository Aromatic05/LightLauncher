import SwiftUI

// MARK: - 插件模式视图
struct PluginModeView: View {
    @ObservedObject var viewModel: LauncherViewModel

    private var items: [any DisplayableItem] { viewModel.displayableItems }
    private var isEmpty: Bool { items.isEmpty }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                contentView
            }
            .onChange(of: viewModel.selectedIndex) { newIndex in
                withAnimation(.easeInOut(duration: 0.2)) {
                    proxy.scrollTo(newIndex, anchor: .center)
                }
            }
        }
    }

    @ViewBuilder
    private var contentView: some View {
        VStack(spacing: 4) {
            if isEmpty {
                // 空状态视图
                PluginEmptyStateView(
                    viewModel: viewModel,
                    pluginController: viewModel.controllers[.plugin] as? PluginModeController)
            } else {
                // 插件结果列表
                ForEach(Array(items.enumerated()), id: \.offset) { index, item in
                    if let pluginItem = item as? PluginItem {
                        PluginItemRowView(
                            item: pluginItem,
                            isSelected: index == viewModel.selectedIndex,
                            index: index
                        )
                        .id(index)
                        .onTapGesture {
                            viewModel.selectedIndex = index
                            if viewModel.executeSelectedAction(at: index) {
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
}

// MARK: - 插件空状态视图
struct PluginEmptyStateView: View {
    @ObservedObject var viewModel: LauncherViewModel
    let pluginController: PluginModeController?

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "puzzlepiece.extension")
                .font(.system(size: 40))
                .foregroundColor(.secondary.opacity(0.6))

            Text(emptyStateTitle)
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.secondary)

            if let plugin = pluginController?.currentPlugin {
                Text("Plugin: \(plugin.manifest.displayName)")
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
