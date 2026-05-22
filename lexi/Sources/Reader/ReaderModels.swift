import Foundation

struct ReaderBook: Equatable, Identifiable, Sendable {
    let id: String
    let title: String
    let author: String
    let fileURL: URL
    let addedAt: Date
    let lastReadAt: Date?
    let progress: Double
    let coverData: Data?
    let coverBg: String?
    let coverInk: String?
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
            addedAt: addedAt,
            lastReadAt: nextLastReadAt,
            progress: nextProgress,
            coverData: coverData,
            coverBg: coverBg,
            coverInk: coverInk
        )
    }
}
