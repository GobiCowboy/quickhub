import SwiftUI
import AppKit
import UserNotifications

// MARK: - 命令项行

struct CommandItemRow: View {
    let item: CommandItem
    let isHovered: Bool
    var onHover: ((Bool) -> Void)?
    var onClose: (() -> Void)?
    @State private var isExecuting = false

    var body: some View {
        HStack(spacing: 6) {
            itemIcon
                .font(.system(size: 13))
                .foregroundColor(isHovered ? .white : .primary)
                .frame(width: 16)

            Text(DefaultItemNameMapping.localizedItemName(item.name))
                .font(.system(size: 12))
                .foregroundColor(isHovered ? .white : .primary)

            Spacer()

            // 命令类型标签（在原生菜单往往省略，或者做得很淡）
            Text(commandTypeLabel)
                .font(.system(size: 9))
                .foregroundColor(isHovered ? .white.opacity(0.8) : .secondary)
                .padding(.horizontal, 4)
                .padding(.vertical, 2)
                .background(isHovered ? Color.white.opacity(0.2) : Color.secondary.opacity(0.1))
                .cornerRadius(4)

            if isExecuting {
                ProgressView()
                    .controlSize(.small)
                    .colorScheme(isHovered ? .dark : .light)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 3)
        .background(
            RoundedRectangle(cornerRadius: 4)
                .fill(isHovered ? Color.accentColor : Color.clear)
        )
        .contentShape(Rectangle())
        .onHover { hovering in
            onHover?(hovering)
        }
        .onTapGesture {
            executeCommand()
        }
        .disabled(isExecuting)
    }

    private var commandTypeLabel: String {
        switch item.type {
        case .shell:
            return localized("command_type.shell")
        case .copyPath:
            return localized("command_type.copy_path")
        case .createFile:
            return localized("command_type.create_file")
        case .createFolder:
            return localized("command_type.create_folder")
        case .openFinder:
            return localized("command_type.open_finder")
        case .openApp:
            return localized("command_type.open_app")
        case .bitwardenSearch:
            return localized("command_type.bitwarden")
        }
    }

    @ViewBuilder
    private var itemIcon: some View {
        if item.icon.hasPrefix("/") {
            // 图标是文件路径
            if let image = NSImage(contentsOfFile: item.icon) {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
            } else {
                Image(systemName: "questionmark")
            }
        } else {
            // 图标是 SF Symbol
            Image(systemName: item.icon)
        }
    }

    private func executeCommand() {
        isExecuting = true
        onClose?()

        // 获取当前 Finder 上下文 - 使用保存的选择，避免面板打开后 Finder 选择改变
        let selection = AppDelegate.shared?.getSavedFinderSelection() ?? []
        let firstPath = selection.first?.path
        let directory: String
        if let url = selection.first {
            var isDir: ObjCBool = false
            if FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir) {
                if isDir.boolValue {
                    directory = url.path
                } else {
                    directory = url.deletingLastPathComponent().path
                }
            } else {
                directory = FileManager.default.homeDirectoryForCurrentUser.path
            }
        } else {
            directory = FileManager.default.homeDirectoryForCurrentUser.path
        }

        let context = ExecutionContext(
            filePath: firstPath,
            directory: directory
        )

        print("[CommandItemRow] 执行命令: \(item.name)")
        print("[CommandItemRow] 保存的选择: \(selection.map { $0.lastPathComponent })")
        print("[CommandItemRow] context.filePath: \(context.filePath ?? "nil")")
        print("[CommandItemRow] context.directory: \(context.directory)")
        print("[CommandItemRow] context.fileName: \(context.fileName ?? "nil")")

        Task {
            do {
                let result = try await CommandExecutor.shared.execute(item, context: context)
                if result.success {
                    showNotification(title: item.name, message: result.output)
                }
            } catch {
                showNotification(title: localized("notification.execution_failed"), message: error.localizedDescription)
            }
            isExecuting = false
        }
    }

    private func showNotification(title: String, message: String) {
        // 检查设置是否允许发送通知
        let settings = StorageService.shared.loadConfig().settings
        guard settings.showNotifications else { return }

        let center = UNUserNotificationCenter.current()
        center.requestAuthorization(options: [.alert, .sound]) { granted, _ in
            if granted {
                let content = UNMutableNotificationContent()
                content.title = title
                content.body = message
                let request = UNNotificationRequest(
                    identifier: UUID().uuidString,
                    content: content,
                    trigger: nil
                )
                center.add(request)
            }
        }
    }
}
