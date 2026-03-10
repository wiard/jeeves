import SwiftUI

struct DiscoveryPulsePanel: View {
    let cells: [DiscoveryCell]
    let onTap: () -> Void

    private var hotCells: [DiscoveryCell] {
        cells.filter { $0.intensity == .hot || $0.intensity == .rising }
    }

    private var summaryLine: String {
        let hotCount = cells.filter { $0.intensity == .hot }.count
        let risingCount = cells.filter { $0.intensity == .rising }.count

        if hotCount > 0 {
            let names = cells.filter { $0.intensity == .hot }.prefix(2).map(\.title)
            return "\(names.joined(separator: ", ")) — elevated activity."
        }
        if risingCount > 0 {
            return "\(risingCount) cell\(risingCount == 1 ? "" : "s") showing rising pressure."
        }
        return "All cells quiet."
    }

    private var totalClusters: Int {
        cells.reduce(0) { $0 + $1.clusterCount }
    }

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 16) {
                miniGrid
                    .frame(width: 54, height: 54)

                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Image(systemName: "sparkles")
                            .font(.jeevesCaption)
                            .foregroundStyle(hotCells.isEmpty ? .secondary : Color.jeevesGold)
                        Text("Discovery pulse")
                            .font(.jeevesHeadline)
                            .foregroundStyle(.primary)
                    }

                    Text(summaryLine)
                        .font(.jeevesCaption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)

                    if totalClusters > 0 {
                        Text("\(totalClusters) active clusters")
                            .font(.jeevesMonoSmall)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer(minLength: 0)

                Image(systemName: "chevron.right")
                    .font(.jeevesCaption)
                    .foregroundStyle(.tertiary)
            }
            .padding(16)
            .background(Color(.secondarySystemBackground))
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(Color.primary.opacity(0.06), lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Mini 3×3 Grid

    private var miniGrid: some View {
        let gridCells = Array(cells.prefix(9))
        let padded = gridCells + Array(
            repeating: DiscoveryCell(id: "empty", title: "", subtitle: "", intensity: .quiet, clusterCount: 0, hints: []),
            count: max(0, 9 - gridCells.count)
        )

        return VStack(spacing: 3) {
            ForEach(0..<3, id: \.self) { row in
                HStack(spacing: 3) {
                    ForEach(0..<3, id: \.self) { col in
                        let cell = padded[row * 3 + col]
                        RoundedRectangle(cornerRadius: 3, style: .continuous)
                            .fill(cellColor(for: cell.intensity))
                            .aspectRatio(1, contentMode: .fit)
                    }
                }
            }
        }
    }

    private func cellColor(for intensity: RadarIntensity) -> Color {
        switch intensity {
        case .quiet:  return Color.gray.opacity(0.15)
        case .normal: return Color.blue.opacity(0.35)
        case .rising: return Color.orange.opacity(0.6)
        case .hot:    return Color.red.opacity(0.7)
        }
    }
}
