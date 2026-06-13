import Foundation
import AppKit

/// Finder 交互服务 - 获取当前选中的文件/目录
class FinderService: FinderServiceProtocol {
    static let shared = FinderService()

    private init() {}

    /// 获取当前 Finder 选中的文件和目录
    func getSelectedItems() -> [URL] {
        // 使用更可靠的 AppleScript 获取选中项
        // 使用 item i of selection 而不是 repeat with anItem in selection
        let script = """
        tell application "Finder"
            try
                set sel to selection
                if sel is not {} then
                    set pathList to ""
                    repeat with i from 1 to (count sel)
                        set anItem to item i of sel
                        set pathList to pathList & POSIX path of (anItem as alias) & linefeed
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

        return executeAppleScript(script: script)
    }

    /// 执行 AppleScript 并解析结果
    private func executeAppleScript(script: String) -> [URL] {
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

        let paths = parsePaths(from: result)

        print("[FinderService] 解析后路径数量: \(paths.count)")
        return paths
    }

    private func parsePaths(from result: NSAppleEventDescriptor) -> [URL] {
        if result.numberOfItems > 0 {
            var paths: [URL] = []
            for index in 1...result.numberOfItems {
                guard let descriptor = result.atIndex(index),
                      let path = descriptor.stringValue?.trimmingCharacters(in: .whitespacesAndNewlines),
                      !path.isEmpty else {
                    continue
                }
                paths.append(URL(fileURLWithPath: path))
            }

            if !paths.isEmpty {
                print("[FinderService] 获取到路径列表: \(paths.map { $0.path })")
                return paths
            }
        }

        guard let pathString = result.stringValue?.trimmingCharacters(in: .whitespacesAndNewlines),
              !pathString.isEmpty else {
            print("[FinderService] AppleScript 返回空值")
            return []
        }

        print("[FinderService] 获取到路径文本: \(pathString)")

        return pathString.components(separatedBy: "\n")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .map { URL(fileURLWithPath: $0) }
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

    /// 检测 Finder 是否有可见的前台窗口（桌面被手势隐藏时返回 false）
    func hasVisibleFinderWindow() -> Bool {
        guard let app = NSWorkspace.shared.frontmostApplication,
              app.bundleIdentifier == "com.apple.finder" else {
            return false
        }

        let script = """
        tell application "Finder"
            try
                if (count of Finder windows) > 0 then
                    return true
                end if
            end try
            return false
        end tell
        """

        var error: NSDictionary?
        guard let appleScript = NSAppleScript(source: script) else { return false }
        let result = appleScript.executeAndReturnError(&error)
        if error != nil { return false }
        return result.booleanValue
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
