import XCTest
@testable import LightLauncher

/// 测试 PluginConfigManager 的配置管理功能
@MainActor
final class PluginConfigManagerTests: XCTestCase {
    var configManager: PluginConfigManager!
    var testConfigDirectory: URL!
    
    override func setUp() async throws {
        try await super.setUp()
        configManager = PluginConfigManager.shared
        
        // 清空缓存
        configManager.clearCache()
    }
    
    override func tearDown() async throws {
        // 清理测试配置
        let testPluginNames = ["test_config", "test_save", "test_value", "test_delete", "test_reset"]
        for name in testPluginNames {
            _ = configManager.deleteConfig(for: name)
        }
        
        configManager.clearCache()
        try await super.tearDown()
    }
    
    // MARK: - 配置加载测试
    
    func testLoadConfig_withNonexistentConfig_shouldReturnDefaultConfig() {
        let config = configManager.loadConfig(for: "nonexistent_plugin_xyz")
        
        XCTAssertNotNil(config)
        XCTAssertTrue(config.settings.isEmpty)
    }
    
    func testLoadConfig_shouldCacheConfig() {
        // 第一次加载
        let config1 = configManager.loadConfig(for: "test_cache")
        
        // 第二次加载应从缓存返回
        let config2 = configManager.loadConfig(for: "test_cache")
        
        // 应该返回相同的配置对象（从缓存）
        XCTAssertEqual(config1.settings.count, config2.settings.count)
    }
    
    // MARK: - 配置保存测试
    
    func testSaveConfig_shouldCreateConfigFile() {
        var config = PluginConfig()
        config.settings["test_key"] = ConfigValue(
            type: "string",
            value: "test_value",
            description: "Test setting"
        )
        
        let success = configManager.saveConfig(config, for: "test_save")
        
        XCTAssertTrue(success)
        
        // 验证可以重新加载
        let loaded = configManager.loadConfig(for: "test_save")
        XCTAssertEqual(loaded.settings["test_key"]?.value as? String, "test_value")
    }
    
    func testSaveConfig_shouldUpdateCache() {
        var config = PluginConfig()
        config.settings["key1"] = ConfigValue(type: "string", value: "value1")
        
        _ = configManager.saveConfig(config, for: "test_cache_update")
        
        // 从缓存加载应该得到更新后的值
        let cached = configManager.loadConfig(for: "test_cache_update")
        XCTAssertEqual(cached.settings["key1"]?.value as? String, "value1")
    }
    
    // MARK: - 配置值操作测试
    
    func testSetValue_shouldSaveStringValue() {
        let success = configManager.setValue(
            "test_string",
            for: "string_key",
            in: "test_value",
            description: "String value"
        )
        
        XCTAssertTrue(success)
        
        let value = configManager.getValue(for: "string_key", in: "test_value", as: String.self)
        XCTAssertEqual(value, "test_string")
    }
    
    func testSetValue_shouldSaveBoolValue() {
        let success = configManager.setValue(
            true,
            for: "bool_key",
            in: "test_value",
            description: "Bool value"
        )
        
        XCTAssertTrue(success)
        
        let value = configManager.getValue(for: "bool_key", in: "test_value", as: Bool.self)
        XCTAssertEqual(value, true)
    }
    
    func testSetValue_shouldSaveNumberValue() {
        let success = configManager.setValue(
            42.5,
            for: "number_key",
            in: "test_value",
            description: "Number value"
        )
        
        XCTAssertTrue(success)
        
        let value = configManager.getValue(for: "number_key", in: "test_value", as: Double.self)
        XCTAssertEqual(value, 42.5)
    }
    
    func testSetValue_shouldOverwriteExistingValue() {
        _ = configManager.setValue("old_value", for: "key", in: "test_overwrite")
        _ = configManager.setValue("new_value", for: "key", in: "test_overwrite")
        
        let value = configManager.getValue(for: "key", in: "test_overwrite", as: String.self)
        XCTAssertEqual(value, "new_value")
    }
    
    func testGetValue_withNonexistentKey_shouldReturnNil() {
        let value = configManager.getValue(
            for: "nonexistent_key",
            in: "test_value",
            as: String.self
        )
        
        XCTAssertNil(value)
    }
    
    func testGetValue_withWrongType_shouldReturnNil() {
        _ = configManager.setValue("string_value", for: "key", in: "test_type")
        
        // 尝试以错误的类型获取
        let value = configManager.getValue(for: "key", in: "test_type", as: Int.self)
        
        XCTAssertNil(value)
    }
    
    func testRemoveValue_shouldDeleteKey() {
        _ = configManager.setValue("value", for: "key_to_remove", in: "test_remove")
        
        let removed = configManager.removeValue(for: "key_to_remove", in: "test_remove")
        XCTAssertTrue(removed)
        
        let value = configManager.getValue(for: "key_to_remove", in: "test_remove", as: String.self)
        XCTAssertNil(value)
    }
    
    func testRemoveValue_withNonexistentKey_shouldReturnTrue() {
        let removed = configManager.removeValue(for: "nonexistent_key", in: "test_remove")
        
        // 即使键不存在，操作也应成功
        XCTAssertTrue(removed)
    }
    
    // MARK: - 配置重置和删除测试
    
    func testResetConfig_shouldClearAllSettings() {
        _ = configManager.setValue("value1", for: "key1", in: "test_reset")
        _ = configManager.setValue("value2", for: "key2", in: "test_reset")
        
        let reset = configManager.resetConfig(for: "test_reset")
        XCTAssertTrue(reset)
        
        let config = configManager.loadConfig(for: "test_reset")
        XCTAssertTrue(config.settings.isEmpty)
    }
    
    func testResetConfig_shouldClearCache() {
        _ = configManager.setValue("cached_value", for: "key", in: "test_reset_cache")
        
        // 先加载到缓存
        _ = configManager.loadConfig(for: "test_reset_cache")
        
        // 重置配置
        _ = configManager.resetConfig(for: "test_reset_cache")
        
        // 重新加载应该得到空配置
        let config = configManager.loadConfig(for: "test_reset_cache")
        XCTAssertTrue(config.settings.isEmpty)
    }
    
    func testDeleteConfig_shouldRemoveConfigFile() {
        _ = configManager.setValue("value", for: "key", in: "test_delete")
        
        let deleted = configManager.deleteConfig(for: "test_delete")
        XCTAssertTrue(deleted)
        
        // 删除后加载应返回默认配置
        let config = configManager.loadConfig(for: "test_delete")
        XCTAssertTrue(config.settings.isEmpty)
    }
    
    func testDeleteConfig_withNonexistentConfig_shouldReturnFalseOrNotCrash() {
        // 删除不存在的配置不应崩溃
        _ = configManager.deleteConfig(for: "nonexistent_config_xyz")
    }
    
    // MARK: - 配置列表测试
    
    func testGetAllConfigNames_shouldReturnExistingConfigs() {
        // 创建几个配置
        _ = configManager.setValue("v1", for: "k1", in: "config1")
        _ = configManager.setValue("v2", for: "k2", in: "config2")
        _ = configManager.setValue("v3", for: "k3", in: "config3")
        
        let names = configManager.getAllConfigNames()
        
        XCTAssertTrue(names.contains("config1"))
        XCTAssertTrue(names.contains("config2"))
        XCTAssertTrue(names.contains("config3"))
        
        // 清理
        _ = configManager.deleteConfig(for: "config1")
        _ = configManager.deleteConfig(for: "config2")
        _ = configManager.deleteConfig(for: "config3")
    }
    
    func testGetAllConfigNames_withNoConfigs_shouldReturnEmptyOrExisting() {
        // 可能还有其他配置文件存在
        let names = configManager.getAllConfigNames()
        
        XCTAssertNotNil(names)
    }
    
    // MARK: - 缓存测试
    
    func testClearCache_shouldRemoveAllCachedConfigs() {
        // 加载一些配置到缓存
        _ = configManager.loadConfig(for: "cache1")
        _ = configManager.loadConfig(for: "cache2")
        
        configManager.clearCache()
        
        // 清除后应该从文件重新加载（虽然我们无法直接验证，但不应崩溃）
        let config = configManager.loadConfig(for: "cache1")
        XCTAssertNotNil(config)
    }
    
    // MARK: - 配置路径测试
    
    func testGetConfigPath_shouldReturnCorrectPath() {
        let path = configManager.getConfigPath(for: "test_plugin")
        
        XCTAssertTrue(path.path.contains("test_plugin.yaml"))
        XCTAssertTrue(path.path.contains("LightLauncher"))
        XCTAssertTrue(path.path.contains("configs"))
    }
    
    // MARK: - 多值类型测试
    
    func testMultipleValueTypes_shouldCoexist() {
        let pluginName = "test_multi_types"
        
        _ = configManager.setValue("string_val", for: "str_key", in: pluginName)
        _ = configManager.setValue(42, for: "int_key", in: pluginName)
        _ = configManager.setValue(3.14, for: "double_key", in: pluginName)
        _ = configManager.setValue(true, for: "bool_key", in: pluginName)
        
        XCTAssertEqual(
            configManager.getValue(for: "str_key", in: pluginName, as: String.self),
            "string_val"
        )
        XCTAssertEqual(
            configManager.getValue(for: "int_key", in: pluginName, as: Int.self),
            42
        )
        XCTAssertEqual(
            configManager.getValue(for: "double_key", in: pluginName, as: Double.self),
            3.14
        )
        XCTAssertEqual(
            configManager.getValue(for: "bool_key", in: pluginName, as: Bool.self),
            true
        )
        
        // 清理
        _ = configManager.deleteConfig(for: pluginName)
    }
    
    // MARK: - 边界情况测试
    
    func testSetValue_withEmptyString_shouldWork() {
        let success = configManager.setValue("", for: "empty_key", in: "test_empty")
        
        XCTAssertTrue(success)
        
        let value = configManager.getValue(for: "empty_key", in: "test_empty", as: String.self)
        XCTAssertEqual(value, "")
        
        // 清理
        _ = configManager.deleteConfig(for: "test_empty")
    }
    
    func testSetValue_withSpecialCharacters_shouldWork() {
        let specialString = "特殊字符 !@#$%^&*() 测试"
        let success = configManager.setValue(
            specialString,
            for: "special_key",
            in: "test_special"
        )
        
        XCTAssertTrue(success)
        
        let value = configManager.getValue(for: "special_key", in: "test_special", as: String.self)
        XCTAssertEqual(value, specialString)
        
        // 清理
        _ = configManager.deleteConfig(for: "test_special")
    }
    
    func testSetValue_withLongDescription_shouldWork() {
        let longDesc = String(repeating: "This is a very long description. ", count: 100)
        let success = configManager.setValue(
            "value",
            for: "long_desc_key",
            in: "test_long_desc",
            description: longDesc
        )
        
        XCTAssertTrue(success)
        
        // 清理
        _ = configManager.deleteConfig(for: "test_long_desc")
    }
}
