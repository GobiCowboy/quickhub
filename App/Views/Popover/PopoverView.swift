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
        DispatchQueue.main.async {
            self.config = StorageService.shared.loadConfig()
        }
    }
}

// MARK: - PopoverView

struct PopoverView: View {
    var onClose: (() -> Void)?

    @State private var searchText = ""
    @State private var hoveredGroupId: UUID?
    @State private var hoveredItemIndex: Int?
    @FocusState private var isSearching: Bool
    @StateObject private var configObserver = ConfigObserver.shared

    // 面板过滤逻辑 - 使用计算属性（SwiftUI 标准推荐）
    private var filteredGroups: [CommandGroup] {
        let groups = configObserver.config.groups.filter { $0.enabled }
        if searchText.isEmpty { return groups }
        
        return groups.map { group in
            var filteredGroup = group
            filteredGroup.items = group.items.filter { item in
                item.enabled && PinyinMatcher.match(item.name, query: searchText)
            }
            return filteredGroup
        }.filter { !$0.items.isEmpty }
    }

    var body: some View {
        VStack(spacing: 0) {
            // 搜索输入
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
                    let groups = filteredGroups

                    if groups.isEmpty {
                        VStack(spacing: 6) {
                            Text("暂无匹配命令")
                                .font(.system(size: 12))
                                .foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.top, 20)
                    } else {
                        ForEach(groups) { group in
                            GroupSectionView(
                                group: group,
                                searchText: searchText,
                                hoveredGroupId: $hoveredGroupId,
                                hoveredItemIndex: $hoveredItemIndex,
                                onClose: onClose
                            )

                            if group.id != groups.last?.id {
                                Divider()
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 3)
                            }
                        }
                    }
                }
                .padding(.vertical, 6)
            }
            .scrollContentBackground(.hidden)
            
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
            }
            .padding(.bottom, 2)
        }
        .frame(width: 240, height: 400)
        .background(VisualEffectBackground())
        .cornerRadius(8)
        .onAppear {
            configObserver.refresh()
            // 确保窗口显示后搜索框立即激活，增加一个小延时防止由于 NSPanel 层级导致的焦点丢失
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                isSearching = true
            }
        }
    }

    private func executeFirstItem() {
        guard let firstItem = filteredGroups.first?.items.first else { return }
        
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
                print("[PopoverView] 快速执行失败")
            }
        }
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
        view.material = .popover
        view.blendingMode = .behindWindow
        view.state = .active
        return view
    }
    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {}
}
