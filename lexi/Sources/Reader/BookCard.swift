import SwiftUI

struct BookCard: View {
    let book: ReaderBook
    let isCurrent: Bool
    let openFromBeginning: () -> Void
    let continueReading: () -> Void
    let revealInFinder: () -> Void
    let clearCache: () -> Void
    let remove: () -> Void

    @State private var isHovering = false
    @AppStorage("reader.accent") private var accent = "copper"

    private var accentChoice: ReaderAccentChoice {
        ReaderAccentChoice(storageValue: accent)
    }

    var body: some View {
        Button(action: continueReading) {
            VStack(alignment: .leading, spacing: 10) {
                ZStack(alignment: .topTrailing) {
                    BookCover(book: book)
                        .frame(maxWidth: .infinity)

                    if isCurrent {
                        Circle()
                            .fill(accentChoice.primary)
                            .frame(width: 18, height: 18)
                            .overlay {
                                Circle()
                                    .fill(Color.white)
                                    .frame(width: 5, height: 5)
                            }
                            .shadow(color: .black.opacity(0.22), radius: 6, y: 2)
                            .offset(x: 0, y: -6)
                    }
                }

                VStack(alignment: .leading, spacing: 0) {
                    Text(book.title)
                        .font(LexiFont.sans(12.5))
                        .fontWeight(.medium)
                        .foregroundStyle(Color.lexiInk)
                        .lineLimit(1)
                        .truncationMode(.tail)

                    Text(book.author)
                        .font(LexiFont.sans(11))
                        .foregroundStyle(Color.lexiInk3)
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .padding(.top, 2)

                    GeometryReader { proxy in
                        ZStack(alignment: .leading) {
                            Color.lexiRule
                            (book.progress >= 1 ? Color.lexiInk3 : accentChoice.primary)
                                .opacity(book.progress >= 1 ? 1 : 0.8)
                                .frame(width: max(0, min(1, book.progress)) * proxy.size.width)
                        }
                    }
                    .frame(height: 1)
                    .padding(.top, 8)
                    .padding(.bottom, 6)

                    HStack {
                        Text(statusText)
                        Spacer(minLength: 8)
                        Text(recentText)
                    }
                    .font(LexiFont.mono(10))
                    .foregroundStyle(Color.lexiInk3)
                }
                .padding(.horizontal, 4)
            }
            .frame(width: 168)
            .contentShape(Rectangle())
            .offset(y: isHovering ? -3 : 0)
            .animation(.easeOut(duration: 0.18), value: isHovering)
        }
        .buttonStyle(.plain)
        .focusable(false)
        .onHover { isHovering = $0 }
        .contextMenu {
            ShelfContextMenu(
                openFromBeginning: openFromBeginning,
                continueReading: continueReading,
                revealInFinder: revealInFinder,
                clearCache: clearCache,
                remove: remove
            )
        }
    }

    private var statusText: String {
        if book.progress <= 0.001 {
            return "NEW"
        }
        if book.progress >= 0.995 {
            return "已读完"
        }
        return "\(Int((book.progress * 100).rounded()))%"
    }

    private var recentText: String {
        guard let date = book.lastReadAt ?? optionalDate(book.addedAt) else {
            return "未读"
        }
        return RelativeDateTimeFormatter.lexiShelf.localizedString(for: date, relativeTo: Date())
    }

    private func optionalDate(_ date: Date) -> Date? {
        date
    }
}

private extension RelativeDateTimeFormatter {
    static let lexiShelf: RelativeDateTimeFormatter = {
        let formatter = RelativeDateTimeFormatter()
        formatter.locale = Locale(identifier: "zh_Hans")
        formatter.unitsStyle = .short
        return formatter
    }()
}
