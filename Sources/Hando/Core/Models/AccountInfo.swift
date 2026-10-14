import Foundation

struct AccountInfo: Hashable, Codable, Sendable {
    var email: String?
    var plan: String?
    var subscriptionEndsAt: Date?

    static let empty = AccountInfo()
}
