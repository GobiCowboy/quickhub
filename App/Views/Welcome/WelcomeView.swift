import SwiftUI

struct WelcomeView: View {
    var onFinished: () -> Void
    
    var body: some View {
        VStack(spacing: 30) {
            // 顶部：图标与标题
            VStack(spacing: 12) {
                Image(systemName: "command.circle.fill")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 64, height: 64)
                    .foregroundColor(.accentColor)
                
                Text("欢迎使用 QuickHub")
                    .font(.system(size: 24, weight: .bold))
                
                Text("极简、极速的 macOS 超级工具箱")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            .padding(.top, 20)
            
            // 中间：核心三要素
            VStack(alignment: .leading, spacing: 20) {
                FeatureRow(
                    icon: "keyboard",
                    title: "快捷唤醒 (⌥⇧Q)",
                    description: "选中 Finder 文件，按住快捷键。面板会瞬时出现在鼠标位置，比右键菜单更快。"
                )
                
                FeatureRow(
                    icon: "magnifyingglass",
                    title: "呼出即搜索",
                    description: "面板弹出后直接打字（如输入 'T'），然后按回车。全程无需挪动鼠标。"
                )
                
                FeatureRow(
                    icon: "slider.horizontal.3",
                    title: "自由定制",
                    description: "在设置 ⚙️ 中，你可以定义 Shell 脚本、文件模板、并随时更换你喜欢的快捷键。"
                )
            }
            .padding(.horizontal, 40)
            
            Spacer()
            
            // 底部：操作按钮
            Button(action: onFinished) {
                Text("我已掌握，开始使用")
                    .fontWeight(.medium)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
            }
            .buttonStyle(.borderedProminent)
            .padding(.horizontal, 40)
            .padding(.bottom, 30)
            .keyboardShortcut(.defaultAction)
        }
        .frame(width: 480, height: 520)
    }
}

struct FeatureRow: View {
    let icon: String
    let title: String
    let description: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 15) {
            Image(systemName: icon)
                .font(.system(size: 24))
                .foregroundColor(.accentColor)
                .frame(width: 32)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                Text(description)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

#Preview {
    WelcomeView(onFinished: {})
}
