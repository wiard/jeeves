import SwiftUI

struct ClusterDetailView: View {
    let cluster: ClusterSummary
    let onPlayChord: (() -> Void)?

    var body: some View {
        List {
            Section("Cluster") {
                row("Label", cluster.label)
                row("Score", String(format: "%.2f", cluster.score))
                row("Cell", "\(cluster.cubeCell.what) / \(cluster.cubeCell.where_) / \(cluster.cubeCell.when)")
            }

            Section("Signals") {
                if cluster.signals.isEmpty {
                    Text("Unavailable")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(cluster.signals, id: \.self) { signal in
                        Text(signal)
                    }
                }
            }

            Section("Nodes") {
                if cluster.nodes.isEmpty {
                    Text("Unavailable")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(cluster.nodes, id: \.self) { node in
                        Text(node)
                    }
                }
            }

            Section {
                Button("Play chord") {
                    onPlayChord?()
                }
                .disabled(onPlayChord == nil)
            }
        }
        .navigationTitle("Cluster Detail")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
    }

    private func row(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label)
                .foregroundStyle(.secondary)
            Spacer(minLength: 8)
            Text(value)
                .font(.jeevesMono)
                .multilineTextAlignment(.trailing)
        }
        .font(.jeevesCaption)
    }
}
