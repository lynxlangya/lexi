import SwiftUI

struct ErrorCard: View {
    let reason: String
    let retry: () -> Void
    let close: () -> Void

    var body: some View {
        PopupFrame(pinned: false) {
            VStack(spacing: 0) {
                HStack {
                    Text("Lexi")
                        .font(LexiFont.sans(11))
                        .fontWeight(.semibold)
                        .foregroundStyle(Color.lexiInk3)
                        .tracking(0.6)
                    Spacer()
                    Label("翻译失败", systemImage: "exclamationmark.triangle")
                        .font(LexiFont.sans(10.5))
                        .foregroundStyle(Color.lexiWarn)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 9)
                .overlay(alignment: .bottom) {
                    Rectangle().fill(Color.lexiRule).frame(height: 1)
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("连接引擎失败")
                        .font(LexiFont.sans(13.5))
                        .fontWeight(.medium)
                        .foregroundStyle(Color.lexiInk)

                    Text("检查网络、API Key 或模型名后重试。")
                        .font(LexiFont.zh(12.5))
                        .lineSpacing(8)
                        .foregroundStyle(Color.lexiInk2)

                    Text(reason)
                        .font(LexiFont.mono(10.5))
                        .foregroundStyle(Color.lexiInk3)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 8)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.lexiInset)
                        .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
                        .overlay {
                            RoundedRectangle(cornerRadius: 5, style: .continuous)
                                .stroke(Color.lexiRule, lineWidth: 1)
                        }
                }
                .padding(16)

                HStack {
                    Spacer()
                    Button("关闭", action: close)
                        .font(LexiFont.sans(11.5))
                    Button("重试", action: retry)
                        .font(LexiFont.sans(11.5))
                        .buttonStyle(.borderedProminent)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color.lexiChrome)
            }
            .frame(width: 360)
        }
    }
}
