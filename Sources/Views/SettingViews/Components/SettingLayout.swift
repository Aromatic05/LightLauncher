import SwiftUI

struct PageHeader: View {
    let title: String
    let subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.title)
                .fontWeight(.bold)
            Text(subtitle)
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
    }
}

struct SectionHeader: View {
    let title: String
    var icon: String? = nil
    var iconColor: Color = .blue
    var count: Int? = nil
    var countLabel: String = ""

    var body: some View {
        HStack {
            if let icon = icon {
                Image(systemName: icon)
                    .foregroundColor(iconColor)
            }
            Text(title)
                .font(.title2)
                .fontWeight(.semibold)
            Spacer()
            if let count = count {
                Text("\(count) \(countLabel)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
}

struct SettingsPage<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 32) {
                content
                Spacer()
            }
            .padding(32)
        }
    }
}

extension View {
    func settingsCard(opacity: Double = 0.3, cornerRadius: CGFloat = 12) -> some View {
        self
            .background(Color(NSColor.controlBackgroundColor).opacity(opacity))
            .cornerRadius(cornerRadius)
    }
}

struct BulletList: View {
    let items: [String]
    var font: Font = .subheadline
    var color: Color = .secondary
    var spacing: CGFloat = 6

    var body: some View {
        VStack(alignment: .leading, spacing: spacing) {
            ForEach(items, id: \.self) { item in
                Text("• \(item)")
            }
        }
        .font(font)
        .foregroundColor(color)
    }
}

struct InfoCallout: View {
    let icon: String
    let iconColor: Color
    let text: String
    var textColor: Color? = nil

    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(iconColor)
            Text(text)
                .font(.caption)
                .foregroundColor(textColor ?? .secondary)
        }
    }
}
