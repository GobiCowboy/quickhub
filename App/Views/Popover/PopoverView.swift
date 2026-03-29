import SwiftUI
import AppKit
import UserNotifications

// MARK: - 配置观察器

class ConfigObserver: ObservableObject {
    static let shared = ConfigObserver()

    @Published var config: AppConfig

    private init() {
        self.config = StorageService.shared.loadConfig()
    }

    func refresh() {
        self.config = StorageService.shared.loadConfig()
    }
}

// MARK: - PopoverView

struct PopoverView: View {
    var onClose: (() -> Void)?

    @State private var searchText = ""
    @State private var selectedGroup: CommandGroup?
    @State private var hoveredGroupId: UUID?
    @State private var hoveredItemIndex: Int?
    @StateObject private var configObserver = ConfigObserver.shared

    var body: some View {
        VStack(spacing: 0) {
            // 顶部栏
            HStack {
                Text("RightClickX")
                    .font(.headline)
                Spacer()
                Button(action: { openSettings() }) {
                    Image(systemName: "gear")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                .help("设置")

                Button(action: { onClose?() }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                .help("关闭")
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(Color(nsColor: .controlBackgroundColor))

            Divider()

            // 搜索框
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                TextField("搜索命令...", text: $searchText)
                    .textFieldStyle(.plain)
                if !searchText.isEmpty {
                    Button(action: { searchText = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(12)
            .background(Color(nsColor: .textBackgroundColor))

            Divider()

            // 命令列表
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 8) {
                    ForEach(filteredGroups) { group in
                        if !group.items.isEmpty {
                            GroupSectionView(
                                group: group,
                                searchText: searchText,
                                hoveredGroupId: $hoveredGroupId,
                                hoveredItemIndex: $hoveredItemIndex,
                                onClose: onClose
                            )
                        }
                    }

                    // 空状态
                    if filteredGroups.isEmpty {
                        VStack(spacing: 12) {
                            Image(systemName: "command.circle")
                                .font(.system(size: 40))
                                .foregroundColor(.secondary)
                            Text("暂无命令")
                                .foregroundColor(.secondary)
                            Text("在设置中添加命令")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.top, 40)
                    }
                }
                .padding(12)
            }
        }
        .frame(width: 320, height: 450)
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private var filteredGroups: [CommandGroup] {
        let enabledGroups = configObserver.config.groups.filter { $0.enabled }

        if searchText.isEmpty {
            return enabledGroups
        }

        return enabledGroups.map { group in
            var filteredGroup = group
            filteredGroup.items = group.items.filter { item in
                item.name.localizedCaseInsensitiveContains(searchText)
            }
            return filteredGroup
        }.filter { !$0.items.isEmpty }
    }

    private func openSettings() {
        onClose?()
        if let appDelegate = NSApp.delegate as? AppDelegate {
            appDelegate.openSettings()
        }
    }
}

// MARK: - 分组视图

struct GroupSectionView: View {
    let group: CommandGroup
    let searchText: String
    @Binding var hoveredGroupId: UUID?
    @Binding var hoveredItemIndex: Int?
    var onClose: (() -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            // 分组标题
            HStack {
                Image(systemName: group.icon)
                    .foregroundColor(.accentColor)
                    .frame(width: 20)
                Text(group.name)
                    .font(.headline)
                    .foregroundColor(.primary)
                Spacer()
                Text("\(group.items.filter { $0.enabled }.count)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(Color.secondary.opacity(0.15))
                    .cornerRadius(10)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(hoveredGroupId == group.id ? Color.accentColor.opacity(0.1) : Color.clear)
            )

            // 命令项
            VStack(spacing: 2) {
                ForEach(Array(group.items.filter { $0.enabled }.enumerated()), id: \.element.id) { index, item in
                    if searchText.isEmpty || item.name.localizedCaseInsensitiveContains(searchText) {
                        CommandItemRow(
                            item: item,
                            isHovered: hoveredGroupId == group.id && hoveredItemIndex == index,
                            onHover: { isHovered in
                                if isHovered {
                                    hoveredGroupId = group.id
                                    hoveredItemIndex = index
                                } else {
                                    if hoveredGroupId == group.id && hoveredItemIndex == index {
                                        hoveredGroupId = nil
                                        hoveredItemIndex = nil
                                    }
                                }
                            },
                            onClose: onClose
                        )
                    }
                }
            }
            .padding(.leading, 16)
        }
    }
}

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

#Preview {
    PopoverView(onClose: {})
}
