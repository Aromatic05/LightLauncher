import SwiftUI

struct StandardSettingsPage<Content: View>: View {
    let title: String
    let subtitle: String
    var contentSpacing: CGFloat
    @ViewBuilder let content: Content

    init(
        title: String,
        subtitle: String,
        contentSpacing: CGFloat = 32,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.subtitle = subtitle
        self.contentSpacing = contentSpacing
        self.content = content()
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: contentSpacing) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(title)
                        .font(.title)
                        .fontWeight(.bold)
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                content
                Spacer(minLength: 0)
            }
            .padding(32)
        }
    }
}

struct StandardSettingsSection<Content: View>: View {
    let title: String
    var icon: String?
    var iconColor: Color
    var count: Int?
    var countLabel: String
    var spacing: CGFloat
    @ViewBuilder let content: Content

    init(
        title: String,
        icon: String? = nil,
        iconColor: Color = .blue,
        count: Int? = nil,
        countLabel: String = "",
        spacing: CGFloat = 16,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.icon = icon
        self.iconColor = iconColor
        self.count = count
        self.countLabel = countLabel
        self.spacing = spacing
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: spacing) {
            HStack(alignment: .center, spacing: 12) {
                HStack(spacing: 8) {
                    if let icon = icon {
                        Image(systemName: icon)
                            .foregroundColor(iconColor)
                    }
                    Text(title)
                        .font(.title2)
                        .fontWeight(.semibold)
                }

                if let count = count {
                    Text("\(count) \(countLabel)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            content
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

struct Badge: View {
    let text: String
    let color: Color

    var body: some View {
        Text(text)
            .font(.caption)
            .padding(.horizontal, 8)
            .padding(.vertical, 2)
            .background(color.opacity(0.2))
            .foregroundColor(color)
            .cornerRadius(4)
    }
}

struct LabeledTextField: View {
    let label: String
    let placeholder: String
    @Binding var text: String
    var textCase: Text.Case? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.subheadline)
                .fontWeight(.medium)
            TextField(placeholder, text: $text)
                .textFieldStyle(.roundedBorder)
                .textCase(textCase)
        }
    }
}

struct EditSheetHeader: View {
    let title: String
    let isValid: Bool
    let onSave: () -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        HStack {
            Text(title)
                .font(.title2)
                .fontWeight(.semibold)

            Spacer()

            Button("取消") {
                dismiss()
            }
            .buttonStyle(.bordered)

            Button("保存", action: onSave)
                .disabled(!isValid)
                .buttonStyle(.borderedProminent)
        }
        .padding(20)
    }
}

struct SettingsCard<Content: View>: View {
    let title: String?
    var contentSpacing: CGFloat
    @ViewBuilder let content: Content

    init(title: String? = nil, contentSpacing: CGFloat = 16, @ViewBuilder content: () -> Content) {
        self.title = title
        self.contentSpacing = contentSpacing
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: contentSpacing) {
            if let title = title {
                Text(title)
                    .font(.headline)
                    .fontWeight(.semibold)
            }
            content
        }
        .padding(20)
        .settingsCard(opacity: 1.0)
    }
}

struct EmptyStatePlaceholder: View {
    let icon: String
    let title: String
    var description: String? = nil
    var actionTitle: String? = nil
    var action: (() -> Void)? = nil

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 40))
                .foregroundColor(.secondary)
            Text(title)
                .font(.headline)
                .foregroundColor(.secondary)
            if let description = description {
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            if let actionTitle = actionTitle, let action = action {
                Button(actionTitle, action: action)
                    .buttonStyle(.borderedProminent)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }
}

struct KeyValueRow: View {
    let key: String
    let value: String

    var body: some View {
        HStack {
            Text(key)
                .font(.system(.body, design: .monospaced))
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .font(.system(.body, design: .monospaced))
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color(NSColor.controlBackgroundColor))
                .cornerRadius(4)
        }
        .padding(.vertical, 2)
    }
}

struct AddButton: View {
    let title: String
    let systemImage: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: systemImage)
                Text(title)
            }
        }
        .buttonStyle(.borderedProminent)
    }
}

struct SidebarActionButton: View {
    let title: String
    let systemImage: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: systemImage)
                    .frame(width: 12)
                Text(title)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .font(.caption)
        .buttonStyle(.bordered)
        .controlSize(.small)
    }
}
