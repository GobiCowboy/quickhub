import SwiftUI

// MARK: - 分组视图

struct GroupSectionView: View {
    let group: CommandGroup
    let searchText: String
    @Binding var hoveredGroupId: UUID?
    @Binding var hoveredItemIndex: Int?
    var onClose: (() -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            // 分组标题（原生的段落标题通常非常低调）
            if !group.name.isEmpty {
                Text(group.name)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 14)
                    .padding(.top, 3)
                    .padding(.bottom, 3)
            }

            // 命令项
            VStack(spacing: 0) {
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
            .padding(.horizontal, 6)
        }
    }
}
