import SwiftUI

// MARK: - 图标选择器

struct IconPickerSheet: View {
    @Binding var selectedIcon: String
    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""

    private let commonIcons = [
        "doc", "doc.text", "doc.fill", "doc.richtext", "doc.richtext.fill",
        "folder", "folder.fill",
        "terminal", "terminal.fill",
        "app", "app.fill",
        "gear", "gearshape", "gearshape.fill",
        "swift", "p.square", "p.square.fill",
        "curlybraces", "curlybraces.square",
        "globe", "safari", "chrome",
        "desktopcomputer", "iphone", "ipad",
        "photo", "photo.fill", "picture",
        "music.note", "music.note.list",
        "film", "film.fill", "video",
        "play.rectangle.fill", "play.circle", "play.circle.fill",
        "tablecells", "tablecells.fill",
        "chart.bar", "chart.pie", "chart.line.uptrend.xyaxis",
        "paintbrush", "paintbrush.fill", "paintpalette",
        "pencil", "pencil.and.outline", "square.and.pencil",
        "shippingbox", "shippingbox.fill",
        "cube.box", "cube.box.fill",
        "arrow.down.circle", "arrow.down.circle.fill",
        "arrow.up.circle", "arrow.up.circle.fill",
        "arrow.triangle.branch", "arrow.triangle.merge",
        "text.alignleft", "text.aligncenter", "text.alignright",
        "link", "link.circle", "link.circle.fill",
        "command", "command.circle", "command.circle.fill",
        "plus", "plus.circle", "plus.circle.fill",
        "minus", "minus.circle", "minus.circle.fill",
        "xmark", "xmark.circle", "xmark.circle.fill",
        "checkmark", "checkmark.circle", "checkmark.circle.fill",
        "star", "star.fill", "star.circle", "star.circle.fill",
        "heart", "heart.fill", "heart.circle", "heart.circle.fill",
        "flag", "flag.fill", "flag.circle", "flag.circle.fill",
        "bookmark", "bookmark.fill", "bookmark.circle", "bookmark.circle.fill",
        "trash", "trash.fill", "trash.circle", "trash.circle.fill",
        "pen", "pencil", "pencil.tip", "square.and.pencil",
        "magnifyingglass", "magnifyingglass.circle",
        "folder.badge.plus", "folder.fill.badge.plus",
        "doc.badge.plus", "doc.fill.badge.plus",
        "plus.square.dashed", "plus.square.dashed.fill",
        "chevron.left", "chevron.right", "chevron.up", "chevron.down"
    ]

    private var filteredIcons: [String] {
        if searchText.isEmpty {
            return commonIcons
        }
        return commonIcons.filter { $0.localizedCaseInsensitiveContains(searchText) }
    }

    var body: some View {
        VStack(spacing: 0) {
            // 标题栏
            HStack {
                Text(localized("icon_picker.title"))
                    .font(.headline)
                Spacer()
                Button(action: { dismiss() }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding()
            .background(Color(nsColor: .controlBackgroundColor))

            Divider()

            // 搜索框
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                TextField(localized("icon_picker.search_placeholder"), text: $searchText)
                    .textFieldStyle(.plain)
                if !searchText.isEmpty {
                    Button(action: { searchText = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(10)
            .background(Color(nsColor: .textBackgroundColor))

            Divider()

            // 图标网格
            ScrollView {
                LazyVGrid(columns: [
                    GridItem(.adaptive(minimum: 60), spacing: 12)
                ], spacing: 12) {
                    ForEach(filteredIcons, id: \.self) { iconName in
                        Button(action: {
                            selectedIcon = iconName
                            dismiss()
                        }) {
                            VStack(spacing: 4) {
                                Image(systemName: iconName)
                                    .font(.title2)
                                    .frame(width: 36, height: 36)
                                    .background(
                                        RoundedRectangle(cornerRadius: 6)
                                            .fill(selectedIcon == iconName ? Color.accentColor.opacity(0.2) : Color.clear)
                                    )
                                Text(iconName)
                                    .font(.caption2)
                                    .lineLimit(1)
                                    .foregroundColor(.secondary)
                            }
                            .frame(width: 60, height: 60)
                        }
                        .buttonStyle(.plain)
                        .help(iconName)
                    }
                }
                .padding()
            }
        }
        .frame(width: 400, height: 450)
    }
}
