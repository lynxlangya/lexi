import SwiftUI

struct BookCover: View {
    let book: ReaderBook

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
        .frame(width: 144, height: 216)
        .clipped()
        .clipShape(RoundedRectangle(cornerRadius: 2, style: .continuous))
        .shadow(color: .black.opacity(0.18), radius: 14, y: 6)
    }

    private var nsImage: NSImage? {
        guard let coverData = book.coverData else {
            return nil
        }
        return NSImage(data: coverData)
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
