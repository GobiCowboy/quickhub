import SwiftUI
import AppKit
import Carbon

struct HotkeyRecorderView: View {
    @Binding var hotkey: HotkeyConfiguration?
    @State private var isRecording = false
    @State private var conflicts: [String] = []
    @State private var showConflictWarning = false
    @State private var localMonitor: Any?
    @State private var displayText: String = "点击设置快捷键"
    var onSave: (() -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 12) {
                // 快捷键显示/录制区域
                Button(action: {
                    if isRecording {
                        isRecording = false
                        stopRecording()
                    } else {
                        isRecording = true
                        startRecording()
                    }
                }) {
                    HStack {
                        if isRecording {
                            Text("按下快捷键...")
                                .foregroundColor(.orange)
                        } else {
                            Text(displayText)
                                .foregroundColor(displayText == "点击设置快捷键" ? .secondary : .primary)
                        }
                    }
                    .font(.system(.body, design: .monospaced))
                    .frame(minWidth: 120, alignment: .center)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(isRecording ? Color.orange.opacity(0.1) : Color.secondary.opacity(0.1))
                    .cornerRadius(6)
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(isRecording ? Color.orange : Color.clear, lineWidth: 2)
                    )
                }
                .buttonStyle(.plain)

                // 清除按钮
                if let config = hotkey, !config.isEmpty {
                    Button(action: {
                        hotkey = nil
                        conflicts = []
                        displayText = "点击设置快捷键"
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                }

                Spacer()
            }

            // 冲突警告
            if showConflictWarning && !conflicts.isEmpty {
                HStack(spacing: 4) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)
                    Text(conflicts.joined(separator: "\n"))
                        .font(.caption)
                        .foregroundColor(.orange)
                }
            }

            // 权限提示
            if !isRecording && hotkey == nil {
                Text("提示：全局快捷键需要辅助功能权限")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .frame(height: 60)
        .onAppear {
            updateDisplayText()
        }
        .onChange(of: hotkey) { newValue in
            updateDisplayText()
        }
        .onDisappear {
            stopRecording()
        }
    }

    private func updateDisplayText() {
        if let config = hotkey, !config.isEmpty {
            displayText = HotkeyUtil.encode(config)
            print("[HotkeyRecorder] 更新显示: \(displayText)")
        } else {
            displayText = "点击设置快捷键"
        }
    }

    private func startRecording() {
        stopRecording()
        print("[HotkeyRecorder] 开始录制")

        // 使用属性存储初始 displayText，避免循环引用
        let currentHotkey = hotkey
        if let config = currentHotkey, !config.isEmpty {
            displayText = HotkeyUtil.encode(config)
        } else {
            displayText = "点击设置快捷键"
        }

        localMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            guard self.isRecording else { return event }

            let modifiers = event.modifierFlags.rawValue & NSEvent.ModifierFlags.deviceIndependentFlagsMask.rawValue
            print("[HotkeyRecorder] 收到事件: keyCode=\(event.keyCode), modifiers=\(modifiers)")

            // 只接受有修饰符的快捷键
            if modifiers != 0 && event.keyCode != 0 {
                print("[HotkeyRecorder] 有效快捷键 recorded")
                // 提取 deviceIndependentFlagsMask 后的修饰符，避免系统添加额外修饰符
                let deviceIndependentModifiers = modifiers & NSEvent.ModifierFlags.deviceIndependentFlagsMask.rawValue
                DispatchQueue.main.async {
                    let config = HotkeyConfiguration(keyCode: event.keyCode, modifiers: deviceIndependentModifiers)
                    self.hotkey = config
                    self.displayText = HotkeyUtil.encode(config)
                    print("[HotkeyRecorder] 新快捷键已设置: \(self.displayText)")
                    self.conflicts = HotkeyUtil.checkSystemConflicts(keyCode: event.keyCode, modifiers: modifiers)
                    self.showConflictWarning = !self.conflicts.isEmpty
                    print("[HotkeyRecorder] 冲突检测结果: \(self.conflicts)")
                    self.isRecording = false
                    // 调用 onSave 保存设置
                    self.onSave?()
                }
                return nil // 消费事件
            }

            // ESC 键取消录制
            if event.keyCode == 53 {
                print("[HotkeyRecorder] ESC 取消录制")
                DispatchQueue.main.async {
                    self.isRecording = false
                    if let config = self.hotkey, !config.isEmpty {
                        self.displayText = HotkeyUtil.encode(config)
                    } else {
                        self.displayText = "点击设置快捷键"
                    }
                }
                return nil
            }

            return event
        }
    }

    private func stopRecording() {
        if let monitor = localMonitor {
            NSEvent.removeMonitor(monitor)
            localMonitor = nil
        }
    }
}
