# QuickHub

[English](#english) | [中文](#中文)

---

## English

Minimal, fast macOS super toolbox. One key press gives your Finder infinite possibilities.

### Download & Install

#### Direct Download (Recommended)
Download the packaged app: https://github.com/GobiCowboy/quickhub/releases/latest

1. Download `QuickHub-vX.X.X.zip`
2. Extract and drag to **Applications** folder
3. On first run, right-click and select "Open"

#### Build from Source
If you install from source, ensure `xcodegen` is installed.

```bash
xcodegen generate
xcodebuild -scheme RightClickX build
```

### Core Features

- **🚀 Instant Activation**: Select a file in Finder, press `⌥⇧Q`. The panel appears exactly at your cursor position.
- **⌨️ Full Keyboard Operation**: Type to search commands after panel appears, press **Enter** to execute. No mouse movement needed.
- **🛠️ Unlimited Extensions**:
  - **Shell Commands**: Quickly open Terminal/iTerm2, VS Code, copy POSIX paths.
  - **File Templates**: Create Markdown, Swift, Python scripts, etc., with custom content support.
  - **One-Click Access**: Quickly open Desktop, Downloads, or any custom paths.
- **✨ Native Interaction**: Built with SwiftUI, perfectly matches macOS system visual style (Popover material).

### Quick Start

1. **Run the app**: QuickHub icon appears in menu bar.
2. **Onboarding**: First launch shows feature introduction.
3. **Settings**: Click ⚙️ icon at panel bottom to customize your shortcuts.

### Why QuickHub?

1. **Better than Context Menu**: No more messy secondary/tertiary context menus. Search + Enter solves everything.
2. **More Precise than Spotlight**: You only search the tools you need, no system noise.
3. **Extremely Lightweight**: Barely uses system resources, only appears when needed.

### System Requirements

- macOS 13.0 (Ventura) or later
- Xcode 15.0 or later

### Language Support

QuickHub supports **English** and **Chinese**. You can switch languages in **Settings → General → Language**.

---

## 中文

极简、极速的 macOS 超级工具箱。通过一个按键，赋予你的 Finder 无限可能。

### 下载安装

#### 直接下载（推荐）
下载打包好的应用：https://github.com/GobiCowboy/quickhub/releases/latest

1. 下载 `QuickHub-vX.X.X.zip`
2. 解压后拖到 **应用程序** 文件夹
3. 首次运行需要右键点击选择"打开"

#### 从源码编译
如果你通过源码安装，请确保已安装 `xcodegen`。

```bash
xcodegen generate
xcodebuild -scheme RightClickX build
```

### 核心特性

- **🚀 瞬时呼出**: 选中 Finder 文件，按 `⌥⇧Q`。面板会精确出现在你的鼠标指针处。
- **⌨️ 全程键盘操作**: 呼出面板后直接打字搜索命令，按 **回车** 立即执行。无需挪动鼠标。
- **🛠️ 无限扩展**:
  - **Shell 命令**: 快速打开终端（Terminal/iTerm2）、VS Code、复制 POSIX 路径。
  - **文件模板**: 快速创建 Markdown、Swift、Python 脚本等，支持自定义内容。
  - **一键触达**: 快速打开桌面、下载目录或任何你常用的自定义路径。
- **✨ 原生交互**: 基于 SwiftUI 打造，完美契合 macOS 系统级视觉风格（Popover 材质）。

### 快速开始

1. **运行应用**: 菜单栏会出现 `QuickHub` 图标。
2. **新手引导**: 首次启动会弹出功能说明，助你快速上手。
3. **设置**: 点击面板底部的 ⚙️ 图标，进入详细设置页面，自定义属于你的快捷指令。

### 为什么选择 QuickHub？

1. **比起右键菜单更爽**: 告别杂乱的二级、三级右键菜单，用搜索和回车解决一切。
2. **比起聚焦搜索更准**: 你只搜索你需要的工具，没有系统杂音。
3. **极其轻量**: 几乎不占系统资源，仅在需要时现身。

### 系统要求

- macOS 13.0 (Ventura) 或更高版本
- Xcode 15.0 或更高版本

### 语言支持

QuickHub 支持 **英文** 和 **中文**。你可以在 **设置 → 通用 → 语言** 中切换语言。

---

感谢你的支持！如果有任何建议，欢迎提交反馈。
