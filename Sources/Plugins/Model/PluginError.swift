import Foundation

// MARK: - 插件系统错误类型
enum PluginError: Error, LocalizedError {
    case directoryNotFound(String)
    case manifestNotFound(String)
    case invalidManifest(String)
    case scriptLoadFailed(String)
    case javascriptExecutionError(String)
    case pluginNotFound(String)
    case duplicateCommand(String)
    case invalidCommand(String)
    case contextCreationFailed
    
    var errorDescription: String? {
        switch self {
        case .directoryNotFound(let path):
            return "Plugin directory not found: \(path)"
        case .manifestNotFound(let path):
            return "Plugin manifest not found: \(path)"
        case .invalidManifest(let reason):
            return "Invalid plugin manifest: \(reason)"
        case .scriptLoadFailed(let reason):
            return "Failed to load plugin script: \(reason)"
        case .javascriptExecutionError(let error):
            return "JavaScript execution error: \(error)"
        case .pluginNotFound(let name):
            return "Plugin not found: \(name)"
        case .duplicateCommand(let command):
            return "Duplicate plugin command: \(command)"
        case .invalidCommand(let command):
            return "Invalid plugin command: \(command)"
        case .contextCreationFailed:
            return "Failed to create JavaScript context"
        }
    }
    
    var recoverySuggestion: String? {
        switch self {
        case .directoryNotFound:
            return "Check if the plugin directory exists and is accessible"
        case .manifestNotFound:
            return "Ensure the plugin has a valid manifest.json file"
        case .invalidManifest:
            return "Check the plugin manifest format and required fields"
        case .scriptLoadFailed:
            return "Verify the plugin script file exists and is readable"
        case .javascriptExecutionError:
            return "Check the plugin JavaScript code for syntax errors"
        case .pluginNotFound:
            return "Install the plugin or check if it's properly loaded"
        case .duplicateCommand:
            return "Remove duplicate plugins or change the command trigger"
        case .invalidCommand:
            return "Use a valid command format starting with '/'"
        case .contextCreationFailed:
            return "Restart the application or check system resources"
        }
    }
}

// MARK: - 插件加载结果
enum PluginLoadResult {
    case success(Plugin)
    case failure(PluginError)
    case skipped(String) // 跳过加载的原因
    
    var isSuccess: Bool {
        if case .success = self {
            return true
        }
        return false
    }
    
    var plugin: Plugin? {
        if case .success(let plugin) = self {
            return plugin
        }
        return nil
    }
    
    var error: PluginError? {
        if case .failure(let error) = self {
            return error
        }
        return nil
    }
}
