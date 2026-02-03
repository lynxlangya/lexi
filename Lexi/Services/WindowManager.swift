//
//  WindowManager.swift
//  Lexi
//
//  Created by Codex on 12/12/25.
//

#if os(macOS)
import AppKit

@MainActor
final class WindowManager {
    static let shared = WindowManager()

    private weak var window: NSWindow?
    private var isConfigured = false
    private let defaultContentSize = NSSize(width: 360, height: 180)
    private var localMonitor: Any?
    private var globalMonitor: Any?
    private var windowDelegate: PopupWindowDelegate?
    private var allowsWindowClose: Bool = false
    private var lastAnchorPoint: NSPoint?
    private var isAutoPositioned: Bool = true

    func attach(window: NSWindow) {
        self.window = window
        if !isConfigured {
            configure(window)
            isConfigured = true
        }
    }

    func togglePopup() {
        guard let window else { return }
        if window.isVisible {
            window.orderOut(nil)
        } else {
            showPopupNearMouse()
        }
    }

    func hidePopup() {
        stopDismissMonitors()
        window?.orderOut(nil)
    }

    func showPopupNearMouse() {
        guard let window else { return }
        lastAnchorPoint = NSEvent.mouseLocation
        isAutoPositioned = true
        window.setContentSize(defaultContentSize)
        window.minSize = defaultContentSize
        if let anchor = lastAnchorPoint {
            position(window: window, near: anchor)
        }
        startDismissMonitorsIfNeeded()
        NSApp.activate(ignoringOtherApps: true)
        if window.canBecomeKey {
            window.makeKeyAndOrderFront(nil)
        } else {
            window.orderFrontRegardless()
        }
        DispatchQueue.main.async { [weak self] in
            self?.refreshLayout()
        }
    }

    func prepareForTermination() {
        allowsWindowClose = true
    }

    func refreshLayout() {
        guard let window, window.isVisible else { return }
        updateWindowToFittingSize(window)
        guard isAutoPositioned, let anchor = lastAnchorPoint else { return }
        position(window: window, near: anchor)
    }

    private func configure(_ window: NSWindow) {
        // Remove titled/toolbar area so content fills the whole window (no top bar).
        window.styleMask = [.borderless]
        window.styleMask.insert(.fullSizeContentView)
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = true
        window.level = .floating
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        window.standardWindowButton(.closeButton)?.isHidden = true
        window.standardWindowButton(.miniaturizeButton)?.isHidden = true
        window.standardWindowButton(.zoomButton)?.isHidden = true
        window.isMovableByWindowBackground = true
        window.isReleasedWhenClosed = false

        windowDelegate = PopupWindowDelegate(
            shouldAllowClose: { [weak self] in
                self?.allowsWindowClose == true
            },
            onCloseAttempt: { [weak self] in
                self?.dismissFromOutsideClick()
            },
            onMove: { [weak self] in
                self?.isAutoPositioned = false
            }
        )
        window.delegate = windowDelegate
    }

    private func startDismissMonitorsIfNeeded() {
        guard localMonitor == nil, globalMonitor == nil else { return }

        localMonitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown, .otherMouseDown]) { [weak self] event in
            guard let self else { return event }
            if let window = self.window, event.window != window, window.isVisible {
                Task { @MainActor in
                    self.dismissFromOutsideClick()
                }
            }
            return event
        }

        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown, .otherMouseDown]) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor in
                self.dismissFromOutsideClick()
            }
        }
    }

    private func stopDismissMonitors() {
        if let localMonitor {
            NSEvent.removeMonitor(localMonitor)
            self.localMonitor = nil
        }
        if let globalMonitor {
            NSEvent.removeMonitor(globalMonitor)
            self.globalMonitor = nil
        }
    }

    private func dismissFromOutsideClick() {
        hidePopup()
        NotificationCenter.default.post(name: .lexiPopupDismissRequested, object: nil)
    }

    private func updateWindowToFittingSize(_ window: NSWindow) {
        window.contentView?.layoutSubtreeIfNeeded()
        let fittingSize = window.contentView?.fittingSize ?? .zero
        guard fittingSize != .zero else { return }
        var frame = window.frame
        frame.size = fittingSize
        let screen = window.screen ?? NSScreen.main
        let visibleFrame = screen?.visibleFrame ?? .zero

        if frame.maxX > visibleFrame.maxX {
            frame.origin.x = max(visibleFrame.minX + 8, visibleFrame.maxX - frame.size.width - 8)
        }
        if frame.minX < visibleFrame.minX {
            frame.origin.x = visibleFrame.minX + 8
        }
        if frame.maxY > visibleFrame.maxY {
            frame.origin.y = max(visibleFrame.minY + 8, visibleFrame.maxY - frame.size.height - 8)
        }
        if frame.minY < visibleFrame.minY {
            frame.origin.y = visibleFrame.minY + 8
        }

        window.setFrame(frame, display: true)
    }

    private func position(window: NSWindow, near point: NSPoint) {
        let size = window.frame.size
        let screen = NSScreen.screens.first(where: { $0.frame.contains(point) }) ?? NSScreen.main
        let visibleFrame = screen?.visibleFrame ?? .zero

        var origin = NSPoint(x: point.x + 12, y: point.y - size.height - 12)

        if origin.x + size.width > visibleFrame.maxX {
            origin.x = max(visibleFrame.minX + 8, visibleFrame.maxX - size.width - 8)
        }
        if origin.x < visibleFrame.minX {
            origin.x = visibleFrame.minX + 8
        }

        if origin.y < visibleFrame.minY {
            origin.y = point.y + 12
        }
        if origin.y + size.height > visibleFrame.maxY {
            origin.y = max(visibleFrame.minY + 8, visibleFrame.maxY - size.height - 8)
        }

        window.setFrameOrigin(origin)
    }
}

private final class PopupWindowDelegate: NSObject, NSWindowDelegate {
    private let shouldAllowClose: () -> Bool
    private let onCloseAttempt: () -> Void
    private let onMove: () -> Void

    init(
        shouldAllowClose: @escaping () -> Bool,
        onCloseAttempt: @escaping () -> Void,
        onMove: @escaping () -> Void
    ) {
        self.shouldAllowClose = shouldAllowClose
        self.onCloseAttempt = onCloseAttempt
        self.onMove = onMove
        super.init()
    }

    func windowShouldClose(_ sender: NSWindow) -> Bool {
        if shouldAllowClose() {
            return true
        }
        onCloseAttempt()
        return false
    }

    func windowDidMove(_ notification: Notification) {
        onMove()
    }
}
#endif
