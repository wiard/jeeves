import SwiftUI

struct ZoekerView: View {
    @Environment(GatewayManager.self) private var gateway
    @StateObject private var viewModel = ZoekerViewModel()
    @State private var selectedCell: RadarHeatmapCell?

    var body: some View {
        NavigationStack {
            ZStack {
                InstrumentBackdrop(
                    colors: [
                        Color(red: 0.99, green: 0.98, blue: 0.96),
                        Color(red: 0.98, green: 0.96, blue: 0.92),
                        Color(red: 0.96, green: 0.97, blue: 0.99)
                    ]
                )
                .ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        InstrumentRoleHeader(
                            eyebrow: "Radar",
                            title: "De Zoeker",
                            summary: "27 cellen laten zien waar residue en onderzoekdruk zich nu ophopen.",
                            accent: .jeevesLogoRed,
                            metrics: [
                                InstrumentRoleMetric(label: "Hete cel", value: viewModel.hottestCell?.displayNumber ?? "--"),
                                InstrumentRoleMetric(label: "Topscore", value: scoreLabel(viewModel.hottestCell?.score ?? 0))
                            ]
                        )

                        if let error = viewModel.error {
                            statusNotice(error)
                        }

                        InstrumentSectionPanel(
                            eyebrow: "Historisch",
                            title: "Cellen 00-08",
                            subtitle: "Onderzoek dat teruggrijpt op geschiedenis, fundamenten en vergeten sporen.",
                            accent: .jeevesGold
                        ) {
                            sectionGrid(for: 0...8)
                        }

                        InstrumentSectionPanel(
                            eyebrow: "Huidig",
                            title: "Cellen 09-17",
                            subtitle: "Waar het systeem nu urgentie, koppelingen en hypotheses ziet.",
                            accent: .jeevesSky
                        ) {
                            sectionGrid(for: 9...17)
                        }

                        InstrumentSectionPanel(
                            eyebrow: "Opkomend",
                            title: "Cellen 18-26",
                            subtitle: "Nieuwe mogelijkheden, risico's en beloftes die zich beginnen af te tekenen.",
                            accent: .jeevesLogoRed
                        ) {
                            sectionGrid(for: 18...26)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 16)
                }
            }
            .navigationTitle("De Zoeker")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .task {
                viewModel.configure(gateway: gateway)
                await viewModel.fetchHeatmap()
            }
            .refreshable {
                viewModel.configure(gateway: gateway)
                await viewModel.fetchHeatmap()
            }
            .onChange(of: gateway.isConnected) {
                if gateway.isConnected {
                    Task {
                        viewModel.configure(gateway: gateway)
                        await viewModel.fetchHeatmap()
                    }
                }
            }
            .sheet(item: $selectedCell) { cell in
                NavigationStack {
                    VStack(alignment: .leading, spacing: 18) {
                        Text("Cel \(cell.displayNumber)")
                            .font(.jeevesLargeTitle)

                        detailRow(label: "Skill", value: cell.skillName)
                        detailRow(label: "Cell ID", value: cell.cellId)
                        detailRow(label: "Score", value: scoreLabel(cell.score))
                    }
                    .padding(24)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    .background(Color.jeevesMist.ignoresSafeArea())
                    .navigationTitle("Celdetail")
                    #if os(iOS)
                    .navigationBarTitleDisplayMode(.inline)
                    #endif
                }
                .presentationDetents([.medium])
            }
        }
    }

    @ViewBuilder
    private func sectionGrid(for range: ClosedRange<Int>) -> some View {
        let cells = range.compactMap(cell(for:))
        let rows = stride(from: 0, to: cells.count, by: 3).map { start in
            Array(cells[start..<min(start + 3, cells.count)])
        }

        VStack(alignment: .leading, spacing: 10) {
            ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                HStack(spacing: 10) {
                    ForEach(row) { cell in
                        Button {
                            selectedCell = cell
                        } label: {
                            VStack(alignment: .leading, spacing: 8) {
                                Text(cell.displayNumber)
                                    .font(.jeevesHeadline.weight(.bold))
                                    .foregroundStyle(Color.jeevesInk)

                                Text(shortSkillName(for: cell))
                                    .font(.caption2)
                                    .foregroundStyle(Color.jeevesSubtleText)
                                    .lineLimit(2)
                                    .fixedSize(horizontal: false, vertical: true)

                                Text(scoreLabel(cell.score))
                                    .font(.caption.monospacedDigit())
                                    .foregroundStyle(Color.jeevesMutedText)
                            }
                            .padding(12)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(
                                RoundedRectangle(cornerRadius: 18, style: .continuous)
                                    .fill(heatColor(for: cell.score))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                                            .stroke(
                                                cell.cellNumber == 13 ? Color.jeevesLogoRed.opacity(0.45) : Color.clear,
                                                lineWidth: cell.cellNumber == 13 ? 1.5 : 0
                                            )
                                    )
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private func cell(for number: Int) -> RadarHeatmapCell? {
        viewModel.cells.first { $0.cellNumber == number }
    }

    private func shortSkillName(for cell: RadarHeatmapCell) -> String {
        let base = cell.skillName.replacingOccurrences(of: " (kerncel)", with: "")
        if base.count <= 26 {
            return base
        }
        return String(base.prefix(26)) + "…"
    }

    private func scoreLabel(_ score: Double) -> String {
        String(format: "%.0f%%", min(max(score, 0), 1) * 100)
    }

    private func heatColor(for score: Double) -> Color {
        let bounded = min(max(score, 0), 1)
        let red = 1.0
        let green = 0.97 - (0.45 * bounded)
        let blue = 0.95 - (0.88 * bounded)
        return Color(red: red, green: green, blue: max(0.12, blue))
    }

    @ViewBuilder
    private func statusNotice(_ message: String) -> some View {
        Text(message)
            .font(.jeevesBody)
            .foregroundStyle(.secondary)
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Color.white.opacity(0.88))
                    .overlay(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .stroke(Color.jeevesLogoRed.opacity(0.14), lineWidth: 1)
                    )
            )
    }

    @ViewBuilder
    private func detailRow(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label.uppercased())
                .font(.caption.weight(.semibold))
                .foregroundStyle(Color.jeevesLogoRed)
            Text(value)
                .font(.jeevesBody)
                .foregroundStyle(Color.jeevesInk)
        }
    }
}
