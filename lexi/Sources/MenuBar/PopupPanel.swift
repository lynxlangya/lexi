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

        let visualEffect = NSVisualEffectView(frame: host.frame)
        visualEffect.material = .hudWindow
        visualEffect.blendingMode = .behindWindow
        visualEffect.state = .active
        visualEffect.wantsLayer = true
        visualEffect.layer?.cornerRadius = cornerRadius(for: kind)
        visualEffect.layer?.masksToBounds = true
        visualEffect.addSubview(host)

        panel.contentView = visualEffect
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
        var x = anchor.midX - size.width / 2
        x = min(max(x, screenFrame.minX + margin), screenFrame.maxX - size.width - margin)

        var y = anchor.minY - size.height - 8
        if y < screenFrame.minY + margin {
            y = anchor.maxY + 8
        }
        y = min(max(y, screenFrame.minY + margin), screenFrame.maxY - size.height - margin)

        return NSRect(origin: CGPoint(x: x, y: y), size: size)
    }

    private func cornerRadius(for kind: PopupKind) -> CGFloat {
        switch kind {
        case .chip:
            return 6
        default:
            return 12
        }
    }
}

private extension NSEvent {
    var locationInScreen: CGPoint {
        NSEvent.mouseLocation
    }
}
