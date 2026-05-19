import SwiftUI

struct TOCSidebar: View {
    let chapters: [DemoChapter]
    @Binding var selectedChapterIndex: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 18) {
                shelfButton
                bookHeader

                Rectangle()
                    .fill(Color.lexiRule)
                    .frame(height: 1)
                    .padding(.horizontal, 8)

                ScrollView {
                    VStack(spacing: 1) {
                        ForEach(Array(chapters.enumerated()), id: \.element.id) { index, chapter in
                            TOCRow(
                                chapter: chapter,
                                isSelected: index == selectedChapterIndex
                            ) {
                                selectedChapterIndex = index
                            }
                        }
                    }
                    .padding(.vertical, 2)
                }
                .scrollIndicators(.never)
            }

            Spacer(minLength: 24)

            sidebarFooter
        }
        .padding(.top, 16)
        .padding(.horizontal, 14)
        .padding(.bottom, 0)
        .frame(width: 232)
        .frame(maxHeight: .infinity, alignment: .top)
        .background(Color.lexiRaised)
    }

    private var shelfButton: some View {
        Button(action: {}) {
            Label("书架", systemImage: "chevron.left")
                .font(LexiFont.sans(12))
                .foregroundStyle(Color.lexiInk3)
                .labelStyle(.titleAndIcon)
        }
        .buttonStyle(.plain)
        .focusable(false)
        .padding(.horizontal, 8)
    }

    private var bookHeader: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Book")
                .font(LexiFont.sans(10.5))
                .fontWeight(.semibold)
                .foregroundStyle(Color.lexiInk3)
                .textCase(.uppercase)

            Text(DemoData.bookTitle)
                .font(LexiFont.serif(14))
                .foregroundStyle(Color.lexiInk)
                .lineSpacing(14 * 0.3)
                .fixedSize(horizontal: false, vertical: true)

            Text(DemoData.author)
                .font(LexiFont.sans(11.5))
                .foregroundStyle(Color.lexiInk3)
        }
        .padding(.horizontal, 8)
    }

    private var sidebarFooter: some View {
        VStack(spacing: 0) {
            Divider()
                .background(Color.lexiRule)
                .padding(.horizontal, 8)
                .padding(.top, 12)
                .padding(.bottom, 10)

            HStack {
                Text("全书进度")
                    .font(LexiFont.sans(11))
                    .foregroundStyle(Color.lexiInk3)

                Spacer()

                Text("\(overallProgress)%")
                    .font(LexiFont.mono(11))
                    .foregroundStyle(Color.lexiInk2)
            }
            .padding(.horizontal, 10)
            .padding(.bottom, 6)
        }
    }

    private var overallProgress: Int {
        Int((Double(selectedChapterIndex) / Double(chapters.count)) * 100)
    }
}

private struct TOCRow: View {
    let chapter: DemoChapter
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text(chapter.n)
                    .font(LexiFont.mono(10.5))
                    .foregroundStyle(isSelected ? Color.lexiAccent : Color.lexiInk3)
                    .frame(width: 28, alignment: .leading)

                Text(chapter.title)
                    .font(LexiFont.sans(12.5))
                    .fontWeight(isSelected ? .medium : .regular)
                    .foregroundStyle(isSelected ? Color.lexiAccent : Color.lexiInk)
                    .lineLimit(1)
                    .truncationMode(.tail)

                Spacer(minLength: 8)

                Circle()
                    .fill(Color.lexiInk4)
                    .frame(width: 5, height: 5)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(isSelected ? Color.lexiAccentSoft : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: LexiRadius.control, style: .continuous))
            .contentShape(RoundedRectangle(cornerRadius: LexiRadius.control, style: .continuous))
        }
        .buttonStyle(.plain)
        .focusable(false)
    }
}
