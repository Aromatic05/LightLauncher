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
    private enum KeyCode: UInt32 {
        case space = 49
        case `return` = 36
        case escape = 53
        case tab = 48
        case delete = 51
        case f1 = 122
        case f2 = 120
        case f3 = 99
        case f4 = 118
        case f5 = 96
        case f6 = 97
        case f7 = 98
        case f8 = 100
        case f9 = 101
        case f10 = 109
        case f11 = 103
        case f12 = 111
        case ansiA = 0
        case ansiB = 11
        case ansiC = 8
        case ansiD = 2
        case ansiE = 14
        case ansiF = 3
        case ansiG = 5
        case ansiH = 4
        case ansiI = 34
        case ansiJ = 38
        case ansiK = 40
        case ansiL = 37
        case ansiM = 46
        case ansiN = 45
        case ansiO = 31
        case ansiP = 35
        case ansiQ = 12
        case ansiR = 15
        case ansiS = 1
        case ansiT = 17
        case ansiU = 32
        case ansiV = 9
        case ansiW = 13
        case ansiX = 7
        case ansiY = 16
        case ansiZ = 6
    }

    public static func getKeyName(for keyCode: UInt32) -> String {
        switch keyCode {
        case KeyCode.space.rawValue: return "Space"
        case KeyCode.return.rawValue: return "Return"
        case KeyCode.escape.rawValue: return "Escape"
        case KeyCode.tab.rawValue: return "Tab"
        case KeyCode.delete.rawValue: return "Delete"
        case KeyCode.f1.rawValue: return "F1"
        case KeyCode.f2.rawValue: return "F2"
        case KeyCode.f3.rawValue: return "F3"
        case KeyCode.f4.rawValue: return "F4"
        case KeyCode.f5.rawValue: return "F5"
        case KeyCode.f6.rawValue: return "F6"
        case KeyCode.f7.rawValue: return "F7"
        case KeyCode.f8.rawValue: return "F8"
        case KeyCode.f9.rawValue: return "F9"
        case KeyCode.f10.rawValue: return "F10"
        case KeyCode.f11.rawValue: return "F11"
        case KeyCode.f12.rawValue: return "F12"
        case KeyCode.ansiA.rawValue: return "A"
        case KeyCode.ansiB.rawValue: return "B"
        case KeyCode.ansiC.rawValue: return "C"
        case KeyCode.ansiD.rawValue: return "D"
        case KeyCode.ansiE.rawValue: return "E"
        case KeyCode.ansiF.rawValue: return "F"
        case KeyCode.ansiG.rawValue: return "G"
        case KeyCode.ansiH.rawValue: return "H"
        case KeyCode.ansiI.rawValue: return "I"
        case KeyCode.ansiJ.rawValue: return "J"
        case KeyCode.ansiK.rawValue: return "K"
        case KeyCode.ansiL.rawValue: return "L"
        case KeyCode.ansiM.rawValue: return "M"
        case KeyCode.ansiN.rawValue: return "N"
        case KeyCode.ansiO.rawValue: return "O"
        case KeyCode.ansiP.rawValue: return "P"
        case KeyCode.ansiQ.rawValue: return "Q"
        case KeyCode.ansiR.rawValue: return "R"
        case KeyCode.ansiS.rawValue: return "S"
        case KeyCode.ansiT.rawValue: return "T"
        case KeyCode.ansiU.rawValue: return "U"
        case KeyCode.ansiV.rawValue: return "V"
        case KeyCode.ansiW.rawValue: return "W"
        case KeyCode.ansiX.rawValue: return "X"
        case KeyCode.ansiY.rawValue: return "Y"
        case KeyCode.ansiZ.rawValue: return "Z"
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