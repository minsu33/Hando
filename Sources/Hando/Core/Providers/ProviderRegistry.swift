import Foundation

struct ProviderRegistry {
    let providers: [any UsageProvider]

    static let live = ProviderRegistry(providers: [
        ClaudeProvider(),
        CodexProvider(),
    ])

    var descriptors: [ProviderDescriptor] { providers.map(\.descriptor) }

    func provider(id: String?) -> (any UsageProvider)? {
        providers.first { $0.descriptor.id == id }
    }

    /// 저장된 선택 > 로그인된 첫 번째 > 그냥 첫 번째
    func resolve(preferredID: String?) -> any UsageProvider {
        if let preferred = provider(id: preferredID) { return preferred }
        return providers.first { $0.hasCredentials() } ?? providers[0]
    }
}
