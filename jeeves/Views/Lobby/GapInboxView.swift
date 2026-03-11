import SwiftUI

enum GapDecisionAction: String {
    case approve
    case deny
    case deferProposal = "defer"

    var label: String {
        switch self {
        case .approve:
            return "Approve"
        case .deny:
            return "Deny"
        case .deferProposal:
            return "Defer"
        }
    }

    var systemImage: String {
        switch self {
        case .approve:
            return "checkmark.circle.fill"
        case .deny:
            return "xmark.circle.fill"
        case .deferProposal:
            return "clock.badge.questionmark.fill"
        }
    }

    var tint: Color {
        switch self {
        case .approve:
            return .consentGreen
        case .deny:
            return .consentRed
        case .deferProposal:
            return .cyan
        }
    }

    var decisionValue: String {
        rawValue
    }
}

struct GapReviewRecord: Identifiable {
    struct TimelineEntry: Identifiable {
        enum State {
            case complete
            case pending
            case blocked
        }

        let id: String
        let title: String
        let detail: String
        let timestampIso: String?
        let state: State
    }

    let proposalId: String
    let title: String
    let summary: String
    let sourceEvidence: [GapEvidenceReference]
    let cubeCell: String
    let scores: GapProposalScores
    let hypothesis: String
    let verificationPlan: [String]
    let killTests: [String]
    let recommendedAction: String
    let status: String
    let agentId: String
    let risk: String
    let intentKey: String
    let createdAtIso: String
    let decidedAtIso: String?
    let decisionReason: String?
    let action: ActionSummary?
    let knowledgeObjectIds: [String]
    let auditHint: String

    var id: String { proposalId }

    var isPending: Bool {
        status.lowercased() == "pending"
    }

    var statusLabel: String {
        switch status.lowercased() {
        case "approved":
            return "APPROVED"
        case "denied":
            return "DENIED"
        case "deferred", "defer":
            return "DEFERRED"
        default:
            return "PENDING"
        }
    }

    var statusTint: Color {
        switch status.lowercased() {
        case "approved":
            return .consentGreen
        case "denied":
            return .consentRed
        case "deferred", "defer":
            return .cyan
        default:
            return .consentOrange
        }
    }

    var primaryScore: Double {
        max(scores.gravity, scores.evidence)
    }

    var uncertaintyScore: Double {
        min(max((scores.entropy + (1 - scores.evidence)) / 2, 0), 1)
    }

    var uncertaintyLabel: String {
        switch uncertaintyScore {
        case 0.75...:
            return "High uncertainty"
        case 0.45...:
            return "Managed uncertainty"
        default:
            return "Low uncertainty"
        }
    }

    var proposalStateLine: String {
        switch status.lowercased() {
        case "approved":
            return "Proposal approved by operator"
        case "denied":
            return "Proposal denied by operator"
        case "deferred", "defer":
            return "Proposal deferred for later review"
        default:
            return "Proposal awaiting explicit human decision"
        }
    }

    var auditStateLine: String {
        if let action, let receipt = action.receipt {
            return "Receipt \(receipt.receiptId) recorded in openclashd-v2"
        }
        switch status.lowercased() {
        case "approved":
            return "Audit trail has approval but no execution receipt yet"
        case "pending":
            return "Audit trail shows proposal queued only"
        default:
            return "Audit trail records the operator decision"
        }
    }

    var executionStateLine: String {
        if let action {
            return "Execution \(action.executionState) via \(action.actionKind)"
        }
        switch status.lowercased() {
        case "approved":
            return "Execution not yet surfaced by the kernel"
        case "pending":
            return "Execution blocked pending human approval"
        default:
            return "No execution path active"
        }
    }

    var knowledgeStateLine: String {
        if !knowledgeObjectIds.isEmpty {
            return "\(knowledgeObjectIds.count) governed knowledge artifact\(knowledgeObjectIds.count == 1 ? "" : "s") linked"
        }
        if action != nil {
            return "Knowledge outcome not yet linked"
        }
        return "No governed knowledge outcome"
    }

    var receiptVisibilityLine: String {
        if let receipt = action?.receipt {
            return "Receipt visible: \(receipt.receiptId)"
        }
        return "Receipt not yet visible in Jeeves"
    }

    var timeline: [TimelineEntry] {
        let approvalState: TimelineEntry.State
        let approvalDetail: String
        switch status.lowercased() {
        case "approved":
            approvalState = .complete
            approvalDetail = decisionReason ?? "Operator approval recorded in Jeeves."
        case "denied":
            approvalState = .blocked
            approvalDetail = decisionReason ?? "Operator denied the proposal."
        case "deferred", "defer":
            approvalState = .pending
            approvalDetail = decisionReason ?? "Operator deferred pending more evidence."
        default:
            approvalState = .pending
            approvalDetail = "Awaiting explicit human approval in Jeeves."
        }

        let executionState: TimelineEntry.State
        let executionDetail: String
        if let action {
            executionState = action.isCompleted ? .complete : (action.isFailed ? .blocked : .pending)
            if let receipt = action.receipt {
                executionDetail = "\(action.actionKind) · \(receipt.resultSummary)"
            } else {
                executionDetail = "\(action.actionKind) · \(action.executionState)"
            }
        } else if status.lowercased() == "approved" {
            executionState = .pending
            executionDetail = "Approval recorded. Waiting for bounded execution receipt from openclashd-v2."
        } else if status.lowercased() == "pending" {
            executionState = .pending
            executionDetail = "Execution is blocked until a human approves."
        } else {
            executionState = .blocked
            executionDetail = "No downstream execution was triggered."
        }

        let knowledgeState: TimelineEntry.State
        let knowledgeDetail: String
        if !knowledgeObjectIds.isEmpty {
            knowledgeState = .complete
            knowledgeDetail = "\(knowledgeObjectIds.count) knowledge artifact\(knowledgeObjectIds.count == 1 ? "" : "s") linked."
        } else if action != nil {
            knowledgeState = .pending
            knowledgeDetail = "Execution receipt exists, but no linked knowledge artifact has been surfaced yet."
        } else {
            knowledgeState = .blocked
            knowledgeDetail = "No governed knowledge artifact linked."
        }

        return [
            TimelineEntry(
                id: "signal",
                title: "Signal",
                detail: "CLASHD27 surfaced a governed gap candidate for operator review.",
                timestampIso: createdAtIso,
                state: .complete
            ),
            TimelineEntry(
                id: "proposal",
                title: "Proposal",
                detail: "Queued in Jeeves without client-side execution.",
                timestampIso: createdAtIso,
                state: .complete
            ),
            TimelineEntry(
                id: "approval",
                title: "Human approval",
                detail: approvalDetail,
                timestampIso: decidedAtIso,
                state: approvalState
            ),
            TimelineEntry(
                id: "execution",
                title: "Bounded execution",
                detail: executionDetail,
                timestampIso: action?.receipt?.completedAtIso ?? decidedAtIso,
                state: executionState
            ),
            TimelineEntry(
                id: "knowledge",
                title: "Knowledge",
                detail: knowledgeDetail,
                timestampIso: action?.receipt?.completedAtIso,
                state: knowledgeState
            )
        ]
    }

    static func fromProposal(
        _ proposal: Proposal,
        decided: DecidedProposal? = nil,
        knowledge: [KnowledgeObject] = []
    ) -> GapReviewRecord? {
        guard proposal.isGapDiscovery || decided?.isGapDiscovery == true else { return nil }
        let details = proposal.gapDetails ?? decided?.gapDetails ?? fallbackDetails(
            title: proposal.title,
            summary: proposal.priorityExplanation,
            cubeCell: "Awaiting cube mapping",
            evidence: [
                GapEvidenceReference(label: "Agent", value: proposal.agentId),
                GapEvidenceReference(label: "Intent", value: proposal.intent.key)
            ],
            scores: derivedScores(from: proposal.priorityFactors, priority: proposal.priorityScore)
        )
        let knowledgeIds = linkedKnowledgeIds(
            proposalId: proposal.proposalId,
            action: decided?.action,
            knowledge: knowledge
        )

        return GapReviewRecord(
            proposalId: proposal.proposalId,
            title: proposal.title,
            summary: details.summary,
            sourceEvidence: details.sourceEvidence,
            cubeCell: details.cubeCell,
            scores: details.scores,
            hypothesis: details.hypothesis,
            verificationPlan: details.verificationPlan,
            killTests: details.killTests,
            recommendedAction: details.recommendedAction,
            status: proposal.status,
            agentId: proposal.agentId,
            risk: proposal.intent.risk,
            intentKey: proposal.intent.key,
            createdAtIso: proposal.createdAtIso,
            decidedAtIso: decided?.decidedAtIso,
            decisionReason: decided?.decisionReason,
            action: decided?.action,
            knowledgeObjectIds: knowledgeIds,
            auditHint: auditHint(status: proposal.status, action: decided?.action)
        )
    }

    static func fromDecision(
        _ decision: DecidedProposal,
        proposal: Proposal? = nil,
        knowledge: [KnowledgeObject] = []
    ) -> GapReviewRecord? {
        guard decision.isGapDiscovery || proposal?.isGapDiscovery == true else { return nil }
        let details = decision.gapDetails
            ?? proposal?.gapDetails
            ?? fallbackDetails(
                title: decision.title,
                summary: decision.decisionReason,
                cubeCell: "Awaiting cube mapping",
                evidence: [
                    GapEvidenceReference(label: "Agent", value: decision.agentId),
                    GapEvidenceReference(label: "Intent", value: decision.intent?.key ?? "gap.discovery")
                ],
                scores: derivedScores(from: proposal?.priorityFactors, priority: decision.priorityScore)
            )
        let knowledgeIds = linkedKnowledgeIds(
            proposalId: decision.proposalId,
            action: decision.action,
            knowledge: knowledge
        )

        return GapReviewRecord(
            proposalId: decision.proposalId,
            title: decision.title,
            summary: details.summary,
            sourceEvidence: details.sourceEvidence,
            cubeCell: details.cubeCell,
            scores: details.scores,
            hypothesis: details.hypothesis,
            verificationPlan: details.verificationPlan,
            killTests: details.killTests,
            recommendedAction: details.recommendedAction,
            status: decision.status,
            agentId: decision.agentId,
            risk: decision.intent?.risk ?? proposal?.intent.risk ?? "unknown",
            intentKey: decision.intent?.key ?? proposal?.intent.key ?? "gap.discovery",
            createdAtIso: proposal?.createdAtIso ?? decision.decidedAtIso ?? ISO8601DateFormatter().string(from: Date()),
            decidedAtIso: decision.decidedAtIso,
            decisionReason: decision.decisionReason,
            action: decision.action,
            knowledgeObjectIds: knowledgeIds,
            auditHint: auditHint(status: decision.status, action: decision.action)
        )
    }

    static func fromGap(
        _ gap: GovernedGapEntry,
        action: ActionSummary? = nil,
        knowledge: [KnowledgeObject] = []
    ) -> GapReviewRecord? {
        let details = gap.gapDetails
        let knowledgeIds = linkedKnowledgeIds(
            proposalId: gap.gapProposalId,
            action: action,
            knowledge: knowledge
        )

        return GapReviewRecord(
            proposalId: gap.gapProposalId,
            title: gap.title,
            summary: details.summary,
            sourceEvidence: details.sourceEvidence,
            cubeCell: details.cubeCell,
            scores: details.scores,
            hypothesis: details.hypothesis,
            verificationPlan: details.verificationPlan,
            killTests: details.killTests,
            recommendedAction: details.recommendedAction,
            status: gap.status == "proposed" ? "pending" : gap.status,
            agentId: gap.source,
            risk: gap.risk,
            intentKey: "intent.gap.govern",
            createdAtIso: gap.createdAtIso,
            decidedAtIso: gap.decidedAtIso,
            decisionReason: gap.decisionReason,
            action: action,
            knowledgeObjectIds: Array(Set(knowledgeIds + gap.knowledgeObjectIds)).sorted(),
            auditHint: auditHint(status: gap.status, action: action)
        )
    }

    private static func fallbackDetails(
        title: String,
        summary: String?,
        cubeCell: String,
        evidence: [GapEvidenceReference],
        scores: GapProposalScores
    ) -> GapProposalDetails {
        GapProposalDetails(
            summary: summary ?? "Governed gap proposal surfaced for operator review.",
            sourceEvidence: evidence,
            cubeCell: cubeCell,
            scores: scores,
            hypothesis: "This gap may block a trustworthy signal-to-action loop if left unresolved.",
            verificationPlan: [
                "Confirm the evidence path through openclashd-v2.",
                "Check whether the operator rationale is explicit in Jeeves."
            ],
            killTests: [
                "Reject if the gap is already explained elsewhere in the cockpit.",
                "Reject if no bounded backend action can verify the hypothesis."
            ],
            recommendedAction: "Review the evidence and decide whether to open a bounded verification action."
        )
    }

    private static func derivedScores(from factors: ProposalPriorityFactors?, priority: Double?) -> GapProposalScores {
        let baseline = normalized(priority ?? 0.55)
        return GapProposalScores(
            novelty: normalized(factors?.novelty ?? baseline),
            collision: normalized(factors?.duplicatePressure ?? baseline * 0.74),
            residue: normalized(factors?.crossDomainRelevance ?? baseline * 0.82),
            gravity: normalized(factors?.governanceValue ?? factors?.riskScore ?? baseline),
            evidence: normalized(factors?.evidenceStrength ?? baseline * 0.88),
            entropy: normalized(factors?.entropy ?? factors?.escalationSignal ?? baseline * 0.79),
            serendipity: normalized(factors?.serendipity ?? factors?.ageUrgency ?? baseline * 0.61)
        )
    }

    private static func normalized(_ raw: Double) -> Double {
        if raw > 1 { return min(max(raw / 100, 0), 1) }
        return min(max(raw, 0), 1)
    }

    private static func linkedKnowledgeIds(
        proposalId: String,
        action: ActionSummary?,
        knowledge: [KnowledgeObject]
    ) -> [String] {
        var ids = action?.receipt?.outputObjectIds ?? []

        for object in knowledge {
            if object.linkedObjectIds?.contains(proposalId) == true {
                ids.append(object.objectId)
                continue
            }
            if let metadata = object.metadata {
                for value in metadata.values {
                    if value.scalarStringValue?.contains(proposalId) == true {
                        ids.append(object.objectId)
                        break
                    }
                }
            }
        }

        var unique: [String] = []
        var seen: Set<String> = []
        for id in ids {
            if seen.insert(id).inserted {
                unique.append(id)
            }
        }
        return unique
    }

    private static func auditHint(status: String, action: ActionSummary?) -> String {
        if let action, let receipt = action.receipt {
            return "openclashd-v2 receipt \(receipt.receiptId) confirms \(receipt.executionState)."
        }
        switch status.lowercased() {
        case "approved":
            return "Operator approval recorded. Waiting for a downstream execution receipt."
        case "denied":
            return "Operator denial recorded. No bounded execution should follow."
        case "deferred", "defer":
            return "Proposal remains governed and inactive until a later review."
        default:
            return "Jeeves is holding this at proposal stage. No client-side execution occurs."
        }
    }
}

struct GapInboxPanel: View {
    let pendingRecords: [GapReviewRecord]
    let historyRecords: [GapReviewRecord]
    let onOpen: (GapReviewRecord) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            header

            if pendingRecords.isEmpty && historyRecords.isEmpty {
                emptyState
            } else {
                if !pendingRecords.isEmpty {
                    sectionTitle("Awaiting operator review", count: pendingRecords.count, tint: .consentOrange)
                    VStack(spacing: 10) {
                        ForEach(pendingRecords) { record in
                            Button {
                                onOpen(record)
                            } label: {
                                GapInboxCard(record: record, emphasis: .primary)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                if !historyRecords.isEmpty {
                    sectionTitle("Tracked outcomes", count: historyRecords.count, tint: .jeevesGold)
                    VStack(spacing: 10) {
                        ForEach(historyRecords) { record in
                            Button {
                                onOpen(record)
                            } label: {
                                GapInboxCard(record: record, emphasis: .secondary)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.white.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(Color.white.opacity(0.14), lineWidth: 1)
                )
        )
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("GAP INBOX")
                        .font(.jeevesMonoSmall)
                        .foregroundStyle(Color.jeevesGold)
                    Text("Governed discovery gaps")
                        .font(.jeevesHeadline.weight(.semibold))
                        .foregroundStyle(.white)
                    Text("A human-readable lane for CLASHD27 gap proposals before bounded execution.")
                        .font(.jeevesCaption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "scope")
                    .font(.system(size: 26, weight: .semibold))
                    .foregroundStyle(Color.jeevesGold)
            }

            HStack(spacing: 10) {
                metric(label: "Pending", value: "\(pendingRecords.count)", tint: .consentOrange)
                metric(
                    label: "Criticality",
                    value: "\(pendingRecords.filter { $0.scores.gravity >= 0.75 }.count)",
                    tint: .consentRed
                )
                metric(label: "Tracked", value: "\(historyRecords.count)", tint: .jeevesGold)
            }

            Text("Signal -> proposal -> human approval -> bounded execution -> knowledge")
                .font(.jeevesCaption2)
                .foregroundStyle(.secondary)

            HStack(spacing: 8) {
                boundaryPill("Human decides", tint: .jeevesGold)
                boundaryPill("Kernel executes", tint: .cyan)
                boundaryPill("Knowledge remains inspectable", tint: .consentGreen)
            }
        }
    }

    private func metric(label: String, value: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label.uppercased())
                .font(.jeevesCaption2.weight(.semibold))
                .foregroundStyle(.secondary)
            Text(value)
                .font(.jeevesMetric)
                .foregroundStyle(tint)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.white.opacity(0.04))
        )
    }

    private func sectionTitle(_ title: String, count: Int, tint: Color) -> some View {
        HStack(spacing: 8) {
            Text(title.uppercased())
                .font(.jeevesCaption.weight(.semibold))
                .foregroundStyle(tint)
            Text("\(count)")
                .font(.jeevesMono)
                .foregroundStyle(.white)
            Spacer()
        }
    }

    private func boundaryPill(_ label: String, tint: Color) -> some View {
        Text(label)
            .font(.jeevesCaption2.weight(.semibold))
            .foregroundStyle(tint)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(tint.opacity(0.12))
            .clipShape(Capsule())
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                Image(systemName: "scope")
                    .font(.jeevesTitle)
                    .foregroundStyle(.secondary)
                Text("No governed gap proposals are waiting.")
                    .font(.jeevesBody)
                    .foregroundStyle(.secondary)
            }
            Text("When CLASHD27 routes a gap proposal through openclashd-v2, it will appear here with evidence, scoring, and audit state.")
                .font(.jeevesCaption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 10)
    }
}

private struct GapInboxCard: View {
    enum Emphasis {
        case primary
        case secondary
    }

    let record: GapReviewRecord
    let emphasis: Emphasis

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 10) {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 8) {
                        statusPill
                        Text(record.cubeCell.uppercased())
                            .font(.jeevesMonoSmall)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                    Text(record.title)
                        .font(.jeevesBody.weight(.semibold))
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.leading)
                    Text(record.summary)
                        .font(.jeevesCaption)
                        .foregroundStyle(.secondary)
                        .lineLimit(emphasis == .primary ? 3 : 2)
                }
                Spacer()
                Text("G\(Int((record.scores.gravity * 100).rounded()))")
                    .font(.jeevesMono.weight(.semibold))
                    .foregroundStyle(record.statusTint)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(record.statusTint.opacity(0.12))
                    .clipShape(Capsule())
            }

            GapScoreStrip(scores: record.scores)

            HStack(spacing: 8) {
                stateBadge(record.proposalStateLine, tint: record.statusTint)
                stateBadge(record.uncertaintyLabel, tint: .cyan)
            }

            Text(record.auditHint)
                .font(.jeevesCaption)
                .foregroundStyle(.secondary)
                .lineLimit(2)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.white.opacity(emphasis == .primary ? 0.06 : 0.04))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(record.statusTint.opacity(emphasis == .primary ? 0.42 : 0.24), lineWidth: 1)
                )
        )
    }

    private var statusPill: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(record.statusTint)
                .frame(width: 7, height: 7)
            Text(record.statusLabel)
                .font(.jeevesMonoSmall)
                .foregroundStyle(record.statusTint)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(record.statusTint.opacity(0.14))
        .clipShape(Capsule())
    }

    private func stateBadge(_ label: String, tint: Color) -> some View {
        Text(label)
            .font(.jeevesCaption2.weight(.medium))
            .foregroundStyle(tint)
            .lineLimit(1)
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(Color.white.opacity(0.05))
            .clipShape(Capsule())
    }
}

private struct GapScoreStrip: View {
    let scores: GapProposalScores

    var body: some View {
        let metrics: [(String, Double, Color)] = [
            ("Novelty", scores.novelty, .blue),
            ("Collision", scores.collision, .orange),
            ("Residue", scores.residue, .cyan),
            ("Gravity", scores.gravity, .red),
            ("Evidence", scores.evidence, .green),
            ("Entropy", scores.entropy, Color(red: 0.95, green: 0.39, blue: 0.72)),
            ("Serendipity", scores.serendipity, Color(red: 0.62, green: 0.53, blue: 0.97))
        ]

        return LazyVGrid(
            columns: [
                GridItem(.flexible(minimum: 88), spacing: 8),
                GridItem(.flexible(minimum: 88), spacing: 8),
                GridItem(.flexible(minimum: 88), spacing: 8)
            ],
            spacing: 8
        ) {
            ForEach(metrics, id: \.0) { metric in
                meter(label: metric.0, value: metric.1, tint: metric.2)
            }
        }
    }

    private func meter(label: String, value: Double, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(label.uppercased())
                .font(.jeevesCaption2.weight(.semibold))
                .foregroundStyle(.secondary)
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.white.opacity(0.08))
                    Capsule()
                        .fill(tint)
                        .frame(width: max(geometry.size.width * value, 6))
                }
            }
            .frame(height: 6)
            Text("\(Int((value * 100).rounded()))")
                .font(.jeevesMonoSmall)
                .foregroundStyle(tint)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white.opacity(0.03))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}

struct GapProposalDetailSheet: View {
    @Environment(\.dismiss) private var dismiss

    let record: GapReviewRecord
    let isActionInFlight: Bool
    let onAction: (GapDecisionAction) -> Void
    let onKnowledgeTap: (String) -> Void

    var body: some View {
        NavigationStack {
            ZStack {
                detailBackground
                ScrollView(showsIndicators: false) {
                    detailContent
                }
            }
            .navigationTitle("Gap Detail")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
            .safeAreaInset(edge: .bottom) {
                actionBar
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(.ultraThinMaterial)
            }
        }
        .preferredColorScheme(.dark)
    }

    private var detailBackground: some View {
        LinearGradient(
            colors: [
                Color(red: 0.05, green: 0.08, blue: 0.12),
                Color(red: 0.02, green: 0.03, blue: 0.06)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
    }

    private var detailContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            heroPanel
            stateDeck
            scoreGrid
            sourceEvidenceSection
            sectionPanel(title: "Hypothesis", icon: "sparkles.rectangle.stack") {
                Text(record.hypothesis)
                    .font(.jeevesBody)
                    .foregroundStyle(.white)
                    .fixedSize(horizontal: false, vertical: true)
            }
            sectionPanel(title: "Verification plan", icon: "checklist") {
                bulletList(record.verificationPlan, fallback: "No explicit verification plan was provided.")
            }
            sectionPanel(title: "Kill tests", icon: "xmark.shield") {
                bulletList(record.killTests, fallback: "No explicit kill tests were provided.")
            }
            sectionPanel(title: "Recommended action", icon: "point.topleft.down.curvedto.point.bottomright.up") {
                Text(record.recommendedAction)
                    .font(.jeevesBody)
                    .foregroundStyle(.white)
                    .fixedSize(horizontal: false, vertical: true)
            }
            boundarySection
            downstreamAuditSection
            if !record.knowledgeObjectIds.isEmpty {
                knowledgeArtifactsSection
            }
            Text("Jeeves remains operator UX only. Decisions from this screen are relayed to openclashd-v2; no hidden execution occurs on the client.")
                .font(.jeevesCaption)
                .foregroundStyle(.secondary)
                .padding(.bottom, 110)
        }
        .padding(16)
    }

    private var sourceEvidenceSection: some View {
        sectionPanel(title: "Source evidence", icon: "doc.text.magnifyingglass") {
            VStack(spacing: 10) {
                ForEach(record.sourceEvidence) { evidence in
                    evidenceRow(evidence)
                }
            }
        }
    }

    private var downstreamAuditSection: some View {
        sectionPanel(title: "Downstream audit state", icon: "timeline.selection") {
            VStack(spacing: 10) {
                ForEach(record.timeline) { entry in
                    timelineRow(entry)
                }
                Text(record.auditHint)
                    .font(.jeevesCaption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var knowledgeArtifactsSection: some View {
        sectionPanel(title: "Knowledge artifacts", icon: "book.closed.fill") {
            VStack(spacing: 10) {
                ForEach(record.knowledgeObjectIds, id: \.self) { objectId in
                    Button {
                        onKnowledgeTap(objectId)
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 3) {
                                Text(objectId)
                                    .font(.jeevesMono)
                                    .foregroundStyle(.white)
                                Text("Open governed knowledge graph")
                                    .font(.jeevesCaption2)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Image(systemName: "arrow.up.right.square")
                                .foregroundStyle(Color.jeevesGold)
                        }
                        .padding(12)
                        .background(Color.white.opacity(0.04))
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var heroPanel: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("GOVERNED GAP PROPOSAL")
                        .font(.jeevesMonoSmall)
                        .foregroundStyle(Color.jeevesGold)
                    Text(record.title)
                        .font(.jeevesTitle.weight(.semibold))
                        .foregroundStyle(.white)
                    Text(record.summary)
                        .font(.jeevesBody)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 6) {
                    Text(record.statusLabel)
                        .font(.jeevesMono.weight(.semibold))
                        .foregroundStyle(record.statusTint)
                    Text(record.risk.uppercased())
                        .font(.jeevesCaption2.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
            }

            HStack(spacing: 10) {
                metaPill(label: "Cube cell", value: record.cubeCell, tint: .jeevesGold)
                metaPill(label: "Intent", value: record.intentKey, tint: .cyan)
            }

            HStack(spacing: 10) {
                metaPill(label: "Source", value: record.agentId, tint: .secondary, usesTintForeground: false)
                metaPill(label: "Proposal", value: record.proposalId, tint: .secondary, usesTintForeground: false)
            }

            HStack(spacing: 8) {
                heroStatusPill(record.proposalStateLine, tint: record.statusTint)
                heroStatusPill(record.uncertaintyLabel, tint: .cyan)
                heroStatusPill("Serendipity \(Int((record.scores.serendipity * 100).rounded()))", tint: Color(red: 0.62, green: 0.53, blue: 0.97))
            }
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Color.white.opacity(0.06))
                .overlay(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .stroke(record.statusTint.opacity(0.45), lineWidth: 1)
                )
        )
        .overlay(alignment: .topTrailing) {
            Circle()
                .fill(record.statusTint.opacity(0.18))
                .frame(width: 140, height: 140)
                .blur(radius: 30)
                .offset(x: 30, y: -30)
        }
    }

    private var stateDeck: some View {
        let tiles: [(String, String, Color)] = [
            ("Proposal state", record.proposalStateLine, record.statusTint),
            ("Audit state", record.auditStateLine, .jeevesGold),
            ("Execution state", record.executionStateLine, .cyan),
            ("Knowledge state", record.knowledgeStateLine, .consentGreen),
            ("Receipt", record.receiptVisibilityLine, .orange),
            ("Certification", "Not certified in Jeeves. Trust remains anchored in openclashd-v2.", Color(red: 0.84, green: 0.60, blue: 0.16))
        ]

        return VStack(alignment: .leading, spacing: 12) {
            Text("Control desk")
                .font(.jeevesHeadline.weight(.semibold))
                .foregroundStyle(.white)
            LazyVGrid(
                columns: [
                    GridItem(.flexible(minimum: 140), spacing: 10),
                    GridItem(.flexible(minimum: 140), spacing: 10)
                ],
                spacing: 10
            ) {
                ForEach(tiles, id: \.0) { tile in
                    VStack(alignment: .leading, spacing: 8) {
                        Text(tile.0.uppercased())
                            .font(.jeevesCaption2.weight(.semibold))
                            .foregroundStyle(.secondary)
                        Text(tile.1)
                            .font(.jeevesCaption)
                            .foregroundStyle(.white)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(Color.white.opacity(0.045))
                            .overlay(
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .stroke(tile.2.opacity(0.36), lineWidth: 1)
                            )
                    )
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [Color.white.opacity(0.05), Color.white.opacity(0.03)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
    }

    private var scoreGrid: some View {
        let metrics: [(String, Double, Color)] = [
            ("Novelty", record.scores.novelty, .blue),
            ("Collision", record.scores.collision, .orange),
            ("Residue", record.scores.residue, .cyan),
            ("Gravity", record.scores.gravity, .red),
            ("Evidence", record.scores.evidence, .green),
            ("Entropy", record.scores.entropy, Color(red: 0.95, green: 0.39, blue: 0.72)),
            ("Serendipity", record.scores.serendipity, Color(red: 0.62, green: 0.53, blue: 0.97))
        ]

        return VStack(alignment: .leading, spacing: 10) {
            Text("Scoring envelope")
                .font(.jeevesHeadline.weight(.semibold))
                .foregroundStyle(.white)
            LazyVGrid(
                columns: [
                    GridItem(.flexible(minimum: 100), spacing: 10),
                    GridItem(.flexible(minimum: 100), spacing: 10)
                ],
                spacing: 10
            ) {
                ForEach(metrics, id: \.0) { metric in
                    VStack(alignment: .leading, spacing: 8) {
                        Text(metric.0.uppercased())
                            .font(.jeevesCaption2.weight(.semibold))
                            .foregroundStyle(.secondary)
                        Text("\(Int((metric.1 * 100).rounded()))")
                            .font(.system(size: 28, weight: .bold, design: .monospaced))
                            .foregroundStyle(metric.2)
                        Capsule()
                            .fill(Color.white.opacity(0.08))
                            .overlay(alignment: .leading) {
                                Capsule()
                                    .fill(metric.2)
                                    .frame(width: max(metric.1 * 140, 10))
                            }
                            .frame(height: 7)
                    }
                    .padding(14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.white.opacity(0.04))
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
            }

            HStack(spacing: 10) {
                scoreCallout(
                    label: "Uncertainty",
                    value: record.uncertaintyLabel,
                    tint: .cyan
                )
                scoreCallout(
                    label: "Why it matters",
                    value: record.scores.gravity >= 0.75 ? "High governance pull" : "Watch and compare",
                    tint: .jeevesGold
                )
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.white.opacity(0.05))
        )
    }

    private var boundarySection: some View {
        sectionPanel(title: "Trust boundary", icon: "shield.lefthalf.filled") {
            VStack(alignment: .leading, spacing: 12) {
                boundaryRow(
                    title: "What the operator sees",
                    detail: "Cube position, evidence, seven scores, rationale, lifecycle state, and any downstream receipt or knowledge link."
                )
                boundaryRow(
                    title: "What the operator can decide",
                    detail: "Approve, deny, or defer the proposal and return that decision to openclashd-v2."
                )
                boundaryRow(
                    title: "What the operator cannot bypass",
                    detail: "Execution logic, certification authority, and direct state mutation remain outside Jeeves."
                )
                boundaryRow(
                    title: "How trust is reinforced",
                    detail: "The screen keeps the proposal legible while making the discovery-to-execution boundary explicit."
                )
            }
        }
    }

    private func sectionPanel<Content: View>(title: String, icon: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .foregroundStyle(Color.jeevesGold)
                Text(title)
                    .font(.jeevesHeadline.weight(.semibold))
                    .foregroundStyle(.white)
            }
            content()
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.white.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(Color.white.opacity(0.1), lineWidth: 1)
                )
        )
    }

    private func heroStatusPill(_ text: String, tint: Color) -> some View {
        Text(text)
            .font(.jeevesCaption2.weight(.semibold))
            .foregroundStyle(tint)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(tint.opacity(0.14))
            .clipShape(Capsule())
    }

    private func metaPill(label: String, value: String, tint: Color, usesTintForeground: Bool = true) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label.uppercased())
                .font(.jeevesCaption2.weight(.semibold))
                .foregroundStyle(.secondary)
            Text(value)
                .font(.jeevesMono)
                .foregroundStyle(usesTintForeground ? tint : .white)
                .lineLimit(1)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Color.white.opacity(0.04))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private func evidenceRow(_ evidence: GapEvidenceReference) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(evidence.label.uppercased())
                .font(.jeevesCaption2.weight(.semibold))
                .foregroundStyle(Color.jeevesGold)
            if let urlString = evidence.url, let url = URL(string: urlString) {
                Link(destination: url) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(evidence.value)
                            .font(.jeevesBody)
                            .foregroundStyle(.white)
                        Text(url.absoluteString)
                            .font(.jeevesCaption2)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
            } else {
                Text(evidence.value)
                    .font(.jeevesBody)
                    .foregroundStyle(.white)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Color.white.opacity(0.04))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private func bulletList(_ items: [String], fallback: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            if items.isEmpty {
                Text(fallback)
                    .font(.jeevesBody)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(Array(items.enumerated()), id: \.offset) { index, item in
                    HStack(alignment: .top, spacing: 10) {
                        Text("\(index + 1)")
                            .font(.jeevesMono.weight(.semibold))
                            .foregroundStyle(Color.jeevesGold)
                            .frame(width: 20, alignment: .leading)
                        Text(item)
                            .font(.jeevesBody)
                            .foregroundStyle(.white)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }
    }

    private func scoreCallout(label: String, value: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label.uppercased())
                .font(.jeevesCaption2.weight(.semibold))
                .foregroundStyle(.secondary)
            Text(value)
                .font(.jeevesBody.weight(.medium))
                .foregroundStyle(tint)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white.opacity(0.04))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private func boundaryRow(title: String, detail: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.jeevesCaption.weight(.semibold))
                .foregroundStyle(Color.jeevesGold)
            Text(detail)
                .font(.jeevesBody)
                .foregroundStyle(.white)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Color.white.opacity(0.04))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private func timelineRow(_ entry: GapReviewRecord.TimelineEntry) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Circle()
                .fill(timelineTint(entry.state))
                .frame(width: 10, height: 10)
                .padding(.top, 5)
            VStack(alignment: .leading, spacing: 4) {
                Text(entry.title)
                    .font(.jeevesBody.weight(.semibold))
                    .foregroundStyle(.white)
                Text(entry.detail)
                    .font(.jeevesCaption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                if let timestamp = entry.timestampIso, !timestamp.isEmpty {
                    Text(timestamp)
                        .font(.jeevesMonoSmall)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
        }
        .padding(12)
        .background(Color.white.opacity(0.04))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private func timelineTint(_ state: GapReviewRecord.TimelineEntry.State) -> Color {
        switch state {
        case .complete:
            return .consentGreen
        case .pending:
            return .consentOrange
        case .blocked:
            return .consentRed
        }
    }

    private var actionBar: some View {
        Group {
            if record.isPending {
                HStack(spacing: 10) {
                    actionButton(.deny)
                    actionButton(.deferProposal)
                    actionButton(.approve)
                }
            } else {
                HStack {
                    Text(record.auditHint)
                        .font(.jeevesCaption)
                        .foregroundStyle(.secondary)
                    Spacer()
                }
            }
        }
    }

    private func actionButton(_ action: GapDecisionAction) -> some View {
        Button {
            onAction(action)
        } label: {
            HStack(spacing: 8) {
                if isActionInFlight {
                    ProgressView()
                        .tint(action.tint)
                } else {
                    Image(systemName: action.systemImage)
                }
                Text(action.label)
            }
            .font(.jeevesBody.weight(.semibold))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(action.tint.opacity(0.16))
            .foregroundStyle(action.tint)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .disabled(isActionInFlight)
    }
}
