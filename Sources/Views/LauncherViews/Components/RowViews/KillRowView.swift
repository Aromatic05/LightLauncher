import SwiftUI

struct RunningAppRowView: View {
    let app: RunningAppInfo
    let isSelected: Bool
    let index: Int

    var body: some View {
        NumberedIconRow(
            index: index,
            icon: app.icon,
            fallbackIconName: "app",
            fallbackGradient: [Color.gray.opacity(0.3), Color.gray.opacity(0.2)],
            title: app.name,
            subtitle: app.isHidden ? "已隐藏" : "运行中",
            subtitleColor: app.isHidden ? .orange : .green,
            isSelected: isSelected,
            selectedGradient: [Color.red, Color.red.opacity(0.8)]
        ) {
            if isSelected {
                HStack(spacing: 4) {
                    Image(systemName: "xmark")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.white.opacity(0.8))
                    Text(ModeRegistry.shared[KillModeController.self]?.forceKillEnabled == true ? "强制结束" : "结束")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.white.opacity(0.8))
                }
            }
        }
    }
}
