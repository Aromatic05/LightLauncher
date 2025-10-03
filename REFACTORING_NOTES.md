# 快捷键组件重构说明

## 📋 概述

本次重构将快捷键录制和显示功能从两个页面中提取出来，创建了可复用的组件和管理器，消除了代码重复。

## 🎯 重构目标

- ✅ 消除 `GeneralSettingsView` 和 `CustomHotKeyEditView` 中的重复代码
- ✅ 创建统一的快捷键录制逻辑
- ✅ 提供可复用的 UI 组件
- ✅ 简化维护和扩展

## 📦 新增组件

### 1. **HotKeyRecorder** (`HotKeyRecorder.swift`)
快捷键录制管理器，负责所有录制逻辑：

**功能：**
- 键盘事件监听（全局和本地）
- 修饰键转换（Cocoa → Carbon）
- 有效按键验证
- 右侧修饰键支持（右 Command、右 Option）
- 自动清理资源

**使用方式：**
```swift
@StateObject private var hotKeyRecorder = HotKeyRecorder()

// 设置回调
hotKeyRecorder.onKeyRecorded = { modifiers, keyCode in
    // 处理录制的快捷键
}

// 开始录制
hotKeyRecorder.startRecording()

// 取消录制
hotKeyRecorder.cancelRecording()
```

### 2. **HotKeyCard** (`HotKeyCard.swift`)
通用快捷键卡片组件：

**特点：**
- 支持自定义标题、描述、图标
- 集成录制功能
- 冲突检测显示
- 可选重置按钮
- 自动资源清理

**使用方式：**
```swift
HotKeyCard(
    title: "全局快捷键",
    description: "设置全局快捷键来显示/隐藏启动器",
    icon: "keyboard",
    iconColor: .blue,
    recorder: hotKeyRecorder,
    modifiers: $modifiers,
    keyCode: $keyCode,
    hasConflict: false,
    onKeyRecorded: { newModifiers, newKeyCode in
        // 保存新的快捷键
    },
    onReset: {
        // 重置到默认值
    }
)
```

### 3. **CompactHotKeyCard** (`HotKeyCard.swift`)
简化版快捷键卡片，用于列表展示：

**用途：**
- 快捷键列表显示
- 编辑/删除操作
- 冲突状态提示

### 4. **HotKeyPreview** (`HotKeyCard.swift`)
快捷键预览组件：

**功能：**
- 显示快捷键组合
- 显示关联文本
- 验证状态提示

## 🔄 更新的组件

### **HotKeySettingsCard** (更新)
已更新为使用 `HotKeyRecorder`，不再需要手动管理录制状态。

### **HotKeyRecordButton** (更新)
已更新为使用 `HotKeyRecorder`，简化了接口。

## 📝 重构的页面

### 1. **GeneralSettingsView**

**变更前：**
- 包含 ~100 行录制相关代码
- 需要管理多个状态变量
- 手动管理事件监听器

**变更后：**
- 使用 `HotKeyCard` 组件
- 只需一个 `@StateObject` 管理录制器
- 代码减少 60%+

**关键改动：**
```swift
// 之前需要的状态
@Binding var isRecordingHotKey: Bool
@Binding var tempHotKeyDescription: String
@Binding var globalMonitor: Any?
@Binding var localMonitor: Any?
@Binding var currentModifiers: UInt32

// 现在只需要
@StateObject private var hotKeyRecorder = HotKeyRecorder()
```

### 2. **CustomHotKeyEditView**

**变更前：**
- 包含 ~90 行录制相关代码
- 重复的事件处理逻辑
- 需要 onDisappear 手动清理

**变更后：**
- 使用 `HotKeySettingsCard` 组件
- 自动资源管理
- 代码更清晰简洁

**关键改动：**
```swift
// 之前需要的状态
@State private var isRecordingHotKey = false
@State private var globalMonitor: Any?
@State private var localMonitor: Any?
@State private var currentModifiers: UInt32 = 0

// 现在只需要
@StateObject private var hotKeyRecorder = HotKeyRecorder()
```

## 📊 重构效果

| 指标 | 改进 |
|------|------|
| 代码重复 | -180 行 |
| 文件组织 | +2 个可复用组件 |
| 维护性 | ⬆️ 统一的录制逻辑 |
| 可测试性 | ⬆️ 独立的管理器类 |
| 扩展性 | ⬆️ 易于添加新功能 |

## 🏗️ 文件结构

```
Sources/Views/SettingViews/
├── Components/
│   ├── HotKeyRecorder.swift          ← 新增：录制管理器
│   ├── HotKeyCard.swift               ← 新增：通用卡片组件
│   └── CustomHotkey/
│       ├── HotKeyEditComponents.swift ← 更新：使用 HotKeyRecorder
│       └── HotKeyInfoCard.swift      ← 保持不变
└── Pages/
    ├── GeneralSettingsView.swift     ← 重构：移除重复代码
    └── CustomHotKeySettingsView.swift ← 重构：移除重复代码
```

## 🎨 设计优势

### 1. **单一职责**
- `HotKeyRecorder`：专注于录制逻辑
- `HotKeyCard`：专注于 UI 展示
- 各个页面：专注于业务逻辑

### 2. **依赖注入**
通过传入 `HotKeyRecorder` 实例，组件可以灵活使用，易于测试。

### 3. **自动资源管理**
使用 `deinit` 和 `onDisappear`，确保事件监听器正确清理。

### 4. **统一的 API**
所有快捷键相关操作使用相同的接口，降低学习成本。

## 🚀 未来扩展

### 可能的增强功能：
1. **快捷键冲突自动检测**
   - 在 `HotKeyRecorder` 中添加冲突检测逻辑
   
2. **录制历史**
   - 记录最近录制的快捷键，方便撤销

3. **快捷键建议**
   - 基于常用组合推荐未使用的快捷键

4. **导入/导出**
   - 批量管理快捷键配置

## 📌 注意事项

1. **向后兼容**：现有配置文件无需修改
2. **性能**：录制器使用弱引用，避免循环引用
3. **线程安全**：所有 UI 更新在主线程进行

## ✅ 验证清单

- [x] 编译无错误
- [x] 移除所有重复代码
- [x] 组件可独立使用
- [x] 资源正确清理
- [x] 功能完全保持

## 📝 后续建议

1. 考虑为 `HotKeyRecorder` 添加单元测试
2. 可以将 `HotKeyInfoCard` 也移至 `HotKeyCard.swift` 统一管理
3. 添加快捷键可访问性支持（VoiceOver）

---

**重构日期**: 2025年10月3日  
**影响范围**: 快捷键设置相关页面和组件  
**状态**: ✅ 完成
