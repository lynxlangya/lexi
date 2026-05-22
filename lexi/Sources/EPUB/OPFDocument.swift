import Foundation
import SwiftSoup

struct OPFDocument {
    struct ManifestItem: Equatable {
        var id: String
        var href: String
        var mediaType: String
        var properties: Set<String>
    }

    var title: String
    var author: String
    var manifest: [String: ManifestItem]
    var spine: [String]
    var navID: String?
    var ncxID: String?
    var epub2CoverID: String?

    static func rootfilePath(in containerURL: URL, limits: EPUBResourceLimits = .standard) throws -> String {
        guard FileManager.default.fileExists(atPath: containerURL.path) else {
            throw EPUBParserError.missingOPF
        }
        let data = try EPUBResourceReader.data(contentsOf: containerURL, maxBytes: limits.maxDocumentBytes)
        let document = try SwiftSoup.parseXML(data, containerURL.absoluteString)
        guard let path = try document.select("rootfile[full-path]").first()?.attr("full-path"),
              !path.isEmpty else {
            throw EPUBParserError.missingOPF
        }
        return path
    }

    static func parse(_ url: URL, limits: EPUBResourceLimits = .standard) throws -> OPFDocument {
        let data = try EPUBResourceReader.data(contentsOf: url, maxBytes: limits.maxDocumentBytes)
        let document = try SwiftSoup.parseXML(data, url.absoluteString)
        let title = try firstText(in: document, tags: ["dc:title", "title"])
        let author = try firstText(in: document, tags: ["dc:creator", "creator"])
        var manifest: [String: ManifestItem] = [:]
        for element in try document.select("manifest item").array() {
            let id = try element.attr("id")
            guard !id.isEmpty else {
                continue
            }

            let properties = Set(try element.attr("properties").split(separator: " ").map(String.init))
            manifest[id] = ManifestItem(
                id: id,
                href: try element.attr("href").normalizedEPUBPath,
                mediaType: try element.attr("media-type"),
                properties: properties
            )
        }

        let spine = try document.select("spine itemref[idref]").array()
            .map { try $0.attr("idref") }
            .filter { !$0.isEmpty }
        if spine.isEmpty {
            throw EPUBParserError.emptySpine
        }

        let navID = manifest.values.first { $0.properties.contains("nav") }?.id
        let ncxID = try document.select("spine[toc]").first()?.attr("toc").nilIfEmpty
        let epub2CoverID = try document.select("metadata meta[name=cover]").first()?.attr("content").nilIfEmpty

        return OPFDocument(
            title: title?.nilIfEmpty ?? "Untitled",
            author: author?.nilIfEmpty ?? "Unknown Author",
            manifest: manifest,
            spine: spine,
            navID: navID,
            ncxID: ncxID,
            epub2CoverID: epub2CoverID
        )
    }

    private static func firstText(in document: Document, tags: [String]) throws -> String? {
        for tag in tags {
            if let text = try document.getElementsByTag(tag).first()?.text().normalizedWhitespace, !text.isEmpty {
                return text
            }
        }
        return nil
    }
}

extension String {
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}
