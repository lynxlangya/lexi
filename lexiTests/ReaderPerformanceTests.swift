import AppKit
import XCTest
@testable import lexi

@MainActor
final class ReaderPerformanceTests: XCTestCase {
    override func tearDown() {
        CoverImageCache.removeAll()
        super.tearDown()
    }

    func testCoverImageCacheReusesDecodedImageForStableCover() throws {
        CoverImageCache.removeAll()
        let coverData = try Self.pngData(red: 0.45, green: 0.24, blue: 0.12)
        let book = ReaderBook(
            id: "book-a",
            title: "Book A",
            author: "Author",
            fileURL: URL(fileURLWithPath: "/tmp/book-a.epub"),
            addedAt: Date(lexiTimestamp: 1_800_000_000),
            lastReadAt: nil,
            progress: 0,
            coverData: coverData,
            coverBg: nil,
            coverInk: nil
        )

        let first = try XCTUnwrap(CoverImageCache.image(for: book))
        let second = try XCTUnwrap(CoverImageCache.image(for: book))

        XCTAssertTrue(first === second)
    }

    func testCoverImageCacheKeyIncludesCoverFingerprint() throws {
        let first = try Self.pngData(red: 0.45, green: 0.24, blue: 0.12)
        let second = try Self.pngData(red: 0.12, green: 0.34, blue: 0.56)

        XCTAssertNotEqual(
            CoverImageCache.cacheKey(bookID: "book-a", coverData: first),
            CoverImageCache.cacheKey(bookID: "book-a", coverData: second)
        )
    }

    func testVocabEntryBookIndexPredecodesSeenInBooksByEntryId() {
        let entries = [
            Self.vocabEntry(id: 1, seenInBooks: "[\"book-a\",\"book-b\"]"),
            Self.vocabEntry(id: 2, seenInBooks: "[]"),
            Self.vocabEntry(id: nil, seenInBooks: "[\"ignored\"]"),
        ]

        let index = VocabEntryBookIndex.makeBookIdsByEntryId(entries)

        XCTAssertEqual(index[1], ["book-a", "book-b"])
        XCTAssertEqual(index[2], [])
        XCTAssertEqual(index.count, 2)
    }

    private static func vocabEntry(id: Int64?, seenInBooks: String) -> VocabEntry {
        VocabEntry(
            id: id,
            word: "observe",
            normalizedWord: "observe",
            context: nil,
            primaryZh: "观察",
            sensesJSON: "[]",
            ukIPA: nil,
            usIPA: nil,
            exampleEN: nil,
            exampleZH: nil,
            seenInBooks: seenInBooks,
            seenGlobally: false,
            mastered: false,
            addedAt: Date(lexiTimestamp: 1_800_000_000),
            updatedAt: Date(lexiTimestamp: 1_800_000_000),
            masteredAt: nil
        )
    }

    private static func pngData(red: CGFloat, green: CGFloat, blue: CGFloat) throws -> Data {
        let rep = try XCTUnwrap(NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: 4,
            pixelsHigh: 4,
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: 0,
            bitsPerPixel: 0
        ))
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
        NSColor(red: red, green: green, blue: blue, alpha: 1).setFill()
        NSRect(x: 0, y: 0, width: 4, height: 4).fill()
        NSGraphicsContext.restoreGraphicsState()
        return try XCTUnwrap(rep.representation(using: .png, properties: [:]))
    }
}
