import SwiftUI

struct BrowserDeploymentsView: View {
    @Bindable var viewModel: BrowserViewModel
    @Environment(ProposalPoller.self) private var poller

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 16) {
                metricsPanel

                if !pendingDeployments.isEmpty {
                    pendingSection
                }

                if !activeDeployments.isEmpty {
                    activeSection
                }

                if !historicalDeployments.isEmpty {
                    historySection
                }

                if pendingDeployments.isEmpty && activeDeployments.isEmpty && historicalDeployments.isEmpty {
                    emptyState
                }

                if let proposalId = viewModel.lastCreatedProposalId {
                    proposalCreatedBanner(proposalId: proposalId)
                }
            }
            .padding()
        }
    }

    // MARK: - Computed

    private var pendingDeployments: [Proposal] {
        poller.pendingProposals.filter { $0.intent.kind.lowercased().contains("deploy") || $0.intent.kind.lowercased().contains("config") }
    }

    private var activeDeployments: [DecidedProposal] {
        poller.decidedProposals.filter(\.isApproved)
    }

    private var historicalDeployments: [DecidedProposal] {
        poller.decidedProposals.filter(\.isDenied)
    }

    // MARK: - Metrics

    private var metricsPanel: some View {
        HStack(spacing: 10) {
            metric(label: "Pending", value: "\(poller.pendingProposals.count)", tint: .consentOrange)
            metric(label: "Approved", value: "\(poller.decidedProposals.filter(\.isApproved).count)", tint: .consentGreen)
            metric(label: "Denied", value: "\(poller.decidedProposals.filter(\.isDenied).count)", tint: .consentRed)
        }
    }

    private func metric(label: String, value: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label.uppercased())
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
            Text(value)
                .font(.jeevesMono.weight(.semibold))
                .foregroundStyle(tint)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(Color.white.opacity(0.03))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    // MARK: - Pending

    private var pendingSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            deploymentSectionHeader("AWAITING APPROVAL", icon: "clock", count: pendingDeployments.count, tint: .consentOrange)

            ForEach(pendingDeployments) { proposal in
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 8) {
                        Image(systemName: "clock.fill")
                            .foregroundStyle(Color.consentOrange)
                            .font(.caption)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(proposal.title)
                                .font(.jeevesCaption.weight(.semibold))
                                .foregroundStyle(.white)
                            Text(proposal.proposalId)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                    }

                    LifecycleTimelineView(steps: pendingLifecycleSteps(proposal))
                }
                .browserPanel(padding: 12)
            }
        }
    }

    // MARK: - Active

    private var activeSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            deploymentSectionHeader("APPROVED", icon: "checkmark.circle.fill", count: activeDeployments.count, tint: .consentGreen)

            ForEach(activeDeployments) { decision in
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(Color.consentGreen)
                            .font(.caption)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(decision.title)
                                .font(.jeevesCaption.weight(.semibold))
                                .foregroundStyle(.white)
                            Text(decision.proposalId)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Text(relativeDateLabel(iso: decision.decidedAtIso))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }

                    LifecycleTimelineView(steps: approvedLifecycleSteps(decision))
                }
                .browserPanel(padding: 12)
            }
        }
    }

    // MARK: - History

    private var historySection: some View {
        VStack(alignment: .leading, spacing: 10) {
            deploymentSectionHeader("DENIED", icon: "xmark.circle.fill", count: historicalDeployments.count, tint: .consentRed)

            ForEach(historicalDeployments) { decision in
                HStack(spacing: 8) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(Color.consentRed)
                        .font(.caption)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(decision.title)
                            .font(.jeevesCaption.weight(.semibold))
                            .foregroundStyle(.white)
                            .lineLimit(1)
                        Text(decision.proposalId)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Text(relativeDateLabel(iso: decision.decidedAtIso))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                .browserPanel(padding: 12)
            }
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "shippingbox.circle")
                .font(.largeTitle)
                .foregroundStyle(.secondary)
            Text("No deployments yet")
                .font(.jeevesHeadline)
                .foregroundStyle(.white)
            Text("Governed deployments will appear here after you propose configurations from the Marketplace.")
                .font(.jeevesCaption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 32)
        .browserPanel(padding: 16)
    }

    // MARK: - Proposal Created Banner

    private func proposalCreatedBanner(proposalId: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "checkmark.seal.fill")
                .foregroundStyle(Color.consentGreen)
            VStack(alignment: .leading, spacing: 2) {
                Text("Proposal Created")
                    .font(.jeevesCaption.weight(.semibold))
                    .foregroundStyle(.white)
                Text("Proposal \(proposalId) is pending approval.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .browserPanel(padding: 10)
    }

    // MARK: - Lifecycle Steps

    private func pendingLifecycleSteps(_ proposal: Proposal) -> [LifecycleTimelineView.LifecycleStep] {
        [
            .init(title: "SafeClash Registry", detail: "Configuration registered", timestamp: nil, isComplete: true),
            .init(title: "Proposal Created", detail: "Proposal \(proposal.proposalId)", timestamp: proposal.createdAtIso, isComplete: true),
            .init(title: "Awaiting Approval", detail: "Pending in governance queue", timestamp: nil, isComplete: false),
            .init(title: "Governed Action", detail: "Pending", timestamp: nil, isComplete: false),
            .init(title: "Knowledge Stored", detail: "Pending", timestamp: nil, isComplete: false)
        ]
    }

    private func approvedLifecycleSteps(_ decision: DecidedProposal) -> [LifecycleTimelineView.LifecycleStep] {
        [
            .init(title: "SafeClash Registry", detail: "Configuration registered", timestamp: nil, isComplete: true),
            .init(title: "Proposal Created", detail: "Proposal \(decision.proposalId)", timestamp: nil, isComplete: true),
            .init(title: "Approval Granted", detail: "Approved by operator", timestamp: decision.decidedAtIso, isComplete: true),
            .init(title: "Governed Action", detail: "Action receipt recorded", timestamp: decision.decidedAtIso, isComplete: true),
            .init(title: "Knowledge Stored", detail: "Artifact stored", timestamp: decision.decidedAtIso, isComplete: true)
        ]
    }

    // MARK: - Helpers

    private func deploymentSectionHeader(_ title: String, icon: String, count: Int, tint: Color) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .foregroundStyle(tint)
                .font(.caption)
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            Spacer()
            Text("\(count)")
                .font(.jeevesMono)
                .foregroundStyle(tint)
        }
    }

    private func relativeDateLabel(iso: String?) -> String {
        guard let iso, !iso.isEmpty else { return "" }
        guard let date = ISO8601DateFormatter().date(from: iso) else { return iso }
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}
