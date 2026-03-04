import SwiftUI

struct CubeCellDetailView: View {
    let cellIndex: Int
    let cubeCell: CubeCell
    let hotspots: [Hotspot]
    let related: CubeRelatedResources
    let onDraw: () -> Void

    var body: some View {
        List {
            Section("Cell") {
                row("Index", "\(cellIndex)")
                row("What", cubeCell.what)
                row("Where", cubeCell.where_)
                row("When", cubeCell.when)
            }

            Section("Residue Summary") {
                ForEach(hotspots.prefix(5)) { hotspot in
                    HStack {
                        Text(label(for: hotspot))
                            .font(.jeevesCaption)
                        Spacer()
                        Text("\(String(format: "%.2f", hotspot.residue)) \(trendArrow(hotspot.trend))")
                            .font(.jeevesMono)
                    }
                }
            }

            Section("Related Repos") {
                relatedRows(related.repos)
            }

            Section("Related Papers") {
                relatedRows(related.papers)
            }

            Section("Related Posts") {
                relatedRows(related.posts)
            }

            Section {
                Button("Draw from this cell") {
                    onDraw()
                }
                .tint(.jeevesGold)
            }
        }
        .navigationTitle("Cell Detail")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
    }

    @ViewBuilder
    private func relatedRows(_ items: [CubeRelatedItem]) -> some View {
        if items.isEmpty {
            Text("Unavailable")
                .foregroundStyle(.secondary)
        } else {
            ForEach(items) { item in
                if let url = URL(string: item.url) {
                    Link(item.title, destination: url)
                } else {
                    Text(item.title)
                }
            }
        }
    }

    private func row(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(.jeevesMono)
        }
    }

    private func label(for hotspot: Hotspot) -> String {
        "\(hotspot.cubeCell.what) / \(hotspot.cubeCell.where_) / \(hotspot.cubeCell.when)"
    }

    private func trendArrow(_ value: Double) -> String {
        value >= 0 ? "↑" : "↓"
    }
}
