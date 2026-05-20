import SwiftUI
import AppKit

/// 用 layer-backed NSView 强制提供完全不透明的背景色，
/// 用来盖掉 NavigationSplitView 在 macOS 上默认套在 sidebar 列上的
/// NSVisualEffectView `.sidebar` material。SwiftUI 的 `.background(Color)`
/// 只是叠加，不能替换底层 material。
struct OpaqueBackground: NSViewRepresentable {
    let color: Color

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        view.wantsLayer = true
        view.layer?.backgroundColor = NSColor(color).cgColor
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        nsView.layer?.backgroundColor = NSColor(color).cgColor
    }
}
