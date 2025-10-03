// Lightweight Carbon compatibility shims to avoid importing the full Carbon module.
// Define only the constants this project uses (modifier masks and commonly used keycodes).
// These values mirror the Carbon constants on macOS but keep the code Swift-native.

import Foundation

// Modifier keys (Carbon-style)
// These are the actual Carbon modifier key masks used by RegisterEventHotKey
public let cmdKey: Int32 = 256       // 0x100 (1 << 8)
public let optionKey: Int32 = 2048   // 0x800 (1 << 11)
public let shiftKey: Int32 = 512     // 0x200 (1 << 9)
public let controlKey: Int32 = 4096  // 0x1000 (1 << 12)

// Common virtual key codes (Apple/Carbon mapping)
public let kVK_Space: Int32 = 49
public let kVK_Return: Int32 = 36
public let kVK_Escape: Int32 = 53
public let kVK_Tab: Int32 = 48
public let kVK_Delete: Int32 = 51

public let kVK_F1: Int32 = 122
public let kVK_F2: Int32 = 120
public let kVK_F3: Int32 = 99
public let kVK_F4: Int32 = 118
public let kVK_F5: Int32 = 96
public let kVK_F6: Int32 = 97
public let kVK_F7: Int32 = 98
public let kVK_F8: Int32 = 100
public let kVK_F9: Int32 = 101
public let kVK_F10: Int32 = 109
public let kVK_F11: Int32 = 103
public let kVK_F12: Int32 = 111

public let kVK_ANSI_A: Int32 = 0
public let kVK_ANSI_B: Int32 = 11
public let kVK_ANSI_C: Int32 = 8
public let kVK_ANSI_D: Int32 = 2
public let kVK_ANSI_E: Int32 = 14
public let kVK_ANSI_F: Int32 = 3
public let kVK_ANSI_G: Int32 = 5
public let kVK_ANSI_H: Int32 = 4
public let kVK_ANSI_I: Int32 = 34
public let kVK_ANSI_J: Int32 = 38
public let kVK_ANSI_K: Int32 = 40
public let kVK_ANSI_L: Int32 = 37
public let kVK_ANSI_M: Int32 = 46
public let kVK_ANSI_N: Int32 = 45
public let kVK_ANSI_O: Int32 = 31
public let kVK_ANSI_P: Int32 = 35
public let kVK_ANSI_Q: Int32 = 12
public let kVK_ANSI_R: Int32 = 15
public let kVK_ANSI_S: Int32 = 1
public let kVK_ANSI_T: Int32 = 17
public let kVK_ANSI_U: Int32 = 32
public let kVK_ANSI_V: Int32 = 9
public let kVK_ANSI_W: Int32 = 13
public let kVK_ANSI_X: Int32 = 7
public let kVK_ANSI_Y: Int32 = 16
public let kVK_ANSI_Z: Int32 = 6
