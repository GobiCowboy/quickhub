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
    let panelWidth: CGFloat
    let panelHeight: CGFloat
    let showsFooterActions: Bool
    var onClose: (() -> Void)?
    private let panelCornerRadius: CGFloat = 16

    @State private var searchText = ""
    @State private var hoveredGroupId: UUID?
    @State private var hoveredItemIndex: Int?
    @FocusState private var isSearching: Bool
    @StateObject private var configObserver = ConfigObserver.shared
    @State private var refreshTrigger = false  // 用于触发视图刷新

    // 面板过滤逻辑 - 使用计算属性（SwiftUI 标准推荐）
    private var filteredGroups: [CommandGroup] {
        let groups = configObserver.config.groups.filter { group in
            guard group.enabled else { return false }

            let visibleItems = visibleItems(in: group)
            return !visibleItems.isEmpty
        }

        if searchText.isEmpty { return groups }

        return groups.map { group in
            var filteredGroup = group
            filteredGroup.items = visibleItems(in: group)
            return filteredGroup
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)

                TextField(localized("popover.search_placeholder"), text: $searchText)
                    .textFieldStyle(.plain)
                    .font(.system(size: 12, weight: .regular))
                    .focused($isSearching)
                    .onSubmit {
                        executeFirstItem()
                    }

                if !searchText.isEmpty {
                    Button {
                        searchText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 13))
                            .foregroundStyle(.tertiary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 13)
            .padding(.vertical, 9)

            Divider()
                .opacity(0.42)

            // 命令列表
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    let groups = filteredGroups

                    if groups.isEmpty {
                        VStack(spacing: 6) {
                            Image(systemName: "magnifyingglass")
                                .font(.system(size: 20))
                                .foregroundColor(.secondary.opacity(0.7))

                            Text(localized("popover.no_results"))
                                .font(.system(size: 11.5))
                                .foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.top, 36)
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
                                    .padding(.horizontal, 11)
                                    .padding(.vertical, 2)
                            }
                        }
                    }
                }
                .padding(.vertical, 4)
                .padding(.horizontal, 3)
            }
            .scrollContentBackground(.hidden)

            if showsFooterActions {
                Divider()
                    .opacity(0.42)

                HStack(spacing: 6) {
                    Spacer()

                    footerButton(systemName: "gearshape", accessibilityLabel: localized("app.settings.title")) {
                        openSettings()
                    }

                    footerButton(systemName: "power", accessibilityLabel: localized("common.quit")) {
                        quitApp()
                    }
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 7)
            }
        }
        .frame(width: panelWidth, height: panelHeight)
        .background(VisualEffectBackground())
        .clipShape(RoundedRectangle(cornerRadius: panelCornerRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: panelCornerRadius, style: .continuous)
                .stroke(Color.primary.opacity(0.06), lineWidth: 1)
        )
        .onAppear {
            configObserver.refresh()
            // 确保窗口显示后搜索框立即激活，增加一个小延时防止由于 NSPanel 层级导致的焦点丢失
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                isSearching = true
            }
            // 监听语言切换
            NotificationCenter.default.addObserver(
                forName: .languageChanged,
                object: nil,
                queue: .main
            ) { [self] _ in
                refreshTrigger.toggle()
            }
        }
    }

    private func executeFirstItem() {
        guard let firstItem = filteredGroups.first?.items.first else { return }

        let paths = (NSApp.delegate as? AppDelegate)?.getSavedFinderSelection() ?? []
        let desktop = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Desktop").path

        let directory: String
        if !FinderService.shared.hasVisibleFinderWindow() {
            directory = desktop
        } else if let firstPath = paths.first {
            var isDir: ObjCBool = false
            if FileManager.default.fileExists(atPath: firstPath.path, isDirectory: &isDir) {
                directory = isDir.boolValue ? firstPath.path : firstPath.deletingLastPathComponent().path
            } else {
                directory = FinderService.shared.getCurrentDirectory()
            }
        } else {
            directory = FinderService.shared.getCurrentDirectory()
        }

        let context = ExecutionContext(
            filePath: paths.first?.path,
            directory: directory
        )

        Task {
            do {
                _ = try await CommandExecutor.shared.execute(firstItem, context: context)
                onClose?()
            } catch {
                print(localized("[PopoverView] popover.no_results"))
            }
        }
    }

    private func visibleItems(in group: CommandGroup) -> [CommandItem] {
        let matchedItems = group.items.filter { item in
            guard item.enabled else { return false }
            return searchText.isEmpty || PinyinMatcher.score(item: item, query: searchText) > 0
        }

        guard !searchText.isEmpty else { return matchedItems }

        return matchedItems.sorted { lhs, rhs in
            let lhsScore = PinyinMatcher.score(item: lhs, query: searchText)
            let rhsScore = PinyinMatcher.score(item: rhs, query: searchText)

            if lhsScore != rhsScore {
                return lhsScore > rhsScore
            }
            return DefaultItemNameMapping.localizedItemName(lhs.name) < DefaultItemNameMapping.localizedItemName(rhs.name)
        }
    }

    private func openSettings() {
        onClose?()
        if let appDelegate = NSApp.delegate as? AppDelegate {
            appDelegate.openSettings()
        }
    }

    private func quitApp() {
        onClose?()
        NSApplication.shared.terminate(nil)
    }

    private func footerButton(systemName: String, accessibilityLabel: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 11.5, weight: .medium))
                .foregroundStyle(.secondary)
                .frame(width: 22, height: 20)
                .background(
                    RoundedRectangle(cornerRadius: 5, style: .continuous)
                        .fill(Color.primary.opacity(0.04))
                )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(accessibilityLabel))
    }

}

// 供实现系统菜单模糊背景
struct VisualEffectBackground: NSViewRepresentable {
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = .menu
        view.blendingMode = .behindWindow
        view.state = .active
        return view
    }
    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {}
}
