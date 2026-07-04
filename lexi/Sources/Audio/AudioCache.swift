import Foundation

nonisolated enum AudioCachePolicy {
    static let maxBytes: Int64 = 500 * 1024 * 1024
}

nonisolated enum AudioCacheLocation {
    static func directory() throws -> URL {
        let support = try FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let directory = support
            .appending(path: "Lexi", directoryHint: .isDirectory)
            .appending(path: "AudioCache", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }

    static func fileURL(cacheKey: String, format: String) throws -> URL {
        try directory().appending(path: "\(cacheKey).\(format)")
    }

    static func removeFiles(
        at urls: [URL],
        cacheDirectory explicitCacheDirectory: URL? = nil,
        fileManager: FileManager = .default
    ) {
        guard let cacheDirectory = try? (explicitCacheDirectory ?? directory()).standardizedFileURL else {
            return
        }
        for url in urls {
            let fileURL = url.standardizedFileURL
            guard fileURL.path.hasPrefix(cacheDirectory.path + "/") else {
                continue
            }
            try? fileManager.removeItem(at: url)
        }
    }
}

extension Notification.Name {
    static let lexiAudioCacheWillClear = Notification.Name("lexi.audioCacheWillClear")
}
