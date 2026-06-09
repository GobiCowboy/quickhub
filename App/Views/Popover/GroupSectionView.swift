import SwiftUI

// MARK: - 分组视图

struct GroupSectionView: View {
    let group: CommandGroup
    let searchText: String
    @Binding var hoveredGroupId: UUID?
    @Binding var hoveredItemIndex: Int?
    var onClose: (() -> Void)?

    var body: some View {
        let visibleItems = group.items.filter { item in
            item.enabled && (searchText.isEmpty || PinyinMatcher.match(item.name, query: searchText))
        }

        if !visibleItems.isEmpty {
            VStack(alignment: .leading, spacing: 0) {
                if !group.name.isEmpty {
                    Text(groupName)
                        .font(.system(size: 8.5, weight: .semibold))
                        .foregroundColor(.secondary.opacity(0.75))
                        .padding(.horizontal, 12)
                        .padding(.top, 5)
                        .padding(.bottom, 2)
                }

                VStack(spacing: 0) {
                    ForEach(Array(visibleItems.enumerated()), id: \.element.id) { index, item in
                        CommandItemRow(
                            item: item,
                            isHovered: hoveredGroupId == group.id && hoveredItemIndex == index,
                            onHover: { isHovered in
                                if isHovered {
                                    hoveredGroupId = group.id
                                    hoveredItemIndex = index
                                } else if hoveredGroupId == group.id && hoveredItemIndex == index {
                                    hoveredGroupId = nil
                                    hoveredItemIndex = nil
                                }
                            },
                            onClose: onClose
                        )
                    }
                }
                .padding(.horizontal, 3)
            }
        }
    }

    /// 本地化的组名
    private var groupName: String {
        DefaultGroupNameMapping.localizedGroupName(group.name)
    }
}
