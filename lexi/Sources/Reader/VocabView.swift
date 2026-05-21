import AppKit
import SwiftUI

struct VocabView: View {
    let database: AppDatabase?
    var initialBookFilter: VocabBookFilter = .all
    let close: () -> Void
    let showToast: (String) -> Void
    let onChanged: () -> Void

    @State private var entries: [VocabEntry] = []
    @State private var bookTitles: [String: String] = [:]
    @State private var search = ""
    @State private var selection = Set<Int64>()
    @State private var bookFilter: VocabBookFilter

    init(
        database: AppDatabase?,
        initialBookFilter: VocabBookFilter = .all,
        close: @escaping () -> Void,
        showToast: @escaping (String) -> Void,
        onChanged: @escaping () -> Void
    ) {
        self.database = database
        self.initialBookFilter = initialBookFilter
        self.close = close
        self.showToast = showToast
        self.onChanged = onChanged
        _bookFilter = State(initialValue: initialBookFilter)
    }

    var body: some View {
        VStack(spacing: 0) {
            titleBar
            toolbar

            if filteredEntries.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "text.book.closed")
                        .font(.system(size: 28))
                        .foregroundStyle(Color.lexiInk4)
                    Text(search.isEmpty ? "还没有生词" : "没有匹配的生词")
                        .font(LexiFont.zh(13))
                        .foregroundStyle(Color.lexiInk3)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.lexiPaper)
            } else {
                List(filteredEntries, selection: $selection) { entry in
                    VocabRow(
                        entry: entry,
                        source: source(for: entry),
                        requery: { requery(entry) }
                    )
                        .tag(entry.id ?? -1)
                        .listRowBackground(Color.lexiPaper)
                }
                .listStyle(.inset)
                .scrollContentBackground(.hidden)
                .background(Color.lexiPaper)
            }
        }
        .frame(width: 720, height: 580)
        .background(Color.lexiPaper)
        .clipShape(RoundedRectangle(cornerRadius: LexiRadius.window, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: LexiRadius.window, style: .continuous)
                .stroke(Color.lexiRule, lineWidth: 1)
        }
        .task(load)
    }

    private var titleBar: some View {
        ZStack {
            HStack(spacing: 8) {
                Button(action: close) {
                    Circle()
                        .fill(Color(red: 1, green: 0.37, blue: 0.34))
                        .frame(width: 12, height: 12)
                }
                .buttonStyle(.plain)
                .help("关闭")
                Circle()
                    .fill(Color(red: 1, green: 0.74, blue: 0.18))
                    .frame(width: 12, height: 12)
                Circle()
                    .fill(Color(red: 0.16, green: 0.78, blue: 0.25))
                    .frame(width: 12, height: 12)
                Spacer()
            }
            .padding(.horizontal, 12)

            Text("生词本")
                .font(LexiFont.zh(12))
                .fontWeight(.medium)
                .foregroundStyle(Color.lexiInk2)
        }
        .frame(height: 38)
        .background(Color.lexiChrome)
        .overlay(alignment: .bottom) {
            Rectangle().fill(Color.lexiRule).frame(height: 1)
        }
    }

    private var toolbar: some View {
        HStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(Color.lexiInk3)
            TextField("搜索 word / context", text: $search)
                .textFieldStyle(.plain)
                .font(LexiFont.zh(12.5))
            Picker("来源", selection: $bookFilter) {
                Text("全部书").tag(VocabBookFilter.all)
                Text("MenuBar").tag(VocabBookFilter.menuBarOnly)
                ForEach(bookFilterOptions, id: \.id) { option in
                    Text(option.title).tag(VocabBookFilter.specific(option.id))
                }
            }
            .labelsHidden()
            .frame(width: 150)
            Spacer()
            Button(role: .destructive) {
                deleteSelected()
            } label: {
                Label("删除选中", systemImage: "trash")
                    .font(LexiFont.zh(12))
            }
            .disabled(selection.isEmpty)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color.lexiRaised)
        .overlay(alignment: .bottom) {
            Rectangle().fill(Color.lexiRule).frame(height: 1)
        }
    }

    private var filteredEntries: [VocabEntry] {
        let needle = search.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let scoped = entries.filter(matchesBookFilter)
        guard !needle.isEmpty else {
            return scoped
        }
        return scoped.filter { entry in
            entry.word.lowercased().contains(needle)
                || entry.primaryZh.lowercased().contains(needle)
                || (entry.context?.lowercased().contains(needle) ?? false)
                || source(for: entry).lowercased().contains(needle)
        }
    }

    private var bookFilterOptions: [(id: String, title: String)] {
        bookTitles
            .map { (id: $0.key, title: $0.value) }
            .sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
    }

    private func load() async {
        entries = (try? await database?.allVocabEntries()) ?? []
        bookTitles = (try? await database?.bookTitlesById()) ?? [:]
    }

    private func source(for entry: VocabEntry) -> String {
        guard let bookId = entry.seenInBookIds.first else {
            return "MenuBar"
        }
        return bookTitles[bookId] ?? bookId
    }

    private func matchesBookFilter(_ entry: VocabEntry) -> Bool {
        switch bookFilter {
        case .all:
            return true
        case .menuBarOnly:
            return entry.seenInBookIds.isEmpty
        case .specific(let bookId):
            return entry.seenInBookIds.contains(bookId)
        }
    }

    private func deleteSelected() {
        let ids = selection
        guard ids.count < 3 || confirmBulkDelete(count: ids.count) else {
            return
        }
        Task {
            try? await database?.deleteVocabEntries(ids: ids)
            selection.removeAll()
            await load()
            onChanged()
            showToast("已删除选中生词")
        }
    }

    private func requery(_ entry: VocabEntry) {
        guard let id = entry.id, let database else {
            return
        }

        Task {
            do {
                let config = await EnginePreferences.popupConfig(database: database)
                let engine = try EngineRegistry.shared.engine(for: config)
                let localEntry = LocalDictionary.lookup(entry.word)
                let context = SentenceContext(
                    fullSentence: entry.context,
                    localDictionary: localEntry
                )
                let result = try await engine.lookup(.wordLookup(word: entry.word, context: context), model: config.model)
                let snapshot = VocabSnapshot.make(word: entry.word, lookup: result, localEntry: localEntry)
                try await database.refreshVocabSnapshot(
                    id: id,
                    context: entry.context,
                    snapshot: snapshot
                )
                await load()
                onChanged()
                showToast("已重查 · \(entry.word)")
            } catch {
                showToast("重查失败 · \(error.localizedDescription)")
            }
        }
    }

    private func confirmBulkDelete(count: Int) -> Bool {
        let alert = NSAlert()
        alert.messageText = "删除 \(count) 条生词？"
        alert.informativeText = "此操作无法撤销。"
        alert.alertStyle = .warning
        alert.addButton(withTitle: "取消")
        alert.addButton(withTitle: "删除")
        return alert.runModal() == .alertSecondButtonReturn
    }
}

private struct VocabRow: View {
    let entry: VocabEntry
    let source: String
    let requery: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            VStack(alignment: .leading, spacing: 5) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(entry.word)
                        .font(LexiFont.serif(18))
                        .foregroundStyle(Color.lexiInk)
                    if let ipa = entry.ukIPA ?? entry.usIPA, !ipa.isEmpty {
                        Text(ipa)
                            .font(LexiFont.mono(11.5))
                            .foregroundStyle(Color.lexiInk3)
                    }
                }

                Text(entry.primaryZh.isEmpty ? "（需重查）" : entry.primaryZh)
                    .font(LexiFont.zh(13.5))
                    .foregroundStyle(entry.primaryZh.isEmpty ? Color.lexiInk4 : Color.lexiInk2)

                if let example = exampleLine {
                    Text(example)
                        .font(LexiFont.serif(12.5))
                        .italic()
                        .lineLimit(1)
                        .foregroundStyle(Color.lexiInk3)
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                Text(source)
                    .font(LexiFont.zh(11.5))
                    .foregroundStyle(Color.lexiInk2)
                Text(entry.addedAt.formatted(date: .abbreviated, time: .omitted))
                    .font(LexiFont.mono(10.5))
                    .foregroundStyle(Color.lexiInk3)
                Button(action: requery) {
                    Label("重查", systemImage: "arrow.clockwise")
                        .font(LexiFont.zh(11))
                }
                .buttonStyle(.plain)
                .foregroundStyle(entry.primaryZh.isEmpty ? Color.lexiAccent : Color.lexiInk3)
                .padding(.top, 3)
            }
        }
        .padding(.vertical, 8)
    }

    private var exampleLine: String? {
        if let exampleEN = entry.exampleEN, !exampleEN.isEmpty {
            return "\"\(exampleEN)\""
        }
        if let context = entry.context, !context.isEmpty {
            return "\"\(context)\""
        }
        return nil
    }
}

enum VocabBookFilter: Equatable, Hashable {
    case all
    case specific(String)
    case menuBarOnly
}
