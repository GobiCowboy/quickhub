import SwiftUI

struct MenuSortSettingsView: View {
    @Binding var config: AppConfig

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            SettingsPageHeader(
                title: localized("menu_sort.title"),
                subtitle: localized("menu_sort.desc"),
                icon: "list.bullet"
            )

            SettingsSurface(title: localized("settings.category.menu_sort"), systemImage: "arrow.up.arrow.down") {
                List {
                    ForEach(config.groups) { group in
                        HStack(spacing: 11) {
                            Image(systemName: "line.3.horizontal")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(.secondary)

                            ZStack {
                                RoundedRectangle(cornerRadius: 7, style: .continuous)
                                    .fill(Color.accentColor.opacity(0.16))

                                Image(systemName: group.icon)
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundColor(.accentColor)
                            }
                            .frame(width: 26, height: 26)

                            Text(DefaultGroupNameMapping.localizedGroupName(group.name))
                                .font(.system(size: 13, weight: .medium))

                            Spacer()
                        }
                        .padding(.vertical, 5)
                        .listRowBackground(Color.clear)
                    }
                    .onMove { source, destination in
                        config.groups.move(fromOffsets: source, toOffset: destination)
                        StorageService.shared.saveConfig(config)
                        ConfigObserver.shared.refresh()
                    }
                }
                .listStyle(.inset)
                .scrollContentBackground(.hidden)
                .frame(minHeight: 260)
            }

            Spacer()
        }
        .padding(22)
    }
}
