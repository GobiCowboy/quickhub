# RightClickX 开发规范

## Swift/macOS 开发规范

### 代码风格

- 使用 Swift 默认的命名规范（camelCase 函数/变量，PascalCase 类型名）
- 使用 4 空格缩进
- 每行不超过 120 字符
- 使用 `guard` 提前返回，减少嵌套

### 文件结构

每个 Swift 文件的结构：
1. `import` 语句
2. `// MARK: -` 注释区分不同区域
3. 类型定义
4. 扩展和协议实现

### 视图组件

- 使用 SwiftUI 的 `@State`、`@Binding`、`@ObservedObject` 正确管理状态
- 视图应该保持简单，复杂逻辑放入 ViewModel
- 使用协议解耦服务层

### 服务层

- 服务类使用单例模式（`static let shared`）
- 通过协议定义接口，便于测试和替换实现
- 避免在服务层直接操作 UI

### 错误处理

- 使用 Swift 的 `Error` 协议和 `throw`
- 定义有意义的错误信息
- 在 UI 层适当展示错误

### 内存管理

- 使用 `@StateObject`、`@ObservedObject` 正确管理对象生命周期
- 注意避免循环引用
- 使用 `weak self` 在闭包中避免强引用

## 可复用组件

项目中的可复用组件放在 `Views/Components/` 目录：

- `IconPickerSheet.swift` - 图标选择器
- `FlowLayout.swift` - 流式布局
- `EnabledChip.swift` - 已启用项目标签
- `AddableChip.swift` - 可添加项目标签

## 服务协议

服务层通过协议定义，存放在 `Services/Protocols/` 目录：

- `StorageServiceProtocol` - 配置存储
- `FinderServiceProtocol` - Finder 交互
- `CommandExecutorProtocol` - 命令执行

## ViewModel

视图模型负责：
- 持有视图状态
- 处理用户交互
- 调用服务层
- 不直接包含 UI 代码
