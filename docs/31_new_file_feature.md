# 新建文件/文件夹功能文档

## 功能概述

新建文件/文件夹功能允许用户在 Finder 中通过右键菜单快速创建文件夹或预设类型的文件（如 Markdown、Swift 文件等）。

## 操作流程

```
用户点击"新建文件夹"或"新建文件" → 弹出窗口关闭 → 显示输入对话框 → 用户输入名称 → 点击"创建" → 创建成功 → 发送通知
```

### 详细步骤

1. **触发操作**
   - 用户在 Finder 中选中一个目录（或不选中任何文件）
   - 打开 RightClickX 弹出菜单
   - 点击"文件操作"分组下的"新建 Markdown"（或其他文件类型）

2. **关闭弹出窗口**
   - 弹出窗口立即关闭 (`onClose?()`)
   - 这是为了让对话框显示在屏幕中央

3. **显示输入对话框**
   - 系统显示"新建文件"对话框
   - 输入框自动聚焦，文本"Untitled"被全选
   - 用户可以直接输入新的文件名

4. **创建文件**
   - 用户点击"创建"按钮
   - 系统在当前 Finder 目录下创建文件
   - 文件使用选定文件类型的模板（如有）

5. **完成通知**
   - 文件创建成功后，显示系统通知
   - 通知标题为命令名称，内容为"已创建: 文件名"

## 技术实现

### 核心组件

| 组件 | 职责 |
|------|------|
| `CommandItemRow` | 触发命令执行，处理用户交互 |
| `CommandExecutor` | 执行具体命令逻辑 |
| `UserInputHelper` | 显示各种输入对话框 |
| `FinderService` | 获取 Finder 上下文信息 |

### 代码调用链

```
CommandItemRow.executeCommand()
    ↓
FinderService.getCurrentDirectory()  // 获取当前目录
    ↓
CommandExecutor.execute(item, context)
    ↓
UserInputHelper.promptFileName()  // 显示输入对话框
    ↓
创建文件 + 发送通知
```

### 关键代码

**CommandExecutor.swift:113-142** - 新建文件执行逻辑

```swift
private func executeCreateFile(_ item: CommandItem, context: ExecutionContext) async throws -> ExecutionResult {
    // 1. 获取用户输入的文件名
    let fileName = await withCheckedContinuation { continuation in
        UserInputHelper.promptFileName(extension: ext, directory: context.directory) { name in
            continuation.resume(returning: name ?? "Untitled")
        }
    }

    // 2. 构建完整路径
    let fullFileName = "\(fileName).\(ext)"
    let fileURL = URL(fileURLWithPath: context.directory).appendingPathComponent(fullFileName)

    // 3. 渲染模板并写入文件
    let content = renderTemplate(template, fileName: fileName)
    try content.write(to: fileURL, atomically: true, encoding: .utf8)

    // 4. 在 Finder 中显示新创建的文件
    NSWorkspace.shared.activateFileViewerSelecting([fileURL])

    return ExecutionResult(success: true, output: "已创建: \(fullFileName)")
}
```

### 用户输入对话框

**UserInputHelper.swift:14-52** - 文件名输入对话框

```swift
static func promptFileName(extension ext: String, directory: String, completion: @escaping (String?) -> Void) {
    let alert = NSAlert()
    alert.messageText = "新建文件"
    alert.informativeText = "请输入文件名："
    alert.addButton(withTitle: "创建")
    alert.addButton(withTitle: "取消")

    let inputField = NSTextField(frame: NSRect(x: 0, y: 0, width: 300, height: 24))
    inputField.stringValue = "Untitled"
    inputField.placeholderString = "文件名"
    alert.accessoryView = inputField

    // 显示对话框
    guard let keyWindow = NSApp.keyWindow else {
        completion(nil)
        return
    }

    alert.beginSheetModal(for: keyWindow) { response in
        if response == .alertFirstButtonReturn {
            completion(inputField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines))
        } else {
            completion(nil)
        }
    }

    // 自动聚焦输入框
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
        keyWindow.makeFirstResponder(inputField)
        inputField.selectText(nil)
    }
}
```

## 文件模板

### 模板变量

| 变量 | 说明 | 示例 |
|------|------|------|
| `{{FILENAME}}` | 用户输入的文件名（不含扩展名） | `MyDocument` |
| `{{DATE}}` | 当前日期 | `2026年3月29日` |
| `{{TIME}}` | 当前时间 | `14:30:00` |

### 默认模板

**新建 Markdown**
```
# {{FILENAME}}

{{DATE}}
```

**新建 Swift 文件**
```
//
//  {{FILENAME}}.swift
//

import Foundation
```

## 已知问题

### 问题：输入对话框不显示或位置不正确

**原因**：当弹出窗口关闭后，`NSApp.keyWindow` 可能变为 nil 或指向错误的窗口，导致对话框显示位置不正确。

**解决方案**：使用延迟聚焦确保对话框正确显示：

```swift
DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
    keyWindow.makeFirstResponder(inputField)
    inputField.selectText(nil)
}
```

## 相关文件

- `App/Services/CommandExecutor.swift` - 命令执行器
- `App/Utilities/UserInputHelper.swift` - 用户输入帮助类
- `App/Services/FinderService.swift` - Finder 服务
- `App/Views/Popover/CommandItemRow.swift` - 命令项行视图
