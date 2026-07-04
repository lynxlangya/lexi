import AppKit
import SwiftUI

@MainActor
final class PopupPanel {
    private let panel: NSPanel
    private let contentInset: CGFloat = 18
    private var globalOutsideMonitor: Any?
    private var localOutsideMonitor: Any?
    private var globalEscMonitor: Any?
    private var localEscMonitor: Any?
    private(set) var pinned = false
    var onDismiss: (() -> Void)?

    struct ScreenBounds {
        let frame: CGRect
        let visibleFrame: CGRect
    }

    init() {
        panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 420, height: 240),
            styleMask: [.nonactivatingPanel, .borderless, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        panel.isFloatingPanel = true
        panel.level = .floating
        panel.becomesKeyOnlyIfNeeded = true
        panel.hidesOnDeactivate = false
        panel.hasShadow = false
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
    }

    var isVisible: Bool {
        panel.isVisible
    }

    func show(kind: PopupKind, near anchor: CGRect, actions: PopupActions, pinned: Bool) {
        self.pinned = pinned
        let view = PopupContent(kind: kind, pinned: pinned, actions: actions)
            .padding(contentInset)
        let host = NSHostingView(rootView: view)
        let size = host.fittingSize
        host.frame = NSRect(origin: .zero, size: size)
        host.wantsLayer = true
        host.layer?.backgroundColor = NSColor.clear.cgColor

        panel.contentView = host
        panel.setFrame(frame(for: size, anchor: anchor), display: true)
        panel.orderFrontRegardless()
        installMonitors()
    }

    func close() {
        panel.orderOut(nil)
        removeMonitors()
        onDismiss?()
    }

    func setPinned(_ value: Bool) {
        pinned = value
    }

    private func installMonitors() {
        if globalOutsideMonitor == nil {
            globalOutsideMonitor = NSEvent.addGlobalMonitorForEvents(matching: .leftMouseDown) { [weak self] event in
                Task { @MainActor in
                    self?.closeIfNeeded(forMouseDown: event)
                }
            }
        }

        if localOutsideMonitor == nil {
            localOutsideMonitor = NSEvent.addLocalMonitorForEvents(matching: .leftMouseDown) { [weak self] event in
                Task { @MainActor in
                    self?.closeIfNeeded(forMouseDown: event)
                }
                return event
            }
        }

        if globalEscMonitor == nil {
            globalEscMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
                Task { @MainActor in
                    self?.closeIfNeeded(forEscape: event)
                }
            }
        }

        if localEscMonitor == nil {
            localEscMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
                Task { @MainActor in
                    self?.closeIfNeeded(forEscape: event)
                }
                return event
            }
        }
    }

    private func removeMonitors() {
        if let globalOutsideMonitor {
            NSEvent.removeMonitor(globalOutsideMonitor)
            self.globalOutsideMonitor = nil
        }
        if let localOutsideMonitor {
            NSEvent.removeMonitor(localOutsideMonitor)
            self.localOutsideMonitor = nil
        }
        if let globalEscMonitor {
            NSEvent.removeMonitor(globalEscMonitor)
            self.globalEscMonitor = nil
        }
        if let localEscMonitor {
            NSEvent.removeMonitor(localEscMonitor)
            self.localEscMonitor = nil
        }
    }

    private func frame(for size: CGSize, anchor: CGRect) -> CGRect {
        let screens = NSScreen.screens.map { ScreenBounds(frame: $0.frame, visibleFrame: $0.visibleFrame) }
        let mainScreen = NSScreen.main.map { ScreenBounds(frame: $0.frame, visibleFrame: $0.visibleFrame) }
        return Self.panelFrame(
            for: size,
            anchor: anchor,
            contentInset: contentInset,
            screens: screens,
            mainScreen: mainScreen
        )
    }

    private func closeIfNeeded(forMouseDown event: NSEvent) {
        guard panel.isVisible else {
            return
        }
        if Self.shouldCloseForMouseDown(
            eventWindowIsPanel: event.window === panel,
            locationInScreen: event.locationInScreen,
            panelFrame: panel.frame,
            pinned: pinned
        ) {
            close()
        }
    }

    private func closeIfNeeded(forEscape event: NSEvent) {
        guard panel.isVisible, Self.shouldCloseForEscape(keyCode: event.keyCode) else {
            return
        }
        close()
    }

    nonisolated static func panelFrame(
        for size: CGSize,
        anchor: CGRect,
        contentInset: CGFloat,
        screens: [ScreenBounds],
        mainScreen: ScreenBounds?
    ) -> CGRect {
        let fallbackFrame = CGRect(x: 0, y: 0, width: 1_440, height: 900)
        let screenFrame = (
            screens.first { $0.frame.intersects(anchor) } ??
                mainScreen ??
                ScreenBounds(frame: fallbackFrame, visibleFrame: fallbackFrame)
        ).visibleFrame
        let margin: CGFloat = 16
        let gap: CGFloat = 10
        let visualWidth = max(0, size.width - contentInset * 2)
        let visualHeight = max(0, size.height - contentInset * 2)
        var visualX = anchor.midX - visualWidth / 2
        visualX = min(max(visualX, screenFrame.minX + margin), screenFrame.maxX - visualWidth - margin)

        let aboveY = anchor.minY - visualHeight - gap
        let belowY = anchor.maxY + gap
        let fitsBelow = belowY + visualHeight <= screenFrame.maxY - margin
        let fitsAbove = aboveY >= screenFrame.minY + margin
        let roomBelow = screenFrame.maxY - margin - belowY
        let roomAbove = aboveY - (screenFrame.minY + margin)

        var visualY: CGFloat
        if fitsBelow {
            visualY = belowY
        } else if fitsAbove {
            visualY = aboveY
        } else {
            visualY = roomBelow >= roomAbove ? belowY : aboveY
        }
        visualY = min(max(visualY, screenFrame.minY + margin), screenFrame.maxY - visualHeight - margin)

        return NSRect(origin: CGPoint(x: visualX - contentInset, y: visualY - contentInset), size: size)
    }

    nonisolated static func shouldCloseForMouseDown(
        eventWindowIsPanel: Bool,
        locationInScreen: CGPoint,
        panelFrame: CGRect,
        pinned: Bool
    ) -> Bool {
        guard !pinned, !eventWindowIsPanel else {
            return false
        }
        return !panelFrame.contains(locationInScreen)
    }

    nonisolated static func shouldCloseForEscape(keyCode: UInt16) -> Bool {
        keyCode == 53
    }
}

private extension NSEvent {
    var locationInScreen: CGPoint {
        NSEvent.mouseLocation
    }
}
