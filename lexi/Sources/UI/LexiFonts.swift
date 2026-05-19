import SwiftUI

enum LexiFont {
    static func serif(_ size: CGFloat) -> Font {
        Font.custom("NewYork-Regular", size: size)
    }

    static func sans(_ size: CGFloat) -> Font {
        Font.custom("SF Pro Text", size: size)
    }

    static func zh(_ size: CGFloat) -> Font {
        Font.custom("PingFang SC", size: size)
    }

    static func mono(_ size: CGFloat) -> Font {
        Font.custom("SF Mono", size: size)
    }
}
