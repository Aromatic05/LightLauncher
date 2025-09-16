import AppKit
import Foundation

class WebUtils {
    private static func isDomainName(_ text: String) -> Bool {
        return text.contains(".") && !text.contains(" ") && !text.hasPrefix(".")
    }

    @MainActor
    private static func getDefaultSearchEngineURL() -> String {
        let engine = ConfigManager.shared.config.modes.defaultSearchEngine
        switch engine {
        case "baidu": return "https://www.baidu.com/s?wd={query}"
        case "bing": return "https://www.bing.com/search?q={query}"
        default: return "https://www.google.com/search?q={query}"
        }
    }

    @MainActor
    static func performWebSearch(
        query: String, encoding: String = "%20", searchEngine: String? = nil,
        category: String? = nil
    ) -> Bool {
        guard !query.trimmingCharacters(in: .whitespaces).isEmpty else { return false }

        let engine = searchEngine ?? ConfigManager.shared.config.modes.defaultSearchEngine
        let category = category ?? ConfigManager.shared.config.modes.defaultSearchEngine
        let encodedQuery: String
        if encoding == "%20" {
            encodedQuery =
                query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query
        } else {
            encodedQuery = query.replacingOccurrences(of: " ", with: encoding)
        }

        let searchURLString = engine.replacingOccurrences(
            of: "{query}", with: encodedQuery)

        SearchHistoryManager.shared.addSearch(query: query, category: category)
        if let url = URL(string: searchURLString) {
            NSWorkspace.shared.open(url)
            return true
        }
        return false
    }

    @MainActor
    static func openWebURL(_ text: String) -> Bool {
        let cleanText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanText.isEmpty else { return false }

        // Try to form a URL directly
        if let url = URL(string: cleanText), url.scheme != nil {
            NSWorkspace.shared.open(url)
            return true
        }

        // Try to treat it as a domain name (e.g., "apple.com")
        if isDomainName(cleanText) {
            if let url = URL(string: "https://\(cleanText)") {
                NSWorkspace.shared.open(url)
                return true
            }
        }

        // Fallback to searching with the default search engine
        return performWebSearch(query: cleanText)
    }
}
