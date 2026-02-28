import SwiftUI

struct AuditDetailView: View {
    let entry: AuditEntry

    var body: some View {
        NavigationStack {
            List {
                Section("Actie") {
                    row("Tool", entry.tool, mono: true)
                    row("Status", statusLabel)
                    row("Kanaal", entry.channel)
                }

                Section("Tijdstip") {
                    row("Datum", entry.timestamp.formatted(date: .abbreviated, time: .standard))
                }

                if let reason = entry.reason, !reason.isEmpty {
                    Section("Reden") {
                        Text(reason)
                            .font(.jeevesBody)
                    }
                }

                if let params = entry.params, !params.isEmpty {
                    Section("Parameters") {
                        ForEach(Array(params.keys.sorted()), id: \.self) { key in
                            row(key, params[key] ?? "", mono: true)
                        }
                    }
                }

                if let cost = entry.cost {
                    Section("Kosten") {
                        row("Kosten", String(format: "$%.2f", cost), mono: true)
                    }
                }
            }
            .navigationTitle("Detail")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
        }
    }

    private func row(_ label: String, _ value: String, mono: Bool = false) -> some View {
        HStack {
            Text(label)
                .font(.jeevesCaption)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(mono ? .jeevesMono : .jeevesBody)
        }
    }

    private var statusLabel: String {
        switch entry.status {
        case .allowed: "Toegestaan"
        case .consentRequested: "Consent gevraagd"
        case .blocked: "Geblokkeerd"
        }
    }
}
