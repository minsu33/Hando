import Foundation
import ServiceManagement

/// 로그인 시 자동 실행. .app으로 실행했을 때만 됨 (swift run은 X)
enum LaunchAtLogin {
    static var isAvailable: Bool {
        Bundle.main.bundleURL.pathExtension == "app"
    }

    static var isEnabled: Bool {
        SMAppService.mainApp.status == .enabled
    }

    static func set(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            Debug.log("launch at login: \(error.localizedDescription)")
        }
    }
}
