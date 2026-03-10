import SwiftUI

struct DailyBriefingView: View {
    let briefing: DailyBriefing
    let warning: String?
    let onSelectAttention: (DailyBriefingItem) -> Void
    let onSelectSignal: (DailyBriefingSignalGroup) -> Void
    let onSelectEvidence: (KnowledgeObject) -> Void

    private let sectionCaps: [MorningSection: Int] = [
        .worldSituation: 3,
        .aiDevelopments: 4,
        .discoveryHints: 3
    ]

    var body: some View {
        let cards = cappedCards()

        VStack(alignment: .leading, spacing: 22) {
            MorningHeroHeader(briefing: briefing, warning: warning)
                .staggeredAppear(delay: 0)

            ForEach(Array(MorningSection.allCases.enumerated()), id: \.element.id) { sectionIndex, section in
                let sectionCards = cards.filter { $0.section == section }
                MorningSectionView(
                    section: section,
                    cards: sectionCards,
                    sectionIndex: sectionIndex,
                    onPrimaryTap: { card in
                        handlePrimaryTap(for: card)
                    },
                    onSecondaryTap: { card in
                        handleSecondaryTap(for: card)
                    }
                )
            }
        }
    }

    private func cappedCards() -> [MorningBriefingCard] {
        var result: [MorningBriefingCard] = []
        for section in MorningSection.allCases {
            let cards = cards(for: section)
            result.append(contentsOf: cards.prefix(sectionCaps[section] ?? 0))
        }
        return Array(result.prefix(10))
    }

    private func cards(for section: MorningSection) -> [MorningBriefingCard] {
        combinedCards()
            .filter { $0.section == section }
            .sorted { lhs, rhs in
                if lhs.priority != rhs.priority {
                    return lhs.priority > rhs.priority
                }
                if lhs.createdAtIso != rhs.createdAtIso {
                    return (lhs.createdAtIso ?? "") > (rhs.createdAtIso ?? "")
                }
                return lhs.id < rhs.id
            }
    }

    private func combinedCards() -> [MorningBriefingCard] {
        let attentionCards = briefing.attention.map { item in
            let section = categorize(text: [item.title, item.summary, item.why], preferredKind: item.kind)
            return MorningBriefingCard(
                id: item.id,
                section: section,
                title: item.title,
                summary: item.summary,
                why: item.why,
                eyebrow: eyebrow(for: item.kind, section: section),
                icon: iconName(for: item.kind, title: item.title, summary: item.summary),
                tint: tint(for: item.kind, section: section, title: item.title, summary: item.summary),
                primaryAction: .explanation(item),
                secondaryAction: firstRelatedEvidence(for: item).map { .evidence($0) },
                priority: item.score,
                createdAtIso: item.createdAtIso,
                imageLabel: sectionImageLabel(for: section)
            )
        }

        let signalCards = briefing.signals.map { signal in
            let item = DailyBriefingItem(
                itemId: signal.groupId,
                kind: "signal",
                title: signal.title,
                summary: signal.summary,
                why: signal.why,
                score: Double(signal.signalCount),
                createdAtIso: signal.latestDetectedAtIso,
                sourceCount: signal.sourceCount,
                objectId: nil,
                proposalId: nil,
                relatedObjectIds: signal.relatedObjectIds
            )
            let section = categorize(text: [signal.title, signal.summary, signal.why], preferredKind: "signal")
            return MorningBriefingCard(
                id: signal.id,
                section: section,
                title: signal.title,
                summary: signal.summary,
                why: signal.why,
                eyebrow: eyebrow(for: "signal", section: section),
                icon: iconName(for: "signal", title: signal.title, summary: signal.summary),
                tint: tint(for: "signal", section: section, title: signal.title, summary: signal.summary),
                primaryAction: .explanation(item),
                secondaryAction: firstRelatedEvidence(for: signal).map { .evidence($0) },
                priority: Double(signal.signalCount + signal.sourceCount),
                createdAtIso: signal.latestDetectedAtIso,
                imageLabel: sectionImageLabel(for: section)
            )
        }

        let evidenceCards = briefing.evidence.map { object in
            let explanation = DailyBriefingItem(
                itemId: object.objectId,
                kind: "knowledge",
                title: object.title,
                summary: object.summary,
                why: "Stored as immutable \(object.kind.replacingOccurrences(of: "_", with: " ")) in the knowledge store.",
                score: 56,
                createdAtIso: object.createdAtIso,
                sourceCount: object.sourceRefs?.count ?? 0,
                objectId: object.objectId,
                proposalId: nil,
                relatedObjectIds: [object.objectId]
            )
            let section = categorize(text: [object.title, object.summary], preferredKind: object.kind)
            return MorningBriefingCard(
                id: object.id,
                section: section,
                title: object.title,
                summary: object.summary,
                why: explanation.why,
                eyebrow: eyebrow(for: object.kind, section: section),
                icon: iconName(for: object.kind, title: object.title, summary: object.summary),
                tint: tint(for: object.kind, section: section, title: object.title, summary: object.summary),
                primaryAction: .evidence(object),
                secondaryAction: .explanation(explanation),
                priority: 40,
                createdAtIso: object.createdAtIso,
                imageLabel: sectionImageLabel(for: section)
            )
        }

        return attentionCards + signalCards + evidenceCards
    }

    private func categorize(text parts: [String], preferredKind: String) -> MorningSection {
        let haystack = parts.joined(separator: " ").lowercased()
        if preferredKind == "approval" || haystack.contains("emerging cluster") || haystack.contains("cross-domain") || haystack.contains("discovery") || haystack.contains("clashd27") || haystack.contains("novel") {
            return .discoveryHints
        }
        if containsAny(haystack, matches: ["geopolit", "sanction", "export control", "conflict", "security", "policy", "government", "state", "supply chain", "world", "europe", "china", "russia", "middle east"]) {
            return .worldSituation
        }
        return .aiDevelopments
    }

    private func containsAny(_ haystack: String, matches: [String]) -> Bool {
        matches.contains { haystack.contains($0) }
    }

    private func eyebrow(for kind: String, section: MorningSection) -> String {
        switch section {
        case .worldSituation:
            return "World situation"
        case .aiDevelopments:
            if kind == "knowledge" || kind == "evidence" {
                return "Research evidence"
            }
            return "AI development"
        case .discoveryHints:
            if kind == "approval" {
                return "Needs approval"
            }
            return "Discovery hint"
        }
    }

    private func iconName(for kind: String, title: String, summary: String) -> String {
        let haystack = "\(title) \(summary)".lowercased()
        if haystack.contains("world") || haystack.contains("geopolit") || haystack.contains("policy") {
            return "globe.europe.africa.fill"
        }
        if haystack.contains("cluster") || haystack.contains("discovery") || haystack.contains("novel") {
            return "sparkles"
        }
        if haystack.contains("code") || haystack.contains("infra") || haystack.contains("runtime") || haystack.contains("engineering") || haystack.contains("repo") || haystack.contains("compiler") || haystack.contains("inference") {
            return "cpu.fill"
        }
        if kind == "approval" {
            return "checkmark.seal.fill"
        }
        if kind == "knowledge" || kind == "evidence" {
            return "doc.text.image.fill"
        }
        return "brain.head.profile"
    }

    private func tint(for kind: String, section: MorningSection, title: String, summary: String) -> Color {
        switch section {
        case .worldSituation:
            return Color(red: 0.12, green: 0.42, blue: 0.72)
        case .aiDevelopments:
            let haystack = "\(title) \(summary)".lowercased()
            if haystack.contains("code") || haystack.contains("infra") || haystack.contains("runtime") || haystack.contains("engineering") || haystack.contains("repo") {
                return Color(red: 0.14, green: 0.61, blue: 0.54)
            }
            return Color(red: 0.45, green: 0.33, blue: 0.80)
        case .discoveryHints:
            return kind == "approval" ? .orange : Color(red: 0.84, green: 0.58, blue: 0.18)
        }
    }

    private func sectionImageLabel(for section: MorningSection) -> String {
        switch section {
        case .worldSituation: return "World"
        case .aiDevelopments: return "AI"
        case .discoveryHints: return "Hint"
        }
    }

    private func firstRelatedEvidence(for item: DailyBriefingItem) -> KnowledgeObject? {
        let ids = Set(item.relatedObjectIds + [item.objectId].compactMap { $0 })
        return briefing.evidence.first { ids.contains($0.objectId) }
    }

    private func firstRelatedEvidence(for signal: DailyBriefingSignalGroup) -> KnowledgeObject? {
        let ids = Set(signal.relatedObjectIds)
        return briefing.evidence.first { ids.contains($0.objectId) }
    }

    private func handlePrimaryTap(for card: MorningBriefingCard) {
        switch card.primaryAction {
        case .explanation(let item):
            onSelectAttention(item)
        case .evidence(let object):
            onSelectEvidence(object)
        }
    }

    private func handleSecondaryTap(for card: MorningBriefingCard) {
        guard let action = card.secondaryAction else { return }
        switch action {
        case .explanation(let item):
            onSelectAttention(item)
        case .evidence(let object):
            onSelectEvidence(object)
        }
    }
}

struct DailyBriefingExplanationSheet: View {
    let item: DailyBriefingItem
    let relatedEvidence: [KnowledgeObject]
    let onSelectEvidence: (KnowledgeObject) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(item.title)
                            .font(.jeevesHeadline)
                        Text(item.summary)
                            .font(.jeevesBody)
                            .foregroundStyle(.secondary)
                        Text("Why this matters")
                            .font(.jeevesMono)
                            .fontWeight(.semibold)
                            .padding(.top, 4)
                        Text(item.why)
                            .font(.jeevesBody)
                            .foregroundStyle(.secondary)
                    }
                    .briefingPanel()

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Context")
                            .font(.jeevesMono)
                            .fontWeight(.semibold)
                        HStack(spacing: 10) {
                            contextChip(item.kind)
                            contextChip("\(item.sourceCount) bron\(item.sourceCount == 1 ? "" : "nen")")
                            contextChip("score \(scoreText)")
                        }
                    }
                    .briefingPanel()

                    if !relatedEvidence.isEmpty {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Evidence")
                                .font(.jeevesMono)
                                .fontWeight(.semibold)
                            ForEach(relatedEvidence) { object in
                                Button {
                                    onSelectEvidence(object)
                                } label: {
                                    BriefingEvidenceCard(object: object)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .briefingPanel()
                    }
                }
                .padding()
            }
            .navigationTitle("Why this matters")
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

    private var scoreText: String {
        item.score >= 1 ? String(format: "%.0f", item.score) : String(format: "%.2f", item.score)
    }

    private func contextChip(_ text: String) -> some View {
        Text(text)
            .font(.jeevesMonoSmall)
            .foregroundStyle(.secondary)
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(Color(.secondarySystemFill))
            .clipShape(Capsule())
    }
}

struct DailyBriefingKnowledgeGraphSheet: View {
    let graphData: KnowledgeGraphResponse?
    let isLoading: Bool
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    ProgressView("Evidence laden...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let graph = graphData {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 16) {
                            if let root = graph.root {
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("Root")
                                        .font(.jeevesMono)
                                        .fontWeight(.semibold)
                                    BriefingEvidenceCard(object: root)
                                }
                                .briefingPanel()
                            }

                            if let linked = graph.linked, !linked.isEmpty {
                                VStack(alignment: .leading, spacing: 10) {
                                    Text("Linked evidence")
                                        .font(.jeevesMono)
                                        .fontWeight(.semibold)
                                    ForEach(linked) { object in
                                        BriefingEvidenceCard(object: object)
                                    }
                                }
                                .briefingPanel()
                            }
                        }
                        .padding()
                    }
                } else {
                    JeevesEmptyState(
                        icon: "doc.text.magnifyingglass",
                        title: "Evidence niet beschikbaar.",
                        subtitle: "De kennisgraaf kon niet worden geladen."
                    )
                }
            }
            .navigationTitle("Supporting Evidence")
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
}

private enum MorningSection: String, CaseIterable, Identifiable {
    case worldSituation
    case aiDevelopments
    case discoveryHints

    var id: String { rawValue }

    var title: String {
        switch self {
        case .worldSituation: return "World situation"
        case .aiDevelopments: return "AI developments"
        case .discoveryHints: return "Discovery hints"
        }
    }

    var subtitle: String {
        switch self {
        case .worldSituation:
            return "Geopolitics, policy, and the outside world that may shift the operating environment."
        case .aiDevelopments:
            return "Research, engineering, and infrastructure movement worth noticing this morning."
        case .discoveryHints:
            return "Possible structural changes, kept calm, explainable, and evidence-backed."
        }
    }

    var icon: String {
        switch self {
        case .worldSituation: return "globe.europe.africa.fill"
        case .aiDevelopments: return "brain.head.profile"
        case .discoveryHints: return "sparkles"
        }
    }

    var accent: Color {
        switch self {
        case .worldSituation: return Color(red: 0.15, green: 0.44, blue: 0.74)
        case .aiDevelopments: return Color(red: 0.45, green: 0.33, blue: 0.80)
        case .discoveryHints: return Color(red: 0.85, green: 0.59, blue: 0.18)
        }
    }
}

private enum MorningCardAction {
    case explanation(DailyBriefingItem)
    case evidence(KnowledgeObject)
}

private struct MorningBriefingCard: Identifiable {
    let id: String
    let section: MorningSection
    let title: String
    let summary: String
    let why: String
    let eyebrow: String
    let icon: String
    let tint: Color
    let primaryAction: MorningCardAction
    let secondaryAction: MorningCardAction?
    let priority: Double
    let createdAtIso: String?
    let imageLabel: String
}

private struct MorningHeroHeader: View {
    let briefing: DailyBriefing
    let warning: String?

    var body: some View {
        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.07, green: 0.10, blue: 0.17),
                            Color(red: 0.10, green: 0.19, blue: 0.31),
                            Color(red: 0.15, green: 0.22, blue: 0.19)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RadarBackdrop()
                        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .stroke(Color.white.opacity(0.08), lineWidth: 1)
                )

            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Good morning, Wiard")
                            .font(.jeevesCaption)
                            .textCase(.uppercase)
                            .foregroundStyle(Color.white.opacity(0.68))
                        Text(briefing.headline)
                            .font(.jeevesLargeTitle)
                            .foregroundStyle(.white)
                            .fixedSize(horizontal: false, vertical: true)
                        Text(briefing.statusLine)
                            .font(.jeevesCaption)
                            .foregroundStyle(Color.white.opacity(0.72))
                    }
                    Spacer(minLength: 12)
                    VStack(alignment: .trailing, spacing: 8) {
                        statusChip("System", status: overallStatus)
                        statusChip("Signals", status: briefing.system.signalRuntime.status)
                        statusChip("Knowledge", status: briefing.system.knowledge.status)
                    }
                }

                if !briefing.overview.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(Array(briefing.overview.prefix(2)), id: \.self) { line in
                            HStack(alignment: .top, spacing: 8) {
                                Circle()
                                    .fill(Color.white.opacity(0.45))
                                    .frame(width: 6, height: 6)
                                    .padding(.top, 6)
                                Text(line)
                                    .font(.jeevesBody)
                                    .foregroundStyle(Color.white.opacity(0.82))
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                    }
                }

                HStack(spacing: 12) {
                    heroMetric(label: "Approvals", value: briefing.counts.pendingApprovals, tint: .orange)
                    heroMetric(label: "Signals", value: briefing.counts.groupedSignals, tint: .cyan)
                    heroMetric(label: "Evidence", value: briefing.counts.recentEvidence, tint: .mint)
                }

                if let warning, !warning.isEmpty {
                    Text(warning)
                        .font(.jeevesCaption)
                        .foregroundStyle(Color.orange.opacity(0.95))
                }
            }
            .padding(24)
        }
    }

    private var overallStatus: String {
        if briefing.counts.stale { return "stale" }
        if briefing.counts.pendingApprovals > 0 || briefing.system.signalRuntime.status == "attention" || briefing.system.knowledge.status == "attention" {
            return "attention"
        }
        return "healthy"
    }

    private func heroMetric(label: String, value: Int, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.jeevesCaption)
                .foregroundStyle(Color.white.opacity(0.64))
            Text("\(value)")
                .font(.jeevesMetric)
                .foregroundStyle(tint)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Color.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func statusChip(_ title: String, status: String) -> some View {
        HStack(spacing: 8) {
            Circle()
                .fill(statusColor(status))
                .frame(width: 8, height: 8)
            Text(title)
                .font(.jeevesMonoSmall)
            Text(status.capitalized)
                .font(.jeevesMonoSmall.weight(.regular))
        }
        .foregroundStyle(Color.white.opacity(0.82))
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(Color.white.opacity(0.08), in: Capsule())
    }

    private func statusColor(_ status: String) -> Color {
        switch status {
        case "healthy": return .green
        case "attention": return .orange
        default: return .red
        }
    }
}

private struct RadarBackdrop: View {
    @State private var sweepAngle: Double = 0
    @State private var pulseScale: CGFloat = 1.0

    var body: some View {
        GeometryReader { geometry in
            let w = geometry.size.width
            let h = geometry.size.height
            let sweepCenter = CGPoint(x: w * 0.62, y: h * 0.40)

            ZStack {
                // Outer ring
                Circle()
                    .stroke(Color.white.opacity(0.04), lineWidth: 1)
                    .frame(width: w * 1.1)
                    .offset(x: w * 0.22, y: -h * 0.06)

                // Middle ring
                Circle()
                    .stroke(Color.white.opacity(0.07), lineWidth: 1)
                    .frame(width: w * 0.9)
                    .offset(x: w * 0.24, y: -h * 0.02)

                // Inner ring
                Circle()
                    .stroke(Color.white.opacity(0.05), lineWidth: 1)
                    .frame(width: w * 0.65)
                    .offset(x: w * 0.20, y: h * 0.08)

                // Sweep arm — slow rotating radar line
                Path { path in
                    path.move(to: sweepCenter)
                    path.addLine(to: CGPoint(x: sweepCenter.x + w * 0.45, y: sweepCenter.y))
                }
                .stroke(Color.white.opacity(0.10), lineWidth: 1)
                .rotationEffect(.degrees(sweepAngle), anchor: UnitPoint(
                    x: sweepCenter.x / w,
                    y: sweepCenter.y / h
                ))

                // Bezier flow line
                Path { path in
                    path.move(to: CGPoint(x: w * 0.14, y: h * 0.58))
                    path.addCurve(to: CGPoint(x: w * 0.88, y: h * 0.46), control1: CGPoint(x: w * 0.32, y: h * 0.34), control2: CGPoint(x: w * 0.62, y: h * 0.72))
                    path.addCurve(to: CGPoint(x: w * 0.92, y: h * 0.70), control1: CGPoint(x: w * 0.92, y: h * 0.52), control2: CGPoint(x: w * 0.96, y: h * 0.58))
                }
                .stroke(Color.white.opacity(0.08), lineWidth: 1)

                // Signal dots with gentle pulse on primary
                ForEach(0..<5, id: \.self) { index in
                    Circle()
                        .fill(Color.white.opacity(index == 0 ? 0.34 : 0.16))
                        .frame(width: index == 0 ? 8 : 5, height: index == 0 ? 8 : 5)
                        .scaleEffect(index == 0 ? pulseScale : 1.0)
                        .offset(
                            x: w * [0.18, 0.48, 0.66, 0.77, 0.84][index] - w / 2,
                            y: h * [0.30, 0.52, 0.35, 0.60, 0.42][index] - h / 2
                        )
                }
            }
        }
        .allowsHitTesting(false)
        .onAppear {
            withAnimation(.linear(duration: 14).repeatForever(autoreverses: false)) {
                sweepAngle = 360
            }
            withAnimation(.easeInOut(duration: 3).repeatForever(autoreverses: true)) {
                pulseScale = 1.25
            }
        }
    }
}

private struct MorningSectionView: View {
    let section: MorningSection
    let cards: [MorningBriefingCard]
    let sectionIndex: Int
    let onPrimaryTap: (MorningBriefingCard) -> Void
    let onSecondaryTap: (MorningBriefingCard) -> Void

    private var sectionBaseDelay: Double {
        Double(sectionIndex) * 0.15 + 0.12
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .center, spacing: 10) {
                Image(systemName: section.icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(section.accent)
                    .frame(width: 28, height: 28)
                    .background(section.accent.opacity(0.12), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                VStack(alignment: .leading, spacing: 2) {
                    Text(section.title)
                        .font(.jeevesHeadline.weight(.semibold))
                    Text(section.subtitle)
                        .font(.jeevesCaption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }
            .staggeredAppear(delay: sectionBaseDelay)

            if cards.isEmpty {
                Text("Quiet this morning.")
                    .font(.jeevesCaption)
                    .foregroundStyle(.secondary)
                    .padding(.leading, 2)
                    .staggeredAppear(delay: sectionBaseDelay + 0.06)
            } else {
                ForEach(Array(cards.enumerated()), id: \.element.id) { cardIndex, card in
                    MorningBriefingCardView(
                        card: card,
                        onPrimaryTap: { onPrimaryTap(card) },
                        onSecondaryTap: card.secondaryAction == nil ? nil : { onSecondaryTap(card) }
                    )
                    .staggeredAppear(delay: sectionBaseDelay + Double(cardIndex + 1) * 0.07)
                }
            }
        }
    }
}

private struct MorningBriefingCardView: View {
    let card: MorningBriefingCard
    let onPrimaryTap: () -> Void
    let onSecondaryTap: (() -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button(action: onPrimaryTap) {
                HStack(alignment: .top, spacing: 14) {
                    VStack(spacing: 8) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .fill(
                                    LinearGradient(
                                        colors: [card.tint.opacity(0.9), card.tint.opacity(0.34)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                            Image(systemName: card.icon)
                                .font(.system(size: 24, weight: .semibold))
                                .foregroundStyle(.white)
                        }
                        .frame(width: 72, height: 88)

                        Text(card.imageLabel)
                            .font(.jeevesMonoSmall)
                            .foregroundStyle(.secondary)
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text(card.eyebrow)
                            .font(.jeevesMonoSmall.weight(.bold))
                            .foregroundStyle(card.tint)
                            .textCase(.uppercase)
                        Text(card.title)
                            .font(.jeevesTitle)
                            .foregroundStyle(.primary)
                            .multilineTextAlignment(.leading)
                            .lineLimit(3)
                        Text(card.summary)
                            .font(.jeevesBody)
                            .foregroundStyle(.secondary)
                            .lineLimit(3)
                        Text(card.why)
                            .font(.jeevesCaption)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }
                    Spacer(minLength: 0)
                }
                .padding(18)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.plain)

            if let onSecondaryTap {
                Divider()
                    .overlay(Color.primary.opacity(0.08))
                    .padding(.horizontal, 18)
                HStack {
                    Spacer()
                    Button(action: onSecondaryTap) {
                        HStack(spacing: 6) {
                            Image(systemName: secondaryIcon)
                            Text(secondaryLabel)
                        }
                        .font(.jeevesMono.weight(.semibold))
                        .foregroundStyle(card.tint)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 12)
                .padding(.bottom, 8)
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color(.secondarySystemBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(card.tint.opacity(0.14), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.04), radius: 14, x: 0, y: 8)
    }

    private var secondaryLabel: String {
        switch card.secondaryAction {
        case .explanation:
            return "Explain"
        case .evidence:
            return "Knowledge graph"
        case nil:
            return ""
        }
    }

    private var secondaryIcon: String {
        switch card.secondaryAction {
        case .explanation:
            return "text.alignleft"
        case .evidence:
            return "point.3.connected.trianglepath.dotted"
        case nil:
            return "circle"
        }
    }
}

private struct BriefingEvidenceCard: View {
    let object: KnowledgeObject

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(object.title)
                    .font(.jeevesBody.weight(.semibold))
                    .foregroundStyle(.primary)
                Spacer()
                Text(object.kind.replacingOccurrences(of: "_", with: " "))
                    .font(.jeevesMonoSmall)
                    .foregroundStyle(.secondary)
            }
            Text(object.summary)
                .font(.jeevesCaption)
                .foregroundStyle(.secondary)
                .lineLimit(3)
        }
        .briefingPanel()
    }
}

// MARK: - Staggered Entrance Animation

private struct StaggeredAppear: ViewModifier {
    let delay: Double
    @State private var isVisible = false

    func body(content: Content) -> some View {
        content
            .opacity(isVisible ? 1 : 0)
            .offset(y: isVisible ? 0 : 14)
            .onAppear {
                withAnimation(.easeOut(duration: 0.4).delay(delay)) {
                    isVisible = true
                }
            }
    }
}

extension View {
    fileprivate func staggeredAppear(delay: Double) -> some View {
        modifier(StaggeredAppear(delay: delay))
    }
}

extension View {
    func briefingPanel() -> some View {
        self
            .padding(16)
            .background(Color(.secondarySystemBackground))
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(Color.primary.opacity(0.06), lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }
}
