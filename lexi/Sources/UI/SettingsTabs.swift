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
        VStack(alignment: .leading, spacing: 9) {
            if !title.isEmpty {
                Text(title)
                    .font(LexiFont.sans(11.5))
                    .fontWeight(.semibold)
                    .foregroundStyle(Color.lexiInk3)
                    .tracking(0.7)
                    .padding(.horizontal, 20)
            }

            VStack(spacing: 0) {
                content
            }
            .background(Color.lexiRaised)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(Color.lexiRule, lineWidth: 1)
            }
        }
        .padding(.bottom, 24)
    }
}

struct SettingsRow<Control: View>: View {
    let label: String
    var hint: String?
    var isLast = false
    var controlWidth: CGFloat = 280
    @ViewBuilder var control: Control

    var body: some View {
        HStack(alignment: .center, spacing: 28) {
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(LexiFont.zh(13.5))
                    .fontWeight(.medium)
                    .foregroundStyle(Color.lexiInk)
                if let hint {
                    Text(hint)
                        .font(LexiFont.zh(11.5))
                        .lineSpacing(4)
                        .foregroundStyle(Color.lexiInk3)
                }
            }
            .layoutPriority(1)
            .frame(maxWidth: .infinity, alignment: .leading)

            control
                .frame(width: controlWidth, alignment: .trailing)
                .fixedSize(horizontal: true, vertical: false)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 17)
        .frame(minHeight: 72)
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
        .frame(width: 210)
        .controlSize(.large)
    }
}

struct SettingsSegmented: View {
    @Binding var value: String
    let options: [(String, String)]

    var body: some View {
        HStack(spacing: 0) {
            ForEach(options, id: \.0) { option in
                Button {
                    value = option.0
                } label: {
                    Text(option.1)
                        .font(LexiFont.zh(12.5))
                        .fontWeight(value == option.0 ? .medium : .regular)
                        .foregroundStyle(value == option.0 ? Color.lexiInk : Color.lexiInk2)
                        .lineLimit(1)
                        .padding(.horizontal, 13)
                        .frame(minWidth: 58, minHeight: 30)
                        .background(value == option.0 ? Color.lexiRaised : Color.clear)
                        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                        .overlay {
                            if value == option.0 {
                                RoundedRectangle(cornerRadius: 6, style: .continuous)
                                    .stroke(Color.lexiRule2, lineWidth: 1)
                            }
                        }
                }
                .buttonStyle(.plain)
            }
        }
        .padding(3)
        .background(Color.lexiInset)
        .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .stroke(Color.lexiRule, lineWidth: 1)
        }
    }
}

struct SettingsIntSegmented: View {
    @Binding var value: Int
    let options: [(Int, String)]

    var body: some View {
        HStack(spacing: 0) {
            ForEach(options, id: \.0) { option in
                Button {
                    value = option.0
                } label: {
                    Text(option.1)
                        .font(LexiFont.zh(12.5))
                        .fontWeight(value == option.0 ? .medium : .regular)
                        .foregroundStyle(value == option.0 ? Color.lexiInk : Color.lexiInk2)
                        .lineLimit(1)
                        .padding(.horizontal, 13)
                        .frame(minWidth: 58, minHeight: 30)
                        .background(value == option.0 ? Color.lexiRaised : Color.clear)
                        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                        .overlay {
                            if value == option.0 {
                                RoundedRectangle(cornerRadius: 6, style: .continuous)
                                    .stroke(Color.lexiRule2, lineWidth: 1)
                            }
                        }
                }
                .buttonStyle(.plain)
            }
        }
        .padding(3)
        .background(Color.lexiInset)
        .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .stroke(Color.lexiRule, lineWidth: 1)
        }
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
