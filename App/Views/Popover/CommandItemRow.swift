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
    private let hoverTint = Color(nsColor: .controlAccentColor).opacity(0.92)

    var body: some View {
        HStack(spacing: 8) {
            CommandIconChip(item: item, isSelected: isHovered, size: 16)

            Text(DefaultItemNameMapping.localizedItemName(item.name))
                .font(.system(size: 11.5, weight: .regular))
                .foregroundStyle(isHovered ? .white : .primary)
                .lineLimit(1)

            Spacer()

            if isExecuting {
                ProgressView()
                    .controlSize(.small)
            }
        }
        .frame(minHeight: 26)
        .padding(.horizontal, 11)
        .padding(.vertical, 1.5)
        .background(hoverGlassBackground)
        .contentShape(Rectangle())
        .onHover { hovering in
            onHover?(hovering)
        }
        .onTapGesture {
            executeCommand()
        }
        .disabled(isExecuting)
        .animation(.easeOut(duration: 0.12), value: isHovered)
    }

    @ViewBuilder
    private var hoverGlassBackground: some View {
        if isHovered {
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(hoverTint)
        } else {
            Color.clear
        }
    }

    private func executeCommand() {
        isExecuting = true
        onClose?()

        // 获取当前 Finder 上下文 - 使用保存的选择，避免面板打开后 Finder 选择改变
        let selection = AppDelegate.shared?.getSavedFinderSelection() ?? []
        let firstPath = selection.first?.path
        let directory: String
        // Finder 不在前台（桌面手势）→ 直接用桌面
        if !(AppDelegate.shared?.finderWasActive ?? true) {
            directory = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Desktop").path
        } else if let url = selection.first {
            var isDir: ObjCBool = false
            if FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir) {
                if isDir.boolValue {
                    directory = url.path
                } else {
                    directory = url.deletingLastPathComponent().path
                }
            } else {
                directory = FinderService.shared.getCurrentDirectory()
            }
        } else {
            directory = FinderService.shared.getCurrentDirectory()
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
                } else {
                    print("[CommandItemRow] 执行失败: \(result.output)")
                }
            } catch {
                print("[CommandItemRow] 执行异常: \(error)")
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
