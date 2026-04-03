import SwiftUI

struct MenuSortSettingsView: View {
    @Binding var config: AppConfig

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(localized("menu_sort.title"))
                .font(.title2)
                .fontWeight(.semibold)

            Text(localized("menu_sort.desc"))
                .font(.subheadline)
                .foregroundColor(.secondary)

            Divider()

            List {
                ForEach(config.groups) { group in
                    HStack {
                        Image(systemName: "line.3.horizontal")
                            .foregroundColor(.secondary)
                            .padding(.trailing, 8)

                        Image(systemName: group.icon)
                            .foregroundColor(.accentColor)
                            .frame(width: 24, alignment: .center)

                        Text(DefaultGroupNameMapping.localizedGroupName(group.name))
                            .font(.body)

                        Spacer()
                    }
                    .padding(.vertical, 4)
                }
                .onMove { source, destination in
                    config.groups.move(fromOffsets: source, toOffset: destination)
                    StorageService.shared.saveConfig(config)
                    ConfigObserver.shared.refresh()
                }
            }
            .listStyle(.inset)
            .background(Color(nsColor: .controlBackgroundColor))
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color(nsColor: .separatorColor), lineWidth: 1)
            )

            Spacer()
        }
        .padding(20)
    }
}
