import XCTest
@testable import lexi

final class MenuBarStreamingTests: XCTestCase {
    func testSentenceLookupDefaultsToCompletedState() {
        let lookup = SentenceLookup(
            text: "A long sentence.",
            zh: "一个长句。",
            engine: .deepseek,
            model: "deepseek-chat"
        )

        XCTAssertFalse(lookup.isStreaming)
    }

    func testStreamingUpdateGateEmitsFirstChunkThenThrottles() {
        var gate = PopupStreamingUpdateGate(interval: 0.066)
        let start = Date(timeIntervalSince1970: 0)

        XCTAssertTrue(gate.shouldEmit(now: start))
        XCTAssertFalse(gate.shouldEmit(now: start.addingTimeInterval(0.020)))
        XCTAssertTrue(gate.shouldEmit(now: start.addingTimeInterval(0.067)))
        XCTAssertFalse(gate.shouldEmit(now: start.addingTimeInterval(0.100)))
        XCTAssertTrue(gate.shouldEmit(now: start.addingTimeInterval(0.134)))
    }
}
