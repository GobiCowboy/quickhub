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
    @FocusState private var isSearching: Bool
    @State private var showSuccessToast = false
    @StateObject private var configObserver = ConfigObserver.shared

    var body: some View {
        VStack(spacing: 0) {
            // 搜索输入（呼出直接输入）
            TextField("快速搜索命令...", text: $searchText)
                .textFieldStyle(.plain)
                .font(.system(size: 13))
                .padding(.horizontal, 14)
                .padding(.top, 12)
                .padding(.bottom, 8)
                .focused($isSearching)
                .onSubmit {
                    executeFirstItem()
                }

            Divider()
                .padding(.horizontal, 8)

            // 命令列表
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 3) {
                    ForEach(filteredGroups) { group in
                        if !group.items.isEmpty {
                            GroupSectionView(
                                group: group,
                                searchText: searchText,
                                hoveredGroupId: $hoveredGroupId,
                                hoveredItemIndex: $hoveredItemIndex,
                                onClose: onClose
                            )
                            
                            if group.id != filteredGroups.last?.id {
                                Divider()
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 3)
                            }
                        }
                    }

                    // 空状态
                    if filteredGroups.isEmpty {
                        VStack(spacing: 6) {
                            Text("暂无命令")
                                .font(.system(size: 12))
                                .foregroundColor(.secondary)
                            Text("请在下方打开设置添加")
                                .font(.system(size: 10))
                                .foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.top, 16)
                        .padding(.bottom, 8)
                    }
                }
                .padding(.vertical, 6)
            }
            
            Divider()
            
            // 底部设置栏
            HStack {
                Spacer()
                Button(action: { openSettings() }) {
                    Label("设置...", systemImage: "gear")
                        .font(.system(size: 12))
                        .foregroundColor(.primary)
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 14)
                .padding(.vertical, 6)
                .contentShape(Rectangle())
                .onHover { isHovered in
                    if isHovered {
                        NSCursor.pointingHand.set()
                    } else {
                        NSCursor.arrow.set()
                    }
                }
            }
            .padding(.bottom, 2)
        }
        .frame(width: 240, height: 350) // 收敛固定尺寸以符合更细的间距
        .background(VisualEffectBackground()) // 采用系统级高斯模糊外观
        .cornerRadius(8)
        .onAppear {
            configObserver.refresh()
            isSearching = true
        }
    }

    private func executeFirstItem() {
        guard let firstItem = filteredGroups.first?.items.first(where: { it in
            it.enabled && (searchText.isEmpty || it.name.localizedCaseInsensitiveContains(searchText))
        }) else { return }
        
        let paths = (NSApp.delegate as? AppDelegate)?.getSavedFinderSelection() ?? []
        let context = ExecutionContext(
            filePath: paths.first?.path,
            directory: paths.first?.deletingLastPathComponent().path ?? FileManager.default.homeDirectoryForCurrentUser.path
        )
        
        Task {
            do {
                _ = try await CommandExecutor.shared.execute(firstItem, context: context)
                onClose?()
            } catch {
                print("[PopoverView] 快速执行失败: \(error)")
            }
        }
    }

    private var filteredGroups: [CommandGroup] {
        let enabledGroups = configObserver.config.groups.filter { $0.enabled }

        if searchText.isEmpty {
            return enabledGroups
        }

        let results = enabledGroups.map { group in
            var filteredGroup = group
            filteredGroup.items = group.items.filter { item in
                item.enabled && PinyinMatcher.match(item.name, query: searchText)
            }
            return filteredGroup
        }.filter { !$0.items.isEmpty }
        
        if !searchText.isEmpty {
            let totalCount = results.reduce(0) { $0 + $1.items.count }
            print("[PopoverView] Search: '\(searchText)', Results Groups: \(results.count), Items: \(totalCount)")
        }
        
        return results
    }

    private func openSettings() {
        onClose?()
        if let appDelegate = NSApp.delegate as? AppDelegate {
            appDelegate.openSettings()
        }
    }
}

// 供实现系统菜单模糊背景
struct VisualEffectBackground: NSViewRepresentable {
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = .popover // 使用 popover 可以获得更明亮清透的系统底色
        view.blendingMode = .behindWindow
        view.state = .active
        return view
    }
    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = .popover
    }
}

#Preview {
    PopoverView(onClose: {})
}
