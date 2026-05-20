import SwiftUI

enum SettingsTab: String, CaseIterable, Identifiable {
    case general
    case engine
    case shortcuts
    case reader

    var id: String { rawValue }

    var title: String {
        switch self {
        case .general:
            return "通用"
        case .engine:
            return "引擎"
        case .shortcuts:
            return "快捷键"
        case .reader:
            return "阅读器"
        }
    }

    var symbol: String {
        switch self {
        case .general:
            return "line.3.horizontal"
        case .engine:
            return "sparkles"
        case .shortcuts:
            return "keyboard"
        case .reader:
            return "book.pages"
        }
    }
}

struct SettingsSection<Content: View>: View {
    let title: String
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if !title.isEmpty {
                Text(title)
                    .font(LexiFont.sans(10.5))
                    .fontWeight(.semibold)
                    .foregroundStyle(Color.lexiInk3)
                    .tracking(1)
                    .padding(.horizontal, 16)
            }

            VStack(spacing: 0) {
                content
            }
            .background(Color.lexiRaised)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(Color.lexiRule, lineWidth: 1)
            }
        }
        .padding(.bottom, 18)
    }
}

struct SettingsRow<Control: View>: View {
    let label: String
    var hint: String?
    var isLast = false
    @ViewBuilder var control: Control

    var body: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(LexiFont.zh(12.5))
                    .foregroundStyle(Color.lexiInk)
                if let hint {
                    Text(hint)
                        .font(LexiFont.zh(11))
                        .lineSpacing(5)
                        .foregroundStyle(Color.lexiInk3)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            control
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .frame(minHeight: 40)
        .overlay(alignment: .bottom) {
            if !isLast {
                Rectangle()
                    .fill(Color.lexiRule)
                    .frame(height: 1)
            }
        }
    }
}

struct SettingsSelect: View {
    @Binding var value: String
    let options: [(String, String)]

    var body: some View {
        Picker("", selection: $value) {
            ForEach(options, id: \.0) { option in
                Text(option.1).tag(option.0)
            }
        }
        .labelsHidden()
        .frame(width: 180)
    }
}

struct SettingsSegmented: View {
    @Binding var value: String
    let options: [(String, String)]

    var body: some View {
        Picker("", selection: $value) {
            ForEach(options, id: \.0) { option in
                Text(option.1).tag(option.0)
            }
        }
        .pickerStyle(.segmented)
        .labelsHidden()
        .frame(width: CGFloat(max(140, options.count * 64)))
    }
}

struct SettingsToast: View {
    let text: String?

    var body: some View {
        if let text {
            Text(text)
                .font(LexiFont.zh(12.5))
                .foregroundStyle(Color.lexiInk)
                .padding(.horizontal, 14)
                .padding(.vertical, 9)
                .background(Color.lexiRaised)
                .clipShape(RoundedRectangle(cornerRadius: LexiRadius.control, style: .continuous))
                .shadow(color: .black.opacity(0.16), radius: 18, y: 8)
                .overlay {
                    RoundedRectangle(cornerRadius: LexiRadius.control, style: .continuous)
                        .stroke(Color.lexiRule, lineWidth: 1)
                }
                .transition(.move(edge: .top).combined(with: .opacity))
        }
    }
}
