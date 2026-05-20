import AppKit
import SwiftUI

struct ReaderScrollViewStyler: NSViewRepresentable {
    let preferences: ReaderRuntimePreferences

    func makeNSView(context: Context) -> NSView {
        NSView(frame: .zero)
    }

    func updateNSView(_ view: NSView, context: Context) {
        DispatchQueue.main.async {
            guard let scrollView = view.firstSuperview(of: NSScrollView.self) else {
                return
            }

            scrollView.drawsBackground = true
            scrollView.backgroundColor = NSColor(preferences.theme.paper)
            scrollView.scrollerStyle = .overlay
            scrollView.verticalScroller?.controlSize = .small
            scrollView.verticalScroller?.knobStyle = knobStyle
        }
    }

    private var knobStyle: NSScroller.KnobStyle {
        let appearance = NSApp.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua])
        return appearance == .darkAqua ? .light : .dark
    }
}

private extension NSView {
    func firstSuperview<T: NSView>(of type: T.Type) -> T? {
        var current = superview
        while let view = current {
            if let match = view as? T {
                return match
            }
            current = view.superview
        }
        return nil
    }
}
