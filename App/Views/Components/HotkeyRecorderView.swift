import SwiftUI
import AppKit

struct HotkeyRecorderView: View {
    @Binding var hotkey: HotkeyConfiguration?
    @State private var isRecording = false
    @State private var conflicts: [String] = []
    @State private var showConflictWarning = false
    @State private var localMonitor: Any?

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
                                .foregroundColor(.secondary)
                        } else if let config = hotkey, !config.isEmpty {
                            Text(HotkeyUtil.encode(config))
                                .foregroundColor(.primary)
                        } else {
                            Text("点击设置快捷键")
                                .foregroundColor(.secondary)
                        }
                    }
                    .font(.system(.body, design: .monospaced))
                    .frame(minWidth: 120, alignment: .center)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(isRecording ? Color.accentColor.opacity(0.1) : Color.secondary.opacity(0.1))
                    .cornerRadius(6)
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(isRecording ? Color.accentColor : Color.clear, lineWidth: 2)
                    )
                }
                .buttonStyle(.plain)

                // 清除按钮
                if let config = hotkey, !config.isEmpty {
                    Button(action: {
                        hotkey = nil
                        conflicts = []
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
        }
        .frame(height: 50)
        .onDisappear {
            stopRecording()
        }
    }

    private func startRecording() {
        stopRecording()
        print("[HotkeyRecorder] 开始录制")

        localMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [self] event in
            guard isRecording else { return event }

            let modifiers = event.modifierFlags.rawValue & NSEvent.ModifierFlags.deviceIndependentFlagsMask.rawValue
            print("[HotkeyRecorder] 收到事件: keyCode=\(event.keyCode), modifiers=\(modifiers)")

            // 只接受有修饰符的快捷键
            if modifiers != 0 && event.keyCode != 0 {
                print("[HotkeyRecorder] 有效快捷键 recorded")
                DispatchQueue.main.async {
                    let config = HotkeyConfiguration(keyCode: event.keyCode, modifiers: modifiers)
                    self.hotkey = config
                    self.conflicts = HotkeyUtil.checkSystemConflicts(keyCode: event.keyCode, modifiers: modifiers)
                    self.showConflictWarning = !self.conflicts.isEmpty
                    print("[HotkeyRecorder] 冲突检测结果: \(self.conflicts)")
                    self.isRecording = false
                }
                return nil // 消费事件
            }

            // ESC 键取消录制
            if event.keyCode == 53 {
                print("[HotkeyRecorder] ESC 取消录制")
                DispatchQueue.main.async {
                    self.isRecording = false
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
