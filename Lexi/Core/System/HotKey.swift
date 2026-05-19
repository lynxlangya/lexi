//
//  HotKey.swift
//  Lexi
//
//  Created by Codex on 12/12/25.
//

#if os(macOS)
import Carbon.HIToolbox
import Foundation
import AppKit

struct HotKey: Codable, Hashable {
    var keyCode: UInt32
    var modifiers: UInt32

    static let `default` = HotKey(
        keyCode: UInt32(kVK_ANSI_L),
        modifiers: UInt32(cmdKey | shiftKey)
    )

    var displayString: String {
        var parts: [String] = []
        if modifiers & UInt32(cmdKey) != 0 { parts.append("⌘") }
        if modifiers & UInt32(shiftKey) != 0 { parts.append("⇧") }
        if modifiers & UInt32(optionKey) != 0 { parts.append("⌥") }
        if modifiers & UInt32(controlKey) != 0 { parts.append("⌃") }
        parts.append(Self.keyName(for: keyCode))
        return parts.joined()
    }

    static func carbonModifiers(from flags: NSEvent.ModifierFlags) -> UInt32 {
        var mods: UInt32 = 0
        if flags.contains(.command) { mods |= UInt32(cmdKey) }
        if flags.contains(.shift) { mods |= UInt32(shiftKey) }
        if flags.contains(.option) { mods |= UInt32(optionKey) }
        if flags.contains(.control) { mods |= UInt32(controlKey) }
        return mods
    }

    static func isModifierKey(_ keyCode: UInt16) -> Bool {
        switch Int(keyCode) {
        case kVK_Command, kVK_Shift, kVK_Option, kVK_Control,
             kVK_RightCommand, kVK_RightShift, kVK_RightOption, kVK_RightControl,
             kVK_CapsLock:
            return true
        default:
            return false
        }
    }

    private static func keyName(for code: UInt32) -> String {
        let special: [UInt32: String] = [
            UInt32(kVK_Return): "↩",
            UInt32(kVK_Escape): "⎋",
            UInt32(kVK_Delete): "⌫",
            UInt32(kVK_ForwardDelete): "⌦",
            UInt32(kVK_Tab): "⇥",
            UInt32(kVK_Space): "Space",
            UInt32(kVK_LeftArrow): "←",
            UInt32(kVK_RightArrow): "→",
            UInt32(kVK_UpArrow): "↑",
            UInt32(kVK_DownArrow): "↓",
        ]
        if let mapped = special[code] {
            return mapped
        }

        if let keyString = keyCodeToString(code) {
            return keyString.uppercased()
        }
        return "Key\(code)"
    }

    private static func keyCodeToString(_ keyCode: UInt32) -> String? {
        guard let inputSource = TISCopyCurrentKeyboardLayoutInputSource()?.takeRetainedValue(),
              let layoutData = TISGetInputSourceProperty(inputSource, kTISPropertyUnicodeKeyLayoutData)
        else {
            return nil
        }

        let data = unsafeBitCast(layoutData, to: CFData.self)
        guard let bytes = CFDataGetBytePtr(data) else { return nil }
        let layout = UnsafePointer<UCKeyboardLayout>(OpaquePointer(bytes))

        var deadKeyState: UInt32 = 0
        var chars: [UniChar] = Array(repeating: 0, count: 4)
        var length: Int = 0

        let status = UCKeyTranslate(
            layout,
            UInt16(keyCode),
            UInt16(kUCKeyActionDisplay),
            0,
            UInt32(LMGetKbdType()),
            UInt32(kUCKeyTranslateNoDeadKeysBit),
            &deadKeyState,
            chars.count,
            &length,
            &chars
        )

        guard status == noErr, length > 0 else { return nil }
        return String(utf16CodeUnits: chars, count: length)
    }
}
#endif
