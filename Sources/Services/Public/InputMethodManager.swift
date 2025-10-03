import AppKit
import Carbon.HIToolbox

// 输入法管理器
class InputMethodManager {
    private var previousInputSource: TISInputSource?

    // 切换到英文输入法
    func switchToEnglish() {
        // 保存当前输入法
        previousInputSource = TISCopyCurrentKeyboardInputSource()?.takeRetainedValue()

        // 获取英文输入法列表
        let filter = [kTISPropertyInputSourceCategory: kTISCategoryKeyboardInputSource] as CFDictionary
        guard let inputSources = TISCreateInputSourceList(filter, false)?.takeRetainedValue() else {
            return
        }

        let sources = inputSources as NSArray
        for case let source as TISInputSource in sources {
            // 获取输入法ID（作为 CFString）
            if let rawProp = TISGetInputSourceProperty(source, kTISPropertyInputSourceID) {
                let id = (rawProp as! CFString) as String

                // 查找 ABC 或 US 输入法（美式英语键盘）
                if id == "com.apple.keylayout.ABC" || id == "com.apple.keylayout.US" {
                    TISSelectInputSource(source)
                    break
                }
            }
        }
    }

    // 恢复之前的输入法
    func restorePreviousInputMethod() {
        if let previous = previousInputSource {
            TISSelectInputSource(previous)
            previousInputSource = nil
        }
    }
}
