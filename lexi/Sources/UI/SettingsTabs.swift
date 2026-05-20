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

    var iconPath: SettingsTabIcon.PathKind { .init(tab: self) }
}

struct SettingsTabIcon: Shape {
    enum PathKind {
        case general
        case engine
        case shortcuts
        case reader

        init(tab: SettingsTab) {
            switch tab {
            case .general:
                self = .general
            case .engine:
                self = .engine
            case .shortcuts:
                self = .shortcuts
            case .reader:
                self = .reader
            }
        }
    }

    let kind: PathKind

    func path(in rect: CGRect) -> Path {
        let scaleX = rect.width / 16
        let scaleY = rect.height / 16

        func point(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
            CGPoint(x: rect.minX + x * scaleX, y: rect.minY + y * scaleY)
        }

        func drawLine(_ path: inout Path, _ x1: CGFloat, _ y1: CGFloat, _ x2: CGFloat, _ y2: CGFloat) {
            path.move(to: point(x1, y1))
            path.addLine(to: point(x2, y2))
        }

        func drawRect(_ path: inout Path, _ x: CGFloat, _ y: CGFloat, _ width: CGFloat, _ height: CGFloat) {
            path.addRect(CGRect(
                x: rect.minX + x * scaleX,
                y: rect.minY + y * scaleY,
                width: width * scaleX,
                height: height * scaleY
            ))
        }

        var path = Path()
        switch kind {
        case .general:
            drawLine(&path, 3, 8, 13, 8)
            drawLine(&path, 3, 4, 13, 4)
            drawLine(&path, 3, 12, 13, 12)
        case .engine:
            drawLine(&path, 8, 2.5, 8, 5.5)
            drawLine(&path, 8, 10.5, 8, 13.5)
            drawLine(&path, 2.5, 8, 5.5, 8)
            drawLine(&path, 10.5, 8, 13.5, 8)
            drawLine(&path, 4.4, 4.4, 6.4, 6.4)
            drawLine(&path, 9.6, 9.6, 11.6, 11.6)
            drawLine(&path, 4.4, 11.6, 6.4, 9.6)
            drawLine(&path, 9.6, 6.4, 11.6, 4.4)
        case .shortcuts:
            drawRect(&path, 2.5, 4.5, 11, 7)
            drawLine(&path, 4, 7, 4.1, 7)
            drawLine(&path, 6, 7, 6.1, 7)
            drawLine(&path, 8, 7, 8.1, 7)
            drawLine(&path, 10, 7, 10.1, 7)
            drawLine(&path, 12, 7, 12.1, 7)
            drawLine(&path, 4.5, 9.5, 11.5, 9.5)
        case .reader:
            drawRect(&path, 3, 3.5, 6, 9)
            drawRect(&path, 9, 3.5, 4, 9)
        }
        return path
    }
}

struct SettingsSection<Content: View>: View {
    let title: String
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if !title.isEmpty {
                Text(title)
                    .font(LexiFont.sans(10.5))
                    .fontWeight(.semibold)
                    .foregroundStyle(Color.lexiInk3)
                    .tracking(1.05)
                    .textCase(.uppercase)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 8)
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
    var controlWidth: CGFloat = 280
    @ViewBuilder var control: Control

    var body: some View {
        HStack(alignment: .center, spacing: 16) {
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(LexiFont.zh(12.5))
                    .foregroundStyle(Color.lexiInk)
                if let hint {
                    Text(hint)
                        .font(LexiFont.zh(11))
                        .lineSpacing(2)
                        .foregroundStyle(Color.lexiInk3)
                }
            }
            .layoutPriority(1)
            .frame(maxWidth: .infinity, alignment: .leading)

            control
                .frame(width: controlWidth, alignment: .trailing)
                .fixedSize(horizontal: true, vertical: false)
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
        .pickerStyle(.menu)
        .controlSize(.small)
        .font(LexiFont.zh(12))
        .fixedSize()
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

struct SettingsFlatButtonStyle: ButtonStyle {
    var danger = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(LexiFont.sans(11.5))
            .fontWeight(.medium)
            .foregroundStyle(danger ? Color.lexiDanger : Color.lexiInk)
            .padding(.horizontal, 10)
            .padding(.vertical, 3)
            .background(Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .stroke(danger ? Color.lexiDanger : Color.lexiRule2, lineWidth: 1)
            }
            .opacity(configuration.isPressed ? 0.72 : 1)
    }
}
