import SwiftUI

struct ErrorCard: View {
    let title: String
    let message: String
    let reason: String
    let actionTitle: String
    let action: () -> Void
    let retry: (() -> Void)?
    let close: () -> Void

    var body: some View {
        PopupThemeReader { theme in
            PopupCard(width: 420, pinned: false, theme: theme) {
                VStack(spacing: 0) {
                    HStack {
                        Text("Lexi".uppercased())
                            .font(LexiFont.sans(11))
                            .fontWeight(.semibold)
                            .foregroundStyle(theme.ink3)
                            .tracking(0.7)

                        Spacer()

                        Label("翻译失败", systemImage: "exclamationmark.triangle")
                            .font(LexiFont.sans(11))
                            .fontWeight(.medium)
                            .foregroundStyle(theme.warn)
                    }
                    .frame(height: 56)
                    .padding(.horizontal, 20)
                    .overlay(alignment: .bottom) {
                        Rectangle()
                            .fill(theme.rule)
                            .frame(height: 1)
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        Text(title)
                            .font(LexiFont.sans(15))
                            .fontWeight(.medium)
                            .foregroundStyle(theme.ink)

                        Text(message)
                            .font(LexiFont.zh(13.5))
                            .lineSpacing(8)
                            .foregroundStyle(theme.ink2)

                        Text(reason)
                            .font(LexiFont.mono(11))
                            .foregroundStyle(theme.ink3)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 9)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(theme.bgInset)
                            .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
                            .overlay {
                                RoundedRectangle(cornerRadius: 7, style: .continuous)
                                    .stroke(theme.rule, lineWidth: 1)
                            }
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 20)

                    PopupFooter(theme: theme) {
                        PopupOutlineButton(theme: theme, action: action) {
                            Text(actionTitle)
                        }

                        Spacer()

                        PopupOutlineButton(theme: theme, action: close) {
                            Text("关闭")
                        }

                        if let retry {
                            PopupPrimaryButton(theme: theme, action: retry) {
                                Text("重试")
                            }
                        }
                    }
                }
            }
        }
    }
}
