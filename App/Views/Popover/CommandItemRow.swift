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
        HStack(spacing: 12) {
            itemIcon
                .foregroundColor(.accentColor)
                .frame(width: 20)

            Text(item.name)
                .foregroundColor(.primary)

            Spacer()

            // 命令类型标签
            Text(commandTypeLabel)
                .font(.caption2)
                .foregroundColor(.secondary)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Color.secondary.opacity(0.1))
                .cornerRadius(4)

            if isExecuting {
                ProgressView()
                    .controlSize(.small)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(isHovered ? Color.accentColor.opacity(0.15) : Color.clear)
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
            return "Shell"
        case .createFile:
            return "文件"
        case .createFolder:
            return "文件夹"
        case .openFinder:
            return "目录"
        case .openApp:
            return "应用"
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

        // 获取当前 Finder 上下文
        let context = ExecutionContext(
            filePath: FinderService.shared.getFirstSelectedPath(),
            directory: FinderService.shared.getCurrentDirectory()
        )

        Task {
            do {
                let result = try await CommandExecutor.shared.execute(item, context: context)
                if result.success {
                    showNotification(title: item.name, message: result.output)
                }
            } catch {
                showNotification(title: "执行失败", message: error.localizedDescription)
            }
            isExecuting = false
        }
    }

    private func showNotification(title: String, message: String) {
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
