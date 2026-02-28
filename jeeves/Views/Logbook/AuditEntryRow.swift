import SwiftUI

struct AuditEntryRow: View {
    let entry: AuditEntry

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: statusIcon)
                .foregroundStyle(statusColor)
                .frame(width: 24)
                .padding(.top, 2)

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(entry.timestamp, style: .time)
                        .font(.jeevesCaption)
                        .foregroundStyle(.secondary)
                    Text(entry.tool)
                        .font(.jeevesMono)
                }

                Text(statusLabel)
                    .font(.jeevesCaption)
                    .foregroundStyle(statusColor)

                if let reason = entry.reason, !reason.isEmpty {
                    Text(reason)
                        .font(.jeevesCaption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                HStack {
                    Text("Kanaal: \(entry.channel)")
                        .font(.jeevesCaption)
                        .foregroundStyle(.secondary)
                    if let cost = entry.cost {
                        Spacer()
                        Text(String(format: "$%.2f", cost))
                            .font(.jeevesMono)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(entry.tool), \(statusLabel), \(entry.channel)")
    }

    private var statusIcon: String {
        switch entry.status {
        case .allowed: "checkmark.circle.fill"
        case .consentRequested: "exclamationmark.triangle.fill"
        case .blocked: "xmark.octagon.fill"
        }
    }

    private var statusColor: Color {
        switch entry.status {
        case .allowed: .consentGreen
        case .consentRequested: .consentOrange
        case .blocked: .consentRed
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
