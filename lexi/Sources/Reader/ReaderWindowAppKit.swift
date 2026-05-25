import AppKit
import SwiftUI

struct ReaderWindowTitleUpdater: NSViewRepresentable {
    let title: String
    let isReaderSurface: Bool

    func makeNSView(context: Context) -> NSView {
        NSView(frame: .zero)
    }

    func updateNSView(_ view: NSView, context: Context) {
        DispatchQueue.main.async {
            guard let window = view.window else {
                return
            }

            window.title = title
            window.titleVisibility = isReaderSurface ? .hidden : .visible
        }
    }
}

struct ReaderWindowSizeUpdater: NSViewRepresentable {
    let isCompactReadAloud: Bool

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeNSView(context: Context) -> NSView {
        NSView(frame: .zero)
    }

    func updateNSView(_ view: NSView, context: Context) {
        DispatchQueue.main.async {
            guard let window = view.window else {
                return
            }
            context.coordinator.apply(isCompactReadAloud: isCompactReadAloud, to: window)
        }
    }

    final class Coordinator {
        private let compactWidth: CGFloat = 480
        private let compactMinWidth: CGFloat = 440
        private let expandedMinWidth: CGFloat = 920
        private let minHeight: CGFloat = 620
        private var previousExpandedFrame: NSRect?
        private var wasCompact = false

        func apply(isCompactReadAloud: Bool, to window: NSWindow) {
            guard !window.styleMask.contains(.fullScreen) else {
                return
            }

            if isCompactReadAloud {
                if !wasCompact {
                    previousExpandedFrame = window.frame
                }
                wasCompact = true
                window.contentMinSize = NSSize(width: compactMinWidth, height: minHeight)

                guard abs(window.frame.width - compactWidth) > 1 else {
                    return
                }
                window.setFrame(
                    constrainedFrame(width: compactWidth, height: max(window.frame.height, minHeight), basedOn: window.frame, screen: window.screen),
                    display: true,
                    animate: true
                )
            } else {
                window.contentMinSize = NSSize(width: expandedMinWidth, height: minHeight)
                guard wasCompact else {
                    return
                }
                wasCompact = false

                let target = previousExpandedFrame ?? defaultExpandedFrame(from: window.frame, screen: window.screen)
                previousExpandedFrame = nil
                window.setFrame(
                    constrainedFrame(width: max(target.width, expandedMinWidth), height: max(target.height, minHeight), basedOn: target, screen: window.screen),
                    display: true,
                    animate: true
                )
            }
        }

        private func defaultExpandedFrame(from frame: NSRect, screen: NSScreen?) -> NSRect {
            constrainedFrame(width: 1200, height: max(frame.height, 760), basedOn: frame, screen: screen)
        }

        private func constrainedFrame(width: CGFloat, height: CGFloat, basedOn frame: NSRect, screen: NSScreen?) -> NSRect {
            var next = NSRect(
                x: frame.midX - width / 2,
                y: frame.midY - height / 2,
                width: width,
                height: height
            )

            guard let visibleFrame = screen?.visibleFrame else {
                return next
            }

            if next.width > visibleFrame.width {
                next.size.width = visibleFrame.width
                next.origin.x = visibleFrame.minX
            } else {
                next.origin.x = min(max(next.origin.x, visibleFrame.minX), visibleFrame.maxX - next.width)
            }

            if next.height > visibleFrame.height {
                next.size.height = visibleFrame.height
                next.origin.y = visibleFrame.minY
            } else {
                next.origin.y = min(max(next.origin.y, visibleFrame.minY), visibleFrame.maxY - next.height)
            }

            return next
        }
    }
}

struct ReaderWindowCloseBehavior: NSViewRepresentable {
    let willClose: (@escaping () -> Void) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(willClose: willClose)
    }

    func makeNSView(context: Context) -> NSView {
        NSView(frame: .zero)
    }

    func updateNSView(_ view: NSView, context: Context) {
        DispatchQueue.main.async {
            guard let window = view.window else {
                return
            }
            context.coordinator.willClose = willClose
            guard window.delegate !== context.coordinator else {
                return
            }
            window.delegate = context.coordinator
        }
    }

    final class Coordinator: NSObject, NSWindowDelegate {
        var willClose: (@escaping () -> Void) -> Void
        private var isClosingAfterFlush = false
        private var isTerminatingAfterFlush = false

        init(willClose: @escaping (@escaping () -> Void) -> Void) {
            self.willClose = willClose
        }

        func windowShouldClose(_ sender: NSWindow) -> Bool {
            if isClosingAfterFlush || isTerminatingAfterFlush {
                isClosingAfterFlush = false
                return true
            }

            if UserDefaults.standard.string(forKey: LexiDefaultsKey.generalOnClose) == "quit" {
                willClose {
                    self.isTerminatingAfterFlush = true
                    NSApp.terminate(nil)
                }
            } else {
                willClose { [weak sender] in
                    guard let sender else {
                        return
                    }
                    self.isClosingAfterFlush = true
                    sender.performClose(nil)
                }
            }

            return false
        }

        func windowWillClose(_ notification: Notification) {
            NSApp.setActivationPolicy(.accessory)
        }
    }
}
