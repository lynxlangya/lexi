import XCTest
@testable import lexi

@MainActor
final class PopupPanelTests: XCTestCase {
    func testPopupFrameUsesScreenIntersectingAnchor() {
        let main = PopupPanel.ScreenBounds(
            frame: CGRect(x: 0, y: 0, width: 1_000, height: 800),
            visibleFrame: CGRect(x: 0, y: 0, width: 1_000, height: 800)
        )
        let secondary = PopupPanel.ScreenBounds(
            frame: CGRect(x: 1_000, y: 0, width: 800, height: 600),
            visibleFrame: CGRect(x: 1_000, y: 0, width: 800, height: 600)
        )

        let frame = PopupPanel.panelFrame(
            for: CGSize(width: 260, height: 180),
            anchor: CGRect(x: 1_380, y: 280, width: 40, height: 24),
            contentInset: 18,
            screens: [main, secondary],
            mainScreen: main
        )

        XCTAssertGreaterThanOrEqual(frame.minX + 18, secondary.visibleFrame.minX + 16)
        XCTAssertLessThanOrEqual(frame.maxX - 18, secondary.visibleFrame.maxX - 16)
    }

    func testMouseDownInsidePanelDoesNotClosePopup() {
        let panelFrame = CGRect(x: 100, y: 100, width: 300, height: 180)

        XCTAssertFalse(PopupPanel.shouldCloseForMouseDown(
            eventWindowIsPanel: true,
            locationInScreen: CGPoint(x: 20, y: 20),
            panelFrame: panelFrame,
            pinned: false
        ))
        XCTAssertFalse(PopupPanel.shouldCloseForMouseDown(
            eventWindowIsPanel: false,
            locationInScreen: CGPoint(x: 180, y: 140),
            panelFrame: panelFrame,
            pinned: false
        ))
    }

    func testMouseDownOutsidePanelClosesOnlyWhenUnpinned() {
        let panelFrame = CGRect(x: 100, y: 100, width: 300, height: 180)
        let outside = CGPoint(x: 30, y: 30)

        XCTAssertTrue(PopupPanel.shouldCloseForMouseDown(
            eventWindowIsPanel: false,
            locationInScreen: outside,
            panelFrame: panelFrame,
            pinned: false
        ))
        XCTAssertFalse(PopupPanel.shouldCloseForMouseDown(
            eventWindowIsPanel: false,
            locationInScreen: outside,
            panelFrame: panelFrame,
            pinned: true
        ))
    }

    func testEscapeKeyClosesPopupFromLocalOrGlobalMonitor() {
        XCTAssertTrue(PopupPanel.shouldCloseForEscape(keyCode: 53))
        XCTAssertFalse(PopupPanel.shouldCloseForEscape(keyCode: 36))
    }
}
