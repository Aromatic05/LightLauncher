import Foundation
import Carbon
import Yams

// 配置数据结构
struct AppConfig: Codable {
    var hotKey: HotKeyConfig
    var searchDirectories: [String]
    var commonAbbreviations: [String: [String]]
    
    struct HotKeyConfig: Codable {
        var modifiers: UInt32
        var keyCode: UInt32
        
        init(modifiers: UInt32 = UInt32(optionKey), keyCode: UInt32 = UInt32(kVK_Space)) {
            self.modifiers = modifiers
            self.keyCode = keyCode
        }
    }
}

// 配置管理器
@MainActor
class ConfigManager: ObservableObject {
    static let shared = ConfigManager()
    
    @Published var config: AppConfig
    
    // 配置文件路径
    let configURL: URL
    
    private init() {
        // 创建配置目录
        let homeDirectory = FileManager.default.homeDirectoryForCurrentUser
        let configDirectory = homeDirectory.appendingPathComponent(".config/LightLauncher")
        
        do {
            try FileManager.default.createDirectory(at: configDirectory, withIntermediateDirectories: true, attributes: nil)
        } catch {
            print("无法创建配置目录: \(error)")
        }
        
        self.configURL = configDirectory.appendingPathComponent("config.yaml")
        
        // 加载或创建默认配置
        if let loadedConfig = Self.loadConfig(from: configURL) {
            self.config = loadedConfig
        } else {
            self.config = Self.createDefaultConfig()
            saveConfig()
        }
    }
    
    // 创建默认配置
    private static func createDefaultConfig() -> AppConfig {
        return AppConfig(
            hotKey: AppConfig.HotKeyConfig(),
            searchDirectories: [
                "/Applications",
                "/Applications/Utilities",
                "/System/Applications",
                "/System/Applications/Utilities",
                "~/Applications"
            ],
            commonAbbreviations: [
                "ps": ["photoshop"],
                "ai": ["illustrator"],
                "pr": ["premiere"],
                "ae": ["after effects"],
                "id": ["indesign"],
                "lr": ["lightroom"],
                "dw": ["dreamweaver"],
                "xd": ["adobe xd"],
                "vs": ["visual studio", "code"],
                "vsc": ["visual studio code", "code"],
                "code": ["visual studio code", "code"],
                "chrome": ["google chrome"],
                "ff": ["firefox"],
                "safari": ["safari"],
                "edge": ["microsoft edge"],
                "word": ["microsoft word"],
                "excel": ["microsoft excel"],
                "ppt": ["powerpoint"],
                "outlook": ["microsoft outlook"],
                "teams": ["microsoft teams"],
                "qq": ["qq"],
                "wx": ["wechat", "微信"],
                "wechat": ["微信"],
                "sketch": ["sketch"],
                "figma": ["figma"],
                "notion": ["notion"],
                "slack": ["slack"],
                "zoom": ["zoom"],
                "terminal": ["terminal"],
                "finder": ["finder"],
                "calculator": ["calculator"],
                "preview": ["preview"],
                "notes": ["notes"],
                "music": ["music"],
                "photos": ["photos"],
                "mail": ["mail"],
                "calendar": ["calendar"],
                "xcode": ["xcode"],
                "simulator": ["simulator"],
                "docker": ["docker"],
                "postman": ["postman"],
                "git": ["github desktop", "sourcetree"],
                "vm": ["vmware", "parallels"],
                "1password": ["1password"],
                "alfred": ["alfred"],
                "raycast": ["raycast"],
                "obsidian": ["obsidian"],
                "typora": ["typora"],
                "istat": ["istat menus"],
                "cleanmymac": ["cleanmymac"],
                "bartender": ["bartender"],
                "magnet": ["magnet"],
                "rectangle": ["rectangle"],
                "amphetamine": ["amphetamine"],
                "homebrew": ["homebrew"]
            ]
        )
    }
    
    // 从文件加载配置
    private static func loadConfig(from url: URL) -> AppConfig? {
        do {
            let yamlString = try String(contentsOf: url, encoding: .utf8)
            let decoder = YAMLDecoder()
            return try decoder.decode(AppConfig.self, from: yamlString)
        } catch {
            print("加载配置文件失败: \(error)")
            return nil
        }
    }
    
    // 保存配置到文件
    func saveConfig() {
        do {
            let encoder = YAMLEncoder()
            let yamlString = try encoder.encode(config)
            
            // 添加注释头部
            let commentedYaml = """
# LightLauncher 配置文件
# 修改此文件后，需要重启应用或在设置中点击"重新加载配置"

# 全局热键配置
# modifiers: 修饰键组合 (可选值: 256=Cmd, 512=Shift, 1024=Option, 2048=Ctrl)
# 特殊值: 1048592=右Cmd, 1048640=右Option
# keyCode: 按键代码 (0表示仅修饰键, 49=Space, 36=Return 等)

\(yamlString)
"""
            
            try commentedYaml.write(to: configURL, atomically: true, encoding: .utf8)
            print("配置已保存到: \(configURL.path)")
        } catch {
            print("保存配置文件失败: \(error)")
        }
    }
    
    // 重新加载配置
    func reloadConfig() {
        if let loadedConfig = Self.loadConfig(from: configURL) {
            self.config = loadedConfig
            print("配置已重新加载")
        }
    }
    
    // 更新热键配置
    func updateHotKey(modifiers: UInt32, keyCode: UInt32) {
        config.hotKey.modifiers = modifiers
        config.hotKey.keyCode = keyCode
        saveConfig()
        
        // 通知热键变化
        NotificationCenter.default.post(name: .hotKeyChanged, object: nil)
    }
    
    // 获取热键描述
    func getHotKeyDescription() -> String {
        let modifiers = config.hotKey.modifiers
        let keyCode = config.hotKey.keyCode
        
        var description = ""
        
        // 检查特殊的左右修饰键
        if modifiers == 0x100010 { // 右 Command
            description += "R⌘"
        } else if modifiers == 0x100040 { // 右 Option
            description += "R⌥"
        } else {
            // 标准修饰键
            if modifiers & UInt32(cmdKey) != 0 {
                description += "⌘"
            }
            if modifiers & UInt32(optionKey) != 0 {
                description += "⌥"
            }
            if modifiers & UInt32(controlKey) != 0 {
                description += "⌃"
            }
            if modifiers & UInt32(shiftKey) != 0 {
                description += "⇧"
            }
        }
        
        // 如果只有修饰键没有普通键，则不添加键名
        if keyCode == 0 {
            return description.isEmpty ? "无" : description
        }
        
        description += getKeyName(for: keyCode)
        
        return description
    }
    
    private func getKeyName(for keyCode: UInt32) -> String {
        switch keyCode {
        case UInt32(kVK_Space):
            return "Space"
        case UInt32(kVK_Return):
            return "Return"
        case UInt32(kVK_Escape):
            return "Escape"
        case UInt32(kVK_Tab):
            return "Tab"
        case UInt32(kVK_Delete):
            return "Delete"
        case UInt32(kVK_F1):
            return "F1"
        case UInt32(kVK_F2):
            return "F2"
        case UInt32(kVK_F3):
            return "F3"
        case UInt32(kVK_F4):
            return "F4"
        case UInt32(kVK_F5):
            return "F5"
        case UInt32(kVK_F6):
            return "F6"
        case UInt32(kVK_F7):
            return "F7"
        case UInt32(kVK_F8):
            return "F8"
        case UInt32(kVK_F9):
            return "F9"
        case UInt32(kVK_F10):
            return "F10"
        case UInt32(kVK_F11):
            return "F11"
        case UInt32(kVK_F12):
            return "F12"
        case UInt32(kVK_ANSI_A):
            return "A"
        case UInt32(kVK_ANSI_B):
            return "B"
        case UInt32(kVK_ANSI_C):
            return "C"
        case UInt32(kVK_ANSI_D):
            return "D"
        case UInt32(kVK_ANSI_E):
            return "E"
        case UInt32(kVK_ANSI_F):
            return "F"
        case UInt32(kVK_ANSI_G):
            return "G"
        case UInt32(kVK_ANSI_H):
            return "H"
        case UInt32(kVK_ANSI_I):
            return "I"
        case UInt32(kVK_ANSI_J):
            return "J"
        case UInt32(kVK_ANSI_K):
            return "K"
        case UInt32(kVK_ANSI_L):
            return "L"
        case UInt32(kVK_ANSI_M):
            return "M"
        case UInt32(kVK_ANSI_N):
            return "N"
        case UInt32(kVK_ANSI_O):
            return "O"
        case UInt32(kVK_ANSI_P):
            return "P"
        case UInt32(kVK_ANSI_Q):
            return "Q"
        case UInt32(kVK_ANSI_R):
            return "R"
        case UInt32(kVK_ANSI_S):
            return "S"
        case UInt32(kVK_ANSI_T):
            return "T"
        case UInt32(kVK_ANSI_U):
            return "U"
        case UInt32(kVK_ANSI_V):
            return "V"
        case UInt32(kVK_ANSI_W):
            return "W"
        case UInt32(kVK_ANSI_X):
            return "X"
        case UInt32(kVK_ANSI_Y):
            return "Y"
        case UInt32(kVK_ANSI_Z):
            return "Z"
        default:
            return "Key(\(keyCode))"
        }
    }
    
    // 添加搜索目录
    func addSearchDirectory(_ path: String) {
        if !config.searchDirectories.contains(path) {
            config.searchDirectories.append(path)
            saveConfig()
        }
    }
    
    // 移除搜索目录
    func removeSearchDirectory(_ path: String) {
        config.searchDirectories.removeAll { $0 == path }
        saveConfig()
    }
    
    // 添加缩写
    func addAbbreviation(key: String, values: [String]) {
        config.commonAbbreviations[key] = values
        saveConfig()
    }
    
    // 移除缩写
    func removeAbbreviation(key: String) {
        config.commonAbbreviations.removeValue(forKey: key)
        saveConfig()
    }
    
    // 重置为默认配置
    func resetToDefaults() {
        config = Self.createDefaultConfig()
        saveConfig()
        
        // 通知热键变化
        NotificationCenter.default.post(name: .hotKeyChanged, object: nil)
    }
}
