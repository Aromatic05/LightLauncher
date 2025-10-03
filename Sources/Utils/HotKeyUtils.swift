import Foundation

class HotKeyUtils {
    private struct ModifierFlags: OptionSet {
        let rawValue: UInt32

        static let command = ModifierFlags(rawValue: 1 << 20)    // matches Carbon's cmdKey (0x100000)
        static let rightCommand = ModifierFlags(rawValue: 1 << 16) // custom for right-command (0x10000)
        static let option  = ModifierFlags(rawValue: 1 << 19)    // optionKey (0x80000)
        static let rightOption = ModifierFlags(rawValue: 1 << 18) // custom for right-option (0x40000)
        static let control = ModifierFlags(rawValue: 1 << 17)    // controlKey (0x20000)
        static let shift   = ModifierFlags(rawValue: 1 << 16)    // shiftKey (0x10000)
    }
    // NOTE: KeyCode enum removed by request — keycodes will be stored as numeric magic numbers.
    // The getKeyName below maps numeric keycodes to human-readable names.

    public static func getKeyName(for keyCode: UInt32) -> String {
        switch keyCode {
        case 49: return "Space"
        case 36: return "Return"
        case 53: return "Escape"
        case 48: return "Tab"
        case 51: return "Delete"
        case 122: return "F1"
        case 120: return "F2"
        case 99: return "F3"
        case 118: return "F4"
        case 96: return "F5"
        case 97: return "F6"
        case 98: return "F7"
        case 100: return "F8"
        case 101: return "F9"
        case 109: return "F10"
        case 103: return "F11"
        case 111: return "F12"
        case 0: return "A"
        case 11: return "B"
        case 8: return "C"
        case 2: return "D"
        case 14: return "E"
        case 3: return "F"
        case 5: return "G"
        case 4: return "H"
        case 34: return "I"
        case 38: return "J"
        case 40: return "K"
        case 37: return "L"
        case 46: return "M"
        case 45: return "N"
        case 31: return "O"
        case 35: return "P"
        case 12: return "Q"
        case 15: return "R"
        case 1: return "S"
        case 17: return "T"
        case 32: return "U"
        case 9: return "V"
        case 13: return "W"
        case 7: return "X"
        case 16: return "Y"
        case 6: return "Z"
        default: return "Key(\(keyCode))"
        }
    }


    public static func getHotKeyDescription(modifiers: UInt32, keyCode: UInt32) -> String {
        var description = ""

        let rightCommandMask: UInt32 = 0x100010
        let rightOptionMask: UInt32 = 0x100040

        if modifiers == rightCommandMask {
            description += "R⌘"
        } else if modifiers == rightOptionMask {
            description += "R⌥"
        } else {
            let cmdMask: UInt32 = 1 << 20    // 0x100000
            let optionMask: UInt32 = 1 << 19 // 0x80000
            let controlMask: UInt32 = 1 << 17 // 0x20000
            let shiftMask: UInt32 = 1 << 16  // 0x10000

            if modifiers & cmdMask != 0 { description += "⌘" }
            if modifiers & optionMask != 0 { description += "⌥" }
            if modifiers & controlMask != 0 { description += "⌃" }
            if modifiers & shiftMask != 0 { description += "⇧" }
        }

        if keyCode == 0 { return description.isEmpty ? "无" : description }
        description += HotKeyUtils.getKeyName(for: keyCode)
        return description
    }
}