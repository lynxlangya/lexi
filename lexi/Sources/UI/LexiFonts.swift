import AppKit
import CoreText
import Foundation
import SwiftUI

enum LexiFont {
    static func serif(_ size: CGFloat) -> Font {
        if let descriptor = newYorkRegularDescriptor {
            return Font(CTFontCreateWithFontDescriptor(descriptor, size, nil))
        }

        return firstAvailableFont(
            named: [
                "Charter-Roman",
                "IowanOldStyle-Roman",
                "Georgia",
                "TimesNewRomanPSMT",
            ],
            size: size
        )
    }

    static func sans(_ size: CGFloat) -> Font {
        Font(NSFont.systemFont(ofSize: size, weight: .regular))
    }

    static func zh(_ size: CGFloat) -> Font {
        firstAvailableFont(
            named: [
                "PingFangSC-Regular",
                "HiraginoSansGB-W3",
            ],
            size: size
        )
    }

    static func mono(_ size: CGFloat) -> Font {
        Font(NSFont.monospacedSystemFont(ofSize: size, weight: .regular))
    }

    private static let newYorkRegularDescriptor: CTFontDescriptor? = {
        // New York is a hidden system font, so resolve it by descriptor instead of name.
        let url = URL(fileURLWithPath: "/System/Library/Fonts/NewYork.ttf")
        let descriptors = CTFontManagerCreateFontDescriptorsFromURL(url as CFURL) as? [CTFontDescriptor]

        return descriptors?.first { descriptor in
            let name = CTFontDescriptorCopyAttribute(descriptor, kCTFontNameAttribute) as? String
            return name == ".NewYork-Regular"
        }
    }()

    private static func firstAvailableFont(named names: [String], size: CGFloat) -> Font {
        for name in names {
            if let font = NSFont(name: name, size: size) {
                return Font(font)
            }
        }

        return Font(NSFont.systemFont(ofSize: size, weight: .regular))
    }
}
