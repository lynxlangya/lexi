import AppKit
import SwiftUI

enum LexiFont {
    static func serif(_ size: CGFloat) -> Font {
        return Font.system(size: size, design: .serif)
    }

    static func nsSerif(_ size: CGFloat) -> NSFont {
        let descriptor = NSFont.systemFont(ofSize: size)
            .fontDescriptor
            .withDesign(.serif)
        if let descriptor,
           let font = NSFont(descriptor: descriptor, size: size) {
            return font
        }
        return NSFont.systemFont(ofSize: size)
    }

    static func nsSans(_ size: CGFloat) -> NSFont {
        NSFont.systemFont(ofSize: size)
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
}
