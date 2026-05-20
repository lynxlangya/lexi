import KeyboardShortcuts
import SwiftUI

struct ShortcutRecorder: View {
    let title: String
    let name: KeyboardShortcuts.Name

    var body: some View {
        KeyboardShortcuts.Recorder(title, name: name)
            .font(LexiFont.zh(12))
    }
}
