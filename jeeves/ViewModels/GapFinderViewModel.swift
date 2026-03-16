import Foundation
import Observation

/// Dedicated ViewModel for gap finder data.
///
/// SAFETY: This VM is strictly read-only and observational.
/// It does NOT create proposals, execute actions, or modify governance state.
/// Gap finder data flows one way: backend → display.
@MainActor
@Observable
final class GapFinderViewModel {
    var snapshot: SystemGapFinderSnapshot?
    var isLoading = false
    var hasLoaded = false
    var errorMessage: String?

    // MARK: - Derived display data

    var stats: GapFinderStats {
        guard let snapshot else { return .empty }
        return GapFinderStats.from(snapshot: snapshot)
    }

    var discoveryItems: [GapFinderDiscoveryItem] {
        guard let snapshot else { return [] }
        return GapFinderDiscoveryItem.from(snapshot: snapshot)
    }

    var candidateStructures: [GapFinderCandidateStructure] {
        guard let snapshot else { return [] }
        return GapFinderCandidateStructure.from(snapshot: snapshot)
    }

    var hasData: Bool {
        snapshot != nil && (stats.matchCount > 0 || stats.gapCount > 0)
    }

    // MARK: - Loading

    func load(gateway: GatewayManager, force: Bool = false) async {
        if isLoading && !force { return }
        if hasLoaded && !force { return }

        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        if gateway.useMock || gateway.host.lowercased() == "mock" {
            snapshot = .demo
            hasLoaded = true
            return
        }

        let resolved = await gateway.resolveEndpoint()
        guard let token = resolved.token, !token.isEmpty else {
            errorMessage = "No valid gateway token for gap finder."
            return
        }

        let builder = AuthorizedRequestBuilder(
            host: resolved.host,
            port: resolved.port,
            token: token
        )

        do {
            snapshot = try await ObservatoryAPI.systemGapFinder(builder: builder)
            hasLoaded = true
        } catch {
            errorMessage = "Gap finder data unavailable."
            if snapshot != nil { hasLoaded = true }
        }
    }
}
