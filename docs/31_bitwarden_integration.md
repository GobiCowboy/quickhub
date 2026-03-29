# Bitwarden 密码搜索功能实现文档

## 1. 概述

RightClickX 通过调用 Bitwarden CLI (`bw`) 实现密码搜索功能。用户可以在右键菜单中直接搜索 Bitwarden 保险库中的密码，无需打开 Bitwarden 应用。

### 功能流程

1. 用户点击"搜索 Bitwarden 密码"菜单项
2. 弹出搜索框，用户输入关键词
3. 调用 `bw list items --search <关键词>` 搜索
4. 如果只有一个结果，直接复制密码到剪贴板
5. 如果有多个结果，显示列表让用户选择
6. 用户选择后，复制对应密码到剪贴板

## 2. 数据结构

### 2.1 命令类型扩展

在 `Models.swift` 中新增命令类型：

```swift
enum CommandType: String, Codable, CaseIterable {
    case shell = "shell"
    case createFile = "create_file"
    case createFolder = "create_folder"
    case openFinder = "open_finder"
    case openApp = "open_app"
    case bitwardenSearch = "bitwarden_search"  // 新增
}
```

### 2.2 Bitwarden 数据模型

```swift
struct BitwardenItem: Codable, Identifiable {
    let id: String
    let name: String
    let login: BitwardenLoginItem?
    let notes: String?
}

struct BitwardenLoginItem: Codable {
    let username: String?
    let password: String?
    let totp: String?
    let uris: [BitwardenUri]?
}
```

## 3. 核心组件

### 3.1 BitwardenService

位置：`App/Services/BitwardenService.swift`

```swift
class BitwardenService: BitwardenServiceProtocol {
    static let shared = BitwardenService()

    /// 搜索密码
    func searchPasswords(query: String) async throws -> [BitwardenItem] {
        // 执行: bw list items --search <query>
    }

    /// 获取密码详情
    func getPassword(itemId: String) async throws -> BitwardenLoginItem? {
        // 执行: bw get item <itemId>
    }
}
```

**关键实现**：
- 使用 `Process` 调用 `/opt/homebrew/bin/bw`
- 通过 `Pipe` 捕获 stdout/stderr
- 使用 `JSONDecoder` 解析输出

### 3.2 服务协议

在 `App/Services/Protocols/ServiceProtocols.swift` 中定义：

```swift
protocol BitwardenServiceProtocol {
    func searchPasswords(query: String) async throws -> [BitwardenItem]
    func getPassword(itemId: String) async throws -> BitwardenLoginItem?
}
```

## 4. 执行流程

### 4.1 CommandExecutor 扩展

在 `CommandExecutor.swift` 中新增 `executeBitwardenSearch` 方法：

```swift
private func executeBitwardenSearch(context: ExecutionContext) async throws -> ExecutionResult {
    // 1. 弹出搜索框获取用户输入
    let query = await withCheckedContinuation { continuation in
        UserInputHelper.promptBitwardenSearch { searchText in
            continuation.resume(returning: searchText ?? "")
        }
    }

    guard !query.isEmpty else {
        return ExecutionResult(success: false, output: "搜索已取消")
    }

    // 2. 搜索密码
    let items = try await BitwardenService.shared.searchPasswords(query: query)

    if items.isEmpty {
        return ExecutionResult(success: true, output: "未找到匹配的密码")
    }

    // 3. 只有一个结果，直接复制
    if items.count == 1, let item = items.first, let login = item.login, let password = login.password {
        copyToClipboard(password)
        return ExecutionResult(success: true, output: "已复制 \(item.name) 的密码")
    }

    // 4. 多个结果，弹出选择窗口
    let selectedItem = await withCheckedContinuation { continuation in
        UserInputHelper.showBitwardenResults(items: items) { selected in
            continuation.resume(returning: selected)
        }
    }

    if let item = selectedItem, let login = item.login, let password = login.password {
        copyToClipboard(password)
        return ExecutionResult(success: true, output: "已复制 \(item.name) 的密码")
    }

    return ExecutionResult(success: false, output: "未选择或密码为空")
}
```

### 4.2 用户输入辅助

在 `UserInputHelper.swift` 中新增两个方法：

#### 搜索框

```swift
static func promptBitwardenSearch(completion: @escaping (String?) -> Void) {
    DispatchQueue.main.async {
        let alert = NSAlert()
        alert.messageText = "搜索密码"
        alert.informativeText = "请输入搜索关键词："
        alert.addButton(withTitle: "搜索")
        alert.addButton(withTitle: "取消")

        let inputField = NSTextField(frame: NSRect(x: 0, y: 0, width: 300, height: 24))
        alert.accessoryView = inputField

        alert.beginSheetModal(for: NSApp.keyWindow ?? NSWindow()) { response in
            if response == .alertFirstButtonReturn {
                completion(inputField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines))
            } else {
                completion(nil)
            }
        }
    }
}
```

#### 搜索结果列表

```swift
static func showBitwardenResults(items: [BitwardenItem], completion: @escaping (BitwardenItem?) -> Void) {
    DispatchQueue.main.async {
        let hostingController = NSHostingController(
            rootView: BitwardenResultsView(items: items, onSelect: completion)
        )

        let panel = NSPanel(contentViewController: hostingController)
        panel.title = "搜索结果"
        panel.styleMask = [.titled, .closable, .fullSizeContentView]
        panel.setContentSize(NSSize(width: 400, height: 300))
        panel.center()

        NSApp.activate(ignoringOtherApps: true)
        panel.makeKeyAndOrderFront(nil)
    }
}
```

### 4.3 搜索结果视图

```swift
struct BitwardenResultsView: View {
    let items: [BitwardenItem]
    let onSelect: (BitwardenItem?) -> Void

    var body: some View {
        VStack(spacing: 0) {
            List(items) { item in
                Button(action: {
                    onSelect(item)
                }) {
                    HStack {
                        Image(systemName: "key.fill")
                            .foregroundColor(.orange)
                        VStack(alignment: .leading) {
                            Text(item.name)
                            if let username = item.login?.username {
                                Text(username)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        Spacer()
                    }
                }
            }

            HStack {
                Spacer()
                Button("取消") {
                    onSelect(nil)
                }
            }
            .padding()
        }
        .frame(width: 400, height: 300)
    }
}
```

## 5. UI 集成

### 5.1 命令类型标签

在 `CommandItemRow.swift` 中显示类型标签：

```swift
private var commandTypeLabel: String {
    switch item.type {
    // ...
    case .bitwardenSearch:
        return "密码"
    }
}
```

### 5.2 编辑器支持

在 `ItemEditorSheet.swift` 中支持 bitwardenSearch 类型：

```swift
case .bitwardenSearch:
    Text("Bitwarden 搜索无需配置")
        .foregroundColor(.secondary)
```

### 5.3 EditableItem 枚举

在 `AppSettingsView.swift` 中扩展：

```swift
enum EditableItem: Identifiable, Equatable {
    // ...
    case bitwardenSearch(CommandItem)
}
```

## 6. 默认配置

在 `StorageService.swift` 的默认配置中添加：

```swift
CommandGroup(
    name: "终端命令",
    icon: "terminal",
    items: [
        // ...
        CommandItem(
            name: "搜索 Bitwarden 密码",
            icon: "key.fill",
            type: .bitwardenSearch
        )
    ]
)
```

## 7. 前提条件

### 7.1 安装 Bitwarden CLI

需要安装 Bitwarden CLI (`bw`)：

```bash
brew install bitwarden-cli
```

### 7.2 登录状态

`bw` 命令需要处于登录状态。如果未登录，需要先执行：

```bash
bw login
```

### 7.3 解锁保险库

如果保险库已锁定，需要先解锁：

```bash
bw unlock
```

**注意**：当前实现假设 `bw` 已经完成登录和解锁。如果需要，可以在执行前检查状态：

```bash
bw status
```

## 8. 错误处理

### 8.1 错误类型

```swift
enum BitwardenError: Error, LocalizedError {
    case searchFailed(String)      // 搜索失败
    case itemNotFound             // 项目不存在
    case executionFailed(String)  // 执行失败
    case notUnlocked             // 未解锁
}
```

### 8.2 常见错误

| 错误信息 | 原因 | 解决方案 |
|---------|------|----------|
| `Search failed: Vault is locked` | 保险库已锁定 | 运行 `bw unlock` |
| `Search failed: Not authenticated` | 未登录 | 运行 `bw login` |
| `itemNotFound` | 项目不存在 | 检查 ID |

## 9. 安全性考虑

1. **密码仅存在剪贴板**：密码不会存储在任何地方
2. **剪贴板不自动清除**：建议配合剪贴板自动清除工具使用
3. **日志脱敏**：调试日志中不输出密码内容

## 10. 扩展方向

- [ ] 支持 TOTP（两步验证）复制
- [ ] 支持复制用户名而非密码
- [ ] 自动清除剪贴板（可配置时间）
- [ ] 支持多个 Bitwarden 账户
- [ ] 检查 `bw` 是否已登录，未登录时提示用户
