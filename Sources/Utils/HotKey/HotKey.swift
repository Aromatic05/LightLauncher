import Foundation
import AppKit

// MARK: - HotKey (Single UInt32 Encoding)
/**
 快捷键的统一表示，使用单个 UInt32 编码所有信息
 
 编码格式 (32 bits):
 ┌─────────────────────────────────────────────────────────┐
 │  Bits 0-15  (16 bits): keyCode (0-65535)               │
 │  Bits 16-19 (4 bits):  Base modifiers                  │
 │    - Bit 16: Command                                    │
 │    - Bit 17: Option                                     │
 │    - Bit 18: Control                                    │
 │    - Bit 19: Shift                                      │
 │  Bits 20-21 (2 bits):  Side specification               │
 │    - 00 (0): No side specification (any)                │
 │    - 01 (1): Left side                                  │
 │    - 10 (2): Right side                                 │
 │    - 11 (3): Reserved                                   │
 │  Bits 22-31 (10 bits): Reserved for future use         │
 └─────────────────────────────────────────────────────────┘
 
 Examples:
 - Option + Space:           0x0002_0031
 - Right Option + Space:     0x0022_0031
 - Right Option only:        0x0022_0000
 - Cmd + Opt + K:            0x0003_0028
 */
struct HotKey: Codable, Hashable {
    let rawValue: UInt32
    
    // MARK: - Bit Masks and Offsets
    private static let keyCodeMask: UInt32      = 0x0000_FFFF  // Bits 0-15
    private static let commandMask: UInt32      = 1 << 16       // Bit 16
    private static let optionMask: UInt32       = 1 << 17       // Bit 17
    private static let controlMask: UInt32      = 1 << 18       // Bit 18
    private static let shiftMask: UInt32        = 1 << 19       // Bit 19
    private static let sideMask: UInt32         = 0x0030_0000   // Bits 20-21
    private static let sideOffset: UInt32       = 20
    
    // MARK: - Side Values
    enum Side: UInt32 {
        case any   = 0  // 00
        case left  = 1  // 01
        case right = 2  // 10
    }
    
    // MARK: - Initialization
    init(rawValue: UInt32) {
        self.rawValue = rawValue
    }
    
    init(keyCode: UInt32, command: Bool = false, option: Bool = false, control: Bool = false, shift: Bool = false, side: Side = .any) {
        var value: UInt32 = keyCode & Self.keyCodeMask
        if command { value |= Self.commandMask }
        if option { value |= Self.optionMask }
        if control { value |= Self.controlMask }
        if shift { value |= Self.shiftMask }
        value |= (side.rawValue << Self.sideOffset)
        self.rawValue = value
    }
    
    // MARK: - 便捷构造器
    /// 从旧的分离式表示创建（向后兼容）
    static func from(modifiers: UInt32, keyCode: UInt32) -> HotKey {
        var command = false
        var option = false
        var control = false
        var shift = false
        var side: Side = .any
        
        // 检测 Carbon masks
        let carbonCmd: UInt32 = UInt32(cmdKey)        // 256
        let carbonOption: UInt32 = UInt32(optionKey)  // 2048
        let carbonControl: UInt32 = UInt32(controlKey) // 4096
        let carbonShift: UInt32 = UInt32(shiftKey)    // 512
        
        if (modifiers & carbonCmd) != 0 { command = true }
        if (modifiers & carbonOption) != 0 { option = true }
        if (modifiers & carbonControl) != 0 { control = true }
        if (modifiers & carbonShift) != 0 { shift = true }
        
        // 检测旧的侧别 masks
        let rightCommandMask: UInt32 = kVK_RightCommandMask  // 0x100010
        let rightOptionMask: UInt32 = kVK_RightOptionMask    // 0x100040
        
        if (modifiers & rightCommandMask) != 0 {
            command = true
            side = .right
        }
        if (modifiers & rightOptionMask) != 0 {
            option = true
            side = .right
        }
        
        // If right-side masks are present, prefer that side; otherwise defer to physicalKeys-based detection (not available here)
        let sideOverride: Side? = ( (modifiers & rightCommandMask) != 0 || (modifiers & rightOptionMask) != 0) ? side : nil
        return build(keyCode: keyCode, command: command, option: option, control: control, shift: shift, physicalKeys: [], sideOverride: sideOverride)
    }
    
    /// 从 NSEvent 和物理按键集合创建
    static func from(event: NSEvent, physicalKeys: Set<UInt16>) -> HotKey {
        let flags = event.modifierFlags
        let eventKeyCode = UInt16(event.keyCode)
        
        let command = flags.contains(.command)
        let option = flags.contains(.option)
        let control = flags.contains(.control)
        let shift = flags.contains(.shift)
        
        // 检测是否为修饰键本身的事件（用于 flagsChanged）
        let isModifierKey = eventKeyCode == UInt16(kVK_LeftCommand) ||
                           eventKeyCode == UInt16(kVK_RightCommand) ||
                           eventKeyCode == UInt16(kVK_LeftOption) ||
                           eventKeyCode == UInt16(kVK_RightOption) ||
                           eventKeyCode == UInt16(kVK_LeftShift) ||
                           eventKeyCode == UInt16(kVK_RightShift) ||
                           eventKeyCode == UInt16(kVK_Control)
        
        // 对于修饰键事件，keyCode 应为 0（表示仅修饰键）
        let keyCode: UInt32 = isModifierKey ? 0 : UInt32(eventKeyCode)
        
        return build(keyCode: keyCode, command: command, option: option, control: control, shift: shift, physicalKeys: physicalKeys, sideOverride: nil)
    }
    
    // MARK: - 属性查询
    var keyCode: UInt32 {
        return rawValue & Self.keyCodeMask
    }
    
    var hasCommand: Bool {
        return (rawValue & Self.commandMask) != 0
    }
    
    var hasOption: Bool {
        return (rawValue & Self.optionMask) != 0
    }
    
    var hasControl: Bool {
        return (rawValue & Self.controlMask) != 0
    }
    
    var hasShift: Bool {
        return (rawValue & Self.shiftMask) != 0
    }
    
    var side: Side {
        let sideValue = (rawValue & Self.sideMask) >> Self.sideOffset
        return Side(rawValue: sideValue) ?? .any
    }
    
    var hasModifiers: Bool {
        return hasCommand || hasOption || hasControl || hasShift
    }
    
    var isModifierOnly: Bool {
        return keyCode == 0 && hasModifiers
    }
    
    var hasSideSpecification: Bool {
        return side != .any
    }

    // 这个可以保持 static，因为它不依赖任何实例状态
    static func isModifierKeyCode(_ code: UInt16) -> Bool {
        switch Int32(code) {
        case kVK_LeftCommand, kVK_RightCommand,
             kVK_LeftOption, kVK_RightOption,
             kVK_LeftShift, kVK_RightShift,
             kVK_Control, kVK_RightControl, kVK_Function, kVK_CapsLock:
            return true
        default:
            return false
        }
    }

    // MARK: - CGEvent Utilities (moved from HotkeyManager)
    static func from(keyCode: UInt16, flagsRaw: UInt64, physicalKeys: Set<UInt16>) -> HotKey {
        let flags = NSEvent.ModifierFlags(rawValue: NSEvent.ModifierFlags.RawValue(truncatingIfNeeded: flagsRaw))
        let command = flags.contains(.command)
        let option = flags.contains(.option)
        let control = flags.contains(.control)
        let shift = flags.contains(.shift)

        let isModifierKey = HotKey.isModifierKeyCode(keyCode)
        let hotKeyCode: UInt32 = isModifierKey ? 0 : UInt32(keyCode)

        return build(keyCode: hotKeyCode, command: command, option: option, control: control, shift: shift, physicalKeys: physicalKeys, sideOverride: nil)
    }

    // MARK: - Internal builder to consolidate side detection
    private static func build(keyCode: UInt32, command: Bool, option: Bool, control: Bool, shift: Bool, physicalKeys: Set<UInt16>, sideOverride: Side?) -> HotKey {
        var side: Side = sideOverride ?? .any

        if sideOverride == nil {
            if command {
                if physicalKeys.contains(UInt16(kVK_LeftCommand)) { side = .left }
                else if physicalKeys.contains(UInt16(kVK_RightCommand)) { side = .right }
            } else if option {
                if physicalKeys.contains(UInt16(kVK_LeftOption)) { side = .left }
                else if physicalKeys.contains(UInt16(kVK_RightOption)) { side = .right }
            } else if shift {
                if physicalKeys.contains(UInt16(kVK_LeftShift)) { side = .left }
                else if physicalKeys.contains(UInt16(kVK_RightShift)) { side = .right }
            }
        }

        return HotKey(keyCode: keyCode, command: command, option: option, control: control, shift: shift, side: side)
    }

    func matchesIgnoringSide(_ other: HotKey) -> Bool {
        let normalizedSelf = HotKey(
            keyCode: keyCode,
            command: hasCommand,
            option: hasOption,
            control: hasControl,
            shift: hasShift,
            side: .any
        )
        let normalizedOther = HotKey(
            keyCode: other.keyCode,
            command: other.hasCommand,
            option: other.hasOption,
            control: other.hasControl,
            shift: other.hasShift,
            side: .any
        )
        return normalizedSelf.rawValue == normalizedOther.rawValue
    }
    
    // MARK: - 验证
    var isValid: Bool {
        if isModifierOnly {
            // 仅修饰键必须指定侧别，以避免与组合键冲突
            return hasSideSpecification
        }
        
        // 功能键可以不需要修饰键
        let isFunctionKey = keyCode >= UInt32(kVK_F1) && keyCode <= UInt32(kVK_F12)
        
        // 其他键必须有修饰键
        return hasModifiers || isFunctionKey
    }
    
    // MARK: - 转换
    /// 转换为 Carbon 修饰键掩码（用于 RegisterEventHotKey，会丢失侧别信息）
    func toCarbonMask() -> UInt32 {
        var mask: UInt32 = 0
        if hasCommand { mask |= UInt32(cmdKey) }
        if hasOption { mask |= UInt32(optionKey) }
        if hasControl { mask |= UInt32(controlKey) }
        if hasShift { mask |= UInt32(shiftKey) }
        return mask
    }
    
    // MARK: - 描述信息
    /// 生成人类可读的描述
    func description(style: DescriptionStyle = .symbols) -> String {
        var parts: [String] = []
        
        let sidePrefix: String
        switch (side, style) {
        case (.left, .symbols):
            sidePrefix = "L"
        case (.left, .text):
            sidePrefix = "Left "
        case (.right, .symbols):
            sidePrefix = "R"
        case (.right, .text):
            sidePrefix = "Right "
        case (.any, _):
            sidePrefix = ""
        }
        
        // 标准顺序：Control, Option, Shift, Command
        if hasControl {
            parts.append(sidePrefix + (style == .symbols ? "⌃" : "Control"))
        }
        if hasOption {
            parts.append(sidePrefix + (style == .symbols ? "⌥" : "Option"))
        }
        if hasShift {
            parts.append(sidePrefix + (style == .symbols ? "⇧" : "Shift"))
        }
        if hasCommand {
            parts.append(sidePrefix + (style == .symbols ? "⌘" : "Command"))
        }
        
        if keyCode != 0 {
            let name = HotKey.keyName(for: keyCode)
            parts.append(name)
        }
        
        let separator = style == .symbols ? "" : " + "
        return parts.isEmpty ? "无" : parts.joined(separator: separator)
    }
    
    enum DescriptionStyle {
        case symbols  // R⌥Space
        case text     // Right Option + Space
    }
}

// MARK: - CustomStringConvertible
extension HotKey: CustomStringConvertible {
    var description: String {
        return description(style: .symbols)
    }
}

// MARK: - 默认值
extension HotKey {
    /// 默认的主快捷键（Option + Space）
    static let defaultMain = HotKey(
        keyCode: UInt32(kVK_Space),
        option: true
    )
    
    /// 空快捷键（无效）
    static let empty = HotKey(rawValue: 0)
}

// MARK: - Helper Extensions
extension HotKey {
    /// 返回常用 keyCode 的友好名称（包含字母、数字、功能键和特殊键）
    static func keyName(for keyCode: UInt32) -> String {
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
        default:
            // 尝试字母或数字映射（ANSI 0-25 -> A-Z，0-9）
            let intCode = Int(keyCode)
            // Letters A-Z mapping by known constants
            let letterMap: [Int: String] = [
                Int(kVK_ANSI_A): "A", Int(kVK_ANSI_B): "B", Int(kVK_ANSI_C): "C", Int(kVK_ANSI_D): "D",
                Int(kVK_ANSI_E): "E", Int(kVK_ANSI_F): "F", Int(kVK_ANSI_G): "G", Int(kVK_ANSI_H): "H",
                Int(kVK_ANSI_I): "I", Int(kVK_ANSI_J): "J", Int(kVK_ANSI_K): "K", Int(kVK_ANSI_L): "L",
                Int(kVK_ANSI_M): "M", Int(kVK_ANSI_N): "N", Int(kVK_ANSI_O): "O", Int(kVK_ANSI_P): "P",
                Int(kVK_ANSI_Q): "Q", Int(kVK_ANSI_R): "R", Int(kVK_ANSI_S): "S", Int(kVK_ANSI_T): "T",
                Int(kVK_ANSI_U): "U", Int(kVK_ANSI_V): "V", Int(kVK_ANSI_W): "W", Int(kVK_ANSI_X): "X",
                Int(kVK_ANSI_Y): "Y", Int(kVK_ANSI_Z): "Z",
                Int(kVK_ANSI_0): "0", Int(kVK_ANSI_1): "1", Int(kVK_ANSI_2): "2", Int(kVK_ANSI_3): "3",
                Int(kVK_ANSI_4): "4", Int(kVK_ANSI_5): "5", Int(kVK_ANSI_6): "6", Int(kVK_ANSI_7): "7",
                Int(kVK_ANSI_8): "8", Int(kVK_ANSI_9): "9",
            ]

            if let s = letterMap[intCode] {
                return s
            }

            // Fallback: return numeric representation
            return "Key_\(keyCode)"
        }
    }
}

private extension String {
    func padLeft(toLength: Int, withPad: String) -> String {
        let padCount = max(0, toLength - self.count)
        return String(repeating: withPad, count: padCount) + self
    }
}
