import Foundation

struct ProviderDescriptor: Hashable, Identifiable, Sendable {
    let id: String
    let displayName: String     // 팝오버: "Codex"
    let menuBarLabel: String    // 메뉴바 글자: "CODEX"
}

/// 서비스 하나 추가할 때 이거 구현해서 ProviderRegistry에 등록
protocol UsageProvider: Sendable {
    var descriptor: ProviderDescriptor { get }

    /// 로그인 정보가 있는지 (네트워크 안 탐). 기본 서비스 고를 때 씀
    func hasCredentials() -> Bool

    func fetch() async throws -> UsageSnapshot

    /// 바뀌면 바로 다시 가져올 파일들 (CLI가 로그인 정보를 쓰는 곳)
    var watchedFiles: [URL] { get }

    /// 계정 바꾸기/로그아웃용 CLI 명령. 없으면 버튼 안 보임
    var accountCommands: AccountCommands? { get }

    /// 쓰는 중이면 바뀌는 폴더 (CLI 세션 로그). 바뀌면 사용량도 바로 다시 가져옴
    var activityFolders: [URL] { get }
}

extension UsageProvider {
    var watchedFiles: [URL] { [] }
    var accountCommands: AccountCommands? { nil }
    var activityFolders: [URL] { [] }
}
