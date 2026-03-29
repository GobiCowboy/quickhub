import Foundation

// MARK: - 存储服务协议

protocol StorageServiceProtocol {
    /// 加载配置
    func loadConfig() -> AppConfig

    /// 保存配置
    func saveConfig(_ config: AppConfig)

    /// 添加分组
    func addGroup(_ group: CommandGroup)

    /// 更新分组
    func updateGroup(_ group: CommandGroup)

    /// 删除分组
    func deleteGroup(_ group: CommandGroup)

    /// 添加命令项到分组
    func addItem(_ item: CommandItem, to group: CommandGroup)

    /// 更新分组中的命令项
    func updateItem(_ item: CommandItem, in group: CommandGroup)

    /// 从分组中删除命令项
    func deleteItem(_ item: CommandItem, from group: CommandGroup)
}

// MARK: - Finder 服务协议

protocol FinderServiceProtocol {
    /// 获取当前 Finder 选中的文件和目录
    func getSelectedItems() -> [URL]

    /// 获取当前目录
    func getCurrentDirectory() -> String

    /// 获取选中的第一个文件/目录的路径
    func getFirstSelectedPath() -> String?
}

// MARK: - 命令执行器协议

protocol CommandExecutorProtocol {
    /// 执行命令
    func execute(_ item: CommandItem, context: ExecutionContext) async throws -> ExecutionResult
}

// MARK: - Bitwarden 服务协议

protocol BitwardenServiceProtocol {
    /// 搜索密码
    func searchPasswords(query: String) async throws -> [BitwardenItem]

    /// 获取密码详情
    func getPassword(itemId: String) async throws -> BitwardenLoginItem?
}

// MARK: - 上下文

struct ExecutionContext {
    var filePath: String?   // 完整文件路径
    var fileName: String?   // 文件名（不含路径）
    var directory: String   // 所在目录

    init(filePath: String? = nil, directory: String = "") {
        self.filePath = filePath
        self.fileName = filePath?.components(separatedBy: "/").last
        self.directory = directory

        // 如果没有提供目录，从文件路径推导
        if self.directory.isEmpty, let path = filePath {
            self.directory = (path as NSString).deletingLastPathComponent
        }
    }
}

// MARK: - 结果

struct ExecutionResult {
    var success: Bool
    var output: String
}

// MARK: - 错误

enum ExecutionError: LocalizedError {
    case missingCommand
    case missingTemplate
    case missingPath
    case commandFailed(String)
    case executionFailed(String)

    var errorDescription: String? {
        switch self {
        case .missingCommand:
            return "命令未设置"
        case .missingTemplate:
            return "模板未设置"
        case .missingPath:
            return "路径未设置"
        case .commandFailed(let msg):
            return "命令执行失败: \(msg)"
        case .executionFailed(let msg):
            return "执行失败: \(msg)"
        }
    }
}
