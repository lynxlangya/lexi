import XCTest
@testable import lexi

final class ReaderImportToastTests: XCTestCase {
    func testImportOutcomeMessages() {
        XCTAssertEqual(ReaderImportToast.message(for: .inserted, title: "Book"), "已加入书架 · Book")
        XCTAssertEqual(ReaderImportToast.message(for: .contentReplaced, title: "Book"), "已更新内容 · 原译文缓存已失效")
        XCTAssertEqual(ReaderImportToast.message(for: .unchanged, title: "Book"), "内容无变化 · Book")
    }
}
