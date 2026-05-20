import SwiftUI

struct ShelfContextMenu: View {
    let open: () -> Void
    let continueReading: () -> Void
    let revealInFinder: () -> Void
    let clearCache: () -> Void
    let remove: () -> Void

    var body: some View {
        Button("打开", action: open)
            .keyboardShortcut("o", modifiers: [.command])

        Button("继续阅读", action: continueReading)
            .keyboardShortcut(.return, modifiers: [])

        Divider()

        Button("Finder 中显示", action: revealInFinder)
            .keyboardShortcut("r", modifiers: [.option, .command])

        Divider()

        Button("清除翻译缓存", action: clearCache)

        Divider()

        Button(role: .destructive, action: remove) {
            Text("从书架移除")
        }
    }
}
