import Foundation

/// 앱이 들고 있는 사본. 키체인을 매번 안 읽으려고 둠
struct CachedClaudeCredentials: Codable, Equatable, Sendable {
    let credentials: ClaudeCredentials
    let sourceVersion: Date     // 복사해올 때 원본 수정 시각
    let email: String?
}

protocol ClaudeCredentialCache: Sendable {
    func load() -> CachedClaudeCredentials?
    func save(_ entry: CachedClaudeCredentials)
    func clear()
}

/// Application Support/Hando/claude.json (0600)
/// 키체인에 두면 ad-hoc 서명이 바뀔 때마다 허용 창이 떠서 파일로 둠. 리프레시 토큰은 없음
struct FileClaudeCredentialCache: ClaudeCredentialCache {
    var url: URL = AppPaths.support.appendingPathComponent("claude.json")

    func load() -> CachedClaudeCredentials? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(CachedClaudeCredentials.self, from: data)
    }

    func save(_ entry: CachedClaudeCredentials) {
        guard let data = try? JSONEncoder().encode(entry) else { return }
        try? data.write(to: url, options: [.atomic])
        try? FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: url.path)
    }

    func clear() {
        try? FileManager.default.removeItem(at: url)
    }
}
