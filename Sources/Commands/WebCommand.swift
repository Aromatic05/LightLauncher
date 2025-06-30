import Foundation
import AppKit

// MARK: - 网页打开命令处理器
@MainActor
class WebCommandProcessor: CommandProcessor {
    func canHandle(command: String) -> Bool {
        return command == "/w"
    }
    
    func process(command: String, in viewModel: LauncherViewModel) -> Bool {
        guard command == "/w" else { return false }
        viewModel.switchToWebMode()
        return true
    }
    
    func handleSearch(text: String, in viewModel: LauncherViewModel) {
        // 在网页打开模式下，直接显示输入文本，不需要过滤
        // 用户按回车时会打开网页
    }
    
    func executeAction(at index: Int, in viewModel: LauncherViewModel) -> Bool {
        guard viewModel.mode == .web else { return false }
        
        // 提取URL文本，去掉 "/w " 前缀
        let urlText = viewModel.searchText.hasPrefix("/w ") ? 
            String(viewModel.searchText.dropFirst(3)) : viewModel.searchText
        
        guard !urlText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return false
        }
        
        return openWebsite(urlText: urlText, in: viewModel)
    }
    
    private func openWebsite(urlText: String, in viewModel: LauncherViewModel) -> Bool {
        let cleanText = urlText.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // 首先尝试直接解析为URL
        if let url = URL(string: cleanText), url.scheme != nil {
            NSWorkspace.shared.open(url)
            viewModel.resetToLaunchMode()
            return true
        }
        
        // 如果不是完整URL，检查是否是域名
        if isDomainName(cleanText) {
            if let url = URL(string: "https://\(cleanText)") {
                NSWorkspace.shared.open(url)
                viewModel.resetToLaunchMode()
                return true
            }
        }
        
        // 如果都不是，作为搜索处理
        let encodedQuery = cleanText.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? cleanText
        let searchURL = getDefaultSearchEngine().replacingOccurrences(of: "{query}", with: encodedQuery)
        
        if let url = URL(string: searchURL) {
            NSWorkspace.shared.open(url)
            viewModel.resetToLaunchMode()
            return true
        }
        
        return false
    }
    
    private func getDefaultSearchEngine() -> String {
        let configManager = ConfigManager.shared
        let engine = configManager.config.modes.defaultSearchEngine
        
        switch engine {
        case "baidu":
            return "https://www.baidu.com/s?wd={query}"
        case "bing":
            return "https://www.bing.com/search?q={query}"
        case "google":
            fallthrough
        default:
            return "https://www.google.com/search?q={query}"
        }
    }
    
    private func isDomainName(_ text: String) -> Bool {
        // 简单的域名检测：包含点且不包含空格
        return text.contains(".") && !text.contains(" ") && !text.hasPrefix(".")
    }
}

// MARK: - LauncherViewModel 扩展
extension LauncherViewModel {
    func switchToWebMode() {
        mode = .web
        selectedIndex = 0
    }
}
