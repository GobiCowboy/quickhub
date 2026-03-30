# 快捷键系统

## 概述

RightClickX 使用全局快捷键打开右键菜单面板。默认快捷键为 `⌥⇧Q`（Option + Shift + Q）。

## 默认快捷键

```swift
static let defaultHotkey = HotkeyConfiguration(keyCode: 12, modifiers: 655360) // ⌥⇧Q
```

## 快捷键配置

### 修饰符值

| 修饰符 | Raw Value |
|--------|-----------|
| Control | 4096 |
| Option | 131072 |
| Shift | 262144 |
| Command | 1048576 |
| ⌥⇧ | 655360 |

### 键码参考

| 按键 | KeyCode |
|------|---------|
| Q | 12 |
| W | 13 |
| A | 0 |
| S | 1 |
| ... | ... |

## 辅助功能权限

全局快捷键需要 macOS 辅助功能权限。

### 权限配置

1. 打开 **系统设置 → 隐私与安全性 → 辅助功能**
2. 添加并启用 **RightClickX**

### 代码签名要求

- 应用需要使用有效的 Apple Developer 签名（adhoc 签名会导致权限失效）
- 每次重新构建后可能需要重新授权

### 检测权限状态

```swift
let trusted = AXIsProcessTrusted()
```

## 快捷键录制

`HotkeyRecorderView` 组件负责录制用户按下的快捷键：

1. 点击录制按钮开始录制
2. 按下期望的快捷键组合
3. 系统检测是否与常用快捷键冲突
4. 保存配置

### 保存流程

快捷键录制完成后自动调用 `onSave` 回调保存到 `StorageService`。

## 冲突检测

`HotkeyUtil.checkSystemConflicts()` 检测与以下应用的冲突：

- Chrome
- Safari
- Finder
- Xcode
- Terminal
- iTerm2
- VSCode

## 文件结构

- `Models.swift` - `HotkeyConfiguration` 数据模型
- `HotkeyUtil.swift` - 快捷键工具函数
- `HotkeyRecorderView.swift` - 快捷键录制 UI 组件
- `AppDelegate.swift` - 全局快捷键注册
- `GeneralSettingsView.swift` - 快捷键设置界面
