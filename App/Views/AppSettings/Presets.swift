import Foundation

// MARK: - 文件模板预设

struct FileTemplatePreset: Identifiable {
    let id = UUID()
    let name: String
    let ext: String
    let icon: String

    func toCommandItem() -> CommandItem {
        CommandItem(name: name, icon: icon, type: .createFile, template: "", fileExtension: ext)
    }
}

// MARK: - 应用预设

struct AppPreset: Identifiable {
    let id = UUID()
    let name: String
    let path: String
    let icon: String

    func toCommandItem() -> CommandItem {
        CommandItem(name: name, icon: icon, type: .openApp, targetPath: path)
    }
}

// MARK: - 文件夹预设

struct FolderPreset: Identifiable {
    let id = UUID()
    let name: String
    let path: String
    let icon: String

    func toCommandItem() -> CommandItem {
        CommandItem(name: name, icon: icon, type: .openFinder, targetPath: path)
    }
}

// MARK: - Shell 命令预设

struct ShellPreset: Identifiable {
    let id = UUID()
    let name: String
    let command: String
    let icon: String
    let openTerminal: Bool

    func toCommandItem() -> CommandItem {
        CommandItem(name: name, icon: icon, type: .shell, command: command, openInTerminal: openTerminal)
    }
}
