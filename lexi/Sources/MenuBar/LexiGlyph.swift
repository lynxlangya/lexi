import SwiftUI

struct LexiGlyph: View {
    var color: Color = .primary
    var size: CGFloat = 14

    var body: some View {
        Canvas { context, canvasSize in
            let scale = min(canvasSize.width, canvasSize.height) / 16
            let top = CGRect(x: 2 * scale, y: 5 * scale, width: 10 * scale, height: 2 * scale)
            let bottom = CGRect(x: 2 * scale, y: 9 * scale, width: 7 * scale, height: 2 * scale)
            let dot = CGRect(x: 12 * scale, y: 5 * scale, width: 2 * scale, height: 2 * scale)

            context.fill(Path(roundedRect: top, cornerRadius: scale), with: .color(color))
            context.opacity = 0.55
            context.fill(Path(roundedRect: bottom, cornerRadius: scale), with: .color(color))
            context.opacity = 1
            context.fill(Path(ellipseIn: dot), with: .color(color))
        }
        .frame(width: size, height: size)
    }
}
