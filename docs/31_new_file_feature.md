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
   - 点击"新建文件/文件夹"分组下的"新建文件夹"或具体的文件类型

2. **关闭弹出窗口**
   - 弹出窗口立即关闭 (`onClose?()`)
   - 这是为了让对话框显示在屏幕中央

3. **显示输入对话框**
   - 系统显示"新建文件"或"新建文件夹"对话框
   - 输入框自动聚焦，文本被全选
   - 用户可以直接输入新的名称

4. **创建文件/文件夹**
   - 用户点击"创建"按钮
   - 系统检查目标位置是否已存在同名文件/文件夹
   - 如果存在，弹出确认对话框询问是否替换
   - 用户确认后，在当前 Finder 目录下创建文件/文件夹

5. **完成通知**
   - 创建成功后，显示系统通知
   - 通知标题为命令名称，内容为"已创建: 文件/文件夹名"

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
UserInputHelper.promptFileName() / promptFolderName()  // 显示输入对话框
    ↓
检查文件是否存在 → 如存在则弹出确认对话框
    ↓
创建文件/文件夹 + 发送通知
```

### 关键代码

**CommandExecutor.swift** - 新建文件执行逻辑

```swift
private func executeCreateFile(_ item: CommandItem, context: ExecutionContext) async throws -> ExecutionResult {
    // 1. 获取用户输入的文件名
    let fileName = await withCheckedContinuation { continuation in
        UserInputHelper.promptFileName(extension: ext, directory: context.directory) { name in
            continuation.resume(returning: name)
        }
    }

    // 2. 用户取消
    guard let fileName = fileName else {
        return ExecutionResult(success: false, output: "已取消")
    }

    // 3. 构建完整路径
    let fullFileName = "\(fileName).\(ext)"
    let fileURL = URL(fileURLWithPath: context.directory).appendingPathComponent(fullFileName)

    // 4. 检查文件是否已存在
    if FileManager.default.fileExists(atPath: fileURL.path) {
        let shouldReplace = await withCheckedContinuation { continuation in
            // 弹出确认对话框...
        }
        if !shouldReplace {
            return ExecutionResult(success: false, output: "已取消")
        }
    }

    // 5. 渲染模板并写入文件
    let content = renderTemplate(template, fileName: fileName)
    try content.write(to: fileURL, atomically: true, encoding: .utf8)

    return ExecutionResult(success: true, output: "已创建: \(fullFileName)")
}
```

**CommandExecutor.swift** - 新建文件夹执行逻辑

```swift
private func executeCreateFolder(_ item: CommandItem, context: ExecutionContext) async throws -> ExecutionResult {
    // 1. 获取用户输入的文件夹名
    let folderName = await withCheckedContinuation { continuation in
        UserInputHelper.promptFolderName(directory: context.directory) { name in
            continuation.resume(returning: name)
        }
    }

    // 2. 用户取消
    guard let folderName = folderName else {
        return ExecutionResult(success: false, output: "已取消")
    }

    let folderURL = URL(fileURLWithPath: context.directory).appendingPathComponent(folderName)

    // 3. 检查文件夹是否已存在
    if FileManager.default.fileExists(atPath: folderURL.path) {
        // 弹出确认对话框...
        // 如果用户取消，删除已存在的文件夹
        try FileManager.default.removeItem(at: folderURL)
    }

    // 4. 创建文件夹
    try FileManager.default.createDirectory(at: folderURL, withIntermediateDirectories: true)

    return ExecutionResult(success: true, output: "已创建: \(folderName)")
}
```

### 用户输入对话框

**UserInputHelper.swift** - 文件名输入对话框

```swift
static func promptFileName(extension ext: String, directory: String, completion: @escaping (String?) -> Void) {
    DispatchQueue.main.async {
        let alert = NSAlert()
        alert.messageText = "新建文件"
        alert.informativeText = "请输入文件名："
        alert.addButton(withTitle: "创建")
        alert.addButton(withTitle: "取消")

        let inputField = NSTextField(frame: NSRect(x: 0, y: 0, width: 300, height: 24))
        inputField.stringValue = "Untitled"
        alert.accessoryView = inputField

        // 激活应用
        NSApp.activate(ignoringOtherApps: true)

        // 创建一个临时窗口作为 sheet 的父窗口
        let tempWindow = NSWindow(contentRect: .zero, styleMask: .borderless, backing: .buffered, defer: false)
        tempWindow.level = .floating
        tempWindow.center()
        tempWindow.makeKeyAndOrderFront(nil)

        // 显示 sheet 并在显示后聚焦输入框
        alert.beginSheetModal(for: tempWindow) { response in
            if response == .alertFirstButtonReturn {
                completion(inputField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines))
            } else {
                completion(nil)
            }
        }

        // 延迟聚焦到输入框
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            tempWindow.makeFirstResponder(inputField)
            inputField.selectText(nil)
        }
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

### 默认分组配置

- **分组名称**：新建文件/文件夹
- **图标**：`folder.badge.plus`
- **默认项**：新建文件夹

用户可在设置页面添加更多文件模板（Markdown、Swift、Python 等）

## 权限说明

### Finder 自动化权限

应用启动时会自动请求 Finder 自动化权限：

```swift
private func requestFinderAccess() {
    let script = """
    tell application "Finder"
        return name of it
    end tell
    """
    // 尝试执行脚本，触发权限请求
}
```

**授权路径**：系统设置 → 隐私与安全性 → 自动化 → RightClickX → Finder

## 相关文件

- `App/Services/CommandExecutor.swift` - 命令执行器
- `App/Utilities/UserInputHelper.swift` - 用户输入帮助类
- `App/Services/FinderService.swift` - Finder 服务
- `App/Views/Popover/CommandItemRow.swift` - 命令项行视图
- `App/Info.plist` - 权限配置
