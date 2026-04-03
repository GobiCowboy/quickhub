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
            alert.messageText = localized("input.new_file.title")
            alert.informativeText = localized("input.new_file.prompt")
            alert.addButton(withTitle: localized("common.create"))
            alert.addButton(withTitle: localized("common.cancel"))

            let inputField = NSTextField(frame: NSRect(x: 0, y: 0, width: 300, height: 24))
            inputField.stringValue = localized("input.new_file.default")
            inputField.placeholderString = localized("input.new_file.placeholder")
            alert.accessoryView = inputField

            // 激活应用
            NSApp.activate(ignoringOtherApps: true)

            // 创建一个临时窗口作为 sheet 的父窗口
            let tempWindow = NSWindow(contentRect: .zero, styleMask: .borderless, backing: .buffered, defer: false)
            tempWindow.level = .floating
            tempWindow.center()
            tempWindow.makeKeyAndOrderFront(nil)

            // 显示 sheet 并在显示后聚焦输入框
            alert.beginSheetModal(for: tempWindow) { response in
                if response == .alertFirstButtonReturn {
                    let fileName = inputField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
                    completion(fileName.isEmpty ? localized("input.new_file.default") : fileName)
                } else {
                    completion(nil)
                }
            }

            // 延迟聚焦到输入框
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                tempWindow.makeFirstResponder(inputField)
                inputField.selectText(nil)
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
            alert.messageText = localized("input.new_folder.title")
            alert.informativeText = localized("input.new_folder.prompt")
            alert.addButton(withTitle: localized("common.create"))
            alert.addButton(withTitle: localized("common.cancel"))

            let inputField = NSTextField(frame: NSRect(x: 0, y: 0, width: 300, height: 24))
            inputField.stringValue = localized("input.new_folder.default")
            inputField.placeholderString = localized("input.new_folder.placeholder")
            alert.accessoryView = inputField

            // 激活应用
            NSApp.activate(ignoringOtherApps: true)

            // 创建一个临时窗口作为 sheet 的父窗口
            let tempWindow = NSWindow(contentRect: .zero, styleMask: .borderless, backing: .buffered, defer: false)
            tempWindow.level = .floating
            tempWindow.center()
            tempWindow.makeKeyAndOrderFront(nil)

            // 显示 sheet 并在显示后聚焦输入框
            alert.beginSheetModal(for: tempWindow) { response in
                if response == .alertFirstButtonReturn {
                    let folderName = inputField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
                    completion(folderName.isEmpty ? localized("input.new_folder.default") : folderName)
                } else {
                    completion(nil)
                }
            }

            // 延迟聚焦到输入框
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                tempWindow.makeFirstResponder(inputField)
                inputField.selectText(nil)
            }
        }
    }

    /// 显示 Bitwarden 搜索对话框
    static func promptBitwardenSearch(completion: @escaping (String?) -> Void) {
        DispatchQueue.main.async {
            let alert = NSAlert()
            alert.messageText = localized("input.bitwarden_search.title")
            alert.informativeText = localized("input.bitwarden_search.prompt")
            alert.addButton(withTitle: localized("bitwarden.search_button"))
            alert.addButton(withTitle: localized("common.cancel"))

            let inputField = NSTextField(frame: NSRect(x: 0, y: 0, width: 300, height: 24))
            inputField.placeholderString = localized("input.bitwarden_search.placeholder")
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
            panel.title = localized("input.bitwarden_results.title")
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
                Text(localized("bitwarden.no_results"))
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
                Button(localized("common.cancel")) {
                    onSelect(nil)
                }
                .keyboardShortcut(.cancelAction)
            }
            .padding()
        }
        .frame(width: 400, height: 300)
    }
}
