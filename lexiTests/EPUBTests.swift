import XCTest
import ZIPFoundation
@testable import lexi

final class EPUBTests: XCTestCase {
    func testParseAndImportEPUBWithCover() async throws {
        let fixture = try fixtureURL("gatsby", "epub")
        let parser = EPUBParser(now: { Date(lexiTimestamp: 1_800_000_100) })

        let payload = try await parser.parse(fixture)

        XCTAssertEqual(payload.book.title, "The Great Gatsby")
        XCTAssertEqual(payload.book.author, "F. Scott Fitzgerald")
        XCTAssertEqual(payload.book.coverData, Data([0x89, 0x50, 0x4E, 0x47]))
        XCTAssertNil(payload.book.coverBg)
        XCTAssertEqual(payload.chapters.count, 2)
        XCTAssertEqual(payload.chapters[0].0.title, "Chapter I")
        XCTAssertEqual(payload.chapters[0].1.first?.en, "In my younger and more vulnerable years my father gave me some advice.")
        XCTAssertEqual(payload.chapters[1].1.last?.en, "So we beat on, boats against the current, borne back ceaselessly into the past.")

        let database = try AppDatabase.makeTransient()
        try await database.importBook(payload)

        let bookCount = try await database.bookCount()
        let chapterCount = try await database.chapterCount()
        let paragraphCount = try await database.paragraphCount()
        XCTAssertEqual(bookCount, 1)
        XCTAssertEqual(chapterCount, 2)
        XCTAssertEqual(paragraphCount, 4)
    }

    func testParseEPUBWithoutCoverUsesFallbackPalette() async throws {
        let fixture = try makeEPUBFixture(hasCover: false)
        let parser = EPUBParser(now: { Date(lexiTimestamp: 1_800_000_100) })

        let payload = try await parser.parse(fixture)

        XCTAssertNil(payload.book.coverData)
        XCTAssertNotNil(payload.book.coverBg)
        XCTAssertNotNil(payload.book.coverInk)
    }

    func testParserUsesContentsTOCWhenSpineIsSplitIntoInternalFiles() async throws {
        let fixture = try makeSplitSpineEPUBFixture()
        let parser = EPUBParser(now: { Date(lexiTimestamp: 1_800_000_100) })

        let payload = try await parser.parse(fixture)

        XCTAssertEqual(payload.chapters.map(\.0.title), [
            "Introduction: THREE SLEEPLESS NIGHTS",
            "1. CREATING ALIEN MINDS",
            "2. ALIGNING THE ALIEN",
        ])
        XCTAssertEqual(payload.chapters.count, 3)
        XCTAssertEqual(payload.chapters[0].1.map(\.en), ["Intro paragraph."])
        XCTAssertEqual(payload.chapters[1].1.map(\.en), ["Chapter one paragraph."])
        XCTAssertEqual(payload.chapters[2].1.map(\.en), ["Chapter two starts here.", "Chapter two continues in another split file."])
    }

    func testCorruptZipProducesSpecificError() async throws {
        let url = FileManager.default.temporaryDirectory.appending(path: "\(UUID().uuidString).epub")
        try Data("not a zip".utf8).write(to: url)
        defer {
            try? FileManager.default.removeItem(at: url)
        }

        await XCTAssertThrowsErrorAsync(try await EPUBParser().parse(url)) { error in
            XCTAssertEqual(error as? EPUBParserError, .corruptZip)
        }
    }

    func testMissingOPFProducesSpecificError() async throws {
        let fixture = try makeArchive(entries: [
            "mimetype": "application/epub+zip",
            "META-INF/container.xml": """
            <?xml version="1.0"?>
            <container version="1.0" xmlns="urn:oasis:names:tc:opendocument:xmlns:container">
              <rootfiles>
                <rootfile full-path="OPS/missing.opf" media-type="application/oebps-package+xml"/>
              </rootfiles>
            </container>
            """,
        ])

        await XCTAssertThrowsErrorAsync(try await EPUBParser().parse(fixture)) { error in
            XCTAssertEqual(error as? EPUBParserError, .missingOPF)
        }
    }

    func testEmptySpineProducesSpecificError() async throws {
        let fixture = try makeArchive(entries: baseEntries(opfBody: """
        <metadata xmlns:dc="http://purl.org/dc/elements/1.1/">
          <dc:title>The Great Gatsby</dc:title>
          <dc:creator>F. Scott Fitzgerald</dc:creator>
        </metadata>
        <manifest>
          <item id="chap1" href="chap1.xhtml" media-type="application/xhtml+xml"/>
        </manifest>
        <spine/>
        """))

        await XCTAssertThrowsErrorAsync(try await EPUBParser().parse(fixture)) { error in
            XCTAssertEqual(error as? EPUBParserError, .emptySpine)
        }
    }

    func testManifestPathOutsideArchiveRootFailsAsCorruptZip() async throws {
        let fixture = try makeArchive(entries: baseEntries(opfBody: """
        <metadata xmlns:dc="http://purl.org/dc/elements/1.1/">
          <dc:title>The Great Gatsby</dc:title>
          <dc:creator>F. Scott Fitzgerald</dc:creator>
        </metadata>
        <manifest>
          <item id="chap1" href="../../outside.xhtml" media-type="application/xhtml+xml"/>
        </manifest>
        <spine>
          <itemref idref="chap1"/>
        </spine>
        """))

        await XCTAssertThrowsErrorAsync(try await EPUBParser().parse(fixture)) { error in
            XCTAssertEqual(error as? EPUBParserError, .corruptZip)
        }
    }

    private func makeEPUBFixture(hasCover: Bool) throws -> URL {
        var opfBody = """
        <metadata xmlns:dc="http://purl.org/dc/elements/1.1/">
          <dc:title>The Great Gatsby</dc:title>
          <dc:creator>F. Scott Fitzgerald</dc:creator>
          \(hasCover ? "<meta name=\"cover\" content=\"cover\"/>" : "")
        </metadata>
        <manifest>
          <item id="nav" href="nav.xhtml" media-type="application/xhtml+xml" properties="nav"/>
          <item id="chap1" href="chap1.xhtml" media-type="application/xhtml+xml"/>
          <item id="chap2" href="chap2.xhtml" media-type="application/xhtml+xml"/>
        """
        if hasCover {
            opfBody += "\n  <item id=\"cover\" href=\"cover.png\" media-type=\"image/png\" properties=\"cover-image\"/>"
        }
        opfBody += """

        </manifest>
        <spine>
          <itemref idref="chap1"/>
          <itemref idref="chap2"/>
        </spine>
        """

        var entries = baseEntries(opfBody: opfBody)
        entries["OPS/nav.xhtml"] = """
        <?xml version="1.0" encoding="utf-8"?>
        <html xmlns="http://www.w3.org/1999/xhtml">
          <body>
            <nav epub:type="toc">
              <ol>
                <li><a href="chap1.xhtml">Chapter I</a></li>
                <li><a href="chap2.xhtml">Chapter II</a></li>
              </ol>
            </nav>
          </body>
        </html>
        """
        entries["OPS/chap1.xhtml"] = """
        <?xml version="1.0" encoding="utf-8"?>
        <html xmlns="http://www.w3.org/1999/xhtml">
          <body>
            <h1>Fallback One</h1>
            <p>In my younger and more <span>vulnerable</span> years my father gave me some advice.</p>
            <p>Whenever you feel like criticizing any one, remember that all the people in this world haven't had the advantages that you've had.</p>
          </body>
        </html>
        """
        entries["OPS/chap2.xhtml"] = """
        <?xml version="1.0" encoding="utf-8"?>
        <html xmlns="http://www.w3.org/1999/xhtml">
          <body>
            <h1>Fallback Two</h1>
            <p>Gatsby believed in the green light, the orgastic future that year by year recedes before us.</p>
            <p>So we beat on, boats against the current, borne back ceaselessly into the past.</p>
          </body>
        </html>
        """
        if hasCover {
            entries["OPS/cover.png"] = Data([0x89, 0x50, 0x4E, 0x47])
        }

        return try makeArchive(entries: entries)
    }

    private func makeSplitSpineEPUBFixture() throws -> URL {
        let opfBody = """
        <metadata xmlns:dc="http://purl.org/dc/elements/1.1/">
          <dc:title>Split Spine Book</dc:title>
          <dc:creator>Example Author</dc:creator>
        </metadata>
        <manifest>
          <item id="contents" href="contents.xhtml" media-type="application/xhtml+xml"/>
          <item id="split1" href="split1.xhtml" media-type="application/xhtml+xml"/>
          <item id="split2" href="split2.xhtml" media-type="application/xhtml+xml"/>
          <item id="split3" href="split3.xhtml" media-type="application/xhtml+xml"/>
          <item id="ncx" href="toc.ncx" media-type="application/x-dtbncx+xml"/>
        </manifest>
        <spine toc="ncx">
          <itemref idref="contents"/>
          <itemref idref="split1"/>
          <itemref idref="split2"/>
          <itemref idref="split3"/>
        </spine>
        """
        var entries = baseEntries(opfBody: opfBody)
        entries["OPS/toc.ncx"] = """
        <?xml version="1.0" encoding="utf-8"?>
        <ncx xmlns="http://www.daisy.org/z3986/2005/ncx/">
          <navMap>
            <navPoint id="part" playOrder="1">
              <navLabel><text>PART I</text></navLabel>
              <content src="split1.xhtml#intro"/>
            </navPoint>
          </navMap>
        </ncx>
        """
        entries["OPS/contents.xhtml"] = """
        <?xml version="1.0" encoding="utf-8"?>
        <html xmlns="http://www.w3.org/1999/xhtml">
          <body>
            <div role="doc-toc">
              <h1>Contents</h1>
              <p><a href="split1.xhtml#intro">Introduction:</a> THREE SLEEPLESS NIGHTS</p>
              <p><a href="split2.xhtml#chapter-one">1.</a> CREATING ALIEN MINDS</p>
              <p><a href="split2.xhtml#chapter-two">2.</a> ALIGNING THE ALIEN</p>
            </div>
          </body>
        </html>
        """
        entries["OPS/split1.xhtml"] = """
        <?xml version="1.0" encoding="utf-8"?>
        <html xmlns="http://www.w3.org/1999/xhtml">
          <body>
            <h1 id="intro">Introduction</h1>
            <h2>THREE SLEEPLESS NIGHTS</h2>
            <p>Intro paragraph.</p>
          </body>
        </html>
        """
        entries["OPS/split2.xhtml"] = """
        <?xml version="1.0" encoding="utf-8"?>
        <html xmlns="http://www.w3.org/1999/xhtml">
          <body>
            <h1 id="chapter-one">1 CREATING ALIEN MINDS</h1>
            <p>Chapter one paragraph.</p>
            <h1><span id="chapter-two"></span>2 ALIGNING THE ALIEN</h1>
            <p>Chapter two starts here.</p>
          </body>
        </html>
        """
        entries["OPS/split3.xhtml"] = """
        <?xml version="1.0" encoding="utf-8"?>
        <html xmlns="http://www.w3.org/1999/xhtml">
          <body>
            <p>Chapter two continues in another split file.</p>
          </body>
        </html>
        """
        return try makeArchive(entries: entries)
    }

    private func fixtureURL(_ name: String, _ fileExtension: String) throws -> URL {
        let bundle = Bundle(for: EPUBTests.self)
        return try XCTUnwrap(
            bundle.url(forResource: name, withExtension: fileExtension, subdirectory: "Fixtures")
                ?? bundle.url(forResource: name, withExtension: fileExtension)
        )
    }

    private func baseEntries(opfBody: String) -> [String: Any] {
        [
            "mimetype": "application/epub+zip",
            "META-INF/container.xml": """
            <?xml version="1.0"?>
            <container version="1.0" xmlns="urn:oasis:names:tc:opendocument:xmlns:container">
              <rootfiles>
                <rootfile full-path="OPS/content.opf" media-type="application/oebps-package+xml"/>
              </rootfiles>
            </container>
            """,
            "OPS/content.opf": """
            <?xml version="1.0" encoding="UTF-8"?>
            <package xmlns="http://www.idpf.org/2007/opf" version="3.0">
              \(opfBody)
            </package>
            """,
        ]
    }

    private func makeArchive(entries: [String: Any]) throws -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appending(path: "LexiEPUBTests-\(UUID().uuidString)", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let archiveURL = directory.appending(path: "gatsby.epub")
        let archive = try Archive(url: archiveURL, accessMode: .create)

        for (path, value) in entries {
            let data: Data
            if let string = value as? String {
                data = Data(string.utf8)
            } else if let rawData = value as? Data {
                data = rawData
            } else {
                XCTFail("Unsupported fixture entry type for \(path)")
                continue
            }

            try archive.addEntry(
                with: path,
                type: .file,
                uncompressedSize: Int64(data.count),
                compressionMethod: .none,
                provider: { position, size in
                    data.subdata(in: Int(position)..<min(Int(position) + size, data.count))
                }
            )
        }

        return archiveURL
    }
}

private func XCTAssertThrowsErrorAsync<T>(
    _ expression: @autoclosure () async throws -> T,
    _ verify: (Error) -> Void,
    file: StaticString = #filePath,
    line: UInt = #line
) async {
    do {
        _ = try await expression()
        XCTFail("Expected expression to throw", file: file, line: line)
    } catch {
        verify(error)
    }
}
