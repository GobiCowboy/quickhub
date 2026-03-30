# 终端命令功能文档

## 功能概述

终端命令功能允许用户通过右键菜单快速执行常用的终端命令。

## 分组配置

| 配置项 | 值 |
|--------|-----|
| 分组名称 | 终端命令 |
| 图标 | `terminal` |
| 命令类型 | `.shell` |

## 默认命令列表

| 名称 | 命令 | 说明 |
|------|------|------|
| 复制路径 | `echo -n '{path}' | pbcopy` | 复制选中文件/文件夹的完整路径到剪贴板 |
| 在终端打开 | `osascript -e 'tell application "Terminal" to do script "cd \\"{dir}\\" && zsh"'` | 在 macOS Terminal 中打开当前目录 |
| 在 iTerm2 打开 | `osascript -e 'tell application "iTerm" to create session with default profile' -e 'tell session -1 of window 1 to write text "cd \\"{dir}\\"""'` | 在 iTerm2 中打开当前目录 |
| 在 VS Code 打开 | `cd '{dir}' && code .` | 使用 VS Code 打开当前目录 |

## 变量说明

| 变量 | 说明 |
|------|------|
| `{path}` | 选中文件/文件夹的完整路径 |
| `{dir}` | 当前目录（父目录路径） |
| `{filename}` | 文件名（不含路径） |

## 命令执行方式

### 直接执行（openInTerminal: false）

命令通过 `Process` 直接执行，不需要终端窗口：

```swift
let process = Process()
process.executableURL = URL(fileURLWithPath: "/bin/zsh")
process.arguments = ["-c", command]
process.launch()
```

### 终端执行（openInTerminal: true）

命令在终端窗口中执行，用户可以看到输出：

```swift
let script = """
do shell script "\(command)"
"""
var error: NSDictionary?
NSAppleScript(script).executeAndReturnError(&error)
```

## 设置页面

设置页面提供以下功能：

1. **已启用命令** - 显示当前已添加的命令
2. **预设命令** - 提供常用命令快速添加（水平滚动布局）
3. **自定义命令** - 用户可添加自定义命令

### UI 布局

- 整个设置页面使用 `ScrollView` 包裹，内容超出时可整体滚动
- 预设命令区域使用 `ScrollView(.horizontal)` 水平滚动
- 已启用命令区域使用 `FlowLayout` 流式布局

### 自定义命令示例

```
复制路径: echo -n '{path}' | pbcopy
终端打开: osascript -e 'tell application "Terminal" to do script "cd \\"{dir}\\" && zsh"'
iTerm2: osascript -e 'tell application "iTerm" to create session with default profile' -e 'tell session -1 of window 1 to write text "cd \\"{dir}\\"""'
VSCode: cd '{dir}' && code .
```

## 技术实现

### 执行逻辑

**CommandExecutor.swift** - `executeShell`

```swift
private func executeShell(_ item: CommandItem, context: ExecutionContext) async throws -> ExecutionResult {
    guard let command = item.command else {
        throw ExecutionError.missingCommand
    }

    // 替换变量
    let resolvedCommand = resolveVariables(command, context: context)

    // 根据 openInTerminal 决定执行方式
    if item.openInTerminal {
        return try await executeInTerminal(resolvedCommand)
    } else {
        return try await executeDirectly(resolvedCommand)
    }
}
```

### 变量替换

```swift
private func resolveVariables(_ command: String, context: ExecutionContext) -> String {
    var result = command
    result = result.replacingOccurrences(of: "{path}", with: context.selectedPath)
    result = result.replacingOccurrences(of: "{dir}", with: context.directory)
    result = result.replacingOccurrences(of: "{filename}", with: context.fileName)
    return result
}
```

## 相关文件

- `App/Services/StorageService.swift` - 默认命令配置
- `App/Views/AppSettings/ShellCommandSettingsView.swift` - 设置页面
- `App/Views/AppSettings/Presets.swift` - ShellPreset 模型
- `App/Services/CommandExecutor.swift` - 命令执行器
- `App/Views/Components/EnabledChip.swift` - 启用/可添加 Chip 组件
- `App/Views/Components/FlowLayout.swift` - 流式布局
