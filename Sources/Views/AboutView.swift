import SwiftUI

struct AboutView: View {
    var body: some View {
        VStack(spacing: 18) {
            Image(nsImage: NSImage(named: "AppIcon") ?? NSImage())
                .resizable()
                .frame(width: 64, height: 64)
                .cornerRadius(12)
            Text("LightLauncher")
                .font(.title)
                .bold()
            Text("版本 1.0.0")
                .font(.subheadline)
                .foregroundColor(.secondary)
            Divider()
            Text("一个轻量级 macOS 启动器，快速启动应用、插件和搜索。\n© 2025 Aromatic05")
                .font(.footnote)
                .multilineTextAlignment(.center)
        }
        .padding(24)
        .frame(width: 360, height: 200)
    }
}
