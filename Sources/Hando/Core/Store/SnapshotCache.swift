import Foundation

/// 마지막으로 받은 사용량. 껐다 켜도 바로 보여주고, 최근 거면 켜자마자 요청 안 함
protocol SnapshotCache: Sendable {
    func load(providerID: String) -> UsageSnapshot?
    func save(_ snapshot: UsageSnapshot, providerID: String)
}

/// Application Support/Hando/last-<서비스>.json (0600, 이메일 들어있어서)
struct FileSnapshotCache: SnapshotCache {
    var directory: URL = AppPaths.support

    func load(providerID: String) -> UsageSnapshot? {
        guard let data = try? Data(contentsOf: url(providerID)) else { return nil }
        return try? JSONDecoder().decode(UsageSnapshot.self, from: data)
    }

    func save(_ snapshot: UsageSnapshot, providerID: String) {
        guard let data = try? JSONEncoder().encode(snapshot) else { return }
        let url = url(providerID)
        try? data.write(to: url, options: [.atomic])
        try? FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: url.path)
    }

    private func url(_ providerID: String) -> URL {
        directory.appendingPathComponent("last-\(providerID).json")
    }
}

/// 테스트, 데모용
struct NoSnapshotCache: SnapshotCache {
    func load(providerID: String) -> UsageSnapshot? { nil }
    func save(_ snapshot: UsageSnapshot, providerID: String) {}
}
