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
                                isRead: index < selectedChapterIndex,
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
        .padding(.top, 60)
        .padding(.horizontal, 14)
        .padding(.bottom, 0)
        .frame(width: 232)
        .frame(maxHeight: .infinity, alignment: .top)
        .overlay(alignment: .trailing) {
            Rectangle()
                .fill(preferences.theme.rule)
                .frame(width: 1)
                .ignoresSafeArea(edges: .vertical)
        }
        .background {
            OpaqueBackground(color: preferences.theme.raised)
                .ignoresSafeArea()
        }
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
    let isRead: Bool
    let state: ChapterTranslationState
    let preferences: ReaderRuntimePreferences
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(chapter.n)
                    .font(LexiFont.mono(10.5))
                    .tracking(0.4)
                    .foregroundStyle(numberColor)
                    .frame(width: 28, alignment: .leading)

                Text(chapter.title)
                    .font(LexiFont.sans(12.5))
                    .fontWeight(isSelected ? .medium : .regular)
                    .foregroundStyle(titleColor)
                    .lineLimit(1)
                    .truncationMode(.tail)

                Spacer(minLength: 8)

                if !isSelected {
                    statusIndicator
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(isSelected ? preferences.accent.soft : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: LexiRadius.control, style: .continuous))
            .contentShape(RoundedRectangle(cornerRadius: LexiRadius.control, style: .continuous))
        }
        .buttonStyle(.plain)
        .focusable(false)
    }

    private var numberColor: Color {
        if isSelected {
            preferences.accent.primary
        } else if isRead {
            preferences.theme.ink4
        } else {
            preferences.theme.ink3
        }
    }

    private var titleColor: Color {
        if isSelected {
            preferences.accent.primary
        } else if isRead {
            preferences.theme.ink3
        } else {
            preferences.theme.ink
        }
    }

    @ViewBuilder
    private var statusIndicator: some View {
        Group {
            switch state {
            case .translating:
                SpinnerDot(size: 8, accent: preferences.accent.primary)
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
                    .font(.system(size: 8, weight: .medium))
                    .foregroundStyle(Color.lexiWarn)
            }
        }
        .frame(width: 10, alignment: .center)
    }
}
