import SwiftUI

struct ExtensionDetailSheet: View {
    let manifest: ExtensionManifest
    let onKnowledgeTap: (String) -> Void
    let onGraphTap: (String) -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    header
                    metadata
                    capabilitiesSection
                    knowledgeLinksSection
                    auditTrailSection
                    receiptSection
                }
                .padding()
            }
            .navigationTitle("Extension")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("OK") { dismiss() }
                }
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(manifest.title)
                .font(.jeevesHeadline)
            HStack(spacing: 8) {
                riskBadge
                Text(manifest.status)
                    .font(.jeevesCaption)
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
            }
        }
    }

    private var metadata: some View {
        VStack(alignment: .leading, spacing: 8) {
            detailRow(label: TextKeys.Lobby.extensionPurpose, value: manifest.purpose)
            detailRow(label: TextKeys.Lobby.extensionRisk, value: manifest.risk)
            detailRow(label: TextKeys.Lobby.extensionEntrypoint, value: manifest.entrypoint)
            detailRow(label: TextKeys.Lobby.extensionSource, value: manifest.sourceType ?? "unknown")
            detailRow(label: TextKeys.Lobby.extensionCodeHash, value: manifest.codeHash)
            if let approvedAtIso = manifest.approvedAtIso {
                detailRow(label: "Approved", value: approvedAtIso)
            }
            if let loadedAtIso = manifest.loadedAtIso {
                detailRow(label: "Loaded", value: loadedAtIso)
            }
            Button(TextKeys.Lobby.extensionGraph) {
                onGraphTap(manifest.extensionId)
            }
            .buttonStyle(.bordered)
        }
    }

    private var capabilitiesSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(TextKeys.Lobby.extensionCapabilities)
                .font(.jeevesHeadline)
            if manifest.capabilities.isEmpty {
                Text("Geen capabilities.")
                    .font(.jeevesCaption)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(manifest.capabilities) { capability in
                    VStack(alignment: .leading, spacing: 2) {
                        Text(capability.title)
                            .font(.jeevesBody)
                        if let details = capability.details, !details.isEmpty {
                            Text(details)
                                .font(.jeevesCaption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(10)
                    .background(Color(.secondarySystemFill).opacity(0.35))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
            }
        }
    }

    private var knowledgeLinksSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(TextKeys.Lobby.extensionKnowledgeLinks)
                .font(.jeevesHeadline)
            if manifest.knowledgeLinks.isEmpty {
                Text("Geen knowledge links.")
                    .font(.jeevesCaption)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(manifest.knowledgeLinks, id: \.self) { link in
                    Button {
                        onKnowledgeTap(link)
                    } label: {
                        HStack {
                            Image(systemName: "link")
                            Text(link)
                                .font(.jeevesMono)
                                .lineLimit(1)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .foregroundStyle(.tertiary)
                        }
                        .padding(10)
                        .background(Color(.secondarySystemFill).opacity(0.35))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var auditTrailSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(TextKeys.Lobby.extensionAuditTrail)
                .font(.jeevesHeadline)
            if manifest.auditTrail.isEmpty {
                Text("Nog geen auditregels.")
                    .font(.jeevesCaption)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(manifest.auditTrail) { decision in
                    VStack(alignment: .leading, spacing: 3) {
                        Text(decision.status)
                            .font(.jeevesCaption)
                            .foregroundStyle(.secondary)
                            .textCase(.uppercase)
                        if let reason = decision.reason, !reason.isEmpty {
                            Text(reason)
                                .font(.jeevesBody)
                        }
                        if let actor = decision.actor, !actor.isEmpty {
                            Text(actor)
                                .font(.jeevesCaption)
                                .foregroundStyle(.secondary)
                        }
                        if let decisionAtIso = decision.decisionAtIso, !decisionAtIso.isEmpty {
                            Text(decisionAtIso)
                                .font(.jeevesCaption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(10)
                    .background(Color(.secondarySystemFill).opacity(0.35))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
            }
        }
    }

    @ViewBuilder
    private var receiptSection: some View {
        if let receipt = manifest.receipt {
            VStack(alignment: .leading, spacing: 8) {
                Text(TextKeys.Lobby.extensionReceipt)
                    .font(.jeevesHeadline)
                detailRow(label: "Status", value: receipt.status)
                if let summary = receipt.summary, !summary.isEmpty {
                    detailRow(label: "Summary", value: summary)
                }
                if let approved = receipt.approvedAtIso, !approved.isEmpty {
                    detailRow(label: "Approved", value: approved)
                }
                if let loaded = receipt.loadedAtIso, !loaded.isEmpty {
                    detailRow(label: "Loaded", value: loaded)
                }
            }
        }
    }

    private var riskBadge: some View {
        let normalized = manifest.risk.lowercased()
        let color: Color
        switch normalized {
        case "green":
            color = .green
        case "orange":
            color = .orange
        case "red":
            color = .red
        default:
            color = .secondary
        }
        return Text(normalized)
            .font(.jeevesCaption)
            .foregroundStyle(color)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(color.opacity(0.14))
            .clipShape(Capsule())
    }

    private func detailRow(label: String, value: String) -> some View {
        HStack(alignment: .top) {
            Text("\(label):")
                .font(.jeevesCaption)
                .foregroundStyle(.secondary)
                .frame(width: 110, alignment: .leading)
            Text(value)
                .font(.jeevesMono)
        }
    }
}
