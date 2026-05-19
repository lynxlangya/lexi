import Foundation
import SwiftSoup
import ZIPFoundation

struct EPUBParser {
    private let fileManager: FileManager
    private let now: @Sendable () -> Date

    init(fileManager: FileManager = .default, now: @escaping @Sendable () -> Date = Date.init) {
        self.fileManager = fileManager
        self.now = now
    }

    func parse(_ url: URL) async throws -> (book: Book, chapters: [(Chapter, [Paragraph])]) {
        let workingDirectory = fileManager.temporaryDirectory
            .appending(path: "LexiEPUB-\(UUID().uuidString)", directoryHint: .isDirectory)
        try fileManager.createDirectory(at: workingDirectory, withIntermediateDirectories: true)
        defer {
            try? fileManager.removeItem(at: workingDirectory)
        }

        try extractArchive(at: url, to: workingDirectory)

        let containerURL = workingDirectory.appending(path: "META-INF/container.xml")
        let opfRelativePath = try OPFDocument.rootfilePath(in: containerURL)
        let opfURL = try EPUBPath.resolve(opfRelativePath, relativeTo: workingDirectory, root: workingDirectory)
        guard fileManager.fileExists(atPath: opfURL.path) else {
            throw EPUBParserError.missingOPF
        }

        let opf = try OPFDocument.parse(opfURL)
        guard !opf.spine.isEmpty else {
            throw EPUBParserError.emptySpine
        }

        let baseURL = opfURL.deletingLastPathComponent()
        let navTitles = try NavDocument.chapterTitles(opf: opf, baseURL: baseURL, rootURL: workingDirectory)
        let bookID = stableBookID(title: opf.title, author: opf.author, fileURL: url)
        let cover = try CoverExtractor.cover(for: opf, baseURL: baseURL, rootURL: workingDirectory, bookID: bookID)
        let book = Book(
            id: bookID,
            title: opf.title,
            author: opf.author,
            fileURL: url,
            addedAt: now(),
            lastReadAt: nil,
            progress: 0,
            coverData: cover.data,
            coverBg: cover.fallback?.bg,
            coverInk: cover.fallback?.ink
        )

        let chapters = try opf.spine.enumerated().map { offset, itemID in
            guard let item = opf.manifest[itemID] else {
                throw EPUBParserError.missingManifestItem(itemID)
            }

            let chapterURL = try EPUBPath.resolve(item.href, relativeTo: baseURL, root: workingDirectory)
            let chapterData = try Data(contentsOf: chapterURL)
            let document = try SwiftSoup.parse(chapterData, chapterURL.absoluteString)
            let fallbackTitle = try document.select("h1, h2").first()?.text().normalizedWhitespace
            let title = navTitles[item.href.normalizedEPUBPath]
                ?? navTitles[itemID]
                ?? fallbackTitle
                ?? "Chapter \(offset + 1)"
            let chapter = Chapter(
                id: nil,
                bookId: book.id,
                idx: offset,
                n: String(offset + 1),
                title: title
            )
            let paragraphs = try document.select("p").array().enumerated().compactMap { paragraphOffset, element -> Paragraph? in
                let text = try element.text().normalizedWhitespace
                guard !text.isEmpty else {
                    return nil
                }
                return Paragraph(id: nil, chapterId: 0, ord: paragraphOffset, en: text)
            }
            return (chapter, paragraphs)
        }

        return (book, chapters)
    }

    private func extractArchive(at url: URL, to directory: URL) throws {
        do {
            let archive = try Archive(url: url, accessMode: .read)
            for entry in archive {
                let destination = directory.appendingPathComponent(entry.path)
                guard destination.standardizedFileURL.path.hasPrefix(directory.standardizedFileURL.path + "/") else {
                    throw EPUBParserError.corruptZip
                }
                _ = try archive.extract(entry, to: destination)
            }
        } catch let error as EPUBParserError {
            throw error
        } catch {
            throw EPUBParserError.corruptZip
        }
    }

    private func stableBookID(title: String, author: String, fileURL: URL) -> String {
        let source = "\(title)|\(author)|\(fileURL.lastPathComponent)"
        let hash = source.utf8.reduce(UInt64(14_695_981_039_346_656_037)) { partial, byte in
            (partial ^ UInt64(byte)) &* 1_099_511_628_211
        }
        return "book-\(String(hash, radix: 16))"
    }
}

enum EPUBPath {
    static func resolve(_ path: String, relativeTo baseURL: URL, root: URL) throws -> URL {
        let resolved = URL(
            fileURLWithPath: path.normalizedEPUBPath,
            relativeTo: baseURL
        ).standardizedFileURL
        let rootPath = root.standardizedFileURL.path
        guard resolved.path == rootPath || resolved.path.hasPrefix(rootPath + "/") else {
            throw EPUBParserError.corruptZip
        }
        return resolved
    }
}

enum EPUBParserError: Error, Equatable, LocalizedError {
    case corruptZip
    case missingOPF
    case emptySpine
    case missingManifestItem(String)

    var errorDescription: String? {
        switch self {
        case .corruptZip:
            return "EPUB archive is not a readable zip file."
        case .missingOPF:
            return "EPUB package document is missing."
        case .emptySpine:
            return "EPUB spine is empty."
        case .missingManifestItem(let id):
            return "EPUB spine references missing manifest item: \(id)."
        }
    }
}

extension String {
    var normalizedWhitespace: String {
        components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }

    var normalizedEPUBPath: String {
        removingPercentEncoding?
            .components(separatedBy: "#")[0]
            .replacingOccurrences(of: "\\", with: "/")
            ?? self
    }
}
