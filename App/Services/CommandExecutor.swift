import Foundation
import AppKit
import AVFoundation
import ImageIO
import SwiftUI
import UniformTypeIdentifiers

/// 命令执行器
class CommandExecutor: CommandExecutorProtocol {
    static let shared = CommandExecutor()

    private init() {}

    func dismissFileInfoPanel() {
        MainActor.assumeIsolated {
            InternalFileInfoPresenter.shared.dismiss()
        }
    }

    /// 执行命令
    func execute(_ item: CommandItem, context: ExecutionContext) async throws -> ExecutionResult {
        switch item.type {
        case .shell:
            return try await executeShell(item, context: context)
        case .copyPath:
            return executeCopyPath(context)
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

        if isInternalFileInfoCommand(command) {
            await MainActor.run {
                InternalFileInfoPresenter.shared.present(using: context)
            }
            return ExecutionResult(success: true, output: localized("executor.file_info_shown"))
        }

        // 处理旧版的带有 bug 的 AppleScript 终端启动代码，强制升级为原生更快的 open -a 指令
        var processedCommand = command
        if processedCommand.hasPrefix("osascript") {
            if processedCommand.contains("\"Terminal\"") && processedCommand.contains("cd") {
                processedCommand = "open -a Terminal '{dir}'"
            } else if processedCommand.contains("\"iTerm\"") && processedCommand.contains("cd") {
                processedCommand = "open -a iTerm '{dir}'"
            }
        }

        // 替换占位符
        let expandedCommand = expandCommand(processedCommand, context: context)

        // 是否在终端中执行
        if item.openInTerminal == true {
            return try await executeInTerminal(expandedCommand, directory: context.directory)
        } else {
            return try await executeSilently(expandedCommand)
        }
    }

    private func executeCopyPath(_ context: ExecutionContext) -> ExecutionResult {
        guard let filePath = context.filePath else {
            return ExecutionResult(success: false, output: localized("executor.path_empty"))
        }

        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(filePath, forType: .string)
        print("[CommandExecutor] 复制路径到剪贴板: \(filePath)")
        return ExecutionResult(success: true, output: localized("executor.copied", with: filePath))
    }

    private func expandCommand(_ command: String, context: ExecutionContext) -> String {
        var result = command
        result = result.replacingOccurrences(of: "{path}", with: context.filePath ?? "")
        result = result.replacingOccurrences(of: "{dir}", with: context.directory)
        result = result.replacingOccurrences(of: "{filename}", with: context.fileName ?? "")
        return result
    }

    private func executeSilently(_ command: String) async throws -> ExecutionResult {
        print("[CommandExecutor] executeSilently: \(command)")

        // 对于其他命令（包括 osascript 直接调用 Terminal/iTerm），使用 zsh 执行
        print("[CommandExecutor] Using zsh to execute")
        return try await withCheckedThrowingContinuation { continuation in
            let task = Process()
            task.executableURL = URL(fileURLWithPath: "/bin/zsh")
            task.arguments = ["-c", command]
            task.environment = {
                var env = ProcessInfo.processInfo.environment
                env["LANG"] = "en_US.UTF-8"
                return env
            }()

            let pipe = Pipe()
            task.standardOutput = pipe
            task.standardError = pipe

            do {
                try task.run()
                task.waitUntilExit()

                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                let output = String(data: data, encoding: .utf8) ?? ""
                print("[CommandExecutor] zsh output: \(output), status: \(task.terminationStatus)")

                if task.terminationStatus == 0 {
                    continuation.resume(returning: ExecutionResult(success: true, output: output))
                } else {
                    continuation.resume(throwing: ExecutionError.commandFailed(output))
                }
            } catch {
                print("[CommandExecutor] zsh error: \(error)")
                continuation.resume(throwing: ExecutionError.executionFailed(error.localizedDescription))
            }
        }
    }

    private func executeInTerminal(_ command: String, directory: String) async throws -> ExecutionResult {
        // 命令已经通过 expandCommand 替换了 {dir}，直接使用
        let script = command

        // 安全转义 AppleScript 中的字符串（处理反斜杠和双引号）
        let appleScriptEscapedScript = script
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")

        let appleScript = """
        tell application "Terminal"
            activate
            do script "\(appleScriptEscapedScript)"
        end tell
        """

        var error: NSDictionary?
        if let scriptObject = NSAppleScript(source: appleScript) {
            scriptObject.executeAndReturnError(&error)

            if let error = error {
                throw ExecutionError.executionFailed(error.description)
            }
        }

        return ExecutionResult(success: true, output: localized("executor.terminal_executed"))
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
            return ExecutionResult(success: false, output: localized("executor.cancelled"))
        }

        let fullFileName = "\(fileName).\(ext)"
        let fileURL = uniqueURL(in: context.directory, name: fileName, extension: ext)

        // 渲染模板
        let content = renderTemplate(template, fileName: fileName)

        do {
            try content.write(to: fileURL, atomically: true, encoding: .utf8)

            selectInFinder(fileURL, directory: context.directory)

            let createdName = fileURL.lastPathComponent
            return ExecutionResult(success: true, output: localized("executor.created", with: createdName))
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

    /// 自动递增文件名：file.md → file 1.md → file 2.md ...
    private func uniqueURL(in directory: String, name: String, extension ext: String) -> URL {
        let base = URL(fileURLWithPath: directory).appendingPathComponent("\(name).\(ext)")
        if !FileManager.default.fileExists(atPath: base.path) {
            return base
        }
        var counter = 1
        while true {
            let candidate = URL(fileURLWithPath: directory).appendingPathComponent("\(name) \(counter).\(ext)")
            if !FileManager.default.fileExists(atPath: candidate.path) {
                return candidate
            }
            counter += 1
        }
    }

    /// 自动递增文件夹名：folder → folder 1 → folder 2 ...
    private func uniqueFolderURL(in directory: String, name: String) -> URL {
        let base = URL(fileURLWithPath: directory).appendingPathComponent(name)
        if !FileManager.default.fileExists(atPath: base.path) {
            return base
        }
        var counter = 1
        while true {
            let candidate = URL(fileURLWithPath: directory).appendingPathComponent("\(name) \(counter)")
            if !FileManager.default.fileExists(atPath: candidate.path) {
                return candidate
            }
            counter += 1
        }
    }

    /// 在 Finder 中选中指定文件/文件夹（不弹新窗口）
    private func selectInFinder(_ url: URL, directory: String) {
        // 桌面上不激活 Finder，避免弹出窗口
        let desktop = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Desktop").path
        if directory == desktop { return }

        let script = """
        tell application "Finder"
            try
                activate
                select (POSIX file "\(url.path)" as alias)
            end try
        end tell
        """
        var error: NSDictionary?
        if let appleScript = NSAppleScript(source: script) {
            appleScript.executeAndReturnError(&error)
        }
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
            return ExecutionResult(success: false, output: localized("executor.cancelled"))
        }

        let folderURL = uniqueFolderURL(in: context.directory, name: folderName)

        do {
            try FileManager.default.createDirectory(at: folderURL, withIntermediateDirectories: true)

            selectInFinder(folderURL, directory: context.directory)

            let createdName = folderURL.lastPathComponent
            return ExecutionResult(success: true, output: localized("executor.created", with: createdName))
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

        return ExecutionResult(success: true, output: localized("executor.opened_in_finder", with: path))
    }

    // MARK: - 打开应用

    private func executeOpenApp(_ item: CommandItem, context: ExecutionContext) async throws -> ExecutionResult {
        guard let path = item.targetPath else {
            throw ExecutionError.missingPath
        }

        let url = URL(fileURLWithPath: path)

        try await NSWorkspace.shared.openApplication(at: url, configuration: NSWorkspace.OpenConfiguration())

        return ExecutionResult(success: true, output: localized("executor.app_opened"))
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
            return ExecutionResult(success: false, output: localized("executor.search_cancelled"))
        }

        // 搜索密码
        let items = try await BitwardenService.shared.searchPasswords(query: query)

        if items.isEmpty {
            return ExecutionResult(success: true, output: localized("executor.no_matching_passwords"))
        }

        // 如果只有一个结果，直接复制
        if items.count == 1, let item = items.first, let login = item.login, let password = login.password {
            copyToClipboard(password)
            return ExecutionResult(success: true, output: localized("executor.copied_password", with: item.name))
        }

        // 多个结果，弹出选择
        let selectedItem = await withCheckedContinuation { continuation in
            UserInputHelper.showBitwardenResults(items: items) { selected in
                continuation.resume(returning: selected)
            }
        }

        if let item = selectedItem, let login = item.login, let password = login.password {
            copyToClipboard(password)
            return ExecutionResult(success: true, output: localized("executor.copied_password", with: item.name))
        }

        return ExecutionResult(success: false, output: localized("executor.not_selected"))
    }

    private func copyToClipboard(_ text: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
    }
}

// MARK: - 内置文件信息

private func isInternalFileInfoCommand(_ command: String) -> Bool {
    command == InternalShellCommand.fileInfo || command.contains("/usr/local/bin/getinfo")
}

private struct FileInfoRecord: Identifiable {
    let id = UUID()
    let url: URL
    let icon: NSImage
    let name: String
    let path: String
    let type: String
    let size: String
    let created: String
    let modified: String
    let permissions: String
    let details: [String]

    init(url: URL) {
        self.url = url

        let fileManager = FileManager.default
        let path = url.path
        self.path = path
        self.name = url.lastPathComponent

        let icon = NSWorkspace.shared.icon(forFile: path)
        icon.size = NSSize(width: 34, height: 34)
        self.icon = icon

        let attrs = (try? fileManager.attributesOfItem(atPath: path)) ?? [:]
        let isDirectory = (attrs[.type] as? FileAttributeType) == .typeDirectory

        if isDirectory {
            self.type = localized("command_type.folder")
        } else if let utType = UTType(filenameExtension: url.pathExtension) {
            self.type = utType.localizedDescription ?? ".\(url.pathExtension)"
        } else if !url.pathExtension.isEmpty {
            self.type = ".\(url.pathExtension)"
        } else {
            self.type = localized("command_type.file")
        }

        let rawSize = (attrs[.size] as? NSNumber)?.int64Value ?? 0
        self.size = isDirectory ? FileInfoFormatter.folderSize(at: url) : FileInfoFormatter.formatSize(rawSize)
        self.created = FileInfoFormatter.formatDate(attrs[.creationDate] as? Date)
        self.modified = FileInfoFormatter.formatDate(attrs[.modificationDate] as? Date)
        let perms = (attrs[.posixPermissions] as? NSNumber)?.uint16Value ?? 0
        self.permissions = String(perms, radix: 8)

        var extraDetails: [String] = []
        if isDirectory {
            extraDetails.append(localized("file_info.items", with: "\(FileInfoFormatter.folderItemCount(at: url))"))
        }
        if let dimensions = FileInfoFormatter.imageDimensions(at: url) {
            extraDetails.append(dimensions)
        }
        self.details = extraDetails
    }
}

private enum FileInfoFormatter {
    static func formatSize(_ size: Int64) -> String {
        if size < 1024 { return "\(size) B" }
        if size < 1024 * 1024 { return String(format: "%.1f KB", Double(size) / 1024.0) }
        if size < 1024 * 1024 * 1024 { return String(format: "%.1f MB", Double(size) / (1024.0 * 1024.0)) }
        return String(format: "%.2f GB", Double(size) / (1024.0 * 1024.0 * 1024.0))
    }

    static func formatDate(_ date: Date?) -> String {
        guard let date else { return "—" }
        let formatter = DateFormatter()
        formatter.locale = Locale.current
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    static func folderItemCount(at url: URL) -> Int {
        (try? FileManager.default.contentsOfDirectory(atPath: url.path).count) ?? 0
    }

    static func folderSize(at url: URL) -> String {
        guard let enumerator = FileManager.default.enumerator(at: url, includingPropertiesForKeys: [.fileSizeKey], options: [.skipsHiddenFiles]) else {
            return "0 B"
        }

        var totalSize: Int64 = 0
        for case let fileURL as URL in enumerator {
            let values = try? fileURL.resourceValues(forKeys: [.isRegularFileKey, .fileSizeKey])
            if values?.isRegularFile == true {
                totalSize += Int64(values?.fileSize ?? 0)
            }
        }
        return formatSize(totalSize)
    }

    static func imageDimensions(at url: URL) -> String? {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [String: Any],
              let width = properties[kCGImagePropertyPixelWidth as String] as? Int,
              let height = properties[kCGImagePropertyPixelHeight as String] as? Int else {
            return nil
        }
        return "\(width) × \(height) px"
    }
}

private struct FileInfoPanelView: View {
    let records: [FileInfoRecord]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                ForEach(records) { record in
                    VStack(alignment: .leading, spacing: 10) {
                        HStack(alignment: .center, spacing: 10) {
                            Image(nsImage: record.icon)
                                .resizable()
                                .frame(width: 34, height: 34)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(record.name)
                                    .font(.system(size: 15, weight: .semibold))
                                    .lineLimit(1)
                                    .truncationMode(.middle)

                                Text(record.path)
                                    .font(.system(size: 11))
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                                    .truncationMode(.middle)
                            }
                        }

                        Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 6) {
                            FileInfoGridRow(label: localized("file_info.type"), value: record.type)
                            FileInfoGridRow(label: localized("file_info.size"), value: record.size)
                            FileInfoGridRow(label: localized("file_info.created"), value: record.created)
                            FileInfoGridRow(label: localized("file_info.modified"), value: record.modified)
                            FileInfoGridRow(label: localized("file_info.permissions"), value: record.permissions)
                            ForEach(record.details, id: \.self) { detail in
                                FileInfoGridRow(label: localized("file_info.extra"), value: detail)
                            }
                        }
                    }
                    .padding(14)
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(.ultraThinMaterial)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(Color.white.opacity(0.14), lineWidth: 1)
                    )
                }
            }
            .padding(16)
        }
        .frame(width: 520, height: min(560, max(240, CGFloat(records.count) * 180)))
        .background(Color.clear)
    }
}

private struct FileInfoGridRow: View {
    let label: String
    let value: String

    var body: some View {
        GridRow(alignment: .firstTextBaseline) {
            Text(label)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.secondary)
                .frame(width: 80, alignment: .leading)

            Text(value)
                .font(.system(size: 11))
                .foregroundStyle(.primary)
                .lineLimit(1)
                .truncationMode(.middle)
        }
    }
}

@MainActor
private final class InternalFileInfoPresenter {
    static let shared = InternalFileInfoPresenter()

    private var panel: NSPanel?
    private var dismissMonitor: Any?

    func dismiss() {
        if let monitor = dismissMonitor {
            NSEvent.removeMonitor(monitor)
            dismissMonitor = nil
        }
        panel?.orderOut(nil)
        panel = nil
    }

    private func startDismissMonitor() {
        stopDismissMonitor()
        dismissMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown, .keyDown]) { [weak self] _ in
            guard let self = self, self.panel?.isVisible == true else { return }
            DispatchQueue.main.async {
                self.dismiss()
            }
        }
    }

    private func stopDismissMonitor() {
        if let monitor = dismissMonitor {
            NSEvent.removeMonitor(monitor)
            dismissMonitor = nil
        }
    }

    func present(using context: ExecutionContext) {
        let selection = AppDelegate.shared?.getSavedFinderSelection() ?? []
        let urls = selection.isEmpty ? fallbackURLs(from: context) : selection
        let records = urls.compactMap { FileInfoRecord(url: $0) }

        guard !records.isEmpty else { return }

        let hostingController = NSHostingController(rootView: FileInfoPanelView(records: records))
        let panelSize = panelSize(for: records.count)
        let frame = frameForPanel(size: panelSize)
        let panel = NSPanel(
            contentRect: frame,
            styleMask: [.titled, .nonactivatingPanel, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        panel.contentViewController = hostingController
        panel.isFloatingPanel = true
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hidesOnDeactivate = false
        panel.animationBehavior = .none
        panel.titleVisibility = .hidden
        panel.titlebarAppearsTransparent = true
        panel.standardWindowButton(.closeButton)?.isHidden = true
        panel.standardWindowButton(.miniaturizeButton)?.isHidden = true
        panel.standardWindowButton(.zoomButton)?.isHidden = true

        if let existing = self.panel {
            existing.orderOut(nil)
        }
        self.panel = panel

        panel.makeKeyAndOrderFront(nil)
        startDismissMonitor()
        NSApp.activate(ignoringOtherApps: true)
    }

    private func panelSize(for recordCount: Int) -> NSSize {
        let height = min(560, max(240, CGFloat(recordCount) * 180))
        return NSSize(width: 520, height: height)
    }

    private func frameForPanel(size: NSSize) -> NSRect {
        let mouseLocation = NSEvent.mouseLocation
        let screen = screen(at: mouseLocation) ?? NSScreen.main
        guard let screen else {
            return NSRect(x: mouseLocation.x, y: mouseLocation.y - size.height, width: size.width, height: size.height)
        }

        let screenFrame = screen.visibleFrame
        var origin = NSPoint(
            x: mouseLocation.x,
            y: mouseLocation.y - size.height
        )

        if origin.x + size.width > screenFrame.maxX {
            origin.x = screenFrame.maxX - size.width
        }
        if origin.x < screenFrame.minX {
            origin.x = screenFrame.minX
        }
        if origin.y < screenFrame.minY {
            origin.y = screenFrame.minY
        }
        if origin.y + size.height > screenFrame.maxY {
            origin.y = screenFrame.maxY - size.height
        }

        return NSRect(origin: origin, size: size)
    }

    private func screen(at location: NSPoint) -> NSScreen? {
        NSScreen.screens.first { screen in
            NSMouseInRect(location, screen.frame, false)
        }
    }

    private func fallbackURLs(from context: ExecutionContext) -> [URL] {
        if let filePath = context.filePath, !filePath.isEmpty {
            return [URL(fileURLWithPath: filePath)]
        }

        if !context.directory.isEmpty {
            return [URL(fileURLWithPath: context.directory)]
        }

        return []
    }
}
