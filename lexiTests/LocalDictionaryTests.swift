import XCTest
@testable import lexi

final class LocalDictionaryTests: XCTestCase {
    func testLookupExtractsIPAAndPartsOfSpeechFromDefinitionProvider() {
        let entry = LocalDictionary.lookup("observe") { _ in
            """
            observe |əbˈzɜːv| /əbˈzɝːv/
            verb: notice or perceive something and register it as significant.
            """
        }

        XCTAssertEqual(entry?.ukIPA, "/əbˈzɜːv/")
        XCTAssertEqual(entry?.usIPA, "/əbˈzɝːv/")
        XCTAssertEqual(entry?.partsOfSpeech, ["v."])
        XCTAssertTrue(entry?.rawDefinition?.contains("notice or perceive") == true)
    }

    func testLookupReturnsNilWhenNoDefinitionIsAvailable() {
        let entry = LocalDictionary.lookup("not-a-word") { _ in nil }

        XCTAssertNil(entry)
    }
}
