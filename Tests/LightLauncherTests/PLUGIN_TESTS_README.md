# LightLauncher 插件系统测试套件

本目录包含了 LightLauncher 插件系统的全面测试用例，涵盖所有核心组件和功能。

## 测试文件概览

### 1. PluginManagerTests.swift
**测试范围：插件管理器 (`PluginManager`)**

- ✅ 插件注册、注销、查询
- ✅ 插件加载和重载
- ✅ 启用/禁用插件
- ✅ 获取已启用插件列表
- ✅ 插件命令冲突检测
- ✅ 插件搜索功能
- ✅ 统计信息获取
- ✅ 重复插件处理
- ✅ 边界情况和错误处理

**测试用例数：** ~15 个

### 2. PluginLoaderTests.swift
**测试范围：插件加载器 (`PluginLoader`)**

- ✅ 从目录加载插件
- ✅ 解析 manifest.yaml 文件
- ✅ 加载自定义主文件
- ✅ 权限声明解析
- ✅ 目录扫描功能
- ✅ 错误处理（缺失文件、无效 YAML、空脚本等）
- ✅ 必需字段验证
- ✅ 插件目录识别

**测试用例数：** ~15 个

### 3. PluginPermissionManagerTests.swift
**测试范围：权限管理器 (`PluginPermissionManager`)**

- ✅ 基础权限检查
- ✅ 文件权限（读/写）
- ✅ 目录级别的权限控制
- ✅ 多目录权限
- ✅ 读写权限独立性
- ✅ 权限验证
- ✅ 权限摘要生成
- ✅ 子目录权限继承
- ✅ 路径前缀匹配
- ✅ 根路径权限处理

**测试用例数：** ~20 个

### 4. PluginExecutorTests.swift
**测试范围：插件执行器 (`PluginExecutor`)**

- ✅ 插件实例创建
- ✅ JavaScript 上下文设置
- ✅ 实例获取和查询
- ✅ 实例销毁和清理
- ✅ 实例重建
- ✅ 多实例管理
- ✅ API 注入验证
- ✅ JavaScript 异常处理
- ✅ 脚本执行验证
- ✅ 实例隔离性
- ✅ 防止重复创建

**测试用例数：** ~18 个

### 5. PluginConfigManagerTests.swift
**测试范围：配置管理器 (`PluginConfigManager`)**

- ✅ 配置加载
- ✅ 配置保存
- ✅ 配置缓存机制
- ✅ 配置值设置（String、Bool、Number）
- ✅ 配置值获取
- ✅ 类型检查
- ✅ 配置删除
- ✅ 配置重置
- ✅ 配置列表获取
- ✅ 缓存清理
- ✅ 多值类型共存
- ✅ 特殊字符处理
- ✅ 空值处理

**测试用例数：** ~22 个

### 6. APIManagerTests.swift
**测试范围：API 管理器 (`APIManager`)**

- ✅ API 注入（核心、文件、剪贴板、网络、系统、权限）
- ✅ `lightlauncher` 对象创建
- ✅ 核心 API（display、log、registerCallback、getConfig、getDataPath）
- ✅ 文件 API 权限控制
- ✅ 数据目录无需额外权限
- ✅ 剪贴板 API 权限控制
- ✅ 权限检查 API
- ✅ 无效数据处理
- ✅ 部分数据处理
- ✅ 不存在文件处理
- ✅ 无效路径处理

**测试用例数：** ~25 个

### 7. PluginInstanceTests.swift
**测试范围：插件实例 (`PluginInstance`)**

- ✅ 实例初始化
- ✅ Context 设置
- ✅ 输入处理
- ✅ 回调机制
- ✅ 动作执行
- ✅ 数据项管理
- ✅ 数据变更发布
- ✅ 搜索回调设置
- ✅ 动作处理器设置
- ✅ 实例清理
- ✅ 启用/禁用状态
- ✅ 更新通知回调
- ✅ JavaScript 异常处理
- ✅ 特殊字符处理
- ✅ 空输入处理

**测试用例数：** ~30 个

### 8. PluginModeControllerTests.swift
**测试范围：插件模式控制器 (`PluginModeController`)**

- ✅ ModeStateController 协议实现
- ✅ 模式属性验证
- ✅ 输入处理和路由
- ✅ 插件激活
- ✅ 参数传递
- ✅ 插件列表显示
- ✅ 插件切换
- ✅ 数据变更发布
- ✅ Placeholder 动态更新
- ✅ 错误处理
- ✅ 状态一致性
- ✅ 完整工作流集成测试

**测试用例数：** ~18 个

## 总体覆盖

### 组件覆盖率
- ✅ **核心管理层**：PluginManager, PluginLoader, PluginExecutor
- ✅ **权限和配置层**：PluginPermissionManager, PluginConfigManager
- ✅ **API 层**：APIManager
- ✅ **运行时层**：PluginInstance
- ✅ **模式层**：PluginModeController

### 功能覆盖率
- ✅ 插件生命周期管理
- ✅ 权限系统
- ✅ 配置系统
- ✅ API 注入和调用
- ✅ JavaScript 执行
- ✅ 错误处理
- ✅ 异步操作
- ✅ 数据更新和发布
- ✅ 文件操作
- ✅ 剪贴板操作
- ✅ 边界情况

### 测试总数
**约 163+ 个测试用例**

## 运行测试

### 运行所有插件测试
```bash
swift test --filter "Plugin"
```

### 运行特定测试类
```bash
swift test --filter "PluginManagerTests"
swift test --filter "PluginPermissionManagerTests"
swift test --filter "APIManagerTests"
```

### 在 Xcode 中运行
1. 打开 Package.swift 或项目
2. 按 `Cmd+U` 运行所有测试
3. 或在测试导航器中选择特定测试类/方法

## 测试覆盖的关键场景

### 安全性测试
- ✅ 未授权的文件访问被拒绝
- ✅ 未授权的剪贴板访问被拒绝
- ✅ 未授权的网络访问被拒绝
- ✅ 插件数据目录隔离
- ✅ JavaScript 异常不会导致崩溃

### 可靠性测试
- ✅ 多次清理不会崩溃
- ✅ 重复创建实例的处理
- ✅ 无效输入的处理
- ✅ 缺失文件的处理
- ✅ 损坏的 YAML 处理

### 性能相关测试
- ✅ 配置缓存机制
- ✅ 实例重用
- ✅ 避免重复创建

### 集成测试
- ✅ 完整插件工作流（加载→激活→输入→显示→执行→清理）
- ✅ 多插件切换
- ✅ 插件间隔离

## 未来测试扩展

以下是可以继续添加的测试：

1. **网络 API 测试**
   - HTTP 请求测试
   - 超时处理
   - 响应解析

2. **系统命令测试**
   - 命令执行
   - 输出捕获
   - 错误处理

3. **通知 API 测试**
   - 通知显示
   - 通知内容验证

4. **性能测试**
   - 大量插件加载
   - 高频输入处理
   - 内存泄漏检测

5. **并发测试**
   - 多线程安全性
   - 异步操作竞态条件

## 测试最佳实践

本测试套件遵循以下最佳实践：

1. **独立性**：每个测试都是独立的，不依赖其他测试
2. **可重复性**：测试可以多次运行，结果一致
3. **清理**：每个测试后都清理临时数据和状态
4. **描述性命名**：测试方法名清楚描述了测试内容
5. **边界测试**：覆盖正常、边界和异常情况
6. **隔离**：使用临时目录避免影响真实数据

## 贡献指南

添加新测试时：

1. 在适当的测试类中添加测试方法
2. 使用描述性的方法名（如 `testFeature_condition_expectedOutcome`）
3. 在 `setUp()` 中初始化测试环境
4. 在 `tearDown()` 中清理测试数据
5. 使用 XCTAssert 系列断言验证结果
6. 更新本 README 中的测试数量和覆盖范围

## 问题报告

如果测试失败：

1. 检查是否是实现问题还是测试问题
2. 查看测试输出中的错误信息
3. 验证测试假设是否与实际实现一致
4. 考虑是否需要调整测试或修复代码

---

**最后更新：** 2025-11-07
**测试框架：** XCTest
**语言：** Swift 5.x
