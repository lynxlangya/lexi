import Foundation

enum CoverExtractor {
    struct Cover: Equatable {
        var data: Data?
        var fallback: FallbackCover?
    }

    struct FallbackCover: Equatable {
        var bg: String
        var ink: String
    }

    private static let palette = [
        FallbackCover(bg: "#d8c4a0", ink: "#1f1b15"),
        FallbackCover(bg: "#9e8a6c", ink: "#fbf8f1"),
        FallbackCover(bg: "#384a5c", ink: "#f5f1e8"),
        FallbackCover(bg: "#5c4b3a", ink: "#ebe3d0"),
        FallbackCover(bg: "#a89478", ink: "#1f1b15"),
        FallbackCover(bg: "#b89878", ink: "#1f1b15"),
        FallbackCover(bg: "#3d4434", ink: "#ebe3d0"),
        FallbackCover(bg: "#7a3a2a", ink: "#f5f1e8"),
    ]

    static func cover(for opf: OPFDocument, baseURL: URL, rootURL: URL, bookID: String) throws -> Cover {
        let coverItem = opf.manifest.values.first { $0.properties.contains("cover-image") }
            ?? opf.epub2CoverID.flatMap { opf.manifest[$0] }

        if let coverItem {
            let coverURL = try EPUBPath.resolve(coverItem.href, relativeTo: baseURL, root: rootURL)
            if FileManager.default.fileExists(atPath: coverURL.path) {
                return Cover(data: try Data(contentsOf: coverURL), fallback: nil)
            }
        }

        return Cover(data: nil, fallback: fallback(for: bookID))
    }

    private static func fallback(for bookID: String) -> FallbackCover {
        let value = bookID.utf8.reduce(0) { ($0 &* 31) &+ Int($1) }
        return palette[abs(value) % palette.count]
    }
}
