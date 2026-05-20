import AppKit
import SwiftUI

enum LexiFont {
    static func serif(_ size: CGFloat) -> Font {
        #if DEBUG
        _ = serifDiagnostic
        #endif
        return Font.system(size: size, design: .serif)
    }

    static func sans(_ size: CGFloat) -> Font {
        Font.system(size: size, design: .default)
    }

    static func zh(_ size: CGFloat) -> Font {
        Font.system(size: size, design: .default)
    }

    static func mono(_ size: CGFloat) -> Font {
        Font.system(size: size, design: .monospaced)
    }

    #if DEBUG
    private static let serifDiagnostic: Void = {
        let probeSize: CGFloat = 17
        let serifDescriptor = NSFont.systemFont(ofSize: probeSize)
            .fontDescriptor
            .withDesign(.serif)
        let resolved: String
        if let serifDescriptor,
           let nsFont = NSFont(descriptor: serifDescriptor, size: probeSize) {
            resolved = nsFont.fontName.hasPrefix(".")
                ? String(nsFont.fontName.dropFirst())
                : nsFont.fontName
        } else {
            resolved = "<system default - .serif design not available>"
        }
        print("[Lexi] serif resolved to: \(resolved)")
    }()
    #endif
}
