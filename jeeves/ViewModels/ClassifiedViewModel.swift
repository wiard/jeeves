import Foundation
import SwiftUI

@MainActor
final class ClassifiedViewModel: ObservableObject {
    @Published var items: [ClassifiedDiscovery] = []
    @Published var activeFilter: String = "ALLE"
    @Published var isLoading = false
    @Published var error: String?

    private weak var gateway: GatewayManager?

    static let outcomeTypes = ["ALLE", "GAP", "DISCOVERY", "OPPORTUNITY", "SURPRISE", "SURE_WIN"]

    var filtered: [ClassifiedDiscovery] {
        guard activeFilter != "ALLE" else { return items }
        return items.filter { $0.outcomeType == activeFilter }
    }

    func configure(gateway: GatewayManager) {
        self.gateway = gateway
    }

    func fetch() async {
        guard let gateway else {
            error = "De gateway is nog niet ingesteld."
            return
        }

        if isLoading { return }
        isLoading = true
        defer { isLoading = false }

        guard let api = await gateway.makeOperatorSurfacesAPI() else {
            items = []
            error = gateway.useMock ? nil : "Geen conductor-token beschikbaar."
            return
        }

        do {
            let result = try await api.fetchClassifiedDiscoveries()
            items = result
            error = nil
        } catch {
            items = []
            self.error = "Geclassificeerde ontdekkingen konden niet worden geladen."
        }
    }
}
