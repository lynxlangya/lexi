import AppKit
import SwiftUI

@MainActor
final class PopupPanel {
    private let panel: NSPanel
    private let contentInset: CGFloat = 18
    private var outsideMonitor: Any?
    private var escMonitor: Any?
    private(set) var pinned = false
    var onDismiss: (() -> Void)?

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
        if outsideMonitor == nil {
            outsideMonitor = NSEvent.addGlobalMonitorForEvents(matching: .leftMouseDown) { [weak self] event in
                Task { @MainActor in
                    guard let self, self.panel.isVisible, !self.pinned else {
                        return
                    }
                    if !self.panel.frame.contains(event.locationInScreen) {
                        self.close()
                    }
                }
            }
        }

        if escMonitor == nil {
            escMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
                guard event.keyCode == 53 else {
                    return
                }
                Task { @MainActor in
                    self?.close()
                }
            }
        }
    }

    private func removeMonitors() {
        if let outsideMonitor {
            NSEvent.removeMonitor(outsideMonitor)
            self.outsideMonitor = nil
        }
        if let escMonitor {
            NSEvent.removeMonitor(escMonitor)
            self.escMonitor = nil
        }
    }

    private func frame(for size: CGSize, anchor: CGRect) -> CGRect {
        let screenFrame = NSScreen.main?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)
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
}

private extension NSEvent {
    var locationInScreen: CGPoint {
        NSEvent.mouseLocation
    }
}
