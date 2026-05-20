import SwiftUI

enum EngineStatusDot {
    case unset
    case ok
    case keyOkModelUnknown
    case fail

    var color: Color {
        switch self {
        case .unset:
            return .lexiInk4
        case .ok:
            return Color(red: 0.35, green: 0.54, blue: 0.32)
        case .keyOkModelUnknown:
            return Color(red: 0.72, green: 0.54, blue: 0.22)
        case .fail:
            return .lexiDanger
        }
    }
}

struct EngineRow: View {
    let engine: EngineID
    let status: EngineStatusDot
    @Binding var apiKey: String
    @Binding var model: String
    let testing: Bool
    let accent: ReaderAccentChoice
    let test: () -> Void

    @State private var isEditing = false
    @State private var draftAPIKey = ""
    @State private var draftModel = ""

    private var hasKey: Bool {
        !apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        HStack(spacing: 6) {
            HStack(spacing: 7) {
                Circle()
                    .fill(hasKey ? status.color : Color.lexiInk4)
                    .frame(width: 6, height: 6)

                Text(hasKey ? mask(apiKey) : "未设置")
                    .font(LexiFont.mono(11))
                    .italic(!hasKey)
                    .foregroundStyle(hasKey ? Color.lexiInk : Color.lexiInk3)
                    .lineLimit(1)
                    .truncationMode(.middle)

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 9)
            .frame(width: 184, height: 24)
            .background(Color.lexiInset)
            .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .stroke(Color.lexiRule2, lineWidth: 1)
            }

            if hasKey {
                Button {
                    test()
                } label: {
                    if testing {
                        ProgressView()
                            .controlSize(.mini)
                            .frame(width: 26)
                    } else {
                        Text("测试")
                    }
                }
                .buttonStyle(EnginePlainButtonStyle())
                .disabled(testing)

                Button {
                    openEditor()
                } label: {
                    Text("⋯")
                        .frame(width: 22)
                }
                .buttonStyle(EnginePlainButtonStyle(horizontalPadding: 0))
                .help("更换 Key")
            } else {
                Button("设置…") {
                    openEditor()
                }
                .buttonStyle(EnginePrimaryButtonStyle(accent: accent.primary))
            }
        }
        .frame(height: 24)
        .popover(isPresented: $isEditing, arrowEdge: .trailing) {
            VStack(alignment: .leading, spacing: 12) {
                Text("\(engine.displayName) 设置")
                    .font(LexiFont.zh(12.5))
                    .foregroundStyle(Color.lexiInk)

                VStack(alignment: .leading, spacing: 6) {
                    Text("API Key")
                        .font(LexiFont.sans(10.5))
                        .foregroundStyle(Color.lexiInk3)
                        .textCase(.uppercase)
                    SecureField("API Key", text: $draftAPIKey)
                        .textFieldStyle(.roundedBorder)
                        .font(LexiFont.mono(11))
                        .controlSize(.small)
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text("Model")
                        .font(LexiFont.sans(10.5))
                        .foregroundStyle(Color.lexiInk3)
                        .textCase(.uppercase)
                    TextField(ReaderFixtureStore.defaultModel(for: engine), text: $draftModel)
                        .textFieldStyle(.roundedBorder)
                        .font(LexiFont.mono(11))
                        .controlSize(.small)
                }

                HStack {
                    Spacer()
                    Button("取消") {
                        isEditing = false
                    }
                    .buttonStyle(EnginePlainButtonStyle())

                    Button("确认") {
                        apiKey = draftAPIKey.trimmingCharacters(in: .whitespacesAndNewlines)
                        let nextModel = draftModel.trimmingCharacters(in: .whitespacesAndNewlines)
                        model = nextModel.isEmpty ? ReaderFixtureStore.defaultModel(for: engine) : nextModel
                        isEditing = false
                    }
                    .buttonStyle(EnginePrimaryButtonStyle(accent: accent.primary))
                }
            }
            .padding(14)
            .frame(width: 280)
            .background(Color.lexiRaised)
        }
    }

    private func openEditor() {
        draftAPIKey = apiKey
        draftModel = model
        isEditing = true
    }

    private func mask(_ raw: String) -> String {
        let key = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard key.count >= 8 else {
            return String(repeating: "•", count: 12)
        }
        return "\(key.prefix(3))\(String(repeating: "•", count: 19))\(key.suffix(4))"
    }
}

private struct EnginePlainButtonStyle: ButtonStyle {
    var horizontalPadding: CGFloat = 9

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(LexiFont.zh(11.5))
            .fontWeight(.medium)
            .foregroundStyle(Color.lexiInk2)
            .padding(.horizontal, horizontalPadding)
            .frame(height: 24)
            .background(Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .stroke(Color.lexiRule2, lineWidth: 1)
            }
            .opacity(configuration.isPressed ? 0.72 : 1)
    }
}

private struct EnginePrimaryButtonStyle: ButtonStyle {
    let accent: Color

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(LexiFont.zh(11.5))
            .fontWeight(.medium)
            .foregroundStyle(Color.white)
            .padding(.horizontal, 10)
            .frame(height: 24)
            .background(accent)
            .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
            .opacity(configuration.isPressed ? 0.78 : 1)
    }
}

extension EngineID {
    var displayName: String {
        switch self {
        case .openai:
            return "OpenAI"
        case .anthropic:
            return "Anthropic"
        case .deepseek:
            return "DeepSeek"
        }
    }
}
