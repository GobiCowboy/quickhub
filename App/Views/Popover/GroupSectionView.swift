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
            if !group.name.isEmpty {
                Text(groupName)
                    .font(.system(size: 9, weight: .semibold))
                    .textCase(.uppercase)
                    .foregroundColor(.secondary.opacity(0.78))
                    .padding(.horizontal, 12)
                    .padding(.top, 5)
                    .padding(.bottom, 2)
            }

            VStack(spacing: 0) {
                ForEach(Array(group.items.filter { $0.enabled }.enumerated()), id: \.element.id) { index, item in
                    if searchText.isEmpty || PinyinMatcher.match(item.name, query: searchText) {
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
            .padding(.horizontal, 7)
        }
    }

    /// 本地化的组名
    private var groupName: String {
        DefaultGroupNameMapping.localizedGroupName(group.name)
    }
}
