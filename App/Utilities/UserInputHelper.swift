import AppKit
import SwiftUI

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

            // 激活应用
            NSApp.activate(ignoringOtherApps: true)

            // 延迟显示对话框，确保窗口状态稳定
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                // 先关闭任何可能阻挡的窗口
                if let keyWindow = NSApp.keyWindow {
                    // 使用 keyWindow 作为 sheet 父窗口
                    alert.beginSheetModal(for: keyWindow) { response in
                        if response == .alertFirstButtonReturn {
                            let fileName = inputField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
                            completion(fileName.isEmpty ? "Untitled" : fileName)
                        } else {
                            completion(nil)
                        }
                    }

                    // 延迟聚焦到输入框（sheet 显示后）
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        keyWindow.makeFirstResponder(inputField)
                        inputField.selectText(nil)
                    }
                } else {
                    // 没有 keyWindow，使用 runModal 显示普通对话框
                    let response = alert.runModal()
                    if response == .alertFirstButtonReturn {
                        let fileName = inputField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
                        completion(fileName.isEmpty ? "Untitled" : fileName)
                    } else {
                        completion(nil)
                    }
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

            // 激活应用并获取关键窗口
            NSApp.activate(ignoringOtherApps: true)

            // 延迟显示对话框，确保窗口状态稳定
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                guard let keyWindow = NSApp.keyWindow else {
                    // 如果还是没有 keyWindow，创建一个临时窗口作为 sheet 父窗口
                    let tempWindow = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 1, height: 1), styleMask: .borderless, backing: .buffered, defer: false)
                    tempWindow.level = .floating
                    tempWindow.center()
                    tempWindow.makeKeyAndOrderFront(nil)

                    alert.beginSheetModal(for: tempWindow) { response in
                        if response == .alertFirstButtonReturn {
                            let folderName = inputField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
                            completion(folderName.isEmpty ? "Untitled Folder" : folderName)
                        } else {
                            completion(nil)
                        }
                    }

                    // 延迟聚焦到输入框
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        tempWindow.makeFirstResponder(inputField)
                        inputField.selectText(nil)
                    }
                    return
                }

                alert.beginSheetModal(for: keyWindow) { response in
                    if response == .alertFirstButtonReturn {
                        let folderName = inputField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
                        completion(folderName.isEmpty ? "Untitled Folder" : folderName)
                    } else {
                        completion(nil)
                    }
                }

                // 延迟聚焦到输入框
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    keyWindow.makeFirstResponder(inputField)
                    inputField.selectText(nil)
                }
            }
        }
    }

    /// 显示 Bitwarden 搜索对话框
    static func promptBitwardenSearch(completion: @escaping (String?) -> Void) {
        DispatchQueue.main.async {
            let alert = NSAlert()
            alert.messageText = "搜索密码"
            alert.informativeText = "请输入搜索关键词："
            alert.addButton(withTitle: "搜索")
            alert.addButton(withTitle: "取消")

            let inputField = NSTextField(frame: NSRect(x: 0, y: 0, width: 300, height: 24))
            inputField.placeholderString = "搜索 Bitwarden..."
            alert.accessoryView = inputField

            alert.beginSheetModal(for: NSApp.keyWindow ?? NSWindow()) { response in
                if response == .alertFirstButtonReturn {
                    let query = inputField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
                    completion(query.isEmpty ? nil : query)
                } else {
                    completion(nil)
                }
            }
        }
    }

    /// 显示 Bitwarden 搜索结果列表
    static func showBitwardenResults(items: [BitwardenItem], completion: @escaping (BitwardenItem?) -> Void) {
        DispatchQueue.main.async {
            let hostingController = NSHostingController(
                rootView: BitwardenResultsView(items: items, onSelect: completion)
            )

            let panel = NSPanel(contentViewController: hostingController)
            panel.title = "搜索结果"
            panel.styleMask = [.titled, .closable, .fullSizeContentView]
            panel.setContentSize(NSSize(width: 400, height: 300))
            panel.center()

            NSApp.activate(ignoringOtherApps: true)
            panel.makeKeyAndOrderFront(nil)
        }
    }
}

// MARK: - Bitwarden 搜索结果视图

struct BitwardenResultsView: View {
    let items: [BitwardenItem]
    let onSelect: (BitwardenItem?) -> Void

    var body: some View {
        VStack(spacing: 0) {
            if items.isEmpty {
                Text("未找到匹配的密码")
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List(items) { item in
                    Button(action: {
                        onSelect(item)
                    }) {
                        HStack {
                            Image(systemName: "key.fill")
                                .foregroundColor(.orange)
                            VStack(alignment: .leading) {
                                Text(item.name)
                                    .font(.body)
                                if let username = item.login?.username {
                                    Text(username)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                            Spacer()
                        }
                        .padding(.vertical, 4)
                    }
                    .buttonStyle(.plain)
                }
            }

            Divider()

            HStack {
                Spacer()
                Button("取消") {
                    onSelect(nil)
                }
                .keyboardShortcut(.cancelAction)
            }
            .padding()
        }
        .frame(width: 400, height: 300)
    }
}
