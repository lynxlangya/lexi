import Foundation

struct ReaderBook: Equatable, Identifiable, Sendable {
    let id: String
    let title: String
    let author: String
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
