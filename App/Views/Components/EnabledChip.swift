import SwiftUI

enum CommandVisualStyle {
    static func tint(for item: CommandItem) -> Color {
        switch item.type {
        case .createFile:
            return Color(red: 0.20, green: 0.48, blue: 0.95)
        case .createFolder, .openFinder, .copyPath:
            return Color(red: 0.16, green: 0.62, blue: 0.36)
        case .openApp:
            return Color(red: 0.42, green: 0.34, blue: 0.92)
        case .shell:
            if item.command == InternalShellCommand.fileInfo || item.command?.contains("/usr/local/bin/getinfo") == true {
                return Color(red: 0.95, green: 0.48, blue: 0.18)
            }
            return Color(red: 0.08, green: 0.58, blue: 0.70)
        case .bitwardenSearch:
            return Color(red: 0.82, green: 0.22, blue: 0.38)
        case .moveToTrash:
            return Color(red: 0.75, green: 0.25, blue: 0.25)
        case .rename:
            return Color(red: 0.95, green: 0.58, blue: 0.12)
        case .cutFile, .copyFile, .pasteFile:
            return Color(red: 0.20, green: 0.60, blue: 0.85)
        case .openWith:
            return Color(red: 0.50, green: 0.40, blue: 0.85)
        case .shareFile:
            return Color(red: 0.10, green: 0.65, blue: 0.50)
        }
    }

    static func label(for item: CommandItem) -> String {
        if item.command == InternalShellCommand.fileInfo || item.command?.contains("/usr/local/bin/getinfo") == true {
            return localized("command_type.file_info")
        }

        switch item.type {
        case .shell:
            return localized("command_type.shell")
        case .copyPath:
            return localized("command_type.copy_path")
        case .createFile:
            return localized("command_type.create_file")
        case .createFolder:
            return localized("command_type.create_folder")
        case .openFinder:
            return localized("command_type.open_finder")
        case .openApp:
            return localized("command_type.open_app")
        case .bitwardenSearch:
            return localized("command_type.bitwarden")
        case .moveToTrash:
            return localized("command_type.move_to_trash")
        case .rename:
            return localized("command_type.rename")
        case .cutFile:
            return localized("command_type.cut_file")
        case .copyFile:
            return localized("command_type.copy_file")
        case .pasteFile:
            return localized("command_type.paste_file")
        case .openWith:
            return localized("command_type.open_with")
        case .shareFile:
            return localized("command_type.share_file")
        }
    }

    static func hint(for item: CommandItem) -> String {
        if item.command == InternalShellCommand.fileInfo || item.command?.contains("/usr/local/bin/getinfo") == true {
            return localized("command_type.file_info")
        }

        if let command = item.command, !command.isEmpty {
            return command
        }

        if let path = item.targetPath, !path.isEmpty {
            return path
        }

        return label(for: item)
    }
}

struct CommandIconChip: View {
    let item: CommandItem
    var isSelected = false
    var size: CGFloat = 24

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.28, style: .continuous)
                .fill(CommandVisualStyle.tint(for: item).gradient)

            icon
                .font(.system(size: size * 0.52, weight: .semibold))
                .foregroundStyle(.white)
                .symbolRenderingMode(.hierarchical)
        }
        .frame(width: size, height: size)
        .shadow(color: CommandVisualStyle.tint(for: item).opacity(isSelected ? 0.45 : 0.18), radius: isSelected ? 6 : 2, y: isSelected ? 3 : 1)
    }

    @ViewBuilder
    private var icon: some View {
        if item.icon.hasPrefix("/"), let image = NSImage(contentsOfFile: item.icon) {
            Image(nsImage: image)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: size * 0.66, height: size * 0.66)
        } else {
            Image(systemName: item.icon.isEmpty ? "command" : item.icon)
        }
    }
}

// MARK: - 通用 Chip 组件

struct EnabledChip: View {
    let icon: String
    let name: String
    var item: CommandItem? = nil
    var onEdit: () -> Void
    var onDelete: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            if let item {
                CommandIconChip(item: item, size: 22)
            } else {
                Image(systemName: icon)
                    .font(.caption)
                    .frame(width: 22, height: 22)
                    .background(
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(Color.accentColor.opacity(0.18))
                    )
            }

            Text(name)
                .font(.caption)
                .lineLimit(1)

            Button(action: onEdit) {
                Image(systemName: "square.and.pencil")
                    .font(.system(size: 11, weight: .semibold))
                    .frame(width: 20, height: 20)
                    .background(
                        RoundedRectangle(cornerRadius: 5, style: .continuous)
                            .fill(Color.primary.opacity(0.055))
                    )
            }
            .buttonStyle(.plain)
            .foregroundColor(.secondary)

            Button(action: onDelete) {
                Image(systemName: "xmark")
                    .font(.caption2)
            }
            .buttonStyle(.plain)
            .foregroundColor(.red.opacity(0.7))
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(.thinMaterial)
                .overlay(Color.primary.opacity(0.035))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(Color.white.opacity(0.14), lineWidth: 1)
        )
    }
}

// MARK: - 可添加 Chip 组件

struct AddableChip: View {
    let icon: String
    let name: String
    var item: CommandItem? = nil
    var onAdd: () -> Void

    var body: some View {
        Button(action: onAdd) {
            HStack(spacing: 8) {
                if let item {
                    CommandIconChip(item: item, size: 22)
                } else {
                    Image(systemName: icon)
                        .font(.caption)
                        .frame(width: 22, height: 22)
                        .background(
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .fill(Color.secondary.opacity(0.12))
                        )
                }

                Text(name)
                    .font(.caption)
                    .lineLimit(1)

                Image(systemName: "plus")
                    .font(.caption2)
            }
            .padding(.horizontal, 9)
            .padding(.vertical, 6)
            .background(.thinMaterial)
            .background(Color.primary.opacity(0.035))
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(Color.white.opacity(0.16), lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
        .buttonStyle(.plain)
        .foregroundColor(.primary)
    }
}
