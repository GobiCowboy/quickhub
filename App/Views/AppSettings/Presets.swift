import Foundation
import AppKit

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
    let id: String  // 使用 name 作为 id，确保稳定性
    let name: String
    let command: String
    let icon: String
    let openTerminal: Bool

    init(name: String, command: String, icon: String, openTerminal: Bool) {
        self.id = name
        self.name = name
        self.command = command
        self.icon = icon
        self.openTerminal = openTerminal
    }

    func toCommandItem() -> CommandItem {
        CommandItem(name: name, icon: icon, type: .shell, command: command, openInTerminal: openTerminal)
    }
}

// MARK: - 可用性判断

enum AppAvailability {
    static func isInstalled(bundleIdentifier: String) -> Bool {
        NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleIdentifier) != nil
    }

    static func isInstalled(bundleIdentifiers: [String] = [], appPaths: [String] = []) -> Bool {
        for bundleIdentifier in bundleIdentifiers where isInstalled(bundleIdentifier: bundleIdentifier) {
            return true
        }

        for path in appPaths where FileManager.default.fileExists(atPath: (path as NSString).expandingTildeInPath) {
            return true
        }

        return bundleIdentifiers.isEmpty && appPaths.isEmpty
    }
}

enum InternalShellCommand {
    static let fileInfo = "__internal.file_info__"
}

extension ShellPreset {
    var isAvailable: Bool {
        switch name {
        case "shell.open_in_terminal":
            return AppAvailability.isInstalled(bundleIdentifier: "com.apple.Terminal")
        case "shell.open_in_iterm":
            return AppAvailability.isInstalled(bundleIdentifiers: ["com.googlecode.iterm2"], appPaths: ["/Applications/iTerm.app"])
        case "shell.open_in_vscode":
            return AppAvailability.isInstalled(bundleIdentifiers: ["com.microsoft.VSCode", "com.microsoft.VSCodeInsiders"], appPaths: ["/Applications/Visual Studio Code.app"])
        case "shell.open_in_atom":
            return AppAvailability.isInstalled(bundleIdentifiers: ["com.github.atom"], appPaths: ["/Applications/Atom.app"])
        default:
            return true
        }
    }
}
