import AppKit
import Carbon

// MARK: - 快捷键工具类
enum HotkeyUtil {

    // MARK: - 修饰符符号映射
    private static let modifierSymbols: [(flags: NSEvent.ModifierFlags, symbol: String)] = [
        (.control, "⌃"),
        (.option, "⌥"),
        (.shift, "⇧"),
        (.command, "⌘")
    ]

    // MARK: - 键码到字符映射
    private static let keyCodeToString: [UInt16: String] = [
        // 字母键
        0: "A", 1: "S", 2: "D", 3: "F", 4: "H", 5: "G", 6: "Z", 7: "X",
        8: "C", 9: "V", 11: "B", 12: "Q", 13: "W", 14: "E", 15: "R",
        16: "Y", 17: "T", 18: "1", 19: "2", 20: "3", 21: "4", 22: "6",
        23: "5", 24: "=", 25: "9", 26: "7", 27: "-", 28: "8", 29: "0",
        30: "]", 31: "O", 32: "U", 33: "[", 34: "I", 35: "P", 37: "L",
        38: "J", 39: "'", 40: "K", 41: ";", 42: "\\", 43: ",", 44: "/",
        45: "N", 46: "M", 47: ".", 48: "Tab", 49: "Space", 50: "`",
        // 数字行
        53: "Esc",
        // 功能键
        122: "F1", 120: "F2", 99: "F3", 118: "F4", 96: "F5", 97: "F6",
        98: "F7", 101: "F8", 109: "F9", 103: "F10", 111: "F11", 105: "F12",
        // 方向键
        123: "←", 124: "→", 125: "↓", 126: "↑",
        // 控制键
        36: "↩", 51: "⌫", 117: "⌦", 115: "↖", 119: "↘",
        116: "↕", 121: "⎙", 130: "ins",
        // 小键盘
        67: "*", 69: "+", 76: "↩", 78: "-", 65: "."
    ]

    // MARK: - 编码为人类可读格式
    static func encode(keyCode: UInt16, modifiers: UInt) -> String {
        guard keyCode != 0 else { return "未设置" }

        let flags = NSEvent.ModifierFlags(rawValue: modifiers)
        var result = ""

        // 按固定顺序添加修饰符符号
        for (flag, symbol) in modifierSymbols {
            if flags.contains(flag) {
                result += symbol
            }
        }

        // 添加按键字符
        if let keyString = keyCodeToString[keyCode] {
            result += keyString
        } else {
            result += "Key(\(keyCode))"
        }

        return result
    }

    // MARK: - 从人类可读格式解码
    static func decode(_ string: String) -> (keyCode: UInt16, modifiers: UInt)? {
        guard string != "未设置" && !string.isEmpty else {
            return (0, 0)
        }

        var modifiers: UInt = 0
        var keyPart = string

        // 解析修饰符符号
        for (flag, symbol) in modifierSymbols {
            if keyPart.hasPrefix(symbol) {
                modifiers |= flag.rawValue
                keyPart = String(keyPart.dropFirst(symbol.count))
            }
        }

        // 查找键码
        var keyCode: UInt16 = 0
        for (code, str) in keyCodeToString {
            if keyPart == str {
                keyCode = code
                break
            }
        }

        if keyCode == 0 && !keyPart.isEmpty {
            // 尝试解析 Key(x) 格式
            if keyPart.hasPrefix("Key(") && keyPart.hasSuffix(")") {
                let numStr = keyPart.dropFirst(4).dropLast()
                keyCode = UInt16(numStr) ?? 0
            }
        }

        return (keyCode, modifiers)
    }

    // MARK: - 从 NSEvent 提取快捷键配置
    static func extractFromEvent(_ event: NSEvent) -> HotkeyConfiguration {
        let modifiers = event.modifierFlags.rawValue & NSEvent.ModifierFlags.deviceIndependentFlagsMask.rawValue
        return HotkeyConfiguration(keyCode: event.keyCode, modifiers: modifiers)
    }

    // MARK: - 检测系统快捷键冲突
    static func checkSystemConflicts(keyCode: UInt16, modifiers: UInt) -> [String] {
        var conflicts: [String] = []
        let flags = NSEvent.ModifierFlags(rawValue: modifiers)
        let hotkeyString = encode(keyCode: keyCode, modifiers: modifiers)

        // 检测与常见应用快捷键的冲突
        let commonConflicts: [(flags: NSEvent.ModifierFlags, keyCode: UInt16, name: String)] = [
            // Chrome
            (.command, 2, "⌘+D - Chrome: 添加书签"),
            (.command, 3, "⌘+F - Chrome: 查找"),
            (.command, 6, "⌘+H - Chrome: 隐藏窗口"),
            (.command, 7, "⌘+W - Chrome: 关闭窗口"),
            (.command, 8, "⌘+C - Chrome: 复制"),
            (.command, 9, "⌘+V - Chrome: 粘贴"),
            (.command, 11, "⌘+B - Chrome: 书签栏"),
            (.command, 13, "⌘+R - Chrome: 刷新"),
            (.command, 15, "⌘+U - Chrome: 源代码"),
            // Safari
            (.command, 49, "⌘+Space - Spotlight"),
            (.command, 51, "⌘+Delete - 删除"),
            // Finder
            (.command, 49, "⌘+Space - Spotlight"),
            (.command, 52, "⌘+\\ - Finder: 显示隐藏文件"),
            // Xcode
            (.command, 0, "⌘+A - 全选"),
            (.command, 1, "⌘+S - 保存"),
            (.command, 6, "⌘+H - 隐藏"),
            (.command, 7, "⌘+W - 关闭"),
            (.command, 8, "⌘+C - 复制"),
            (.command, 9, "⌘+V - 粘贴"),
            (.command, 11, "⌘+B - 粗体"),
            (.command, 13, "⌘+R - 运行"),
            // Terminal
            (.command, 49, "⌘+Space - Spotlight"),
            // iTerm2
            (.command, 49, "⌘+Space - Spotlight"),
            // VSCode
            (.command, 49, "⌘+Space - VSCode: 命令面板"),
            (.command, 6, "⌘+H - VSCode: 隐藏"),
            (.command, 7, "⌘+W - VSCode: 关闭标签"),
            (.command, 12, "⌘+P - VSCode: 快速打开"),
            (.command, 13, "⌘+R - VSCode: 转到符号"),
        ]

        for conflict in commonConflicts {
            let requiredFlags = conflict.flags.rawValue & NSEvent.ModifierFlags.deviceIndependentFlagsMask.rawValue
            let currentFlags = modifiers & NSEvent.ModifierFlags.deviceIndependentFlagsMask.rawValue

            if requiredFlags == currentFlags && conflict.keyCode == keyCode {
                conflicts.append(conflict.name)
            }
        }

        // 检查是否缺少必要的修饰符
        if modifiers == 0 {
            conflicts.append("无修饰符快捷键容易冲突")
        }

        // 记录当前快捷键
        print("[HotkeyUtil] 检测冲突: \(hotkeyString), 发现冲突: \(conflicts.count)")

        return conflicts
    }

    // MARK: - 编码快捷键配置
    static func encode(_ config: HotkeyConfiguration) -> String {
        return encode(keyCode: config.keyCode, modifiers: config.modifiers)
    }

    // MARK: - 解码为快捷键配置
    static func decodeConfig(_ string: String) -> HotkeyConfiguration {
        guard let result = decode(string) else {
            return .empty
        }
        return HotkeyConfiguration(keyCode: result.keyCode, modifiers: result.modifiers)
    }
}
