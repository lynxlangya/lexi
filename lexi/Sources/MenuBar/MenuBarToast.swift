import AppKit
import SwiftUI

@MainActor
final class MenuBarToast {
    private var panel: NSPanel?
    private var task: Task<Void, Never>?

    func show(_ text: String) {
        task?.cancel()

        let view = Text(text)
            .font(LexiFont.zh(12.5))
            .foregroundStyle(Color.lexiInk)
            .padding(.horizontal, 14)
            .padding(.vertical, 9)
            .background(Color.lexiRaised)
            .clipShape(RoundedRectangle(cornerRadius: LexiRadius.control, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: LexiRadius.control, style: .continuous)
                    .stroke(Color.lexiRule, lineWidth: 1)
            }
            .shadow(color: .black.opacity(0.18), radius: 18, y: 8)

        let host = NSHostingView(rootView: view)
        let size = host.fittingSize
        host.frame = NSRect(origin: .zero, size: size)

        let panel = NSPanel(
            contentRect: NSRect(origin: .zero, size: size),
            styleMask: [.nonactivatingPanel, .borderless],
            backing: .buffered,
            defer: false
        )
        panel.isFloatingPanel = true
        panel.level = .floating
        panel.hidesOnDeactivate = false
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.contentView = host

        let screen = NSScreen.main?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)
        let origin = CGPoint(x: screen.midX - size.width / 2, y: screen.minY + 80)
        panel.setFrame(NSRect(origin: origin, size: size), display: true)

        self.panel?.orderOut(nil)
        self.panel = panel
        panel.orderFrontRegardless()

        task = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 1_600_000_000)
            await MainActor.run {
                self?.panel?.orderOut(nil)
                self?.panel = nil
            }
        }
    }
}
