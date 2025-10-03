import Foundation

class HotKeyUtils {
    static func getKeyName(for keyCode: UInt32) -> String {
        switch keyCode {
        case UInt32(kVK_Space): return "Space"
        case UInt32(kVK_Return): return "Return"
        case UInt32(kVK_Escape): return "Escape"
        case UInt32(kVK_Tab): return "Tab"
        case UInt32(kVK_Delete): return "Delete"
        case UInt32(kVK_F1): return "F1"
        case UInt32(kVK_F2): return "F2"
        case UInt32(kVK_F3): return "F3"
        case UInt32(kVK_F4): return "F4"
        case UInt32(kVK_F5): return "F5"
        case UInt32(kVK_F6): return "F6"
        case UInt32(kVK_F7): return "F7"
        case UInt32(kVK_F8): return "F8"
        case UInt32(kVK_F9): return "F9"
        case UInt32(kVK_F10): return "F10"
        case UInt32(kVK_F11): return "F11"
        case UInt32(kVK_F12): return "F12"
        case UInt32(kVK_ANSI_A): return "A"
        case UInt32(kVK_ANSI_B): return "B"
        case UInt32(kVK_ANSI_C): return "C"
        case UInt32(kVK_ANSI_D): return "D"
        case UInt32(kVK_ANSI_E): return "E"
        case UInt32(kVK_ANSI_F): return "F"
        case UInt32(kVK_ANSI_G): return "G"
        case UInt32(kVK_ANSI_H): return "H"
        case UInt32(kVK_ANSI_I): return "I"
        case UInt32(kVK_ANSI_J): return "J"
        case UInt32(kVK_ANSI_K): return "K"
        case UInt32(kVK_ANSI_L): return "L"
        case UInt32(kVK_ANSI_M): return "M"
        case UInt32(kVK_ANSI_N): return "N"
        case UInt32(kVK_ANSI_O): return "O"
        case UInt32(kVK_ANSI_P): return "P"
        case UInt32(kVK_ANSI_Q): return "Q"
        case UInt32(kVK_ANSI_R): return "R"
        case UInt32(kVK_ANSI_S): return "S"
        case UInt32(kVK_ANSI_T): return "T"
        case UInt32(kVK_ANSI_U): return "U"
        case UInt32(kVK_ANSI_V): return "V"
        case UInt32(kVK_ANSI_W): return "W"
        case UInt32(kVK_ANSI_X): return "X"
        case UInt32(kVK_ANSI_Y): return "Y"
        case UInt32(kVK_ANSI_Z): return "Z"
        default: return "Key(\(keyCode))"
        }
    }


    public static func getHotKeyDescription(modifiers: UInt32, keyCode: UInt32) -> String {
        print("[HotKeyUtils] getHotKeyDescription called modifiers=\(modifiers) keyCode=\(keyCode)")
        var description = ""

        // Side-specific masks (defined in CarbonCompat.swift)
        let rightCommandMask: UInt32 = kVK_RightCommandMask
        let rightOptionMask: UInt32 = kVK_RightOptionMask

        // Common display masks (app-specific)
        let cmdMask: UInt32 = 1 << 20    // 0x100000
        let optionMask: UInt32 = 1 << 19 // 0x80000
        let controlMask: UInt32 = 1 << 17 // 0x20000
        let shiftMask: UInt32 = 1 << 16  // 0x10000

        // Carbon-style masks from CarbonCompat
        let carbonCmd: UInt32 = UInt32(cmdKey)
        let carbonOption: UInt32 = UInt32(optionKey)
        let carbonControl: UInt32 = UInt32(controlKey)
        let carbonShift: UInt32 = UInt32(shiftKey)

        // Side-specific first
        if (modifiers & rightCommandMask) != 0 {
            description += "R⌘"
        }
        if (modifiers & rightOptionMask) != 0 {
            description += "R⌥"
        }

        // Generic/Carbon masks (avoid duplicating symbols)
        // Command
        if description.contains("R⌘") {
            // already accounted for right command
        } else if (modifiers & cmdMask) != 0 || (modifiers & carbonCmd) != 0 {
            description += "⌘"
        }

        // Option
        if description.contains("R⌥") {
            // already accounted for right option
        } else if (modifiers & optionMask) != 0 || (modifiers & carbonOption) != 0 {
            description += "⌥"
        }

        // Control
        if (modifiers & controlMask) != 0 || (modifiers & carbonControl) != 0 {
            description += "⌃"
        }

        // Shift
        if (modifiers & shiftMask) != 0 || (modifiers & carbonShift) != 0 {
            description += "⇧"
        }

        if keyCode == 0 { return description.isEmpty ? "无" : description }
        description += HotKeyUtils.getKeyName(for: keyCode)
        print("[HotKeyUtils] getHotKeyDescription result=\(description)")
        return description
    }

    public static func getModifierStrings(modifiers: UInt32) -> [String] {
        var modifierStrings: [String] = []

        if modifiers & UInt32(controlKey) != 0 {
            modifierStrings.append("⌃")
        }
        if modifiers & UInt32(optionKey) != 0 {
            modifierStrings.append("⌥")
        }
        if modifiers & UInt32(shiftKey) != 0 {
            modifierStrings.append("⇧")
        }
        if modifiers & UInt32(cmdKey) != 0 {
            modifierStrings.append("⌘")
        }

        return modifierStrings
    }
}