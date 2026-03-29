# 贡献指南

感谢您对 RightClickX 项目的兴趣！我们欢迎任何形式的贡献。

## 如何贡献

### 报告问题

如果您发现了 bug 或有功能建议，请通过 GitHub Issues 提交。请包含：

- 清晰的问题描述
- 重现步骤
- 预期行为 vs 实际行为
- 您的系统环境（macOS 版本等）

### 代码贡献

1. **Fork 本仓库**
2. **创建分支**: 请使用描述性的分支名
   ```bash
   git checkout -b feature/your-feature-name
   # 或
   git checkout -b fix/your-bug-fix
   ```
3. **编写代码**: 遵循项目的代码规范
4. **提交更改**: 使用清晰的提交信息
   ```bash
   git commit -m "feat(scope): 添加新功能"
   ```
5. **推送分支**
   ```bash
   git push origin feature/your-feature-name
   ```
6. **创建 Pull Request**

### Commit 规范

我们遵循 [Conventional Commits](https://www.conventionalcommits.org/) 规范：

- `feat`: 新功能
- `fix`: Bug 修复
- `docs`: 文档变更
- `style`: 代码格式（不影响功能）
- `refactor`: 重构
- `test`: 测试
- `chore`: 构建/工具变更

示例：
```
feat(settings): 添加快捷键自定义功能
fix(popover): 修复面板关闭后快捷键失效问题
docs(readme): 更新编译说明
```

## 开发环境

### 必要条件

- macOS 13.0+
- Xcode 15.0+
- XcodeGen

### 设置开发环境

```bash
# 克隆仓库
git clone <your-fork-url>
cd RightClickX

# 安装 XcodeGen（如果未安装）
brew install xcodegen

# 生成 Xcode 项目
xcodegen generate

# 在 Xcode 中打开并开始开发
open RightClickX.xcodeproj
```

## 项目架构

项目采用 MVVM 架构：

- **Models/**: 数据模型
- **Views/**: SwiftUI 视图
- **ViewModels/**: 视图模型
- **Services/**: 业务逻辑服务
- **Utilities/**: 工具函数

详见 [CLAUDE.md](./RightClickX/CLAUDE.md)

## 代码规范

- 使用 Swift 默认的命名规范
- 添加适当的注释说明复杂逻辑
- 确保代码可读性和可维护性
- 遵循 SOLID 原则

## 测试

在提交前，请确保：

1. 代码可以正常编译
2. 新功能可以正常工作
3. 没有引入新的警告或错误

## 许可证

通过提交代码，您同意您的贡献将遵循 [Apache License 2.0](../../LICENSE)。
