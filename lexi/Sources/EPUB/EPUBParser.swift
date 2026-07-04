import Foundation
import SwiftSoup
import ZIPFoundation

private nonisolated let epubExtractionBufferSize = 64 * 1_024

nonisolated struct EPUBParser {
    private let fileManager: FileManager
    private let now: @Sendable () -> Date
    private let resourceLimits: EPUBResourceLimits
    private let executionProbe: @Sendable () -> Void

    init(
        fileManager: FileManager = .default,
        resourceLimits: EPUBResourceLimits = .standard,
        now: @escaping @Sendable () -> Date = Date.init,
        executionProbe: @escaping @Sendable () -> Void = {}
    ) {
        self.fileManager = fileManager
        self.resourceLimits = resourceLimits
        self.now = now
        self.executionProbe = executionProbe
    }

    @concurrent func parse(_ url: URL) async throws -> (book: Book, chapters: [(Chapter, [Paragraph])]) {
        executionProbe()
        let workingDirectory = fileManager.temporaryDirectory
            .appending(path: "LexiEPUB-\(UUID().uuidString)", directoryHint: .isDirectory)
        try fileManager.createDirectory(at: workingDirectory, withIntermediateDirectories: true)
        defer {
            try? fileManager.removeItem(at: workingDirectory)
        }

        try extractArchive(at: url, to: workingDirectory)

        let containerURL = workingDirectory.appending(path: "META-INF/container.xml")
        let opfRelativePath = try OPFDocument.rootfilePath(in: containerURL, limits: resourceLimits)
        let opfURL = try EPUBPath.resolve(opfRelativePath, relativeTo: workingDirectory, root: workingDirectory)
        guard fileManager.fileExists(atPath: opfURL.path) else {
            throw EPUBParserError.missingOPF
        }

        let opf = try OPFDocument.parse(opfURL, limits: resourceLimits)
        guard !opf.spine.isEmpty else {
            throw EPUBParserError.emptySpine
        }

        let baseURL = opfURL.deletingLastPathComponent()
        let tocEntries = try NavDocument.chapterEntries(opf: opf, baseURL: baseURL, rootURL: workingDirectory, limits: resourceLimits)
        let bookID = stableBookID(title: opf.title, author: opf.author, fileURL: url)
        let cover = try CoverExtractor.cover(for: opf, baseURL: baseURL, rootURL: workingDirectory, bookID: bookID, limits: resourceLimits)
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

        let spineDocuments = try loadSpineDocuments(opf: opf, baseURL: baseURL, rootURL: workingDirectory)
        let chapters = try chapters(from: spineDocuments, tocEntries: tocEntries, bookID: book.id)

        return (book, chapters)
    }

    private func loadSpineDocuments(opf: OPFDocument, baseURL: URL, rootURL: URL) throws -> [SpineDocument] {
        try opf.spine.enumerated().map { offset, itemID in
            guard let item = opf.manifest[itemID] else {
                throw EPUBParserError.missingManifestItem(itemID)
            }

            let url = try EPUBPath.resolve(item.href, relativeTo: baseURL, root: rootURL)
            let documentData = try EPUBResourceReader.data(contentsOf: url, maxBytes: resourceLimits.maxDocumentBytes)
            let document = try SwiftSoup.parse(documentData, url.absoluteString)
            return try SpineDocument(index: offset, href: item.href.normalizedEPUBPath, document: document)
        }
    }

    private func chapters(
        from spineDocuments: [SpineDocument],
        tocEntries: [EPUBTOCEntry],
        bookID: String
    ) throws -> [(Chapter, [Paragraph])] {
        let boundaries = resolvedBoundaries(from: tocEntries, spineDocuments: spineDocuments)
        guard !boundaries.isEmpty else {
            return try fallbackSpineChapters(from: spineDocuments, bookID: bookID)
        }

        return boundaries.enumerated().map { offset, boundary in
            let next = boundaries[safe: offset + 1]?.position
            let paragraphTexts = paragraphs(from: spineDocuments, startingAt: boundary.position, endingBefore: next)
            return (
                Chapter(id: nil, bookId: bookID, idx: offset, n: String(offset + 1), title: boundary.title),
                paragraphTexts.enumerated().map { paragraphOffset, text in
                    Paragraph(id: nil, chapterId: 0, ord: paragraphOffset, en: text)
                }
            )
        }
    }

    private func fallbackSpineChapters(from spineDocuments: [SpineDocument], bookID: String) throws -> [(Chapter, [Paragraph])] {
        spineDocuments.enumerated().map { offset, spineDocument in
            let title = spineDocument.fallbackTitle ?? "Chapter \(offset + 1)"
            return (
                Chapter(id: nil, bookId: bookID, idx: offset, n: String(offset + 1), title: title),
                spineDocument.paragraphs.enumerated().map { paragraphOffset, paragraph in
                    Paragraph(id: nil, chapterId: 0, ord: paragraphOffset, en: paragraph.text)
                }
            )
        }
    }

    private func resolvedBoundaries(from entries: [EPUBTOCEntry], spineDocuments: [SpineDocument]) -> [ResolvedChapterBoundary] {
        let boundaries = entries.compactMap { entry -> ResolvedChapterBoundary? in
            guard let position = headingPosition(for: entry.title, in: spineDocuments)
                ?? hrefPosition(for: entry.location, in: spineDocuments) else {
                return nil
            }
            return ResolvedChapterBoundary(title: entry.title, position: position)
        }

        var seen: Set<ChapterPosition> = []
        return boundaries
            .sorted { $0.position < $1.position }
            .filter { boundary in
                guard !seen.contains(boundary.position) else {
                    return false
                }
                seen.insert(boundary.position)
                return true
            }
    }

    private func headingPosition(for title: String, in spineDocuments: [SpineDocument]) -> ChapterPosition? {
        let variants = titleMatchVariants(for: title)
        for document in spineDocuments {
            if let heading = document.headings.first(where: { variants.contains($0.matchKey) }) {
                return heading.position
            }
        }
        return nil
    }

    private func hrefPosition(for location: EPUBLocation?, in spineDocuments: [SpineDocument]) -> ChapterPosition? {
        guard let location,
              let document = spineDocuments.first(where: { $0.href == location.path || ($0.href as NSString).lastPathComponent == location.path }) else {
            return nil
        }
        if let fragment = location.fragment, let ordinal = document.ordinal(forID: fragment) {
            return ChapterPosition(spineIndex: document.index, ordinal: ordinal)
        }
        return ChapterPosition(spineIndex: document.index, ordinal: 0)
    }

    private func paragraphs(
        from spineDocuments: [SpineDocument],
        startingAt start: ChapterPosition,
        endingBefore end: ChapterPosition?
    ) -> [String] {
        spineDocuments.flatMap { document -> [String] in
            document.paragraphs.compactMap { paragraph in
                let position = paragraph.position
                guard position >= start else {
                    return nil
                }
                if let end, position >= end {
                    return nil
                }
                return paragraph.text
            }
        }
    }

    private func extractArchive(at url: URL, to directory: URL) throws {
        do {
            let archive = try Archive(url: url, accessMode: .read)
            var entryCount = 0
            var declaredTotalUncompressedBytes: UInt64 = 0
            var actualTotalUncompressedBytes: UInt64 = 0
            for entry in archive {
                entryCount += 1
                guard entryCount <= resourceLimits.maxEntryCount else {
                    throw EPUBParserError.resourceLimitExceeded
                }
                guard entry.type != .symlink else {
                    throw EPUBParserError.corruptZip
                }
                guard entry.uncompressedSize <= resourceLimits.maxEntryUncompressedBytes else {
                    throw EPUBParserError.resourceLimitExceeded
                }
                guard entry.uncompressedSize <= resourceLimits.maxTotalUncompressedBytes else {
                    throw EPUBParserError.resourceLimitExceeded
                }
                guard declaredTotalUncompressedBytes <= resourceLimits.maxTotalUncompressedBytes - entry.uncompressedSize else {
                    throw EPUBParserError.resourceLimitExceeded
                }
                declaredTotalUncompressedBytes += entry.uncompressedSize

                let destination = directory.appendingPathComponent(entry.path)
                guard destination.standardizedFileURL.path.hasPrefix(directory.standardizedFileURL.path + "/") else {
                    throw EPUBParserError.corruptZip
                }
                if entry.type == .directory {
                    try fileManager.createDirectory(at: destination, withIntermediateDirectories: true)
                } else {
                    try extractFileEntry(
                        entry,
                        from: archive,
                        to: destination,
                        totalUncompressedBytes: &actualTotalUncompressedBytes
                    )
                }
            }
        } catch let error as EPUBParserError {
            throw error
        } catch {
            throw EPUBParserError.corruptZip
        }
    }

    private func extractFileEntry(
        _ entry: Entry,
        from archive: Archive,
        to destination: URL,
        totalUncompressedBytes: inout UInt64
    ) throws {
        guard !fileManager.fileExists(atPath: destination.path) else {
            throw EPUBParserError.corruptZip
        }
        try fileManager.createDirectory(at: destination.deletingLastPathComponent(), withIntermediateDirectories: true)
        guard fileManager.createFile(atPath: destination.path, contents: nil) else {
            throw EPUBParserError.corruptZip
        }

        let handle = try FileHandle(forWritingTo: destination)
        defer {
            try? handle.close()
        }

        var entryUncompressedBytes: UInt64 = 0
        do {
            _ = try archive.extract(entry, bufferSize: epubExtractionBufferSize) { data in
                entryUncompressedBytes += UInt64(data.count)
                totalUncompressedBytes += UInt64(data.count)
                guard entryUncompressedBytes <= resourceLimits.maxEntryUncompressedBytes,
                      totalUncompressedBytes <= resourceLimits.maxTotalUncompressedBytes else {
                    throw EPUBParserError.resourceLimitExceeded
                }
                try handle.write(contentsOf: data)
            }
        } catch {
            try? fileManager.removeItem(at: destination)
            throw error
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

nonisolated private struct SpineDocument {
    struct ParagraphUnit {
        var position: ChapterPosition
        var text: String
    }

    struct HeadingUnit {
        var position: ChapterPosition
        var matchKey: String
    }

    var index: Int
    var href: String
    var fallbackTitle: String?
    var paragraphs: [ParagraphUnit]
    var headings: [HeadingUnit]
    private var idOrdinals: [String: Int]

    init(index: Int, href: String, document: Document) throws {
        self.index = index
        self.href = href

        let elements = try document.select("body *").array()
        var paragraphs: [ParagraphUnit] = []
        var headings: [HeadingUnit] = []
        var idOrdinals: [String: Int] = [:]

        for (ordinal, element) in elements.enumerated() {
            let id = try element.attr("id")
            if !id.isEmpty {
                idOrdinals[id] = ordinal
            }

            let tag = element.tagName().lowercased()
            guard tag == "p" || tag.range(of: #"^h[1-6]$"#, options: .regularExpression) != nil else {
                continue
            }

            let text = try element.text().normalizedWhitespace
            guard !text.isEmpty else {
                continue
            }

            let position = ChapterPosition(spineIndex: index, ordinal: ordinal)
            if tag == "p" {
                try Self.registerBoundaryIDs(in: element, ordinal: ordinal, idOrdinals: &idOrdinals)
                paragraphs.append(ParagraphUnit(position: position, text: text))
            } else {
                try Self.registerBoundaryIDs(in: element, ordinal: ordinal, idOrdinals: &idOrdinals)
                headings.append(HeadingUnit(position: position, matchKey: text.chapterTitleMatchKey))
            }
        }

        self.fallbackTitle = try document.select("h1, h2").first()?.text().normalizedWhitespace
        self.paragraphs = paragraphs
        self.headings = headings
        self.idOrdinals = idOrdinals
    }

    func ordinal(forID id: String) -> Int? {
        idOrdinals[id]
    }

    private static func registerBoundaryIDs(in element: Element, ordinal: Int, idOrdinals: inout [String: Int]) throws {
        for node in try element.select("[id]").array() {
            let id = try node.attr("id")
            if !id.isEmpty, idOrdinals[id] == nil {
                idOrdinals[id] = ordinal
            }
        }
    }
}

nonisolated private struct ChapterPosition: Comparable, Hashable {
    var spineIndex: Int
    var ordinal: Int

    static func < (lhs: ChapterPosition, rhs: ChapterPosition) -> Bool {
        if lhs.spineIndex != rhs.spineIndex {
            return lhs.spineIndex < rhs.spineIndex
        }
        return lhs.ordinal < rhs.ordinal
    }
}

nonisolated private struct ResolvedChapterBoundary {
    var title: String
    var position: ChapterPosition
}

nonisolated enum EPUBPath {
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

nonisolated enum EPUBParserError: Error, Equatable, LocalizedError {
    case corruptZip
    case missingOPF
    case emptySpine
    case missingManifestItem(String)
    case resourceLimitExceeded

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
        case .resourceLimitExceeded:
            return "EPUB archive exceeds Lexi's import safety limits."
        }
    }
}

nonisolated struct EPUBResourceLimits: Equatable, Sendable {
    var maxEntryCount: Int
    var maxEntryUncompressedBytes: UInt64
    var maxTotalUncompressedBytes: UInt64
    var maxDocumentBytes: UInt64
    var maxCoverBytes: UInt64

    static let standard = EPUBResourceLimits(
        maxEntryCount: 2_000,
        maxEntryUncompressedBytes: 25 * 1_024 * 1_024,
        maxTotalUncompressedBytes: 200 * 1_024 * 1_024,
        maxDocumentBytes: 16 * 1_024 * 1_024,
        maxCoverBytes: 8 * 1_024 * 1_024
    )
}

nonisolated enum EPUBResourceReader {
    static func data(contentsOf url: URL, maxBytes: UInt64) throws -> Data {
        let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
        if let size = attributes[.size] as? NSNumber, size.uint64Value > maxBytes {
            throw EPUBParserError.resourceLimitExceeded
        }

        let data = try Data(contentsOf: url)
        guard UInt64(data.count) <= maxBytes else {
            throw EPUBParserError.resourceLimitExceeded
        }
        return data
    }
}

extension String {
    nonisolated var normalizedWhitespace: String {
        components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }

    nonisolated var normalizedEPUBPath: String {
        removingPercentEncoding?
            .components(separatedBy: "#")[0]
            .replacingOccurrences(of: "\\", with: "/")
            ?? self
    }

    nonisolated var epubLocation: EPUBLocation {
        let normalized = (removingPercentEncoding ?? self)
            .replacingOccurrences(of: "\\", with: "/")
        let parts = normalized.split(separator: "#", maxSplits: 1, omittingEmptySubsequences: false)
        let path = parts.first.map(String.init) ?? ""
        let fragment = parts.count > 1 ? String(parts[1]).nilIfEmpty : nil
        return EPUBLocation(path: path.normalizedEPUBPath, fragment: fragment)
    }

    nonisolated var chapterTitleMatchKey: String {
        lowercased()
            .replacingOccurrences(of: #"[^\p{L}\p{N}]+"#, with: " ", options: .regularExpression)
            .normalizedWhitespace
    }
}

private nonisolated func titleMatchVariants(for title: String) -> Set<String> {
    let pieces = title
        .replacingOccurrences(of: "\u{00a0}", with: " ")
        .components(separatedBy: ":")
        .map(\.normalizedWhitespace)
        .filter { !$0.isEmpty }
    var variants = Set(([title] + pieces).map(\.chapterTitleMatchKey))
    for piece in pieces {
        let withoutLeadingNumber = piece.replacingOccurrences(
            of: #"^\d+\s*[\.\-:]?\s*"#,
            with: "",
            options: .regularExpression
        )
        variants.insert(withoutLeadingNumber.chapterTitleMatchKey)
    }
    return variants.filter { !$0.isEmpty }
}

private extension Array {
    nonisolated subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
