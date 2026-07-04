import XCTest
@testable import lexi

@MainActor
final class TerminationFlushRegistryTests: XCTestCase {
    func testApplicationTerminatesImmediatelyWithoutRegisteredFlush() {
        TerminationFlushRegistry.shared.unregister()

        let reply = LexiAppDelegate().applicationShouldTerminate(NSApp)

        XCTAssertEqual(reply, .terminateNow)
    }

    func testTakeFlushReturnsRegisteredClosureOnce() async throws {
        let registry = TerminationFlushRegistry()
        var flushCount = 0
        registry.register {
            flushCount += 1
        }

        let flush = try XCTUnwrap(registry.takeFlush())
        XCTAssertNil(registry.takeFlush())

        await flush()

        XCTAssertEqual(flushCount, 1)
    }

    func testRunWithTimeoutReturnsTrueWhenFlushCompletesFirst() async {
        var didFlush = false

        let completed = await TerminationFlushRegistry.runWithTimeout(
            {
                didFlush = true
            },
            timeoutNanoseconds: 100_000_000
        )

        XCTAssertTrue(completed)
        XCTAssertTrue(didFlush)
    }

    func testRunWithTimeoutReturnsFalseWhenFlushHangs() async {
        let startedAt = Date()

        let completed = await TerminationFlushRegistry.runWithTimeout(
            {
                try? await Task.sleep(nanoseconds: 5_000_000_000)
            },
            timeoutNanoseconds: 50_000_000
        )

        XCTAssertFalse(completed)
        XCTAssertLessThan(Date().timeIntervalSince(startedAt), 1)
    }
}
