import SwiftUI

// MARK: - Bitwarden 设置视图

struct BitwardenSettingsView: View {
    @Binding var config: AppConfig
    var onEdit: (EditableItem) -> Void

    private var bitwardenItems: [CommandItem] {
        config.groups
            .filter { $0.name == "密码管理" }
            .flatMap { $0.items }
            .filter { $0.type == .bitwardenSearch }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("密码管理")
                .font(.title2)
                .fontWeight(.semibold)

            Text("在右键菜单中显示 Bitwarden 密码搜索功能")
                .font(.subheadline)
                .foregroundColor(.secondary)

            Divider()

            // 已启用
            if !bitwardenItems.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Label("已启用", systemImage: "checkmark.circle.fill")
                        .font(.headline)
                        .foregroundColor(.green)

                    FlowLayout(spacing: 8) {
                        ForEach(bitwardenItems) { item in
                            EnabledChip(
                                icon: item.icon.isEmpty ? "key.fill" : item.icon,
                                name: item.name,
                                onEdit: { onEdit(.bitwardenSearch(item)) },
                                onDelete: { deleteCommand(item) }
                            )
                        }
                    }
                }

                Divider()
            }

            // 添加按钮
            Text("添加 Bitwarden 搜索")
                .font(.headline)

            HStack {
                Button(action: addBitwardenItem) {
                    Label("搜索 Bitwarden 密码", systemImage: "plus.circle.fill")
                }
                .buttonStyle(.borderedProminent)
                .disabled(hasBitwardenItem)

                Spacer()
            }

            Text("使用 Bitwarden CLI (bw) 搜索保险库中的密码")
                .font(.caption)
                .foregroundColor(.secondary)

            Spacer()
        }
        .padding(20)
    }

    private var hasBitwardenItem: Bool {
        bitwardenItems.count > 0
    }

    private func addBitwardenItem() {
        ensureGroup(name: "密码管理", icon: "key.fill")
        if let groupIndex = config.groups.firstIndex(where: { $0.name == "密码管理" }) {
            let newItem = CommandItem(
                name: "搜索 Bitwarden 密码",
                icon: "key.fill",
                type: .bitwardenSearch
            )
            config.groups[groupIndex].items.append(newItem)
            StorageService.shared.saveConfig(config)
            ConfigObserver.shared.refresh()
        }
    }

    private func deleteCommand(_ item: CommandItem) {
        if let groupIndex = config.groups.firstIndex(where: { $0.name == "密码管理" }) {
            config.groups[groupIndex].items.removeAll { $0.id == item.id }
            StorageService.shared.saveConfig(config)
            ConfigObserver.shared.refresh()
        }
    }

    private func ensureGroup(name: String, icon: String) {
        if !config.groups.contains(where: { $0.name == name }) {
            config.groups.append(CommandGroup(name: name, icon: icon))
        }
    }
}
