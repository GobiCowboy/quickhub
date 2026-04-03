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

                Text(String(localized: "welcome.title"))
                    .font(.system(size: 24, weight: .bold))

                Text(String(localized: "welcome.subtitle"))
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            .padding(.top, 20)

            // 中间：核心三要素
            VStack(alignment: .leading, spacing: 20) {
                FeatureRow(
                    icon: "keyboard",
                    title: String(localized: "welcome.feature1.title"),
                    description: String(localized: "welcome.feature1.desc")
                )

                FeatureRow(
                    icon: "magnifyingglass",
                    title: String(localized: "welcome.feature2.title"),
                    description: String(localized: "welcome.feature2.desc")
                )

                FeatureRow(
                    icon: "slider.horizontal.3",
                    title: String(localized: "welcome.feature3.title"),
                    description: String(localized: "welcome.feature3.desc")
                )
            }
            .padding(.horizontal, 40)

            Spacer()

            // 底部：操作按钮
            Button(action: onFinished) {
                Text(String(localized: "welcome.button"))
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
