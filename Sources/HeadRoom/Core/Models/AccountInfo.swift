import Foundation

struct AccountInfo: Hashable, Sendable {
    var email: String?
    var plan: String?
    var subscriptionEndsAt: Date?

    static let empty = AccountInfo()
}
