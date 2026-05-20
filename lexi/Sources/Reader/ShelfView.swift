import AppKit
import SwiftUI
import UniformTypeIdentifiers

enum ShelfSort: String, CaseIterable, Identifiable {
    case recent = "最近"
    case title = "书名"
    case progress = "进度"

    var id: String { rawValue }
}

struct ShelfView: View {
    let books: [ReaderBook]
    let currentBookID: String?
    let openBook: (ReaderBook) -> Void
    let continueReading: (ReaderBook) -> Void
    let revealInFinder: (ReaderBook) -> Void
    let requestClearCache: (ReaderBook) -> Void
    let requestRemove: (ReaderBook) -> Void
    let importEPUBs: ([URL]) -> Void

    @State private var query = ""
    @State private var sort = ShelfSort.recent
    @State private var isDropTargeted = false
    @AppStorage("reader.accent") private var accent = "copper"

    private var accentChoice: ReaderAccentChoice {
        ReaderAccentChoice(storageValue: accent)
    }

    private let columns = [
        GridItem(.adaptive(minimum: 160, maximum: 200), spacing: 28)
    ]

    var body: some View {
        ZStack {
            Color.lexiPaper.ignoresSafeArea()

            VStack(spacing: 0) {
                toolbar

                ScrollView {
                    if filteredBooks.isEmpty {
                        emptyState
                    } else {
                        shelfContent
                    }
                }
                .scrollIndicators(.automatic)
            }

            if isDropTargeted {
                dropOverlay
            }
        }
        .onDrop(
            of: [epubDropType],
            delegate: ShelfDropDelegate(isTargeted: $isDropTargeted, importURLs: importEPUBs)
        )
        .searchable(text: $query, placement: .toolbar, prompt: "搜索书名 / 作者")
    }

    private var toolbar: some View {
        HStack(spacing: 12) {
            Picker("排序", selection: $sort) {
                ForEach(ShelfSort.allCases) { option in
                    Text(option.rawValue).tag(option)
                }
            }
            .pickerStyle(.segmented)
            .frame(width: 174)
            .focusable(false)

            Spacer()

            Button {
                openPanel()
            } label: {
                Label("添加 EPUB", systemImage: "plus")
                    .font(LexiFont.sans(12))
                    .fontWeight(.medium)
            }
            .buttonStyle(.plain)
            .foregroundStyle(accentChoice.primary)
            .padding(.horizontal, 14)
            .frame(height: 28)
            .background(accentChoice.soft)
            .clipShape(RoundedRectangle(cornerRadius: LexiRadius.control, style: .continuous))
            .focusable(false)
        }
        .padding(.top, 12)
        .padding(.horizontal, 56)
    }

    private var shelfContent: some View {
        VStack(alignment: .leading, spacing: 36) {
            if !continueBooks.isEmpty {
                ShelfSectionHeader(title: "继续阅读")
                bookGrid(continueBooks)
            }

            if !shelfBooks.isEmpty {
                ShelfSectionHeader(title: "书架")
                bookGrid(shelfBooks)
            }
        }
        .padding(.horizontal, 56)
        .padding(.top, 32)
        .padding(.bottom, 64)
    }

    private func bookGrid(_ values: [ReaderBook]) -> some View {
        LazyVGrid(columns: columns, alignment: .leading, spacing: 36) {
            ForEach(values) { book in
                BookCard(
                    book: book,
                    isCurrent: book.id == currentBookID,
                    open: { openBook(book) },
                    continueReading: { continueReading(book) },
                    revealInFinder: { revealInFinder(book) },
                    clearCache: { requestClearCache(book) },
                    remove: { requestRemove(book) }
                )
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Text(emptyTitle)
                .font(LexiFont.serif(19))
                .italic()
                .foregroundStyle(Color.lexiInk2)

            if query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Button {
                    openPanel()
                } label: {
                    Text("添加第一本 EPUB")
                        .font(LexiFont.sans(12.5))
                }
                .buttonStyle(.plain)
                .foregroundStyle(accentChoice.primary)
                .focusable(false)
            } else {
                Button {
                    query = ""
                } label: {
                    Text("清除搜索")
                        .font(LexiFont.sans(12.5))
                }
                .buttonStyle(.plain)
                .foregroundStyle(accentChoice.primary)
                .focusable(false)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 96)
    }

    private var dropOverlay: some View {
        RoundedRectangle(cornerRadius: LexiRadius.window, style: .continuous)
            .fill(accentChoice.soft)
            .overlay {
                RoundedRectangle(cornerRadius: LexiRadius.window, style: .continuous)
                    .stroke(accentChoice.primary, style: StrokeStyle(lineWidth: 2, dash: [8, 6]))
            }
            .overlay {
                Text("松开以加入书架")
                    .font(LexiFont.serif(17))
                    .foregroundStyle(Color.lexiInk)
                    .padding(.horizontal, 26)
                    .padding(.vertical, 18)
                    .background(Color.lexiPaper)
                    .clipShape(RoundedRectangle(cornerRadius: LexiRadius.window, style: .continuous))
                    .shadow(color: .black.opacity(0.20), radius: 28, y: 18)
            }
            .padding(16)
            .allowsHitTesting(false)
    }

    private var emptyTitle: String {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            return "书架还是空的"
        }
        return "\"\(trimmed)\" — 书架里没有这本"
    }

    private var filteredBooks: [ReaderBook] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let filtered = trimmed.isEmpty ? books : books.filter { book in
            book.title.lowercased().contains(trimmed) || book.author.lowercased().contains(trimmed)
        }
        return sorted(filtered)
    }

    private var continueBooks: [ReaderBook] {
        guard query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return []
        }
        return books
            .filter { $0.lastReadAt != nil || $0.progress > 0 }
            .sorted { lhs, rhs in
                (lhs.lastReadAt ?? lhs.addedAt) > (rhs.lastReadAt ?? rhs.addedAt)
            }
            .prefix(3)
            .map { $0 }
    }

    private var shelfBooks: [ReaderBook] {
        let continueIDs = Set(continueBooks.map(\.id))
        return filteredBooks.filter { !continueIDs.contains($0.id) }
    }

    private func sorted(_ values: [ReaderBook]) -> [ReaderBook] {
        switch sort {
        case .recent:
            return values.sorted {
                let lhsDate = $0.lastReadAt ?? $0.addedAt
                let rhsDate = $1.lastReadAt ?? $1.addedAt
                if lhsDate == rhsDate {
                    return $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending
                }
                return lhsDate > rhsDate
            }
        case .title:
            return values.sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
        case .progress:
            return values.sorted {
                if $0.progress == $1.progress {
                    return $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending
                }
                return $0.progress > $1.progress
            }
        }
    }

    private func openPanel() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [epubDropType]
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.begin { response in
            guard response == .OK else {
                return
            }
            importEPUBs(panel.urls)
        }
    }
}

private struct ShelfSectionHeader: View {
    let title: String

    var body: some View {
        Text(title)
            .font(LexiFont.sans(11))
            .fontWeight(.semibold)
            .foregroundStyle(Color.lexiInk3)
            .textCase(.uppercase)
    }
}

let epubDropType = UTType(filenameExtension: "epub") ?? UTType("org.idpf.epub-container")!
