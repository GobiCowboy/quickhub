import Foundation
import AppKit

/// Finder 交互服务 - 获取当前选中的文件/目录
class FinderService: FinderServiceProtocol {
    static let shared = FinderService()

    private init() {}

    /// 获取当前 Finder 选中的文件和目录
    func getSelectedItems() -> [URL] {
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
            on error errMsg
                log "FinderService error: " & errMsg
                return ""
            end try
        end tell
        """

        var error: NSDictionary?
        guard let appleScript = NSAppleScript(source: script) else {
            print("[FinderService] NSAppleScript 创建失败")
            return []
        }

        let result = appleScript.executeAndReturnError(&error)

        if let error = error {
            print("[FinderService] AppleScript 执行错误: \(error)")
            return []
        }

        guard let pathString = result.stringValue else {
            print("[FinderService] AppleScript 返回空值")
            return []
        }

        print("[FinderService] 获取到路径: \(pathString)")

        // 解析路径列表
        let paths = pathString.components(separatedBy: "\n")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .map { URL(fileURLWithPath: $0) }

        print("[FinderService] 解析后路径数量: \(paths.count)")
        return paths
    }

    /// 获取当前目录
    func getCurrentDirectory() -> String {
        let items = getSelectedItems()
        print("[FinderService] getCurrentDirectory: items count = \(items.count)")

        if let firstItem = items.first {
            var isDirectory: ObjCBool = false
            if FileManager.default.fileExists(atPath: firstItem.path, isDirectory: &isDirectory) {
                if isDirectory.boolValue {
                    print("[FinderService] 选中的是文件夹: \(firstItem.path)")
                    return firstItem.path
                } else {
                    let dir = firstItem.deletingLastPathComponent().path
                    print("[FinderService] 选中的是文件,所在目录: \(dir)")
                    return dir
                }
            }
        }

        // 如果没有选中，返回当前 Finder 窗口路径
        if let finderDir = getFinderCurrentDirectory(), !finderDir.isEmpty {
            print("[FinderService] 无选中项，使用 Finder 窗口路径: \(finderDir)")
            return finderDir
        }

        // 如果还是失败，返回桌面
        let desktop = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Desktop")
            .path
        print("[FinderService] 全部失败，返回桌面: \(desktop)")
        return desktop
    }

    /// 获取当前 Finder 窗口的路径
    private func getFinderCurrentDirectory() -> String? {
        let script = """
        tell application "Finder"
            try
                return POSIX path of (target of front Finder window as alias)
            on error errMsg
                log "getFinderCurrentDirectory error: " & errMsg
                return ""
            end try
        end tell
        """

        var error: NSDictionary?
        guard let appleScript = NSAppleScript(source: script) else {
            print("[FinderService] getFinderCurrentDirectory NSAppleScript 创建失败")
            return nil
        }

        let result = appleScript.executeAndReturnError(&error)
        if let error = error {
            print("[FinderService] getFinderCurrentDirectory AppleScript 错误: \(error)")
            return nil
        }
        let path = result.stringValue?.trimmingCharacters(in: .whitespacesAndNewlines)
        print("[FinderService] getFinderCurrentDirectory 返回: \(path ?? "nil")")
        return path
    }

    /// 获取选中的第一个文件/目录的路径
    func getFirstSelectedPath() -> String? {
        return getSelectedItems().first?.path
    }
}
