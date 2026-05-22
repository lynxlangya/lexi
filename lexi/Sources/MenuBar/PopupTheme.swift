import SwiftUI

struct PopupTheme {
    let isDark: Bool
    let bg: Color
    let bgInset: Color
    let chrome: Color
    let ink: Color
    let ink2: Color
    let ink3: Color
    let ink4: Color
    let rule: Color
    let rule2: Color
    let shimmer1: Color
    let shimmer2: Color
    let shadow: Color
    let border: Color
    let highlight: Color
    let warn: Color
    let danger: Color
    let accent: ReaderAccentChoice

    init(theme: ReaderThemeMode, accent: ReaderAccentChoice, systemColorScheme: ColorScheme) {
        let darkPalette: Bool
        switch theme {
        case .system:
            darkPalette = systemColorScheme == .dark
        case .day:
            darkPalette = false
        case .night:
            darkPalette = true
        }

        isDark = darkPalette
        self.accent = accent

        if darkPalette {
            bg = Color(red: 0.137, green: 0.125, blue: 0.102)
            bgInset = Color(red: 0.110, green: 0.098, blue: 0.078)
            chrome = Color(red: 0.122, green: 0.110, blue: 0.090)
            ink = Color(red: 0.922, green: 0.890, blue: 0.816)
            ink2 = Color(red: 0.560, green: 0.518, blue: 0.447)
            ink3 = Color(red: 0.416, green: 0.388, blue: 0.325)
            ink4 = Color(red: 0.247, green: 0.227, blue: 0.188)
            rule = Color(red: 0.169, green: 0.153, blue: 0.122)
            rule2 = Color(red: 0.227, green: 0.204, blue: 0.165)
            shimmer1 = Color(red: 1.0, green: 0.941, blue: 0.824).opacity(0.04)
            shimmer2 = Color(red: 1.0, green: 0.941, blue: 0.824).opacity(0.10)
            shadow = .black.opacity(0.62)
            border = .black.opacity(0.58)
            highlight = .white.opacity(0.05)
            warn = Color(red: 0.839, green: 0.541, blue: 0.353)
            danger = Color(red: 0.784, green: 0.439, blue: 0.376)
        } else {
            bg = Color(red: 0.984, green: 0.973, blue: 0.945)
            bgInset = Color(red: 0.945, green: 0.929, blue: 0.878)
            chrome = Color(red: 0.953, green: 0.937, blue: 0.894)
            ink = Color(red: 0.122, green: 0.106, blue: 0.082)
            ink2 = Color(red: 0.478, green: 0.443, blue: 0.388)
            ink3 = Color(red: 0.647, green: 0.612, blue: 0.537)
            ink4 = Color(red: 0.784, green: 0.749, blue: 0.675)
            rule = Color(red: 0.890, green: 0.863, blue: 0.796)
            rule2 = Color(red: 0.812, green: 0.776, blue: 0.694)
            shimmer1 = Color(red: 0.655, green: 0.620, blue: 0.549).opacity(0.10)
            shimmer2 = Color(red: 0.655, green: 0.620, blue: 0.549).opacity(0.22)
            shadow = Color(red: 0.157, green: 0.110, blue: 0.055).opacity(0.30)
            border = .black.opacity(0.10)
            highlight = .white.opacity(0.70)
            warn = Color(red: 0.659, green: 0.353, blue: 0.165)
            danger = Color(red: 0.612, green: 0.290, blue: 0.224)
        }
    }
}

struct PopupThemeReader<Content: View>: View {
    @StateObject private var systemAppearance = SystemColorSchemeObserver()
    @AppStorage(LexiDefaultsKey.readerTheme) private var theme = ReaderThemeMode.system.storageValue
    @AppStorage(LexiDefaultsKey.readerAccent) private var accent = "copper"
    @ViewBuilder var content: (PopupTheme) -> Content

    var body: some View {
        content(
            PopupTheme(
                theme: ReaderThemeMode(storageValue: theme),
                accent: ReaderAccentChoice(storageValue: accent),
                systemColorScheme: systemAppearance.colorScheme
            )
        )
        .onChange(of: theme) { _, _ in
            systemAppearance.refresh()
        }
    }
}

struct PopupCard<Content: View>: View {
    let width: CGFloat
    let pinned: Bool
    let theme: PopupTheme
    var radius: CGFloat = 12
    @ViewBuilder var content: Content

    var body: some View {
        ZStack(alignment: .topTrailing) {
            content
                .frame(width: width)
                .background(theme.bg)
                .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))

            if pinned {
                Circle()
                    .fill(theme.accent.primary)
                    .frame(width: 6, height: 6)
                    .padding(.top, 8)
                    .padding(.trailing, 8)
            }
        }
        .fixedSize()
    }
}

struct PopupHeader: View {
    let label: String
    let pinned: Bool
    let actions: PopupActions
    let theme: PopupTheme

    var body: some View {
        HStack {
            Text(label.uppercased())
                .font(LexiFont.sans(11))
                .fontWeight(.semibold)
                .foregroundStyle(theme.ink3)
                .tracking(0.7)

            Spacer()

            PopupHeaderActions(pinned: pinned, actions: actions, theme: theme)
        }
        .frame(height: 35)
        .padding(.horizontal, 14)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(theme.rule)
                .frame(height: 1)
        }
    }
}

struct PopupFooter<Content: View>: View {
    let theme: PopupTheme
    @ViewBuilder var content: Content

    var body: some View {
        HStack(spacing: 10) {
            content
        }
        .frame(height: 44)
        .padding(.horizontal, 12)
        .background(theme.chrome)
        .overlay(alignment: .top) {
            Rectangle()
                .fill(theme.rule)
                .frame(height: 1)
        }
    }
}

struct PopupEngineLabel: View {
    let engine: EngineID
    let model: String
    let theme: PopupTheme

    var body: some View {
        HStack(spacing: 5) {
            Circle()
                .fill(theme.accent.primary)
                .frame(width: 5, height: 5)

            Text(modelLabel)
                .font(LexiFont.sans(10.5))
                .fontWeight(.semibold)
                .foregroundStyle(theme.ink2)
                .lineLimit(1)
        }
        .padding(.horizontal, 8)
        .frame(height: 24)
        .background(theme.bgInset)
        .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 5, style: .continuous)
                .stroke(theme.rule, lineWidth: 1)
        }
        .help("当前模型：\(engine.menuLabel) · \(model)")
    }

    private var modelLabel: String {
        if model.isEmpty {
            return engine.menuLabel
        }
        return model
    }
}

struct PopupIconButton: View {
    let systemName: String
    let help: String
    let theme: PopupTheme
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 12, weight: .medium))
                .frame(width: 20, height: 20)
                .foregroundStyle(theme.ink3)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(help)
    }
}

struct PopupPrimaryButton<Label: View>: View {
    let theme: PopupTheme
    let action: () -> Void
    @ViewBuilder var label: Label

    var body: some View {
        Button(action: action) {
            label
                .font(LexiFont.sans(11.5))
                .fontWeight(.medium)
                .foregroundStyle(.white)
                .padding(.horizontal, 10)
                .frame(height: 26)
                .background(theme.accent.primary)
                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

struct PopupOutlineButton<Label: View>: View {
    let theme: PopupTheme
    let action: () -> Void
    @ViewBuilder var label: Label

    var body: some View {
        Button(action: action) {
            label
                .font(LexiFont.sans(11.5))
                .fontWeight(.medium)
                .foregroundStyle(theme.ink2)
                .padding(.horizontal, 9)
                .frame(height: 26)
                .background(Color.clear)
                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .stroke(theme.rule2, lineWidth: 1)
                }
        }
        .buttonStyle(.plain)
    }
}
