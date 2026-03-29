import SwiftUI

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
