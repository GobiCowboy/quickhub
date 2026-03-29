# 常用应用功能文档

## 功能概述

常用应用功能允许用户快速打开常用应用程序。

## 分组配置

| 配置项 | 值 |
|--------|-----|
| 分组名称 | 常用应用 |
| 图标 | `app` |
| 命令类型 | `.openApp` |

## 预设应用分类

### 办公

| 名称 | 路径 | 图标 |
|------|------|------|
| Word | `/Applications/Microsoft Word.app` | `doc.fill` |
| Excel | `/Applications/Microsoft Excel.app` | `tablecells` |
| PowerPoint | `/Applications/Microsoft PowerPoint.app` | `chart.bar` |
| Pages | `/Applications/Pages.app` | `doc.richtext.fill` |
| Numbers | `/Applications/Numbers.app` | `tablecells.fill` |
| Keynote | `/Applications/Keynote.app` | `play.rectangle.fill` |

### 设计

| 名称 | 路径 | 图标 |
|------|------|------|
| Figma | `/Applications/Figma.app` | `square.and.pencil` |
| Sketch | `/Applications/Sketch.app` | `pencil.tip` |
| Photoshop | `/Applications/Adobe Photoshop 2024/Adobe Photoshop 2024.app` | `photo` |
| Illustrator | `/Applications/Adobe Illustrator 2024/Adobe Illustrator 2024.app` | `pencil.and.outline` |
| Preview | `/Applications/Preview.app` | `eye` |
| Pixelmator | `/Applications/Pixelmator.app` | `paintbrush.fill` |

### 开发

| 名称 | 路径 | 图标 |
|------|------|------|
| Visual Studio Code | `/Applications/Visual Studio Code.app` | `p.square.fill` |
| Xcode | `/Applications/Xcode.app` | `hammer.fill` |
| Sublime Text | `/Applications/Sublime Text.app` | `doc.text` |
| Typora | `/Applications/Typora.app` | `doc.richtext` |
| iTerm | `/Applications/iTerm.app` | `terminal.fill` |
| Terminal | `/Applications/Utilities/Terminal.app` | `terminal` |
| Docker | `/Applications/Docker.app` | `shippingbox.fill` |

### 视频

| 名称 | 路径 | 图标 |
|------|------|------|
| VLC | `/Applications/VLC.app` | `play.rectangle.fill` |
| IINA | `/Applications/IINA.app` | `play.circle.fill` |
| QuickTime Player | `/Applications/QuickTime Player.app` | `film` |
| DaVinci Resolve | `/Applications/DaVinci Resolve.app` | `film.fill` |

### AI

| 名称 | 路径 | 图标 |
|------|------|------|
| ChatGPT | `/Applications/ChatGPT.app` | `bubble.left.fill` |
| Claude | `/Applications/Claude.app` | `brain` |
| Copilot | `/Applications/Copilot.app` | `airplane` |
| Perplexity | `/Applications/Perplexity.app` | `sparkles` |
| Ollama | `/Applications/Ollama.app` | `cpu` |

## 操作流程

```
用户点击"常用应用" → 显示应用列表 → 点击应用项 → 启动该应用
```

## 技术实现

### 执行逻辑

**CommandExecutor.swift** - `executeOpenApp`

```swift
private func executeOpenApp(_ item: CommandItem, context: ExecutionContext) async throws -> ExecutionResult {
    guard let path = item.targetPath else {
        throw ExecutionError.missingPath
    }

    let url = URL(fileURLWithPath: path)

    do {
        try NSWorkspace.shared.openApplication(at: url, configuration: NSWorkspace.OpenConfiguration())
        return ExecutionResult(success: true, output: "已打开应用")
    } catch {
        throw ExecutionError.executionFailed(error.localizedDescription)
    }
}
```

## 应用检测与错误处理

### 添加应用时的检测

添加预设应用时，系统会检查应用是否存在于指定路径：

```swift
if !FileManager.default.fileExists(atPath: app.path) {
    errorMessage = "\(app.name) 文件位置有误或未下载，请通过自定义方式设置"
    return
}
```

### 已添加应用的检测

打开设置页面时，系统会自动检测已添加的应用路径是否有效：

```swift
private func checkForMissingApps() {
    let enabledApps = getEnabledApps()
    for app in enabledApps {
        if let targetPath = app.targetPath {
            if !FileManager.default.fileExists(atPath: targetPath) {
                errorMessage = "\(app.name) 文件位置有误或未下载"
                return
            }
        }
    }
}
```

### 错误提示

当应用不存在时，显示警告提示：

```
⚠️ [应用名称] 文件位置有误或未下载，请通过自定义方式设置
```

用户可以点击"清除"按钮关闭提示，或通过自定义方式重新设置正确的应用路径。

## 相关文件

- `App/Views/AppSettings/OpenAppSettingsView.swift` - 设置页面视图
- `App/Views/AppSettings/Presets.swift` - 预设数据模型
- `App/Services/CommandExecutor.swift` - 命令执行器
