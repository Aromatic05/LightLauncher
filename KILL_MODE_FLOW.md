# Kill Mode 交互流程

## 新的 Kill Mode 行为

### 进入 Kill Mode
1. 用户输入 `/k`
2. 系统切换到 kill mode
3. 搜索框显示 `/k` 前缀并等待后续输入

### 在 Kill Mode 中搜索
1. 用户在 `/k` 后输入搜索内容，如 `/kSafari`
2. 系统提取 "Safari" 作为搜索关键字
3. 显示匹配的运行应用

### 退出 Kill Mode
1. 用户删除 `/k` 前缀，如改为 `Safari`
2. 系统自动切换回 launch mode
3. 使用 "Safari" 作为搜索关键字在应用中搜索

## 代码改进说明

### CommandProcessor.swift
- 优先检查 kill mode 状态
- 检测 `/k` 前缀的存在与否
- 自动切换模式并传递搜索内容

### LauncherViewModel.swift  
- `switchToKillMode()` 不再清空搜索文本
- 保持 `/k` 前缀显示

### UI 文本更新
- 帮助文本更新为反映新的交互方式
- 空状态文本优化

## 用户体验改进
- 更直观的模式切换
- 保持搜索上下文
- 清晰的视觉反馈
- 一致的交互模式
