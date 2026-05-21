import SwiftUI

struct LexiMenuPanel: View {
    let vocabCount: Int
    let unmasteredCount: Int
    let todayCount: Int
    let translateSelection: () -> Void
    let translateAndReplace: () -> Void
    let toggleReader: () -> Void
    let openVocab: () -> Void
    let openSettings: () -> Void
    let quit: () -> Void
    @AppStorage("reader.accent") private var accent = "copper"

    private var accentChoice: ReaderAccentChoice {
        ReaderAccentChoice(storageValue: accent)
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            stats
            menuItems
        }
        .frame(width: 280)
        .background(Color.lexiRaised)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Text("Lexi")
                    .font(LexiFont.sans(13))
                    .fontWeight(.semibold)
                    .foregroundStyle(Color.lexiInk)
                Spacer()
                Text("⌘⇧L")
                    .font(LexiFont.mono(10.5))
                    .foregroundStyle(Color.lexiInk3)
            }
            Text("全局划词翻译已激活")
                .font(LexiFont.zh(11.5))
                .foregroundStyle(Color.lexiInk3)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
    }

    private var stats: some View {
        HStack(spacing: 8) {
            stat(title: "生词本", value: "\(vocabCount)", suffix: "词")
            stat(title: "今日查询", value: "\(todayCount)", suffix: "")
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .overlay(alignment: .top) {
            Rectangle().fill(Color.lexiRule).frame(height: 1)
        }
        .overlay(alignment: .bottom) {
            Rectangle().fill(Color.lexiRule).frame(height: 1)
        }
    }

    private func stat(title: String, value: String, suffix: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(LexiFont.sans(10))
                .fontWeight(.semibold)
                .foregroundStyle(Color.lexiInk3)
                .tracking(0.8)
            HStack(alignment: .firstTextBaseline, spacing: 3) {
                Text(value)
                    .font(LexiFont.serif(17))
                    .foregroundStyle(Color.lexiInk)
                if !suffix.isEmpty {
                    Text(suffix)
                        .font(LexiFont.zh(11))
                        .foregroundStyle(Color.lexiInk3)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var menuItems: some View {
        VStack(spacing: 0) {
            menuButton("划词翻译", shortcut: "⌘⇧L", action: translateSelection)
            menuButton("即时翻译选中文字", shortcut: "⌘⇧T", action: translateAndReplace)
            menuButton("打开阅读器…", shortcut: "⌘⇧K", action: toggleReader)
            divider
            menuButton("生词本…", shortcut: "", action: openVocab)
            menuButton("未掌握 \(unmasteredCount) 词", shortcut: "", action: openVocab)
            divider
            menuButton("设置…", shortcut: "⌘,", action: openSettings)
            menuButton("退出 Lexi", shortcut: "⌘Q", danger: true, action: quit)
        }
        .padding(6)
    }

    private var divider: some View {
        Rectangle()
            .fill(Color.lexiRule)
            .frame(height: 1)
            .padding(.horizontal, 6)
            .padding(.vertical, 4)
    }

    private func menuButton(
        _ title: String,
        shortcut: String,
        disabled: Bool = false,
        danger: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack {
                Text(title)
                    .font(LexiFont.zh(12.5))
                Spacer()
                if !shortcut.isEmpty {
                    Text(shortcut)
                        .font(LexiFont.mono(10.5))
                        .foregroundStyle(Color.lexiInk3)
                }
            }
            .foregroundStyle(disabled ? Color.lexiInk4 : (danger ? Color.lexiDanger : Color.lexiInk))
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(disabled ? accentChoice.soft.opacity(0.55) : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(disabled)
    }
}
