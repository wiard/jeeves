import Foundation
import SwiftUI

struct SecurityInboxView: View {
    let proposals: [Proposal]
    let onApprove: (Proposal) -> Void
    let onDeny: (Proposal) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header

            if sortedProposals.isEmpty {
                emptyState
            } else {
                LazyVStack(spacing: 10) {
                    ForEach(sortedProposals) { proposal in
                        securityProposalCard(proposal)
                    }
                }
            }
        }
    }

    private var header: some View {
        HStack(spacing: 10) {
            Text("Security Inbox")
                .font(.jeevesHeadline.weight(.semibold))
                .foregroundStyle(.white)
            Spacer()
            Text("\(pendingCount) pending")
                .font(.jeevesMono.weight(.semibold))
                .foregroundStyle(Color.consentOrange)
        }
    }

    private var emptyState: some View {
        HStack(spacing: 12) {
            Image(systemName: "lock.shield")
                .font(.jeevesTitle)
                .foregroundStyle(.secondary)
            Text("No Security proposals are waiting for operator review.")
                .font(.jeevesBody)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .securityPanel()
    }

    private func securityProposalCard(_ proposal: Proposal) -> some View {
        let severity = metadataString(for: proposal, keys: ["severity"])?.lowercased() ?? severityFromRisk(proposal.intent.risk)
        let tint = severityTint(severity)
        let isPending = proposal.isPending
        let signalType = humanize(metadataString(for: proposal, keys: ["signal_type"]) ?? "security_signal")
        let target = metadataString(for: proposal, keys: ["target"]) ?? "unknown target"
        let evidence = metadataString(for: proposal, keys: ["evidence"]) ?? proposal.priorityExplanation ?? proposal.intent.key
        let remediationHint = metadataString(for: proposal, keys: ["remediation_hint", "remediation_proposal"])
            ?? "Open Jeeves to decide the next bounded step."

        return VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 10) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(proposal.title)
                        .font(.jeevesBody.weight(.semibold))
                        .foregroundStyle(.white)
                    Text(signalType)
                        .font(.jeevesCaption.weight(.medium))
                        .foregroundStyle(tint)
                }
                Spacer()
                Text(severity.uppercased())
                    .font(.jeevesMono.weight(.semibold))
                    .foregroundStyle(tint)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(tint.opacity(0.12))
                    .clipShape(Capsule())
            }

            VStack(alignment: .leading, spacing: 6) {
                metadataRow(label: "Target", value: target)
                metadataRow(label: "Evidence", value: evidence)
                metadataRow(label: "Hint", value: remediationHint)
                metadataRow(label: "Created", value: createdLabel(for: proposal))
            }

            if isPending {
                HStack(spacing: 10) {
                    Button {
                        onDeny(proposal)
                    } label: {
                        Text("Deny")
                            .font(.jeevesHeadline.weight(.semibold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(Color.consentRed.opacity(0.86))
                            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    }

                    Button {
                        onApprove(proposal)
                    } label: {
                        Text("Approve")
                            .font(.jeevesHeadline.weight(.semibold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(Color.consentGreen.opacity(0.86))
                            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    }
                }
            } else {
                Text("Status: \(proposal.status.capitalized)")
                    .font(.jeevesMono)
                    .foregroundStyle(tint)
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            tint.opacity(0.16),
                            Color.white.opacity(0.04),
                            Color.black.opacity(0.14)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(tint.opacity(0.38), lineWidth: 1)
                )
        )
    }

    private func metadataRow(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label.uppercased())
                .font(.jeevesCaption2.weight(.medium))
                .foregroundStyle(.secondary)
            Text(value)
                .font(.jeevesMono)
                .foregroundStyle(Color(red: 0.58, green: 0.77, blue: 0.99))
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var sortedProposals: [Proposal] {
        proposals.sorted { left, right in
            if left.isPending != right.isPending {
                return left.isPending && !right.isPending
            }
            let leftDate = left.createdAt ?? .distantPast
            let rightDate = right.createdAt ?? .distantPast
            if leftDate != rightDate {
                return leftDate > rightDate
            }
            return left.proposalId < right.proposalId
        }
    }

    private var pendingCount: Int {
        proposals.filter(\.isPending).count
    }

    private func createdLabel(for proposal: Proposal) -> String {
        guard let createdAt = proposal.createdAt else {
            return proposal.createdAtIso
        }
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter.localizedString(for: createdAt, relativeTo: Date())
    }

    private func metadataString(for proposal: Proposal, keys: [String]) -> String? {
        guard let metadata = proposal.metadata else { return nil }
        let normalized = Dictionary(uniqueKeysWithValues: metadata.map { ($0.key.lowercased(), $0.value) })
        for key in keys.map({ $0.lowercased() }) {
            if let value = normalized[key]?.scalarStringValue?.trimmingCharacters(in: .whitespacesAndNewlines),
               !value.isEmpty {
                return value
            }
        }
        return nil
    }

    private func severityFromRisk(_ risk: String) -> String {
        switch risk.lowercased() {
        case "red":
            return "high"
        case "orange":
            return "medium"
        default:
            return "low"
        }
    }

    private func severityTint(_ severity: String) -> Color {
        switch severity {
        case "critical":
            return .consentRed
        case "high":
            return .consentOrange
        case "medium":
            return .blue
        default:
            return .secondary
        }
    }

    private func humanize(_ value: String) -> String {
        value.replacingOccurrences(of: "_", with: " ").capitalized
    }
}

private struct SecurityPanelModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.08),
                                Color.consentRed.opacity(0.04),
                                Color.black.opacity(0.12)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(Color.white.opacity(0.14), lineWidth: 1)
                    )
            )
    }
}

private extension View {
    func securityPanel() -> some View {
        modifier(SecurityPanelModifier())
    }
}
