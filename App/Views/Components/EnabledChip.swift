import SwiftUI

// MARK: - 通用 Chip 组件

struct EnabledChip: View {
    let icon: String
    let name: String
    var onEdit: () -> Void
    var onDelete: () -> Void

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.caption)

            Text(name)
                .font(.caption)
                .lineLimit(1)

            Button(action: onEdit) {
                Image(systemName: "pencil")
                    .font(.caption2)
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
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Color.accentColor.opacity(0.15))
        .cornerRadius(16)
    }
}

// MARK: - 可添加 Chip 组件

struct AddableChip: View {
    let icon: String
    let name: String
    var onAdd: () -> Void

    var body: some View {
        Button(action: onAdd) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.caption)

                Text(name)
                    .font(.caption)
                    .lineLimit(1)

                Image(systemName: "plus")
                    .font(.caption2)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Color.secondary.opacity(0.1))
            .cornerRadius(16)
        }
        .buttonStyle(.plain)
        .foregroundColor(.primary)
    }
}
