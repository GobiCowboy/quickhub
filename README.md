# RightClickX

macOS 右键菜单增强工具 - 快速执行自定义命令

## 功能特性

- **快捷命令**: 在 Finder 右键菜单中添加自定义命令
- **新建文件**: 快速创建常见文件类型（Markdown、Swift、Python 等）
- **新建文件夹**: 快速创建文件夹
- **打开应用**: 一键打开常用应用
- **打开文件夹**: 快速访问常用目录
- **终端命令**: 支持在终端中执行自定义 Shell 命令
- **热键呼出**: 使用 `Cmd+Shift+P` 全局快捷键呼出菜单

## 系统要求

- macOS 13.0 (Ventura) 或更高版本
- Xcode 15.0 或更高版本

## 编译运行

### 1. 安装 XcodeGen

如果你还没有安装 XcodeGen，请先安装：

```bash
brew install xcodegen
```

### 2. 生成 Xcode 项目

```bash
cd RightClickX
xcodegen generate
```

### 3. 编译项目

```bash
xcodebuild -scheme RightClickX build
```

### 4. 运行应用

编译成功后，可以在 `~/Library/Developer/Xcode/DerivedData/` 目录下找到生成的应用，或直接在 Xcode 中运行。

## 项目结构

```
RightClickX/
├── App/
│   ├── main.swift                          # 应用入口
│   ├── AppDelegate.swift                   # 应用代理
│   │
│   ├── Models/                             # 数据模型
│   │   └── Models.swift                    # CommandItem, CommandGroup, AppConfig
│   │
│   ├── Services/                           # 服务层
│   │   ├── Protocols/                      # 服务协议定义
│   │   ├── StorageService.swift            # 配置持久化
│   │   ├── FinderService.swift             # Finder 交互
│   │   └── CommandExecutor.swift           # 命令执行
│   │
│   ├── ViewModels/                         # 视图模型
│   ├── Views/                              # 视图层
│   │   ├── Popover/                        # 浮窗视图
│   │   ├── AppSettings/                    # 设置视图
│   │   └── Components/                     # 可复用 UI 组件
│   │
│   ├── Utilities/                          # 工具函数
│   └── Resources/
│       └── Assets.xcassets/
│
├── project.yml                              # XcodeGen 配置
└── README.md
```

## 使用方法

1. 运行应用，菜单栏会出现一个命令图标
2. 按 `Cmd+Shift+P` 或点击菜单栏图标打开命令面板
3. 在 Finder 中右键点击文件/文件夹，即可看到自定义命令
4. 点击菜单栏图标可打开设置界面

## 配置说明

配置文件位于 `~/.config/rightclickx/config.json`，可以手动编辑或通过设置界面修改。

## 开发相关

- [贡献指南](./CONTRIBUTING.md)
- [项目规范](./RightClickX/CLAUDE.md)

## License

Apache License 2.0 - 详见 [LICENSE](./LICENSE) 文件
