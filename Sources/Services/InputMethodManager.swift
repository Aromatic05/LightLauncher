import Carbon

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
        
        let count = CFArrayGetCount(inputSources)
        for i in 0..<count {
            guard let inputSource = CFArrayGetValueAtIndex(inputSources, i) else { continue }
            let source = Unmanaged<TISInputSource>.fromOpaque(inputSource).takeUnretainedValue()
            
            // 获取输入法ID
            guard let sourceID = TISGetInputSourceProperty(source, kTISPropertyInputSourceID) else { continue }
            let id = Unmanaged<CFString>.fromOpaque(sourceID).takeUnretainedValue() as String
            
            // 查找ABC输入法（美式英语键盘）
            if id == "com.apple.keylayout.ABC" || id == "com.apple.keylayout.US" {
                TISSelectInputSource(source)
                break
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