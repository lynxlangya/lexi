import Foundation

enum ReaderTranslationMode: String, CaseIterable {
    case both
    case en
    case zh

    var next: ReaderTranslationMode {
        switch self {
        case .both:
            return .en
        case .en:
            return .zh
        case .zh:
            return .both
        }
    }
}
