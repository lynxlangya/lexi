import Foundation
import SwiftSoup

struct EPUBLocation: Equatable {
    var path: String
    var fragment: String?
}

struct EPUBTOCEntry: Equatable {
    enum Source {
        case epub3Nav
        case epub2NCX
        case contentsPage
    }

    var title: String
    var location: EPUBLocation?
    var source: Source
}

enum NavDocument {
    static func chapterEntries(
        opf: OPFDocument,
        baseURL: URL,
        rootURL: URL,
        limits: EPUBResourceLimits = .standard
    ) throws -> [EPUBTOCEntry] {
        var declaredEntries: [EPUBTOCEntry] = []
        if let navID = opf.navID, let navItem = opf.manifest[navID] {
            let navURL = try EPUBPath.resolve(navItem.href, relativeTo: baseURL, root: rootURL)
            declaredEntries = try epub3Entries(navURL: navURL, limits: limits)
        }

        if declaredEntries.isEmpty, let ncxID = opf.ncxID, let ncxItem = opf.manifest[ncxID] {
            let ncxURL = try EPUBPath.resolve(ncxItem.href, relativeTo: baseURL, root: rootURL)
            declaredEntries = try epub2Entries(ncxURL: ncxURL, limits: limits)
        }

        let contentsEntries = try contentsPageEntries(opf: opf, baseURL: baseURL, rootURL: rootURL, limits: limits)
        if shouldPreferContentsPage(over: declaredEntries, contentsEntries: contentsEntries) {
            return contentsEntries
        }

        return declaredEntries.isEmpty ? contentsEntries : declaredEntries
    }

    static func chapterTitles(opf: OPFDocument, baseURL: URL, rootURL: URL) throws -> [String: String] {
        try chapterEntries(opf: opf, baseURL: baseURL, rootURL: rootURL)
            .reduce(into: [:]) { result, entry in
                guard let location = entry.location else {
                    return
                }
                result[location.path] = entry.title
                result[(location.path as NSString).lastPathComponent] = entry.title
            }
    }

    private static func epub3Entries(navURL: URL, limits: EPUBResourceLimits) throws -> [EPUBTOCEntry] {
        guard FileManager.default.fileExists(atPath: navURL.path) else {
            return []
        }

        let documentData = try EPUBResourceReader.data(contentsOf: navURL, maxBytes: limits.maxDocumentBytes)
        let document = try SwiftSoup.parse(documentData, navURL.absoluteString)
        let links = try document.select("nav[epub\\:type=toc] a[href], nav[type=toc] a[href], nav a[href]").array()
        return try links.compactMap { element in
            let href = try element.attr("href")
            let title = try element.text().normalizedWhitespace
            guard !href.isEmpty, !title.isEmpty else {
                return nil
            }
            return EPUBTOCEntry(title: title, location: href.epubLocation, source: .epub3Nav)
        }
    }

    private static func epub2Entries(ncxURL: URL, limits: EPUBResourceLimits) throws -> [EPUBTOCEntry] {
        guard FileManager.default.fileExists(atPath: ncxURL.path) else {
            return []
        }

        let documentData = try EPUBResourceReader.data(contentsOf: ncxURL, maxBytes: limits.maxDocumentBytes)
        let document = try SwiftSoup.parseXML(documentData, ncxURL.absoluteString)
        let points = try document.getElementsByTag("navPoint").array()
        return try points.compactMap { point in
            let title = try point.getElementsByTag("text").first()?.text().normalizedWhitespace ?? ""
            let href = try point.select("content[src]").first()?.attr("src") ?? ""
            guard !title.isEmpty else {
                return nil
            }
            return EPUBTOCEntry(title: title, location: href.nilIfEmpty?.epubLocation, source: .epub2NCX)
        }
    }

    private static func contentsPageEntries(
        opf: OPFDocument,
        baseURL: URL,
        rootURL: URL,
        limits: EPUBResourceLimits
    ) throws -> [EPUBTOCEntry] {
        var entries: [EPUBTOCEntry] = []
        for itemID in opf.spine {
            guard let item = opf.manifest[itemID],
                  item.mediaType.contains("html") || item.mediaType.contains("xhtml") else {
                continue
            }

            let documentURL = try EPUBPath.resolve(item.href, relativeTo: baseURL, root: rootURL)
            guard FileManager.default.fileExists(atPath: documentURL.path) else {
                continue
            }

            let documentData = try EPUBResourceReader.data(contentsOf: documentURL, maxBytes: limits.maxDocumentBytes)
            let document = try SwiftSoup.parse(documentData, documentURL.absoluteString)
            let containers = try document.select("[role=doc-toc], nav[epub\\:type=toc], nav[type=toc]").array()
            let candidates = containers.isEmpty && isLikelyContentsDocument(document)
                ? [document.body()].compactMap { $0 }
                : containers
            for container in candidates {
                entries.append(contentsOf: try contentsEntries(in: container))
            }
        }

        return deduplicated(entries)
    }

    private static func contentsEntries(in container: Element) throws -> [EPUBTOCEntry] {
        try container.select("li, p").array().compactMap { element in
            let title = cleanedTitle(try element.text())
            guard isLikelyTOCTitle(title) else {
                return nil
            }

            let href = try element.select("a[href]").first()?.attr("href")
            return EPUBTOCEntry(title: title, location: href?.nilIfEmpty?.epubLocation, source: .contentsPage)
        }
    }

    private static func isLikelyContentsDocument(_ document: Document) -> Bool {
        let bodyHeading = (try? document.select("body h1, body h2")
            .first()?
            .text()
            .normalizedWhitespace
            .lowercased()) ?? ""
        let documentTitle = (try? document.select("title")
            .first()?
            .text()
            .normalizedWhitespace
            .lowercased()) ?? ""
        return bodyHeading == "contents"
            || bodyHeading == "table of contents"
            || documentTitle == "contents"
            || documentTitle == "table of contents"
    }

    private static func isLikelyTOCTitle(_ title: String) -> Bool {
        guard title.count > 1 else {
            return false
        }
        let lower = title.lowercased()
        return lower != "contents" && lower != "table of contents" && !title.hasPrefix("_")
    }

    private static func cleanedTitle(_ raw: String) -> String {
        raw.replacingOccurrences(of: "\u{00a0}", with: " ")
            .normalizedWhitespace
    }

    private static func deduplicated(_ entries: [EPUBTOCEntry]) -> [EPUBTOCEntry] {
        var seen: Set<String> = []
        return entries.filter { entry in
            let key = "\(entry.title)|\(entry.location?.path ?? "")|\(entry.location?.fragment ?? "")"
            guard !seen.contains(key) else {
                return false
            }
            seen.insert(key)
            return true
        }
    }

    private static func shouldPreferContentsPage(over declaredEntries: [EPUBTOCEntry], contentsEntries: [EPUBTOCEntry]) -> Bool {
        guard !contentsEntries.isEmpty else {
            return false
        }
        guard !declaredEntries.isEmpty else {
            return true
        }
        if declaredEntries.count < 5, contentsEntries.count > declaredEntries.count {
            return true
        }
        return contentsEntries.count >= declaredEntries.count + 2
    }
}
