import Foundation

@MainActor
final class TerminationFlushRegistry {
    typealias Flush = () async -> Void

    static let shared = TerminationFlushRegistry()
    nonisolated static let timeoutNanoseconds: UInt64 = 2_000_000_000

    private var flush: Flush?

    func register(_ flush: @escaping Flush) {
        self.flush = flush
    }

    func unregister() {
        flush = nil
    }

    func takeFlush() -> Flush? {
        defer {
            flush = nil
        }
        return flush
    }

    @discardableResult
    static func runWithTimeout(
        _ flush: @escaping Flush,
        timeoutNanoseconds: UInt64 = timeoutNanoseconds
    ) async -> Bool {
        await withTaskGroup(of: Bool.self) { group in
            group.addTask {
                await flush()
                return true
            }
            group.addTask {
                try? await Task.sleep(nanoseconds: timeoutNanoseconds)
                return false
            }

            let didFlush = await group.next() ?? false
            group.cancelAll()
            return didFlush
        }
    }
}
