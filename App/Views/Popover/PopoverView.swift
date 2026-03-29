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

#Preview {
    PopoverView(onClose: {})
}
