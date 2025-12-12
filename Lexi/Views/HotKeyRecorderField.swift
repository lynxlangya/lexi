//
//  HotKeyRecorderField.swift
//  Lexi
//
//  Created by Codex on 12/12/25.
//

#if os(macOS)
import SwiftUI
import AppKit
import Carbon.HIToolbox

struct HotKeyRecorderField: NSViewRepresentable {
    @Binding var hotKey: HotKey

    func makeCoordinator() -> Coordinator {
        Coordinator(hotKey: $hotKey)
    }

    func makeNSView(context: Context) -> RecorderView {
        let view = RecorderView()
        view.currentHotKey = hotKey
        view.onHotKeyChange = { newHotKey in
            context.coordinator.hotKey = newHotKey
        }
        return view
    }

    func updateNSView(_ nsView: RecorderView, context: Context) {
        nsView.currentHotKey = hotKey
    }

    final class Coordinator: NSObject {
        @Binding var hotKey: HotKey

        init(hotKey: Binding<HotKey>) {
            _hotKey = hotKey
        }
    }
}

final class RecorderView: NSView {
    var currentHotKey: HotKey = .default {
        didSet { updateLabel() }
    }
    var onHotKeyChange: ((HotKey) -> Void)?

    private let label = NSTextField(labelWithString: "")
    private var isRecording = false {
        didSet {
            updateLabel()
            updateAppearance()
        }
    }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)

        setContentHuggingPriority(.required, for: .horizontal)
        setContentHuggingPriority(.required, for: .vertical)
        setContentCompressionResistancePriority(.required, for: .horizontal)
        setContentCompressionResistancePriority(.required, for: .vertical)

        wantsLayer = true
        layer?.cornerRadius = 7
        layer?.borderWidth = 0.5

        label.alignment = .center
        label.font = NSFont.systemFont(ofSize: 12, weight: .medium)
        label.textColor = .labelColor
        label.translatesAutoresizingMaskIntoConstraints = false

        addSubview(label)
        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 6),
            label.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -6),
            label.centerYAnchor.constraint(equalTo: centerYAnchor)
        ])

        updateLabel()
        updateAppearance()
    }

    required init?(coder: NSCoder) {
        nil
    }

    override var acceptsFirstResponder: Bool { true }

    override var intrinsicContentSize: NSSize {
        NSSize(width: 120, height: 22)
    }

    override func mouseDown(with event: NSEvent) {
        isRecording = true
        window?.makeFirstResponder(self)
    }

    override func resignFirstResponder() -> Bool {
        isRecording = false
        return super.resignFirstResponder()
    }

    override func keyDown(with event: NSEvent) {
        guard isRecording else { return }

        if event.keyCode == UInt16(kVK_Escape) {
            isRecording = false
            return
        }

        if HotKey.isModifierKey(event.keyCode) {
            return
        }

        let modifiers = HotKey.carbonModifiers(from: event.modifierFlags)
        let newHotKey = HotKey(keyCode: UInt32(event.keyCode), modifiers: modifiers)
        currentHotKey = newHotKey
        onHotKeyChange?(newHotKey)
        isRecording = false
    }

    private func updateLabel() {
        label.stringValue = isRecording ? "按下新的快捷键…" : currentHotKey.displayString
    }

    private func updateAppearance() {
        let borderColor = isRecording ? NSColor.controlAccentColor : NSColor.quaternaryLabelColor
        layer?.borderColor = borderColor.cgColor
        let backgroundColor = isRecording
            ? NSColor.controlAccentColor.withAlphaComponent(0.12)
            : NSColor.tertiarySystemFill
        layer?.backgroundColor = backgroundColor.cgColor
    }
}
#endif
