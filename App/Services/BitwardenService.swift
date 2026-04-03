import Foundation

/// Bitwarden CLI 服务
class BitwardenService: BitwardenServiceProtocol {
    static let shared = BitwardenService()

    private init() {}

    /// 搜索密码
    func searchPasswords(query: String) async throws -> [BitwardenItem] {
        guard !query.isEmpty else { return [] }

        return try await withCheckedThrowingContinuation { continuation in
            let task = Process()
            task.executableURL = URL(fileURLWithPath: "/opt/homebrew/bin/bw")
            task.arguments = ["list", "items", "--search", query]

            let pipe = Pipe()
            task.standardOutput = pipe
            task.standardError = pipe

            do {
                try task.run()
                task.waitUntilExit()

                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                let output = String(data: data, encoding: .utf8) ?? ""

                if task.terminationStatus == 0 {
                    let items = try JSONDecoder().decode([BitwardenItem].self, from: output.data(using: .utf8) ?? Data())
                    continuation.resume(returning: items)
                } else {
                    continuation.resume(throwing: BitwardenError.searchFailed(output))
                }
            } catch {
                continuation.resume(throwing: BitwardenError.executionFailed(error.localizedDescription))
            }
        }
    }

    /// 获取密码详情（包含密码）
    func getPassword(itemId: String) async throws -> BitwardenLoginItem? {
        return try await withCheckedThrowingContinuation { continuation in
            let task = Process()
            task.executableURL = URL(fileURLWithPath: "/opt/homebrew/bin/bw")
            task.arguments = ["get", "item", itemId]

            let pipe = Pipe()
            task.standardOutput = pipe
            task.standardError = pipe

            do {
                try task.run()
                task.waitUntilExit()

                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                let output = String(data: data, encoding: .utf8) ?? ""

                if task.terminationStatus == 0 {
                    let item = try JSONDecoder().decode(BitwardenItem.self, from: output.data(using: .utf8) ?? Data())
                    continuation.resume(returning: item.login)
                } else {
                    continuation.resume(throwing: BitwardenError.itemNotFound)
                }
            } catch {
                continuation.resume(throwing: BitwardenError.executionFailed(error.localizedDescription))
            }
        }
    }
}

// MARK: - 错误类型

enum BitwardenError: Error, LocalizedError {
    case searchFailed(String)
    case itemNotFound
    case executionFailed(String)
    case notUnlocked

    var errorDescription: String? {
        switch self {
        case .searchFailed(let message):
            return localized("bitwarden.error.search_failed", with: message)
        case .itemNotFound:
            return localized("bitwarden.error.item_not_found")
        case .executionFailed(let message):
            return localized("bitwarden.error.execution_failed", with: message)
        case .notUnlocked:
            return localized("bitwarden.error.not_unlocked")
        }
    }
}
