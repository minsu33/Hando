import Foundation

/// CodexBar 방식:
/// 1. 평소엔 앱 사본만 씀 (허용 창 X)
/// 2. 원본이 바뀌었는지는 수정 시각만 봄 (1분에 한 번)
/// 3. 바뀌었으면 원본 다시 읽음. 백그라운드에선 허용 창 안 띄움 → 필요하면 사용자가 눌렀을 때
/// 4. 만료됐는데 원본 그대로면 CLI한테 재발급 시키고 다시 봄 (5분에 한 번)
actor ClaudeCredentialStore {
    static let probeInterval: TimeInterval = 60
    static let cliRefreshInterval: TimeInterval = 5 * 60

    private let source: ClaudeCredentialSource
    private let cache: ClaudeCredentialCache
    private let refresher: ClaudeCLIRefresher
    private let now: @Sendable () -> Date

    private var lastProbe: (at: Date, version: Date?)?
    private var lastCLIRefresh: Date?

    init(source: ClaudeCredentialSource = ClaudeCodeCredentialSource(),
         cache: ClaudeCredentialCache = FileClaudeCredentialCache(),
         refresher: ClaudeCLIRefresher = ShellClaudeCLIRefresher(),
         now: @escaping @Sendable () -> Date = { Date() }) {
        self.source = source
        self.cache = cache
        self.refresher = refresher
        self.now = now
    }

    func current(_ context: FetchContext) async throws -> CachedClaudeCredentials {
        let version = probe(force: context == .userInitiated)
        guard let version else {
            // CLI에서 로그아웃함
            cache.clear()
            throw ProviderError.notLoggedIn(hint: Strings.Claude.notLoggedIn)
        }

        if let cached = cache.load(), cached.sourceVersion == version {
            Debug.log("[claude] using app copy (expired: \(cached.credentials.isExpired(now: now()) ? "yes" : "no"))")
            if !cached.credentials.isExpired(now: now()) { return cached }
            return try await refreshViaCLI(context, staleVersion: version)
        }
        return try reload(version: version, context)
    }

    /// 401 받았을 때: 사본 버리고 다음엔 원본부터
    func invalidate() {
        cache.clear()
        lastProbe = nil
    }

    func forget() { invalidate() }

    // MARK: -

    private func probe(force: Bool) -> Date? {
        if !force, let lastProbe, now().timeIntervalSince(lastProbe.at) < Self.probeInterval {
            return lastProbe.version
        }
        let version = source.version()
        lastProbe = (now(), version)
        return version
    }

    private func reload(version: Date, _ context: FetchContext) throws -> CachedClaudeCredentials {
        switch source.read(interactive: context == .userInitiated) {
        case .found(let data):
            let entry = CachedClaudeCredentials(credentials: try ClaudeCredentials.parse(data),
                                                sourceVersion: version,
                                                email: source.email())
            cache.save(entry)
            return entry
        case .needsPermission:
            Debug.log("[claude] login changed, keychain needs permission")
            throw ProviderError.needsUserAction(hint: Strings.Claude.needsPermission)
        case .notFound:
            cache.clear()
            throw ProviderError.notLoggedIn(hint: Strings.Claude.notLoggedIn)
        }
    }

    private func refreshViaCLI(_ context: FetchContext, staleVersion: Date) async throws -> CachedClaudeCredentials {
        let canRun = context == .userInitiated
            || lastCLIRefresh.map { now().timeIntervalSince($0) >= Self.cliRefreshInterval } ?? true
        guard canRun else { throw ProviderError.unauthorized(hint: Strings.Claude.relogin) }

        lastCLIRefresh = now()
        await refresher.refresh()

        let renewed = probe(force: true).map { $0 != staleVersion } ?? false
        Debug.log("[claude] cli refresh renewed login: \(renewed ? "yes" : "no")")
        guard let version = probe(force: true), version != staleVersion else {
            throw ProviderError.unauthorized(hint: Strings.Claude.relogin)
        }
        let entry = try reload(version: version, context)
        guard !entry.credentials.isExpired(now: now()) else {
            throw ProviderError.unauthorized(hint: Strings.Claude.relogin)
        }
        return entry
    }
}
