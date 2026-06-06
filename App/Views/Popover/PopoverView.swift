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
    @State private var refreshTrigger = false  // 用于触发视图刷新

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
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.secondary)

                TextField(localized("popover.search_placeholder"), text: $searchText)
                    .textFieldStyle(.plain)
                    .font(.system(size: 13, weight: .regular))
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
            .padding(.horizontal, 11)
            .padding(.vertical, 9)
            .background(Color.primary.opacity(0.018))

            Divider()
                .opacity(0.65)

            // 命令列表
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 3) {
                    let groups = filteredGroups

                    if groups.isEmpty {
                        VStack(spacing: 8) {
                            Image(systemName: "magnifyingglass")
                                .font(.system(size: 22))
                                .foregroundColor(.secondary.opacity(0.7))

                            Text(localized("popover.no_results"))
                                .font(.system(size: 13))
                                .foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.top, 44)
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
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 3)
                            }
                        }
                    }
                }
                .padding(.vertical, 6)
            }
            .scrollContentBackground(.hidden)

            Divider()
                .opacity(0.65)

            HStack {
                Text("QuickHub")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.secondary)

                Spacer()

                footerButton(systemName: "gearshape", action: openSettings)
                footerButton(systemName: "power", action: quitApp)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
        }
        .frame(width: 292, height: 390)
        .background(VisualEffectBackground())
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color.white.opacity(0.07), lineWidth: 1)
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
        let context = ExecutionContext(
            filePath: paths.first?.path,
            directory: paths.first?.deletingLastPathComponent().path ?? FileManager.default.homeDirectoryForCurrentUser.path
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

    private func footerButton(systemName: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.secondary)
                .frame(width: 24, height: 22)
                .background(
                    RoundedRectangle(cornerRadius: 5, style: .continuous)
                        .fill(Color.primary.opacity(0.035))
                )
        }
        .buttonStyle(.plain)
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
