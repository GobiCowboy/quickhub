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
    private let hoverTint = Color(red: 0.28, green: 0.28, blue: 0.30)

    var body: some View {
        HStack(spacing: 8) {
            CommandIconChip(item: item, isSelected: isHovered, size: 20)

            Text(DefaultItemNameMapping.localizedItemName(item.name))
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.primary)
                .lineLimit(1)

            Spacer()

            if isExecuting {
                ProgressView()
                    .controlSize(.small)
            }
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 4)
        .background(hoverGlassBackground)
        .overlay(hoverGlassStroke)
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
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .fill(hoverTint.opacity(0.22))
        } else {
            Color.clear
        }
    }

    @ViewBuilder
    private var hoverGlassStroke: some View {
        RoundedRectangle(cornerRadius: 7, style: .continuous)
            .stroke(
                isHovered ? Color.white.opacity(0.08) : Color.clear,
                lineWidth: 1
            )
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
