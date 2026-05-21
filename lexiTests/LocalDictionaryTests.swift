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

    func testPronounDoesNotAlsoMatchNounPartOfSpeech() {
        let entry = LocalDictionary.lookup("they") { _ in
            "they pronoun: used to refer to two or more people."
        }

        XCTAssertEqual(entry?.partsOfSpeech, ["pron."])
    }

    func testPartOfSpeechOrderIsStable() {
        let definition = "lead noun: a metal. verb: guide someone."

        for _ in 0..<5 {
            let entry = LocalDictionary.lookup("lead") { _ in definition }
            XCTAssertEqual(entry?.partsOfSpeech, ["n.", "v."])
        }
    }

    func testLookupExtractsRColoredAmericanIPA() {
        let entry = LocalDictionary.lookup("bird") { _ in
            "bird |bɜːd| /bɝd/ noun: an animal."
        }

        XCTAssertEqual(entry?.ukIPA, "/bɜːd/")
        XCTAssertEqual(entry?.usIPA, "/bɝd/")
    }
}
