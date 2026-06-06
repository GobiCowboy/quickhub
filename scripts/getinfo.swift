#!/usr/bin/env swift

import AppKit
import AVFoundation
import ImageIO
import UniformTypeIdentifiers

// MARK: - 获取 Finder 选中文件

func getFinderSelection() -> [URL] {
    let script = """
    tell application "Finder"
        try
            set sel to selection
            if sel is not {} then
                set pathList to ""
                repeat with i from 1 to (count sel)
                    set anItem to item i of sel
                    set pathList to pathList & POSIX path of (anItem as alias) & "\\n"
                end repeat
                return pathList
            end if
        end try
        return ""
    end tell
    """

    var error: NSDictionary?
    let appleScript = NSAppleScript(source: script)!
    let result = appleScript.executeAndReturnError(&error)

    return result.stringValue?
        .components(separatedBy: "\n")
        .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        .filter { !$0.isEmpty }
        .map { URL(fileURLWithPath: $0) } ?? []
}

// MARK: - 格式化工具

func formatFileSize(_ size: Int64) -> String {
    if size < 1024 { return "\(size) B" }
    if size < 1024 * 1024 { return String(format: "%.1f KB", Double(size) / 1024.0) }
    if size < 1024 * 1024 * 1024 { return String(format: "%.1f MB", Double(size) / (1024.0 * 1024.0)) }
    return String(format: "%.2f GB", Double(size) / (1024.0 * 1024.0 * 1024.0))
}

func formatDate(_ date: Date) -> String {
    let formatter = DateFormatter()
    formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
    formatter.locale = Locale(identifier: "zh_CN")
    return formatter.string(from: date)
}

// MARK: - 媒体类型判断

let mediaExtensions: Set<String> = [
    "mp4", "mov", "mkv", "avi", "wmv", "flv", "webm", "m4v", "mpg", "mpeg", "ts", "vob",
    "mp3", "m4a", "flac", "wav", "aac", "ogg", "wma", "opus", "aiff", "ape"
]

let imageExtensions: Set<String> = [
    "png", "jpg", "jpeg", "heic", "heif", "tiff", "tif", "webp", "bmp", "gif", "svg", "ico", "raw", "cr2", "nef", "arw", "dng"
]

func isMediaFile(_ ext: String) -> Bool {
    mediaExtensions.contains(ext.lowercased())
}

func isImageFile(_ ext: String) -> Bool {
    imageExtensions.contains(ext.lowercased())
}

// MARK: - 媒体元数据

struct MediaInfo {
    var duration: String?
    var codec: String?
    var bitrate: String?
}

func getMediaMetadata(url: URL) -> MediaInfo {
    let asset = AVURLAsset(url: url)
    var info = MediaInfo()

    // 同步加载 duration（独立进程，无 UI 阻塞问题）
    let durationSemaphore = DispatchSemaphore(value: 0)
    var loadedDuration: CMTime?
    asset.loadValuesAsynchronously(forKeys: ["duration"]) {
        loadedDuration = asset.duration
        durationSemaphore.signal()
    }
    durationSemaphore.wait()

    if let duration = loadedDuration, duration.isValid && !duration.isIndefinite {
        let totalSeconds = CMTimeGetSeconds(duration)
        let hours = Int(totalSeconds) / 3600
        let minutes = (Int(totalSeconds) % 3600) / 60
        let seconds = Int(totalSeconds) % 60
        if hours > 0 {
            info.duration = String(format: "%d:%02d:%02d", hours, minutes, seconds)
        } else {
            info.duration = String(format: "%d:%02d", minutes, seconds)
        }
    }

    // 同步加载 tracks（编码 + 比特率）
    let tracksSemaphore = DispatchSemaphore(value: 0)
    var loadedTracks: [AVAssetTrack] = []
    asset.loadValuesAsynchronously(forKeys: ["tracks"]) {
        loadedTracks = asset.tracks
        tracksSemaphore.signal()
    }
    tracksSemaphore.wait()

    if !loadedTracks.isEmpty {
        // 比特率
        let totalBitrate = loadedTracks.compactMap { $0.estimatedDataRate }.reduce(0, +)
        if totalBitrate > 0 {
            let kbps = Int(totalBitrate / 1000)
            info.bitrate = "\(kbps) kbps"
        }

        // 编码 — 取第一个 track 的格式描述
        if let desc = loadedTracks.first?.formatDescriptions.first {
            let formatDescription = desc as! CMFormatDescription
            let codecType = CMFormatDescriptionGetMediaSubType(formatDescription)
            let fourCC = UTCreateStringForOSType(codecType).takeUnretainedValue() as String
            info.codec = fourCC
        }
    }

    return info
}

struct ImageInfo {
    var dimensions: String?
    var dpi: String?
}

func getImageMetadata(url: URL) -> ImageInfo {
    var info = ImageInfo()
    guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else { return info }

    guard let props = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [String: Any] else { return info }

    // 尺寸
    if let width = props[kCGImagePropertyPixelWidth as String] as? Int,
       let height = props[kCGImagePropertyPixelHeight as String] as? Int {
        info.dimensions = "\(width) × \(height) px"
    }

    // DPI
    let dpiX = props[kCGImagePropertyDPIWidth as String] as? Double ?? 0
    let dpiY = props[kCGImagePropertyDPIHeight as String] as? Double ?? 0
    if dpiX > 0 && dpiY > 0 {
        info.dpi = "\(Int(dpiX)) × \(Int(dpiY))"
    }

    return info
}

// MARK: - 目录文件数

func countDirectoryItems(_ path: String) -> Int {
    guard let items = try? FileManager.default.contentsOfDirectory(atPath: path) else { return 0 }
    return items.count
}

// MARK: - 浮窗

var eventMonitor: Any?
var dismissWork: DispatchWorkItem?

func showInfoPanel(at mouseLocation: NSPoint, fileURL: URL) {
    let fm = FileManager.default
    let path = fileURL.path
    let name = fileURL.lastPathComponent
    let isDir = (try? fm.attributesOfItem(atPath: path))?[.type] as? FileAttributeType == .typeDirectory

    guard let attrs = try? fm.attributesOfItem(atPath: path) else { return }

    // 文件类型
    let ext = fileURL.pathExtension
    var fileType = "文件夹"
    if !isDir, !ext.isEmpty {
        if let utType = UTType(filenameExtension: ext) {
            fileType = utType.localizedDescription ?? ".\(ext)"
        } else {
            fileType = ".\(ext)"
        }
    }

    // 文件大小
    let size = (attrs[.size] as? Int64) ?? 0
    let sizeStr = isDir ? calculateDirectorySize(path) : formatFileSize(size)

    // 日期
    let created = (attrs[.creationDate] as? Date) ?? Date.distantPast
    let modified = (attrs[.modificationDate] as? Date) ?? Date.distantPast

    // 权限
    let perms = (attrs[.posixPermissions] as? UInt16) ?? 0
    let permStr = String(perms, radix: 8, uppercase: false)

    // 文件图标
    let icon = NSWorkspace.shared.icon(forFile: path)
    icon.size = NSSize(width: 32, height: 32)

    // 图标 + 名称
    let iconView = NSImageView(image: icon)
    iconView.frame = NSRect(x: 0, y: 0, width: 32, height: 32)

    let nameLabel = NSTextField(labelWithString: name)
    nameLabel.font = .boldSystemFont(ofSize: 13)
    nameLabel.lineBreakMode = .byTruncatingMiddle
    nameLabel.maximumNumberOfLines = 1
    nameLabel.setContentHuggingPriority(.defaultLow, for: .horizontal)

    let headerStack = NSStackView(views: [iconView, nameLabel])
    headerStack.orientation = .horizontal
    headerStack.spacing = 8
    headerStack.alignment = .centerY
    headerStack.edgeInsets = NSEdgeInsets(top: 0, left: 0, bottom: 0, right: 0)

    // 分隔线
    let divider = NSBox()
    divider.boxType = .separator

    // 详情行
    func detailRow(label: String, value: String) -> NSStackView {
        let l = NSTextField(labelWithString: label)
        l.font = .systemFont(ofSize: 11)
        l.textColor = .secondaryLabelColor
        l.alignment = .right
        l.widthAnchor.constraint(equalToConstant: 54).isActive = true

        let v = NSTextField(labelWithString: value)
        v.font = .monospacedSystemFont(ofSize: 11, weight: .regular)
        v.lineBreakMode = .byTruncatingMiddle
        v.maximumNumberOfLines = 1

        let stack = NSStackView(views: [l, v])
        stack.orientation = .horizontal
        stack.spacing = 8
        return stack
    }

    var details: [(String, String)] = [
        ("类型", fileType),
        ("路径", path),
        ("大小", sizeStr),
        ("创建", formatDate(created)),
        ("修改", formatDate(modified)),
        ("权限", "(\(permStr))"),
    ]

    // 目录：文件数
    if isDir {
        let count = countDirectoryItems(path)
        details.insert(("文件数", "\(count) 个项目"), at: 1)
    }

    // 图片：尺寸 + DPI
    if !isDir, isImageFile(ext) {
        let imgInfo = getImageMetadata(url: fileURL)
        if let dims = imgInfo.dimensions { details.append(("尺寸", dims)) }
        if let dpi = imgInfo.dpi { details.append(("DPI", dpi)) }
    }

    // 音频/视频：时长 + 编码 + 比特率
    if !isDir, isMediaFile(ext) {
        let mediaInfo = getMediaMetadata(url: fileURL)
        if let dur = mediaInfo.duration { details.append(("时长", dur)) }
        if let codec = mediaInfo.codec { details.append(("编码", codec)) }
        if let bitrate = mediaInfo.bitrate { details.append(("比特率", bitrate)) }
    }

    let stack = NSStackView()
    stack.orientation = .vertical
    stack.alignment = .leading
    stack.spacing = 4
    stack.edgeInsets = NSEdgeInsets(top: 12, left: 14, bottom: 12, right: 14)
    stack.addArrangedSubview(headerStack)
    stack.addArrangedSubview(divider)
    for (label, value) in details {
        stack.addArrangedSubview(detailRow(label: label, value: value))
    }

    // 面板
    let panel = NSPanel(
        contentRect: .zero,
        styleMask: [.titled, .fullSizeContentView, .nonactivatingPanel],
        backing: .buffered,
        defer: true
    )
    panel.contentView = stack
    panel.isOpaque = false
    panel.backgroundColor = NSColor.windowBackgroundColor.withAlphaComponent(0.95)
    panel.hasShadow = true
    panel.hidesOnDeactivate = false
    panel.level = .floating
    panel.collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary]
    panel.titlebarAppearsTransparent = true
    panel.titleVisibility = .hidden
    panel.isMovableByWindowBackground = true
    panel.isReleasedWhenClosed = false

    // 尺寸
    let fittingSize = stack.fittingSize
    let panelWidth: CGFloat = 280
    let panelHeight = fittingSize.height
    panel.setContentSize(NSSize(width: panelWidth, height: panelHeight))

    // 位置：鼠标右下方
    var originX = mouseLocation.x + 16
    var originY = mouseLocation.y - panelHeight - 8

    // 屏幕边界
    if let screen = NSScreen.main {
        let frame = screen.visibleFrame
        if originX + panelWidth > frame.maxX { originX = mouseLocation.x - panelWidth - 16 }
        if originY < frame.minY { originY = mouseLocation.y + 16 }
        if originY + panelHeight > frame.maxY { originY = frame.maxY - panelHeight }
        if originX < frame.minX { originX = frame.minX }
    }

    panel.setFrameOrigin(NSPoint(x: originX, y: originY))

    // 关闭逻辑
    func dismiss() {
        guard dismissWork != nil else { return }
        dismissWork = nil
        if let m = eventMonitor {
            NSEvent.removeMonitor(m)
            eventMonitor = nil
        }
        panel.close()
        DispatchQueue.main.async { NSApp.terminate(nil) }
    }

    dismissWork = DispatchWorkItem(block: dismiss)

    // 窗口关闭也触发清理（delegate 是 weak，需要持有强引用）
    let windowDelegate = WindowDelegate(callback: dismiss)
    panel.delegate = windowDelegate

    panel.orderFrontRegardless()
    NSApp.activate(ignoringOtherApps: true)

    // 3 秒自动关闭
    DispatchQueue.main.asyncAfter(deadline: .now() + 3, execute: dismissWork!)

    // 点击外部关闭
    eventMonitor = NSEvent.addGlobalMonitorForEvents(matching: .leftMouseDown) { event in
        let loc = NSEvent.mouseLocation
        if !panel.frame.contains(loc) {
            DispatchQueue.main.async { dismiss() }
        }
    }
}

// MARK: - 计算目录大小

func calculateDirectorySize(_ path: String) -> String {
    let fm = FileManager.default
    guard let enumerator = fm.enumerator(atPath: path) else { return "—" }
    var total: Int64 = 0
    while let file = enumerator.nextObject() as? String {
        let fullPath = (path as NSString).appendingPathComponent(file)
        if let attrs = try? fm.attributesOfItem(atPath: fullPath) {
            total += (attrs[.size] as? Int64) ?? 0
        }
    }
    return formatFileSize(total)
}

// MARK: - 窗口代理

class WindowDelegate: NSObject, NSWindowDelegate {
    let callback: () -> Void
    init(callback: @escaping () -> Void) { self.callback = callback }
    func windowWillClose(_ notification: Notification) { callback() }
}

// MARK: - 入口

let argumentPaths = CommandLine.arguments.dropFirst()
let selection = argumentPaths.isEmpty
    ? getFinderSelection()
    : argumentPaths.map { URL(fileURLWithPath: ($0 as NSString).expandingTildeInPath) }
guard let fileURL = selection.first else {
    print("未在 Finder 中选中文件")
    exit(0)
}

let app = NSApplication.shared
app.setActivationPolicy(.accessory)

showInfoPanel(at: NSEvent.mouseLocation, fileURL: fileURL)

app.run()
