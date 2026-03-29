import Foundation
import AppKit

/// Finder 交互服务 - 获取当前选中的文件/目录
class FinderService {
    static let shared = FinderService()

    private init() {}

    /// 获取当前 Finder 选中的文件和目录
    func getSelectedItems() -> [URL] {
        // 复制路径到剪贴板（Finder 标准操作）
        let script = """
        tell application "Finder"
            try
                set sel to selection as alias list
                if (count sel) > 0 then
                    set pathList to ""
                    repeat with anItem in sel
                        set pathList to pathList & POSIX path of anItem & linefeed
                    end repeat
                    return pathList
                else
                    -- 没有选中，返回当前窗口路径
                    return POSIX path of (target of front Finder window as alias)
                end if
            on error
                return ""
            end try
        end tell
        """

        var error: NSDictionary?
        guard let appleScript = NSAppleScript(source: script) else {
            return []
        }

        let result = appleScript.executeAndReturnError(&error)

        guard let pathString = result.stringValue else {
            return []
        }

        // 解析路径列表
        let paths = pathString.components(separatedBy: "\n")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .map { URL(fileURLWithPath: $0) }

        return paths
    }

    /// 获取当前目录
    func getCurrentDirectory() -> String {
        let items = getSelectedItems()

        if let firstItem = items.first {
            var isDirectory: ObjCBool = false
            if FileManager.default.fileExists(atPath: firstItem.path, isDirectory: &isDirectory) {
                if isDirectory.boolValue {
                    return firstItem.path
                } else {
                    return firstItem.deletingLastPathComponent().path
                }
            }
        }

        // 如果没有选中，返回当前 Finder 窗口路径
        if let finderDir = getFinderCurrentDirectory(), !finderDir.isEmpty {
            return finderDir
        }

        // 如果还是失败，返回桌面
        return FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Desktop")
            .path
    }

    /// 获取当前 Finder 窗口的路径
    private func getFinderCurrentDirectory() -> String? {
        let script = """
        tell application "Finder"
            try
                return POSIX path of (target of front Finder window as alias)
            on error
                return ""
            end try
        end tell
        """

        var error: NSDictionary?
        guard let appleScript = NSAppleScript(source: script) else {
            return nil
        }

        let result = appleScript.executeAndReturnError(&error)
        return result.stringValue?.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// 获取选中的第一个文件/目录的路径
    func getFirstSelectedPath() -> String? {
        return getSelectedItems().first?.path
    }
}
