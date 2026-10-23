import Foundation

// UI 문자열 전부 여기
enum Strings {
    enum Window {
        static let session = "5시간"
        static let weekly = "주간"
        static func model(_ name: String) -> String { "\(name) 주간" }
        static func other(_ seconds: TimeInterval?) -> String {
            guard let seconds else { return "기타" }
            let hours = Int((seconds / 3600).rounded())
            return hours < 48 ? "\(hours)시간" : "\(hours / 24)일"
        }
        static func todayLeft(_ p: Int) -> String { "오늘까지 몫 \(p)% 남음" }
        static func todayOver(_ p: Int) -> String { "오늘까지 몫보다 \(p)% 더 씀" }
        static func resetsIn(_ left: String) -> String { "\(left) 후 리셋" }
        static func resetsAt(_ clock: String) -> String { "\(clock) 리셋" }
    }

    enum Popover {
        static let loading = "불러오는 중…"
        static let noWindows = "표시할 한도 정보가 없어요"
        static let noSessionWindow = "이 플랜은 5시간 한도가 없어서 메뉴바 글자도 주간 기준이에요"
        static let service = "서비스"
        static let typeface = "글꼴"
        static let launchAtLogin = "로그인 시 자동 실행"
        static let lockEffect = "다 찼을 때"
        static let resetMotion = "리셋될 때 움직임"
        static let back = "뒤로"
        static let settings = "설정"
        static let refresh = "새로고침"
        static let quit = "종료"
        static func updated(_ clock: String) -> String { "\(clock) 업데이트" }
    }

    enum Account {
        static let login = "로그인"
        static let logout = "로그아웃"
        static let switchAccount = "다른 계정으로"
        static func managedBy(_ cli: String) -> String { "\(cli) CLI 로그인을 사용해요. 버튼을 누르면 터미널이 열려요" }
        static func subscription(_ date: String, _ dday: String) -> String { "\(date)까지 (\(dday))" }
        static let expired = "만료됨"
    }

    enum Error {
        static let expired = "로그인이 만료됐어요."
        static let rateLimited = "요청이 많아서 잠깐 쉬는 중이에요. 몇 분 뒤 알아서 다시 가져와요"
        static func server(_ status: Int) -> String { "서버 오류 (HTTP \(status))" }
        static let invalidResponse = "응답 형식이 바뀐 것 같아요. HANDO_DEBUG=1로 확인해주세요"
        static let network = "네트워크 오류"
    }

    enum Claude {
        static let notLoggedIn = "Claude Code 로그인 정보가 없어요. 아래 로그인 버튼이나 터미널에서 `claude auth login`"
        static let relogin = "`claude`를 한 번 실행하거나 `claude auth login`을 다시 해주세요"
        static let needsPermission = "로그인 정보가 바뀌었어요. 새로고침을 누르고 키체인 접근을 허용해주세요"
    }

    enum Codex {
        static let noAuthFile = "~/.codex/auth.json이 없어요. 터미널에서 `codex login`을 먼저 해주세요"
        static let noChatGPTLogin = "ChatGPT 계정 로그인 정보가 없어요. API 키 로그인은 구독 한도가 없어요"
        static let relogin = "`codex`를 한 번 실행하거나 `codex login`을 다시 해주세요"
    }

    enum Accessibility {
        static func gauge(_ service: String, session: Int?, weekly: Int?) -> String {
            let s = session.map { "5시간 \($0)% 사용" } ?? "5시간 한도 없음"
            let w = weekly.map { "주간 \($0)% 사용" } ?? ""
            return [service, s, w].filter { !$0.isEmpty }.joined(separator: ", ")
        }
        static func resetsIn(_ left: String) -> String { "\(left) 뒤 리셋" }
        static func weeklyOnly(_ service: String, weekly: Int) -> String { "\(service), 주간 \(weekly)% 사용 (5시간 한도 없는 플랜, 글자도 주간)" }
        static func loading(_ service: String) -> String { "\(service), 불러오는 중" }
        static func error(_ service: String) -> String { "\(service), 오류" }
    }
}
