import KeyboardShortcuts
import SwiftUI

struct ShortcutRecorder: View {
    let title: String
    let name: KeyboardShortcuts.Name

    var body: some View {
        KeyboardShortcuts.RecorderCocoaBridge(name: name)
            .frame(width: 130, height: 24)
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

extension KeyboardShortcuts {
    struct RecorderCocoaBridge: NSViewRepresentable {
        let name: Name

        func makeNSView(context: Context) -> RecorderCocoa {
            let recorder = RecorderCocoa(for: name)
            normalizeDisplay(recorder)
            return recorder
        }

        func updateNSView(_ recorder: RecorderCocoa, context: Context) {
            recorder.shortcutName = name
            normalizeDisplay(recorder)
        }

        private func normalizeDisplay(_ recorder: RecorderCocoa) {
            let raw = recorder.stringValue
            guard raw.contains("⇧"), raw.hasSuffix("=") else {
                return
            }
            recorder.stringValue = raw
                .replacingOccurrences(of: "⇧", with: "")
                .replacingOccurrences(of: "=", with: "+")
        }
    }
}
