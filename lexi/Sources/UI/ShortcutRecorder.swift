import KeyboardShortcuts
import SwiftUI

struct ShortcutRecorder: View {
    let title: String
    let name: KeyboardShortcuts.Name

    var body: some View {
        KeyboardShortcuts.Recorder(for: name)
            .font(LexiFont.zh(12))
            .controlSize(.small)
    }
}

struct ShortcutSettingsRow: View {
    let label: String
    var hint: String?
    let name: KeyboardShortcuts.Name
    var isLast = false

    var body: some View {
        SettingsRow(label: label, hint: hint, isLast: isLast) {
            ShortcutRecorder(title: label, name: name)
                .frame(width: 150, height: 24, alignment: .trailing)
        }
    }
}
