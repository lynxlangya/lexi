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
    let subtitle: String
    let status: EngineStatusDot
    @Binding var apiKey: String
    @Binding var model: String
    let testing: Bool
    let test: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(status.color)
                .frame(width: 7, height: 7)

            VStack(alignment: .leading, spacing: 2) {
                Text(engine.displayName)
                    .font(LexiFont.sans(12.5))
                    .foregroundStyle(Color.lexiInk)
                Text(subtitle)
                    .font(LexiFont.sans(11))
                    .foregroundStyle(Color.lexiInk3)
            }
            .frame(width: 92, alignment: .leading)

            APIKeyField(value: $apiKey)
            ModelField(value: $model, placeholder: ReaderFixtureStore.defaultModel(for: engine))

            Button {
                test()
            } label: {
                if testing {
                    ProgressView()
                        .controlSize(.mini)
                } else {
                    Text("测试")
                }
            }
            .font(LexiFont.zh(11.5))
            .frame(width: 52)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
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
