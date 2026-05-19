import Foundation
import SwiftSoup

enum NavDocument {
    static func chapterTitles(opf: OPFDocument, baseURL: URL, rootURL: URL) throws -> [String: String] {
        if let navID = opf.navID, let navItem = opf.manifest[navID] {
            let navURL = try EPUBPath.resolve(navItem.href, relativeTo: baseURL, root: rootURL)
            let titles = try epub3Titles(navURL: navURL)
            if !titles.isEmpty {
                return titles
            }
        }

        if let ncxID = opf.ncxID, let ncxItem = opf.manifest[ncxID] {
            let ncxURL = try EPUBPath.resolve(ncxItem.href, relativeTo: baseURL, root: rootURL)
            let titles = try epub2Titles(ncxURL: ncxURL)
            if !titles.isEmpty {
                return titles
            }
        }

        return [:]
    }

    private static func epub3Titles(navURL: URL) throws -> [String: String] {
        guard FileManager.default.fileExists(atPath: navURL.path) else {
            return [:]
        }

        let document = try SwiftSoup.parse(try Data(contentsOf: navURL), navURL.absoluteString)
        let links = try document.select("nav[epub\\:type=toc] a[href], nav[type=toc] a[href], nav a[href]").array()
        return try links.reduce(into: [:]) { result, element in
            let href = try element.attr("href").normalizedEPUBPath
            let title = try element.text().normalizedWhitespace
            if !href.isEmpty, !title.isEmpty {
                result[href] = title
                result[(href as NSString).lastPathComponent] = title
            }
        }
    }

    private static func epub2Titles(ncxURL: URL) throws -> [String: String] {
        guard FileManager.default.fileExists(atPath: ncxURL.path) else {
            return [:]
        }

        let document = try SwiftSoup.parseXML(try Data(contentsOf: ncxURL), ncxURL.absoluteString)
        let points = try document.getElementsByTag("navPoint").array()
        return try points.reduce(into: [:]) { result, point in
            guard let content = try point.select("content[src]").first() else {
                return
            }

            let href = try content.attr("src").normalizedEPUBPath
            let title = try point.getElementsByTag("text").first()?.text().normalizedWhitespace ?? ""
            if !href.isEmpty, !title.isEmpty {
                result[href] = title
                result[(href as NSString).lastPathComponent] = title
            }
        }
    }
}
