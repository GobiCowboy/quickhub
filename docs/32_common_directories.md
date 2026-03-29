# 常用目录功能文档

## 功能概述

常用目录功能允许用户快速打开常用文件夹，如桌面、下载等。

## 分组配置

| 配置项 | 值 |
|--------|-----|
| 分组名称 | 常用目录 |
| 图标 | `star.fill` |
| 命令类型 | `.openFinder` |

## 默认目录

| 名称 | 路径 | 图标 |
|------|------|------|
| 桌面 | `~/Desktop` | `desktopcomputer` |
| 下载 | `~/Downloads` | `arrow.down.circle.fill` |

## 操作流程

```
用户点击"常用目录" → 显示目录列表 → 点击目录项 → 在 Finder 中打开该目录
```

## 技术实现

### 核心代码

**StorageService.swift** - 默认分组配置

```swift
CommandGroup(
    name: "常用目录",
    icon: "star.fill",
    items: [
        CommandItem(
            name: "桌面",
            icon: "desktopcomputer",
            type: .openFinder,
            targetPath: "~/Desktop"
        ),
        CommandItem(
            name: "下载",
            icon: "arrow.down.circle.fill",
            type: .openFinder,
            targetPath: "~/Downloads"
        )
    ]
)
```

### 执行逻辑

**CommandExecutor.swift** - `executeOpenFinder`

```swift
private func executeOpenFinder(_ item: CommandItem, context: ExecutionContext) async throws -> ExecutionResult {
    let path: String
    if let target = item.targetPath {
        // 处理 ~ 路径
        path = (target as NSString).expandingTildeInPath
    } else {
        path = context.directory
    }

    let url = URL(fileURLWithPath: path)
    NSWorkspace.shared.open(url)

    return ExecutionResult(success: true, output: "已在 Finder 中打开: \(path)")
}
```

## 设置页面

用户可以在设置页面的"打开文件夹"分类中：

1. **启用/禁用**预设目录（桌面、下载、文档、项目等）
2. **添加自定义目录**通过浏览选择文件夹
3. **删除**已添加的目录

### 可用预设目录

| 名称 | 路径 | 图标 |
|------|------|------|
| 桌面 | `~/Desktop` | `desktopcomputer` |
| 下载 | `~/Downloads` | `arrow.down.circle.fill` |
| 文档 | `~/Documents` | `doc.fill` |
| 项目 | `~/Projects` | `folder.fill` |
| 应用 | `~/Applications` | `app.fill` |
| 图片 | `~/Pictures` | `photo.fill` |
| 音乐 | `~/Music` | `music.note` |
| 影片 | `~/Movies` | `film.fill` |

## 相关文件

- `App/Services/StorageService.swift` - 存储服务和默认配置
- `App/Services/CommandExecutor.swift` - 命令执行器
- `App/Views/AppSettings/OpenFolderSettingsView.swift` - 设置页面视图
