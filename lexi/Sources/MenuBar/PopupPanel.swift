import AppKit
import SwiftUI

@MainActor
final class PopupPanel {
    private let panel: NSPanel
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
        panel.hasShadow = true
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
        var x = anchor.midX - size.width / 2
        x = min(max(x, screenFrame.minX + margin), screenFrame.maxX - size.width - margin)

        let aboveY = anchor.minY - size.height - gap
        let belowY = anchor.maxY + gap
        let fitsBelow = belowY + size.height <= screenFrame.maxY - margin
        let fitsAbove = aboveY >= screenFrame.minY + margin
        let roomBelow = screenFrame.maxY - margin - belowY
        let roomAbove = aboveY - (screenFrame.minY + margin)

        var y: CGFloat
        if fitsBelow {
            y = belowY
        } else if fitsAbove {
            y = aboveY
        } else {
            y = roomBelow >= roomAbove ? belowY : aboveY
        }
        y = min(max(y, screenFrame.minY + margin), screenFrame.maxY - size.height - margin)

        return NSRect(origin: CGPoint(x: x, y: y), size: size)
    }
}

private extension NSEvent {
    var locationInScreen: CGPoint {
        NSEvent.mouseLocation
    }
}
