//
//  HotKeyManager.swift
//  Lexi
//
//  Created by Codex on 12/12/25.
//

#if os(macOS)
import Carbon
import Foundation

final class HotKeyManager {
    static let shared = HotKeyManager()

    private var hotKeyRef: EventHotKeyRef?
    private var handlerRef: EventHandlerRef?
    private var onHotKey: (() -> Void)?

    private let hotKeySignature: OSType = 0x4C455849 // "LEXI"
    private let hotKeyId: UInt32 = 1
    private var handlerInstalled = false

    func registerDefaultHotKey(onHotKey: @escaping () -> Void) {
        registerHotKey(HotKey.default, onHotKey: onHotKey)
    }

    func registerHotKey(_ hotKey: HotKey, onHotKey: @escaping () -> Void) {
        self.onHotKey = onHotKey
        installHandlerIfNeeded()
        unregisterCurrentHotKey()
        registerCarbonHotKey(keyCode: hotKey.keyCode, modifiers: hotKey.modifiers)
    }

    func registerHotKey(keyCode: UInt32, modifiers: UInt32, onHotKey: @escaping () -> Void) {
        registerHotKey(HotKey(keyCode: keyCode, modifiers: modifiers), onHotKey: onHotKey)
    }

    func updateHotKey(_ hotKey: HotKey) {
        installHandlerIfNeeded()
        unregisterCurrentHotKey()
        registerCarbonHotKey(keyCode: hotKey.keyCode, modifiers: hotKey.modifiers)
    }

    private func installHandlerIfNeeded() {
        guard !handlerInstalled else { return }

        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )

        handlerRef = nil
        InstallEventHandler(
            GetApplicationEventTarget(),
            { (_, event, _) -> OSStatus in
                guard let event else { return noErr }
                var hotKeyID = EventHotKeyID()
                let status = GetEventParameter(
                    event,
                    EventParamName(kEventParamDirectObject),
                    EventParamType(typeEventHotKeyID),
                    nil,
                    MemoryLayout<EventHotKeyID>.size,
                    nil,
                    &hotKeyID
                )
                if status == noErr, hotKeyID.signature == HotKeyManager.shared.hotKeySignature {
                    HotKeyManager.shared.onHotKey?()
                }
                return noErr
            },
            1,
            &eventType,
            nil,
            &handlerRef
        )

        handlerInstalled = true
    }

    private func unregisterCurrentHotKey() {
        if let ref = hotKeyRef {
            UnregisterEventHotKey(ref)
            hotKeyRef = nil
        }
    }

    private func registerCarbonHotKey(keyCode: UInt32, modifiers: UInt32) {
        var hotKeyID = EventHotKeyID(signature: hotKeySignature, id: hotKeyId)
        hotKeyRef = nil
        RegisterEventHotKey(keyCode, modifiers, hotKeyID, GetApplicationEventTarget(), 0, &hotKeyRef)
    }
}
#endif
