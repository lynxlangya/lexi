import Foundation

nonisolated protocol TranslationEngine {
    var id: EngineID { get }

    func translate(_ paragraphs: [String], model: String) -> AsyncThrowingStream<TranslationChunk, Error>
    func ping(model: String) async throws -> PingResult
}

nonisolated struct TranslationChunk: Equatable, Sendable {
    let index: Int
    let text: String
}

nonisolated enum PingResult: Equatable, Sendable {
    case ok
    case keyOkModelUnknown
    case fail(reason: String)
}

nonisolated enum EngineError: Error, Equatable, LocalizedError, Sendable {
    case missingAPIKey(EngineID)
    case invalidResponse
    case httpStatus(Int, String)
    case paragraphFailed(index: Int, reason: String)

    var errorDescription: String? {
        switch self {
        case .missingAPIKey(let engine):
            return "Missing API key for \(engine.rawValue)."
        case .invalidResponse:
            return "Invalid engine response."
        case .httpStatus(let status, let reason):
            return "HTTP \(status): \(reason)"
        case .paragraphFailed(let index, let reason):
            return "Paragraph \(index) failed: \(reason)"
        }
    }
}

nonisolated protocol EngineHTTPClient: Sendable {
    func data(for request: URLRequest) async throws -> (Data, HTTPURLResponse)
    func bytes(for request: URLRequest) async throws -> (AsyncThrowingStream<Data, Error>, HTTPURLResponse)
}

nonisolated struct URLSessionEngineHTTPClient: EngineHTTPClient {
    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    func data(for request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw EngineError.invalidResponse
        }
        return (data, httpResponse)
    }

    func bytes(for request: URLRequest) async throws -> (AsyncThrowingStream<Data, Error>, HTTPURLResponse) {
        let (bytes, response) = try await session.bytes(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw EngineError.invalidResponse
        }

        let stream = AsyncThrowingStream<Data, Error> { continuation in
            let task = Task {
                do {
                    var buffer = Data()
                    for try await byte in bytes {
                        buffer.append(byte)
                        if buffer.count >= 1024 {
                            continuation.yield(buffer)
                            buffer.removeAll(keepingCapacity: true)
                        }
                    }
                    if !buffer.isEmpty {
                        continuation.yield(buffer)
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in
                task.cancel()
            }
        }

        return (stream, httpResponse)
    }
}

extension HTTPURLResponse {
    nonisolated var isSuccess: Bool {
        (200..<300).contains(statusCode)
    }
}

nonisolated func engineErrorReason(from data: Data) -> String {
    if let response = try? JSONDecoder().decode(EngineErrorResponse.self, from: data) {
        return response.error.message
    }
    return String(data: data, encoding: .utf8)?.normalizedEngineReason ?? "Unknown engine error"
}

nonisolated private struct EngineErrorResponse: Decodable {
    struct Payload: Decodable {
        var message: String
    }

    var error: Payload
}

private extension String {
    nonisolated var normalizedEngineReason: String {
        components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }
}
