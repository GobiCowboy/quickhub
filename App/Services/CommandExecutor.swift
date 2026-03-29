import Foundation
import AppKit

/// 命令执行器
class CommandExecutor: CommandExecutorProtocol {
    static let shared = CommandExecutor()

    private init() {}

    /// 执行命令
    func execute(_ item: CommandItem, context: ExecutionContext) async throws -> ExecutionResult {
        switch item.type {
        case .shell:
            return try await executeShell(item, context: context)
        case .createFile:
            return try await executeCreateFile(item, context: context)
        case .createFolder:
            return try await executeCreateFolder(item, context: context)
        case .openFinder:
            return try await executeOpenFinder(item, context: context)
        case .openApp:
            return try await executeOpenApp(item, context: context)
        case .bitwardenSearch:
            return try await executeBitwardenSearch(context: context)
        }
    }

    // MARK: - Shell 命令

    private func executeShell(_ item: CommandItem, context: ExecutionContext) async throws -> ExecutionResult {
        guard let command = item.command else {
            throw ExecutionError.missingCommand
        }

        // 替换占位符
        let expandedCommand = expandCommand(command, context: context)

        // 是否在终端中执行
        if item.openInTerminal == true {
            return try await executeInTerminal(expandedCommand, directory: context.directory)
        } else {
            return try await executeSilently(expandedCommand)
        }
    }

    private func expandCommand(_ command: String, context: ExecutionContext) -> String {
        var result = command
        result = result.replacingOccurrences(of: "{path}", with: context.filePath ?? "")
        result = result.replacingOccurrences(of: "{dir}", with: context.directory)
        result = result.replacingOccurrences(of: "{filename}", with: context.fileName ?? "")
        return result
    }

    private func executeSilently(_ command: String) async throws -> ExecutionResult {
        return try await withCheckedThrowingContinuation { continuation in
            let task = Process()
            task.executableURL = URL(fileURLWithPath: "/bin/zsh")
            task.arguments = ["-c", command]

            let pipe = Pipe()
            task.standardOutput = pipe
            task.standardError = pipe

            do {
                try task.run()
                task.waitUntilExit()

                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                let output = String(data: data, encoding: .utf8) ?? ""

                if task.terminationStatus == 0 {
                    continuation.resume(returning: ExecutionResult(success: true, output: output))
                } else {
                    continuation.resume(throwing: ExecutionError.commandFailed(output))
                }
            } catch {
                continuation.resume(throwing: ExecutionError.executionFailed(error.localizedDescription))
            }
        }
    }

    private func executeInTerminal(_ command: String, directory: String) async throws -> ExecutionResult {
        let script: String
        if directory.isEmpty {
            script = command
        } else {
            script = "cd '\(directory)' && \(command)"
        }

        let escapedScript = script.replacingOccurrences(of: "'", with: "'\\''")

        let appleScript = """
        tell application "Terminal"
            activate
            do script "\(escapedScript)"
        end tell
        """

        var error: NSDictionary?
        if let scriptObject = NSAppleScript(source: appleScript) {
            scriptObject.executeAndReturnError(&error)

            if let error = error {
                throw ExecutionError.executionFailed(error.description)
            }
        }

        return ExecutionResult(success: true, output: "已在终端中执行")
    }

    // MARK: - 新建文件

    private func executeCreateFile(_ item: CommandItem, context: ExecutionContext) async throws -> ExecutionResult {
        guard let template = item.template,
              let ext = item.fileExtension else {
            throw ExecutionError.missingTemplate
        }

        // 解析文件名 - 使用用户输入
        let fileName = await withCheckedContinuation { continuation in
            UserInputHelper.promptFileName(extension: ext, directory: context.directory) { name in
                continuation.resume(returning: name)
            }
        }

        // 用户取消
        guard let fileName = fileName else {
            return ExecutionResult(success: false, output: "已取消")
        }

        let fullFileName = "\(fileName).\(ext)"
        let fileURL = URL(fileURLWithPath: context.directory).appendingPathComponent(fullFileName)

        // 检查文件是否已存在
        if FileManager.default.fileExists(atPath: fileURL.path) {
            let shouldReplace = await withCheckedContinuation { continuation in
                DispatchQueue.main.async {
                    let alert = NSAlert()
                    alert.messageText = "文件已存在"
                    alert.informativeText = "\(fullFileName) 已存在。是否要替换它？"
                    alert.addButton(withTitle: "替换")
                    alert.addButton(withTitle: "取消")

                    // 创建临时窗口作为 sheet 父窗口
                    let tempWindow = NSWindow(contentRect: .zero, styleMask: .borderless, backing: .buffered, defer: false)
                    tempWindow.level = .floating
                    tempWindow.center()
                    tempWindow.makeKeyAndOrderFront(nil)

                    alert.beginSheetModal(for: tempWindow) { response in
                        continuation.resume(returning: response == .alertFirstButtonReturn)
                    }
                }
            }

            if !shouldReplace {
                return ExecutionResult(success: false, output: "已取消")
            }
        }

        // 渲染模板
        let content = renderTemplate(template, fileName: fileName)

        do {
            try content.write(to: fileURL, atomically: true, encoding: .utf8)

            // 打开文件
            NSWorkspace.shared.activateFileViewerSelecting([fileURL])

            return ExecutionResult(success: true, output: "已创建: \(fullFileName)")
        } catch {
            throw ExecutionError.executionFailed(error.localizedDescription)
        }
    }

    private func renderTemplate(_ template: String, fileName: String) -> String {
        let now = Date()
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short

        return template
            .replacingOccurrences(of: "{{FILENAME}}", with: fileName)
            .replacingOccurrences(of: "{{DATE}}", with: formatter.string(from: now))
            .replacingOccurrences(of: "{{TIME}}", with: formatter.string(from: now))
    }

    // MARK: - 新建文件夹

    private func executeCreateFolder(_ item: CommandItem, context: ExecutionContext) async throws -> ExecutionResult {
        // 使用用户输入的文件夹名
        let folderName = await withCheckedContinuation { continuation in
            UserInputHelper.promptFolderName(directory: context.directory) { name in
                continuation.resume(returning: name)
            }
        }

        // 用户取消
        guard let folderName = folderName else {
            return ExecutionResult(success: false, output: "已取消")
        }

        let folderURL = URL(fileURLWithPath: context.directory).appendingPathComponent(folderName)

        // 检查文件夹是否已存在
        if FileManager.default.fileExists(atPath: folderURL.path) {
            let shouldReplace = await withCheckedContinuation { continuation in
                DispatchQueue.main.async {
                    let alert = NSAlert()
                    alert.messageText = "文件夹已存在"
                    alert.informativeText = "\(folderName) 已存在。是否要替换它？"
                    alert.addButton(withTitle: "替换")
                    alert.addButton(withTitle: "取消")

                    // 创建临时窗口作为 sheet 父窗口
                    let tempWindow = NSWindow(contentRect: .zero, styleMask: .borderless, backing: .buffered, defer: false)
                    tempWindow.level = .floating
                    tempWindow.center()
                    tempWindow.makeKeyAndOrderFront(nil)

                    alert.beginSheetModal(for: tempWindow) { response in
                        continuation.resume(returning: response == .alertFirstButtonReturn)
                    }
                }
            }

            if !shouldReplace {
                return ExecutionResult(success: false, output: "已取消")
            }

            // 删除已存在的文件夹
            try FileManager.default.removeItem(at: folderURL)
        }

        do {
            try FileManager.default.createDirectory(at: folderURL, withIntermediateDirectories: true)

            // 在 Finder 中显示新创建的文件夹
            NSWorkspace.shared.activateFileViewerSelecting([folderURL])

            return ExecutionResult(success: true, output: "已创建: \(folderName)")
        } catch {
            throw ExecutionError.executionFailed(error.localizedDescription)
        }
    }

    // MARK: - 打开目录

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

    // MARK: - 打开应用

    private func executeOpenApp(_ item: CommandItem, context: ExecutionContext) async throws -> ExecutionResult {
        guard let path = item.targetPath else {
            throw ExecutionError.missingPath
        }

        let url = URL(fileURLWithPath: path)

        try await NSWorkspace.shared.openApplication(at: url, configuration: NSWorkspace.OpenConfiguration())

        return ExecutionResult(success: true, output: "已打开应用")
    }

    // MARK: - Bitwarden 密码搜索

    private func executeBitwardenSearch(context: ExecutionContext) async throws -> ExecutionResult {
        // 弹出搜索框获取用户输入
        let query = await withCheckedContinuation { continuation in
            UserInputHelper.promptBitwardenSearch { searchText in
                continuation.resume(returning: searchText ?? "")
            }
        }

        guard !query.isEmpty else {
            return ExecutionResult(success: false, output: "搜索已取消")
        }

        // 搜索密码
        let items = try await BitwardenService.shared.searchPasswords(query: query)

        if items.isEmpty {
            return ExecutionResult(success: true, output: "未找到匹配的密码")
        }

        // 如果只有一个结果，直接复制
        if items.count == 1, let item = items.first, let login = item.login, let password = login.password {
            copyToClipboard(password)
            return ExecutionResult(success: true, output: "已复制 \(item.name) 的密码")
        }

        // 多个结果，弹出选择
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

    private func copyToClipboard(_ text: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
    }
}
