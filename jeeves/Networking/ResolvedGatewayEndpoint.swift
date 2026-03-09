import Foundation

/// The resolved, canonical gateway endpoint for making API calls.
/// Produced exclusively by GatewayManager.resolveEndpoint().
struct ResolvedGatewayEndpoint: Sendable {
    let host: String
    let port: Int
    let token: String?

    /// Create an AuthorizedRequestBuilder from this endpoint.
    /// Returns nil if token is missing or empty.
    func makeRequestBuilder() -> AuthorizedRequestBuilder? {
        guard let token, !token.isEmpty else { return nil }
        return AuthorizedRequestBuilder(host: host, port: port, token: token)
    }
}
