import AppKit
import SwiftUI

enum ReaderFontChoice: String, Equatable {
    case newYork = "New York"
    case charter = "Charter"
    case iowanOldStyle = "Iowan Old Style"
    case georgia = "Georgia"

    init(storageValue: String) {
        self = Self(rawValue: storageValue) ?? .newYork
    }

    func serif(_ size: CGFloat) -> Font {
        switch self {
        case .newYork:
            return LexiFont.serif(size)
        case .charter:
            return customFont(["Charter-Roman", "Charter"], size: size)
        case .iowanOldStyle:
            return customFont(["IowanOldStyle-Roman", "Iowan Old Style"], size: size)
        case .georgia:
            return customFont(["Georgia"], size: size)
        }
    }

    private func customFont(_ names: [String], size: CGFloat) -> Font {
        for name in names where NSFont(name: name, size: size) != nil {
            return .custom(name, size: size)
        }
        return LexiFont.serif(size)
    }
}

enum ReaderLineHeightChoice: String, Equatable {
    case tight
    case normal
    case loose

    init(storageValue: String) {
        self = Self(rawValue: storageValue) ?? .normal
    }

    var englishSpacingRatio: CGFloat {
        switch self {
        case .tight:
            return 0.48
        case .normal:
            return 0.72
        case .loose:
            return 0.96
        }
    }

    var chineseSpacingRatio: CGFloat {
        switch self {
        case .tight:
            return 0.54
        case .normal:
            return 0.78
        case .loose:
            return 1.02
        }
    }
}

struct ReaderThemeChoice {
    let paper: Color
    let raised: Color
    let chrome: Color
    let ink: Color
    let ink2: Color
    let ink3: Color
    let ink4: Color
    let rule: Color
    let rule2: Color
    let shimmer1: Color
    let shimmer2: Color

    init(storageValue: String) {
        if storageValue == "candlelit" {
            paper = Color(red: 0.105, green: 0.092, blue: 0.075)
            raised = Color(red: 0.145, green: 0.125, blue: 0.102)
            chrome = Color(red: 0.128, green: 0.110, blue: 0.090)
            ink = Color(red: 0.910, green: 0.855, blue: 0.765)
            ink2 = Color(red: 0.750, green: 0.680, blue: 0.570)
            ink3 = Color(red: 0.560, green: 0.500, blue: 0.420)
            ink4 = Color(red: 0.390, green: 0.345, blue: 0.292)
            rule = Color(red: 0.245, green: 0.205, blue: 0.160)
            rule2 = Color(red: 0.335, green: 0.280, blue: 0.215)
            shimmer1 = Color(red: 0.195, green: 0.165, blue: 0.132)
            shimmer2 = Color(red: 0.310, green: 0.250, blue: 0.188)
        } else {
            paper = .lexiPaper
            raised = .lexiRaised
            chrome = .lexiChrome
            ink = .lexiInk
            ink2 = .lexiInk2
            ink3 = .lexiInk3
            ink4 = .lexiInk4
            rule = .lexiRule
            rule2 = .lexiRule2
            shimmer1 = .lexiShimmer1
            shimmer2 = .lexiShimmer2
        }
    }
}

struct ReaderAccentChoice {
    let primary: Color
    let soft: Color
    let faint: Color

    init(storageValue: String) {
        switch storageValue {
        case "moss":
            primary = Color(red: 0.36, green: 0.52, blue: 0.36)
            soft = Color(red: 0.36, green: 0.52, blue: 0.36).opacity(0.16)
            faint = Color(red: 0.36, green: 0.52, blue: 0.36).opacity(0.08)
        case "plum":
            primary = Color(red: 0.46, green: 0.38, blue: 0.56)
            soft = Color(red: 0.46, green: 0.38, blue: 0.56).opacity(0.16)
            faint = Color(red: 0.46, green: 0.38, blue: 0.56).opacity(0.08)
        case "ink":
            primary = .lexiInk2
            soft = Color.lexiInk2.opacity(0.12)
            faint = Color.lexiInk2.opacity(0.06)
        default:
            primary = .lexiAccent
            soft = .lexiAccentSoft
            faint = .lexiAccentFaint
        }
    }
}

struct ReaderRuntimePreferences {
    let font: ReaderFontChoice
    let lineHeight: ReaderLineHeightChoice
    let theme: ReaderThemeChoice
    let accent: ReaderAccentChoice

    init(
        serif: String,
        lineHeight: String,
        theme: String,
        accent: String
    ) {
        font = ReaderFontChoice(storageValue: serif)
        self.lineHeight = ReaderLineHeightChoice(storageValue: lineHeight)
        self.theme = ReaderThemeChoice(storageValue: theme)
        self.accent = ReaderAccentChoice(storageValue: accent)
    }
}
