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
            Text(localized("bitwarden.title"))
                .font(.title2)
                .fontWeight(.semibold)

            Text(localized("bitwarden.desc"))
                .font(.subheadline)
                .foregroundColor(.secondary)

            Divider()

            // 已启用
            if !bitwardenItems.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Label(localized("common.enabled"), systemImage: "checkmark.circle.fill")
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
            Text(localized("bitwarden.add_title"))
                .font(.headline)

            HStack {
                Button(action: addBitwardenItem) {
                    Label(localized("bitwarden.add_button"), systemImage: "plus.circle.fill")
                }
                .buttonStyle(.borderedProminent)
                .disabled(hasBitwardenItem)

                Spacer()
            }

            Text(localized("bitwarden.tip"))
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
