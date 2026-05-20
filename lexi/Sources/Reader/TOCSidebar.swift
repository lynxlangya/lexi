import SwiftUI

struct TOCSidebar: View {
    let book: ReaderBook
    let chapters: [ReaderChapter]
    @Binding var selectedChapterIndex: Int
    let chapterState: (Int64) -> ChapterTranslationState
    let preferences: ReaderRuntimePreferences
    let openShelf: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 18) {
                shelfButton
                bookHeader

                Rectangle()
                    .fill(preferences.theme.rule)
                    .frame(height: 1)
                    .padding(.horizontal, 8)

                ScrollView {
                    VStack(spacing: 1) {
                        ForEach(Array(chapters.enumerated()), id: \.element.id) { index, chapter in
                            TOCRow(
                                chapter: chapter,
                                isSelected: index == selectedChapterIndex,
                                state: chapterState(chapter.id),
                                preferences: preferences
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
        .background(preferences.theme.raised)
    }

    private var shelfButton: some View {
        Button(action: openShelf) {
            Label("书架", systemImage: "chevron.left")
                .font(LexiFont.sans(12))
                .foregroundStyle(preferences.theme.ink3)
                .labelStyle(.titleAndIcon)
        }
        .buttonStyle(.plain)
        .focusable(false)
        .padding(.horizontal, 8)
    }

    private var bookHeader: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(book.title)
                .font(preferences.font.serif(14))
                .foregroundStyle(preferences.theme.ink)
                .lineSpacing(14 * 0.3)
                .fixedSize(horizontal: false, vertical: true)

            Text(book.author)
                .font(LexiFont.sans(11.5))
                .foregroundStyle(preferences.theme.ink3)
        }
        .padding(.horizontal, 8)
    }

    private var sidebarFooter: some View {
        VStack(spacing: 0) {
            Divider()
                .background(preferences.theme.rule)
                .padding(.horizontal, 8)
                .padding(.top, 12)
                .padding(.bottom, 10)

            HStack {
                Text("全书进度")
                    .font(LexiFont.sans(11))
                    .foregroundStyle(preferences.theme.ink3)

                Spacer()

                Text("\(overallProgress)%")
                    .font(LexiFont.mono(11))
                    .foregroundStyle(preferences.theme.ink2)
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
    let chapter: ReaderChapter
    let isSelected: Bool
    let state: ChapterTranslationState
    let preferences: ReaderRuntimePreferences
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text(chapter.n)
                    .font(LexiFont.mono(10.5))
                    .foregroundStyle(isSelected ? preferences.accent.primary : preferences.theme.ink3)
                    .frame(width: 28, alignment: .leading)

                Text(chapter.title)
                    .font(LexiFont.sans(12.5))
                    .fontWeight(isSelected ? .medium : .regular)
                    .foregroundStyle(isSelected ? preferences.accent.primary : preferences.theme.ink)
                    .lineLimit(1)
                    .truncationMode(.tail)

                Spacer(minLength: 8)

                statusIndicator
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(isSelected ? preferences.accent.soft : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: LexiRadius.control, style: .continuous))
            .contentShape(RoundedRectangle(cornerRadius: LexiRadius.control, style: .continuous))
        }
        .buttonStyle(.plain)
        .focusable(false)
    }

    @ViewBuilder
    private var statusIndicator: some View {
        switch state {
        case .translating:
            SpinnerDot(size: 10, accent: preferences.accent.primary)
        case .cached:
            Circle()
                .fill(preferences.theme.ink3)
                .frame(width: 5, height: 5)
        case .idle:
            Circle()
                .fill(preferences.theme.ink4)
                .frame(width: 5, height: 5)
        case .error:
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(Color.lexiWarn)
        }
    }
}
