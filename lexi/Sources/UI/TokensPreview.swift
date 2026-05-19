import SwiftUI

struct TokensPreview: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Text("Lexi Tokens")
                    .font(LexiFont.serif(28))
                    .foregroundStyle(Color.lexiInk)

                LazyVGrid(columns: [GridItem(.adaptive(minimum: 320), spacing: 18)], spacing: 18) {
                    PalettePreviewCard()
                    TypePreviewCard()
                    SpacingPreviewCard()
                }
            }
            .padding(28)
            .frame(maxWidth: 1120, alignment: .topLeading)
        }
        .background(Color.lexiPaper)
    }
}

private struct PalettePreviewCard: View {
    private let groups: [(title: String, swatches: [(name: String, color: Color, value: String)])] = [
        (
            "Surface",
            [
                ("Paper", .lexiPaper, "#f5f1e8 / #1c1915"),
                ("Raised", .lexiRaised, "#fbf8f1 / #23201a"),
                ("Inset", .lexiInset, "#ede7d8 / #16140f"),
                ("Chrome", .lexiChrome, "#f1ede2 / #1f1c17")
            ]
        ),
        (
            "Ink",
            [
                ("Ink", .lexiInk, "#1f1b15 / #ebe3d0"),
                ("Ink2", .lexiInk2, "#7a7163 / #8e8472"),
                ("Ink3", .lexiInk3, "#a59c89 / #6a6353"),
                ("Ink4", .lexiInk4, "#c8bfac / #3f3a30")
            ]
        ),
        (
            "Rule",
            [
                ("Rule", .lexiRule, "#e3dccb / #2b271f"),
                ("Rule2", .lexiRule2, "#cfc6b1 / #3a342a")
            ]
        ),
        (
            "Accent",
            [
                ("Accent", .lexiAccent, "#b35c2c / #d68a5a"),
                ("AccentSoft", .lexiAccentSoft, "10% / 14%"),
                ("Selection", .lexiSelection, "16% / 20%")
            ]
        )
    ]

    var body: some View {
        PreviewCard(title: "Palette") {
            VStack(alignment: .leading, spacing: 16) {
                ForEach(groups, id: \.title) { group in
                    VStack(alignment: .leading, spacing: 10) {
                        SectionLabel(group.title)
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 132), spacing: 10)], spacing: 10) {
                            ForEach(group.swatches, id: \.name) { swatch in
                                SwatchRow(name: swatch.name, color: swatch.color, value: swatch.value)
                            }
                        }
                    }
                }
            }
        }
    }
}

private struct TypePreviewCard: View {
    var body: some View {
        PreviewCard(title: "Type") {
            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: LexiSpacing.enZhGap) {
                    SectionLabel("EN Body 17 / 29")
                    Text("In my younger and more vulnerable years my father gave me some advice that I've been turning over in my mind ever since.")
                        .font(LexiFont.serif(17))
                        .lineSpacing(17 * 0.72)
                        .foregroundStyle(Color.lexiInk)

                    Text("在我年纪尚轻、阅历未深的那些年里，父亲曾给过我一句忠告，我至今仍反复琢磨。")
                        .font(LexiFont.zh(13.5))
                        .lineSpacing(13.5 * 0.78)
                        .foregroundStyle(Color.lexiInk2)
                }

                DividerLine()

                VStack(alignment: .leading, spacing: 12) {
                    TypeRow(label: "H1 28 / 34", text: "Chapter I", font: LexiFont.serif(28), color: .lexiInk)
                    TypeRow(label: "H2 20 / 28", text: "A New Beginning", font: LexiFont.serif(20), color: .lexiInk)
                    TypeRow(label: "UI 13 / 18", text: "第 3 章 / 共 18 章", font: LexiFont.sans(13), color: .lexiInk)
                    TypeRow(label: "Caption 11", text: "THE GREAT GATSBY", font: LexiFont.sans(11), color: .lexiInk3)
                    TypeRow(label: "Mono 11", text: "--ink-secondary: var(--lexi-ink2)", font: LexiFont.mono(11), color: .lexiInk2)
                }
            }
        }
    }
}

private struct SpacingPreviewCard: View {
    var body: some View {
        PreviewCard(title: "Spacing") {
            VStack(alignment: .leading, spacing: 18) {
                SectionLabel("Para group")

                HStack(alignment: .top, spacing: 16) {
                    Rectangle()
                        .fill(Color.lexiRule2)
                        .frame(width: 1)

                    VStack(alignment: .leading, spacing: 0) {
                        Text("He didn't say any more, but we've always been unusually communicative in a reserved way.")
                            .font(LexiFont.serif(17))
                            .lineSpacing(17 * 0.72)
                            .foregroundStyle(Color.lexiInk)

                        Spacer().frame(height: LexiSpacing.enZhGap)

                        Text("他没再多说什么，但我们父子之间向来不必多言便能心领神会。")
                            .font(LexiFont.zh(13.5))
                            .lineSpacing(13.5 * 0.78)
                            .foregroundStyle(Color.lexiInk2)

                        Spacer().frame(height: LexiSpacing.paraGap)

                        Text("In consequence, I'm inclined to reserve all judgments.")
                            .font(LexiFont.serif(17))
                            .lineSpacing(17 * 0.72)
                            .foregroundStyle(Color.lexiInk)

                        Spacer().frame(height: LexiSpacing.enZhGap)

                        Text("因此，我习惯了对一切不轻易下判断。")
                            .font(LexiFont.zh(13.5))
                            .lineSpacing(13.5 * 0.78)
                            .foregroundStyle(Color.lexiInk2)
                    }
                }

                DividerLine()

                VStack(alignment: .leading, spacing: 7) {
                    MetricRow(name: "content-max", value: "\(Int(LexiSpacing.contentMax)) pt")
                    MetricRow(name: "window-pad", value: "\(Int(LexiSpacing.windowPad)) pt")
                    MetricRow(name: "para-gap", value: "\(Int(LexiSpacing.paraGap)) pt")
                    MetricRow(name: "en-zh gap", value: "\(Int(LexiSpacing.enZhGap)) pt")
                    MetricRow(name: "radius/window", value: "\(Int(LexiRadius.window)) pt")
                    MetricRow(name: "radius/control", value: "\(Int(LexiRadius.control)) pt")
                }
            }
        }
    }
}

private struct PreviewCard<Content: View>: View {
    let title: String
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .firstTextBaseline) {
                Text(title)
                    .font(LexiFont.sans(13))
                    .foregroundStyle(Color.lexiInk)
                Spacer()
                Text("TOKEN")
                    .font(LexiFont.mono(10.5))
                    .foregroundStyle(Color.lexiInk3)
            }

            content
        }
        .padding(24)
        .frame(minHeight: 420, alignment: .topLeading)
        .background(Color.lexiRaised)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(Color.lexiRule, lineWidth: 1)
        )
    }
}

private struct SwatchRow: View {
    let name: String
    let color: Color
    let value: String

    var body: some View {
        HStack(spacing: 10) {
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(color)
                .frame(width: 36, height: 36)
                .overlay(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .stroke(Color.lexiRule, lineWidth: 1)
                )

            VStack(alignment: .leading, spacing: 2) {
                Text(name)
                    .font(LexiFont.sans(11))
                    .foregroundStyle(Color.lexiInk)
                Text(value)
                    .font(LexiFont.mono(10.5))
                    .foregroundStyle(Color.lexiInk3)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct TypeRow: View {
    let label: String
    let text: String
    let font: Font
    let color: Color

    var body: some View {
        Grid(alignment: .leading, horizontalSpacing: 18, verticalSpacing: 0) {
            GridRow {
                Text(label)
                    .font(LexiFont.mono(10))
                    .foregroundStyle(Color.lexiInk3)
                    .frame(width: 88, alignment: .leading)
                Text(text)
                    .font(font)
                    .foregroundStyle(color)
            }
        }
    }
}

private struct MetricRow: View {
    let name: String
    let value: String

    var body: some View {
        HStack(spacing: 14) {
            Text(name)
                .foregroundStyle(Color.lexiInk3)
                .frame(width: 104, alignment: .leading)
            Text(value)
                .foregroundStyle(Color.lexiInk2)
        }
        .font(LexiFont.mono(11))
    }
}

private struct SectionLabel: View {
    let text: String

    init(_ text: String) {
        self.text = text
    }

    var body: some View {
        Text(text.uppercased())
            .font(LexiFont.mono(10))
            .foregroundStyle(Color.lexiInk3)
    }
}

private struct DividerLine: View {
    var body: some View {
        Rectangle()
            .fill(Color.lexiRule)
            .frame(height: 1)
    }
}

#Preview("Tokens Light") {
    TokensPreview()
        .environment(\.colorScheme, .light)
}

#Preview("Tokens Dark") {
    TokensPreview()
        .environment(\.colorScheme, .dark)
}
