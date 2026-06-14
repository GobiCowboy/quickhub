import Foundation

/// 剪贴板服务 - 管理文件剪切/复制/粘贴状态
class ClipboardService {
    static let shared = ClipboardService()

    enum Operation {
        case cut
        case copy
    }

    private(set) var sourcePath: String?
    private(set) var operation: Operation?

    private init() {}

    /// 标记文件为待剪切
    func setCut(path: String) {
        sourcePath = path
        operation = .cut
    }

    /// 标记文件为待复制
    func setCopy(path: String) {
        sourcePath = path
        operation = .copy
    }

    /// 清除剪贴板状态
    func clear() {
        sourcePath = nil
        operation = nil
    }

    /// 是否有内容待粘贴
    var hasContent: Bool {
        return sourcePath != nil && operation != nil
    }
}
