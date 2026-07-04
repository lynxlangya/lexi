import Foundation

struct ReaderBook: Equatable, Identifiable, Sendable {
    let id: String
    let title: String
    let author: String
    let fileURL: URL
    let sourceBookmark: Data?
    let addedAt: Date
    let lastReadAt: Date?
    let progress: Double
    let coverData: Data?
    let coverBg: String?
    let coverInk: String?

    init(
        id: String,
        title: String,
        author: String,
        fileURL: URL,
        sourceBookmark: Data? = nil,
        addedAt: Date,
        lastReadAt: Date?,
        progress: Double,
        coverData: Data?,
        coverBg: String?,
        coverInk: String?
    ) {
        self.id = id
        self.title = title
        self.author = author
        self.fileURL = fileURL
        self.sourceBookmark = sourceBookmark
        self.addedAt = addedAt
        self.lastReadAt = lastReadAt
        self.progress = progress
        self.coverData = coverData
        self.coverBg = coverBg
        self.coverInk = coverInk
    }
}

struct ReaderChapter: Equatable, Identifiable, Sendable {
    let id: Int64
    let bookId: String
    let idx: Int
    let n: String
    let title: String
    let paragraphs: [ReaderParagraph]
}

struct ReaderParagraph: Equatable, Identifiable, Sendable {
    let id: Int64
    let ord: Int
    let en: String
}

extension ReaderBook {
    init(book: Book) {
        id = book.id
        title = book.title
        author = book.author
        fileURL = book.fileURL
        sourceBookmark = book.sourceBookmark
        addedAt = book.addedAt
        lastReadAt = book.lastReadAt
        progress = book.progress
        coverData = book.coverData
        coverBg = book.coverBg
        coverInk = book.coverInk
    }

    func updatingProgress(_ nextProgress: Double, lastReadAt nextLastReadAt: Date) -> ReaderBook {
        ReaderBook(
            id: id,
            title: title,
            author: author,
            fileURL: fileURL,
            sourceBookmark: sourceBookmark,
            addedAt: addedAt,
            lastReadAt: nextLastReadAt,
            progress: nextProgress,
            coverData: coverData,
            coverBg: coverBg,
            coverInk: coverInk
        )
    }
}
