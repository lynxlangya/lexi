import Foundation
import SwiftUI

enum CoverImageCache {
    private static let cache: NSCache<NSString, NSImage> = {
        let cache = NSCache<NSString, NSImage>()
        cache.countLimit = 200
        return cache
    }()

    static func image(for book: ReaderBook) -> NSImage? {
        guard let coverData = book.coverData else {
            return nil
        }

        let key = cacheKey(bookID: book.id, coverData: coverData) as NSString
        if let cached = cache.object(forKey: key) {
            return cached
        }

        guard let image = NSImage(data: coverData) else {
            return nil
        }
        cache.setObject(image, forKey: key)
        return image
    }

    static func cacheKey(bookID: String, coverData: Data) -> String {
        let fingerprint = String(format: "%016llx", coverFingerprint(coverData))
        return "\(bookID):\(coverData.count):\(fingerprint)"
    }

    private static func coverFingerprint(_ data: Data) -> UInt64 {
        data.reduce(UInt64(14_695_981_039_346_656_037)) { hash, byte in
            (hash ^ UInt64(byte)) &* 1_099_511_628_211
        }
    }

    #if DEBUG
    static func removeAll() {
        cache.removeAllObjects()
    }
    #endif
}

struct BookCover: View {
    let book: ReaderBook
    var width: CGFloat = 144
    var height: CGFloat = 216
    var cornerRadius: CGFloat = 2
    var shadowRadius: CGFloat = 14
    var shadowYOffset: CGFloat = 6

    var body: some View {
        Group {
            if let image = nsImage {
                Image(nsImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                fallbackCover
            }
        }
        .frame(width: width, height: height)
        .clipped()
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .shadow(color: .black.opacity(0.18), radius: shadowRadius, y: shadowYOffset)
    }

    private var nsImage: NSImage? {
        CoverImageCache.image(for: book)
    }

    private var fallbackCover: some View {
        ZStack {
            coverColor(book.coverBg, fallback: Color(red: 0.85, green: 0.77, blue: 0.63))

            VStack(alignment: .leading, spacing: 0) {
                Rectangle()
                    .fill(inkColor.opacity(0.45))
                    .frame(width: 58, height: 1)

                Spacer()

                VStack(alignment: .leading, spacing: 7) {
                    Text(book.title)
                        .font(LexiFont.serif(15))
                        .fontWeight(.medium)
                        .lineSpacing(15 * 0.15)
                        .foregroundStyle(inkColor)
                        .fixedSize(horizontal: false, vertical: true)
                        .lineLimit(5)

                    Text(book.author)
                        .font(LexiFont.serif(9.5))
                        .italic()
                        .lineSpacing(9.5 * 0.3)
                        .foregroundStyle(inkColor.opacity(0.82))
                        .fixedSize(horizontal: false, vertical: true)
                        .lineLimit(3)
                }

                Spacer()

                Text("LEXI")
                    .font(LexiFont.mono(7))
                    .foregroundStyle(inkColor.opacity(0.5))
            }
            .padding(14)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        }
    }

    private var inkColor: Color {
        coverColor(book.coverInk, fallback: Color(red: 0.12, green: 0.10, blue: 0.08))
    }

    private func coverColor(_ hex: String?, fallback: Color) -> Color {
        guard let hex, let color = Color(hex: hex) else {
            return fallback
        }
        return color
    }
}

private extension Color {
    init?(hex: String) {
        var raw = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if raw.hasPrefix("#") {
            raw.removeFirst()
        }

        guard raw.count == 6, let value = Int(raw, radix: 16) else {
            return nil
        }

        let red = Double((value >> 16) & 0xFF) / 255
        let green = Double((value >> 8) & 0xFF) / 255
        let blue = Double(value & 0xFF) / 255
        self.init(red: red, green: green, blue: blue)
    }
}
