import Foundation

@MainActor
final class ZoekerViewModel: ObservableObject {
    @Published var cells: [RadarHeatmapCell] = (0..<27).map {
        RadarHeatmapCell(
            cellNumber: $0,
            skillName: RadarHeatmapCell.skillName(for: $0),
            cellId: "cell-\(String(format: "%02d", $0))",
            score: 0
        )
    }
    @Published var isLoading = false
    @Published var error: String?

    private weak var gateway: GatewayManager?

    var hottestCell: RadarHeatmapCell? {
        cells.max(by: { $0.score < $1.score })
    }

    func configure(gateway: GatewayManager) {
        self.gateway = gateway
    }

    func fetchHeatmap() async {
        guard let gateway else {
            error = "De gateway is nog niet ingesteld."
            return
        }

        if isLoading {
            return
        }

        isLoading = true
        defer { isLoading = false }

        guard let api = await gateway.makeOperatorSurfacesAPI() else {
            error = gateway.useMock ? nil : "Geen conductor-token beschikbaar voor de Zoeker."
            return
        }

        do {
            let response = try await api.fetchRadarHeatmap()
            cells = response.cells
            error = nil
        } catch {
            self.error = "De heatmap kon niet worden geladen."
        }
    }
}
