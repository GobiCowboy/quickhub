import AppKit

// MARK: - 用户输入帮助类

/// 封装用户输入对话框
enum UserInputHelper {

    /// 显示文件名输入对话框
    /// - Parameters:
    ///   - extension: 文件扩展名
    ///   - directory: 目标目录
    ///   - completion: 回调，返回用户输入的文件名（不含扩展名），如果用户取消则返回 nil
    static func promptFileName(extension ext: String, directory: String, completion: @escaping (String?) -> Void) {
        DispatchQueue.main.async {
            let alert = NSAlert()
            alert.messageText = "新建文件"
            alert.informativeText = "请输入文件名："
            alert.addButton(withTitle: "创建")
            alert.addButton(withTitle: "取消")

            let inputField = NSTextField(frame: NSRect(x: 0, y: 0, width: 300, height: 24))
            inputField.stringValue = "Untitled"
            inputField.placeholderString = "文件名"
            alert.accessoryView = inputField

            alert.beginSheetModal(for: NSApp.keyWindow ?? NSWindow()) { response in
                if response == .alertFirstButtonReturn {
                    let fileName = inputField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
                    if fileName.isEmpty {
                        completion("Untitled")
                    } else {
                        completion(fileName)
                    }
                } else {
                    completion(nil)
                }
            }
        }
    }

    /// 显示文件夹名输入对话框
    /// - Parameters:
    ///   - directory: 目标目录
    ///   - completion: 回调，返回用户输入的文件夹名，如果用户取消则返回 nil
    static func promptFolderName(directory: String, completion: @escaping (String?) -> Void) {
        DispatchQueue.main.async {
            let alert = NSAlert()
            alert.messageText = "新建文件夹"
            alert.informativeText = "请输入文件夹名称："
            alert.addButton(withTitle: "创建")
            alert.addButton(withTitle: "取消")

            let inputField = NSTextField(frame: NSRect(x: 0, y: 0, width: 300, height: 24))
            inputField.stringValue = "Untitled Folder"
            inputField.placeholderString = "文件夹名称"
            alert.accessoryView = inputField

            alert.beginSheetModal(for: NSApp.keyWindow ?? NSWindow()) { response in
                if response == .alertFirstButtonReturn {
                    let folderName = inputField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
                    if folderName.isEmpty {
                        completion("Untitled Folder")
                    } else {
                        completion(folderName)
                    }
                } else {
                    completion(nil)
                }
            }
        }
    }
}
