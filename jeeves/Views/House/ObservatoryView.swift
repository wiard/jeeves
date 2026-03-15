import SwiftUI
import SwiftData

struct ObservatoryView: View {
    @Environment(GatewayManager.self) private var gateway
    @Query private var connections: [GatewayConnection]
    @StateObject private var model = ObservatorySurfaceModel()

    private let columns = [
        GridItem(.flexible(minimum: 160), spacing: 14),
        GridItem(.flexible(minimum: 160), spacing: 14)
    ]

    var body: some View {
        NavigationStack {
            ZStack {
                InstrumentBackdrop(
                    colors: [
                        Color(red: 0.95, green: 0.98, blue: 1.00),
                        Color(red: 0.94, green: 0.97, blue: 0.99),
                        Color(red: 0.98, green: 0.97, blue: 0.95)
                    ]
                )
                .ignoresSafeArea()

                content
            }
            .navigationTitle("Observatory")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.large)
            #endif
            .refreshable {
                await model.refresh(gateway: gateway, connection: connections.first)
            }
            .task {
                if model.snapshot == nil {
                    await model.refresh(gateway: gateway, connection: connections.first)
                }
            }
            .onChange(of: gateway.isConnected) {
                if gateway.isConnected {
                    Task {
                        await model.refresh(gateway: gateway, connection: connections.first)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        if model.isLoading && model.snapshot == nil {
            ProgressView("Observatory preparing…")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    header
                        .calmAppear()

                    IntelligencePhaseStrip(
                        currentStage: model.snapshot?.stagePhase ?? .safety,
                        summary: "The read model stays quiet and legible while governance and approval authority remain unchanged."
                    )
                    .calmAppear(delay: 0.05)

                    if let snapshot = model.snapshot {
                        LazyVGrid(columns: columns, alignment: .leading, spacing: 14) {
                            metricCard("Entropy", value: formatEntropy(snapshot.entropy), tint: .consentOrange)
                            metricCard("Residue strength", value: formatPercent(snapshot.residueStrength), tint: .jeevesMint)
                            metricCard("Discovery rate", value: formatRate(snapshot.discoveryRate), tint: .jeevesSky)
                            metricCard("Approval rate", value: formatPercent(snapshot.approvalRate), tint: .consentGreen)
                            metricCard("Recent patterns", value: "\(snapshot.patternCount)", tint: .jeevesGold)
                            metricCard("Current stage", value: snapshot.stage, tint: snapshot.stagePhase.accent)
                        }
                        .calmAppear(delay: 0.1)

                        interpretationPanel(snapshot)
                            .calmAppear(delay: 0.15)

                        if let runtime = model.signalsRuntime,
                           let gravity = runtime.gravitySummary,
                           gravity.activeEdgeCount > 0 {
                            gravityPanel(runtime: runtime, gravity: gravity)
                                .calmAppear(delay: 0.16)
                        }

                        HumanMeaningPanel(
                            title: "What the field means now",
                            accent: snapshot.stagePhase.accent,
                            explanation: HumanMeaningBuilder.observatory(
                                intelligence: snapshot,
                                entropy: model.entropySnapshot,
                                residueField: model.residueField,
                                recentKnowledgeCount: model.recentKnowledgeCount,
                                stream: model.streamFeed,
                                radar: model.radarStatus
                            )
                        )
                        .calmAppear(delay: 0.17)

                        if let operatorMemory = model.operatorMemory {
                            OperatorMemoryPanel(
                                title: "What the system remembers",
                                accent: .jeevesMint,
                                memory: operatorMemory
                            )
                            .calmAppear(delay: 0.19)
                        }

                        if let collectiveMemory = model.collectiveMemory {
                            CollectiveMemoryPanel(
                                title: "What governed interaction keeps teaching the system",
                                accent: .jeevesGold,
                                memory: collectiveMemory
                            )
                            .calmAppear(delay: 0.2)
                        }

                        if let gapFinder = model.gapFinder {
                            GapFinderPanel(
                                eyebrow: "Discovery Section",
                                title: "Top matches and top gaps",
                                subtitle: "Different domains are compared through method, cause, effect, and entropy signals so the operator can inspect bridge opportunities without changing governance.",
                                accent: .jeevesSky,
                                snapshot: gapFinder
                            )
                            .calmAppear(delay: 0.205)
                        }

                        if let civilization = model.civilization {
                            CivilizationPanel(
                                title: "What has become durable enough to stay visible",
                                accent: .jeevesSky,
                                snapshot: civilization
                            )
                            .calmAppear(delay: 0.21)
                        }

                        if let planetary = model.planetary {
                            PlanetaryPanel(
                                title: "What is escaping the local frame",
                                accent: .jeevesMint,
                                snapshot: planetary
                            )
                            .calmAppear(delay: 0.215)
                        }

                        if let cosmic = model.cosmic {
                            CosmicPanel(
                                title: "What may still matter when the moment has passed",
                                accent: .jeevesGold,
                                snapshot: cosmic
                            )
                            .calmAppear(delay: 0.217)
                        }

                        if let entropySnapshot = model.entropySnapshot {
                            entropyKnowledgePanel(
                                intelligence: snapshot,
                                entropy: entropySnapshot,
                                recentKnowledgeCount: model.recentKnowledgeCount
                            )
                            .calmAppear(delay: 0.18)
                        }

                        if let residueField = model.residueField {
                            residueFieldPanel(residueField)
                                .calmAppear(delay: 0.22)
                        }

                        drilldownPanel
                            .calmAppear(delay: 0.27)
                    } else {
                        unavailablePanel
                            .calmAppear(delay: 0.1)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
            }
        }
    }

    private var header: some View {
        InstrumentRoleHeader(
            eyebrow: "Observatory",
            title: "Governed intelligence, made calm",
            summary: "A quiet read-model of how the runtime is sensing, shaping, and stabilizing knowledge. Nothing here changes authority: signals may rise, but approval still belongs to the operator.",
            accent: .jeevesSky,
            metrics: [
                InstrumentRoleMetric(label: "Loop", value: "Signal to knowledge"),
                InstrumentRoleMetric(label: "Mode", value: "Read only"),
                InstrumentRoleMetric(label: "Authority", value: "Human approval")
            ]
        )
    }

    private func interpretationPanel(_ snapshot: SystemIntelligenceSnapshot) -> some View {
        InstrumentSectionPanel(
            eyebrow: "Reading",
            title: snapshot.stage,
            subtitle: interpretation(for: snapshot),
            accent: snapshot.stagePhase.accent,
            metric: "Updated now"
        ) {
            VStack(alignment: .leading, spacing: 12) {
                Text(stageExplanation(for: snapshot.stagePhase))
                    .font(.jeevesBody)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                if let research = model.signalsRuntime?.researchLane, research.signalCount24h > 0 {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("RESEARCH LANE")
                            .font(.jeevesMonoSmall)
                            .foregroundStyle(Color.jeevesSky)

                        Text(researchLaneSummaryLine(research))
                            .font(.jeevesCaption)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)

                        Text(researchLaneSourceLine(research))
                            .font(.jeevesCaption)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(Color.jeevesSky.opacity(0.08))
                    )
                }
            }
        }
    }

    private var drilldownPanel: some View {
        InstrumentSectionPanel(
            eyebrow: "Drill Down",
            title: "Open the deeper observatory layers",
            subtitle: "The first surface stays compact. When you want the discovery field itself, the CLASHD27 radar remains available as a deeper read-only view.",
            accent: .jeevesGold
        ) {
            NavigationLink {
                CLASHD27RadarView()
            } label: {
                drilldownRow(
                    title: "CLASHD27 Discovery Detail",
                    detail: "Open the spatial radar view for signal pressure, hot zones, and cube-level discovery detail."
                )
            }
            .buttonStyle(.plain)

            NavigationLink {
                KnowledgeBrowserView()
            } label: {
                drilldownRow(
                    title: "Knowledge Browser",
                    detail: "Inspect the resulting knowledge objects, residue-linked evidence, and operator-facing memory."
                )
            }
            .buttonStyle(.plain)
        }
    }

    private func residueFieldPanel(_ field: SystemResidueFieldSnapshot) -> some View {
        InstrumentSectionPanel(
            eyebrow: "Residue Field",
            title: "Where approved interactions are accumulating",
            subtitle: "Residue is structured evidence of governed interaction. This field stays read-only and operator-legible while it shows where meaning is starting to hold shape.",
            accent: .jeevesMint,
            metric: "Field \(formatPercent(field.fieldStrength))"
        ) {
            VStack(alignment: .leading, spacing: 14) {
                Text("The strongest regions and signal families indicate where the governed loop is producing the clearest memory.")
                    .font(.jeevesBody)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                LazyVGrid(columns: columns, alignment: .leading, spacing: 14) {
                    fieldSectionCard(
                        title: "Strongest regions",
                        subtitle: "Residue, approval density, and live signal volume in one ranked field view.",
                        tint: .jeevesSky
                    ) {
                        let regions = Array(field.regions.prefix(4))
                        if regions.isEmpty {
                            Text("No regional residue is visible yet.")
                                .font(.jeevesCaption)
                                .foregroundStyle(.secondary)
                        } else {
                            VStack(alignment: .leading, spacing: 10) {
                                ForEach(Array(regions.enumerated()), id: \.element.id) { index, region in
                                    fieldRankRow(
                                        rank: index + 1,
                                        title: region.region,
                                        detail: "\(formatPercent(region.approvalDensity)) approvals · \(region.signalVolume) live signals · \(region.patternCount) patterns",
                                        strength: region.residueStrength,
                                        tint: .jeevesSky
                                    )
                                }
                            }
                        }
                    }

                    fieldSectionCard(
                        title: "Strongest signal families",
                        subtitle: "Recurring families where governed interpretation is starting to stick.",
                        tint: .jeevesGold
                    ) {
                        let families = Array(field.signalTypes.prefix(4))
                        if families.isEmpty {
                            Text("No signal families have accumulated field shape yet.")
                                .font(.jeevesCaption)
                                .foregroundStyle(.secondary)
                        } else {
                            VStack(alignment: .leading, spacing: 10) {
                                ForEach(Array(families.enumerated()), id: \.element.id) { index, family in
                                    fieldRankRow(
                                        rank: index + 1,
                                        title: humanizeSignalType(family.signalType),
                                        detail: "\(formatPercent(family.approvalDensity)) approvals · \(family.patternCount) patterns",
                                        strength: family.residueStrength,
                                        tint: .jeevesGold
                                    )
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    private func gravityPanel(
        runtime: SignalsRuntimeSnapshot,
        gravity: DiscoveryGravitySummary
    ) -> some View {
        InstrumentSectionPanel(
            eyebrow: "Discovery Gravity",
            title: "What is beginning to pull together",
            subtitle: "Gravity links signals, residue, and discovery candidates when they share semantic, temporal, regional, or evidential affinity. It strengthens discovery only; it does not create authority.",
            accent: .jeevesSky,
            metric: "\(gravity.activeEdgeCount) active links"
        ) {
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 10) {
                    gravityMetricCard(label: "Cross-domain pull", value: "\(gravity.crossDomainPullCount)")
                    gravityMetricCard(label: "Trend", value: gravity.persistenceTrend.capitalized)
                    gravityMetricCard(label: "Anomaly magnet", value: formatPercent(gravity.anomalyMagnetScore))
                }

                if let strongest = gravity.strongestEdge {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("STRONGEST PULL")
                            .font(.jeevesMonoSmall)
                            .foregroundStyle(Color.jeevesSky)

                        Text(strongest.explanation)
                            .font(.jeevesCaption)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)

                        Text("Score \(formatEntropy(strongest.score)) · \(strongest.crossDomain ? "Cross-domain" : "Within-domain")")
                            .font(.jeevesCaption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(Color.jeevesSky.opacity(0.08))
                    )
                }

                ForEach(runtime.gravityEdges.prefix(4)) { edge in
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(alignment: .firstTextBaseline) {
                            Text(edge.explanation)
                                .font(.jeevesCaption.weight(.semibold))
                                .foregroundStyle(Color.jeevesInk)
                                .fixedSize(horizontal: false, vertical: true)

                            Spacer(minLength: 8)

                            Text(formatEntropy(edge.score))
                                .font(.jeevesMonoSmall)
                                .foregroundStyle(Color.jeevesSky)
                        }

                        Text(gravityFactorLine(edge))
                            .font(.jeevesCaption)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)

                        if !edge.domainTags.isEmpty {
                            Text("Domains: \(edge.domainTags.prefix(3).map(humanizeResearchDomain).joined(separator: ", "))")
                                .font(.jeevesCaption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(Color(.secondarySystemBackground))
                    )
                }
            }
        }
    }

    private func entropyKnowledgePanel(
        intelligence: SystemIntelligenceSnapshot,
        entropy: SystemEntropySnapshot,
        recentKnowledgeCount: Int
    ) -> some View {
        let currentStep = transformationCurrentStep(
            intelligence: intelligence,
            entropy: entropy,
            recentKnowledgeCount: recentKnowledgeCount
        )

        return InstrumentSectionPanel(
            eyebrow: "Entropy To Knowledge",
            title: "Order forming from governed uncertainty",
            subtitle: "This read-only section shows how noisy signals are being structured into operator-visible knowledge without changing who decides.",
            accent: .consentOrange,
            metric: "Trend \(entropy.trend.capitalized)"
        ) {
            VStack(alignment: .leading, spacing: 14) {
                LazyVGrid(columns: columns, alignment: .leading, spacing: 14) {
                    metricCard("Entropy score", value: formatEntropy(entropy.entropyScore), tint: .consentOrange)
                    metricCard("Entropy trend", value: entropy.trend.capitalized, tint: trendTint(entropy.trend))
                    metricCard("Recent proposals", value: "\(entropy.proposalCount)", tint: .jeevesSky)
                    metricCard("Approval rate", value: formatPercent(intelligence.approvalRate), tint: .consentGreen)
                    metricCard("Residue strength", value: formatPercent(intelligence.residueStrength), tint: .jeevesMint)
                    metricCard("Knowledge objects", value: "\(recentKnowledgeCount)", tint: .jeevesGold)
                }

                Text("Noise becomes signal, then waits for proposal, approval, residue, and knowledge. The system may interpret more clearly over time, but it still cannot act outside governance.")
                    .font(.jeevesBody)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(Array(transformationSteps.enumerated()), id: \.element.id) { index, step in
                            transformationStepCard(
                                step: step,
                                state: transformationState(for: step.id, current: currentStep)
                            )

                            if index < transformationSteps.count - 1 {
                                Image(systemName: "arrow.right")
                                    .font(.jeevesCaption.weight(.semibold))
                                    .foregroundStyle(Color.jeevesSky.opacity(0.7))
                            }
                        }
                    }
                    .padding(.vertical, 2)
                }

                Text(transformationExplanation(for: currentStep, entropy: entropy, recentKnowledgeCount: recentKnowledgeCount))
                    .font(.jeevesCaption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var unavailablePanel: some View {
        InstrumentSectionPanel(
            eyebrow: "Observatory",
            title: "The intelligence layer is not available yet",
            subtitle: model.errorText ?? "Connect Jeeves to the governed kernel to load the Observatory read model.",
            accent: .consentOrange
        ) {
            Text("No operator authority has changed. This screen is waiting for the read-only aggregate endpoint.")
                .font(.jeevesBody)
                .foregroundStyle(.secondary)
        }
    }

    private func metricCard(_ title: String, value: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title.uppercased())
                .font(.jeevesMonoSmall)
                .foregroundStyle(.secondary)

            Text(value)
                .font(.jeevesLargeTitle)
                .foregroundStyle(tint)

            RoundedRectangle(cornerRadius: 999, style: .continuous)
                .fill(tint.opacity(0.16))
                .frame(height: 6)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .briefingPanel()
    }

    private func fieldSectionCard<Content: View>(
        title: String,
        subtitle: String,
        tint: Color,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title.uppercased())
                .font(.jeevesMonoSmall)
                .foregroundStyle(tint)

            Text(subtitle)
                .font(.jeevesCaption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .briefingPanel()
    }

    private func transformationStepCard(
        step: TransformationStep,
        state: TransformationStepState
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(step.title.uppercased())
                .font(.jeevesMonoSmall)
                .foregroundStyle(state.tint)

            Text(step.subtitle)
                .font(.jeevesCaption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            Text(state.label)
                .font(.jeevesCaption.weight(.semibold))
                .foregroundStyle(state.tint)
        }
        .frame(width: 126, alignment: .leading)
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(state.background)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(state.stroke, lineWidth: 1)
        )
    }

    private func fieldRankRow(
        rank: Int,
        title: String,
        detail: String,
        strength: Double,
        tint: Color
    ) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text("\(rank)")
                .font(.jeevesMonoSmall.weight(.semibold))
                .foregroundStyle(tint)
                .frame(width: 26, height: 26)
                .background(tint.opacity(0.12))
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 5) {
                Text(title)
                    .font(.jeevesBody.weight(.semibold))
                    .foregroundStyle(.primary)

                Text(detail)
                    .font(.jeevesCaption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                RoundedRectangle(cornerRadius: 999, style: .continuous)
                    .fill(tint.opacity(0.18))
                    .overlay(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 999, style: .continuous)
                            .fill(tint)
                            .frame(width: max(18, strength * 120), height: 6)
                    }
                    .frame(width: 120, height: 6)
            }

            Spacer(minLength: 8)

            Text(formatPercent(strength))
                .font(.jeevesMonoSmall)
                .foregroundStyle(tint)
        }
    }

    private func drilldownRow(title: String, detail: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "arrow.up.forward.square")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Color.jeevesSky)
                .frame(width: 34, height: 34)
                .background(Color.jeevesSky.opacity(0.10))
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.jeevesBody.weight(.semibold))
                    .foregroundStyle(.primary)

                Text(detail)
                    .font(.jeevesCaption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 8)

            Image(systemName: "chevron.right")
                .font(.jeevesCaption.weight(.semibold))
                .foregroundStyle(.secondary)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color(.secondarySystemBackground))
        )
    }

    private func interpretation(for snapshot: SystemIntelligenceSnapshot) -> String {
        switch snapshot.stagePhase {
        case .safety:
            return "Discovery pressure is present, but the system is still prioritizing bounded risk and legibility before pushing work further into the governed loop."
        case .define:
            return "Signals are cohering into something actionable. The field is no longer noisy, but it still needs operator framing before it becomes stable knowledge."
        case .investigate:
            return "Recent approvals and residue have started reducing uncertainty. The system is learning, but only through governed decisions and append-only memory."
        }
    }

    private func stageExplanation(for stage: IntelligencePhaseStage) -> String {
        switch stage {
        case .safety:
            return "Safety means the runtime is still filtering raw pressure into something trustworthy. The aim here is not speed, but bounded interpretation."
        case .define:
            return "Define means the runtime has enough structure to form better proposals. The operator can see where patterns are taking shape without surrendering authority."
        case .investigate:
            return "Investigate means residue and approval have already started converting events into structure. The system is becoming more legible because governed decisions left memory behind."
        }
    }

    private func formatEntropy(_ value: Double) -> String {
        String(format: "%.3f", value)
    }

    private func formatPercent(_ value: Double) -> String {
        "\(Int((value * 100).rounded()))%"
    }

    private func formatRate(_ value: Double) -> String {
        String(format: "%.1f / hr", value)
    }

    private func humanizeSignalType(_ value: String) -> String {
        value
            .split(separator: "_")
            .map { $0.capitalized }
            .joined(separator: " ")
    }

    private func humanizeResearchDomain(_ value: String) -> String {
        value
            .split(separator: " ")
            .map { $0.capitalized }
            .joined(separator: " ")
    }

    private func researchLaneSummaryLine(_ research: ResearchLaneSummary) -> String {
        let domains = research.topDomains
            .prefix(3)
            .map(humanizeResearchDomain)
            .joined(separator: ", ")
        let domainLine = domains.isEmpty ? "Hot research domains are still forming." : "Hot domains: \(domains)."
        return "\(research.signalCount24h) research signal\(research.signalCount24h == 1 ? "" : "s") surfaced in the last 24h, with \(research.activitySpikeCount) elevated candidate\(research.activitySpikeCount == 1 ? "" : "s"). \(domainLine)"
    }

    private func researchLaneSourceLine(_ research: ResearchLaneSummary) -> String {
        let sources = research.sourceBreakdown
            .prefix(3)
            .map { "\($0.source.capitalized) \($0.signalCount)" }
            .joined(separator: " · ")
        return sources.isEmpty
            ? "OpenAlex, PubMed, and Europe PMC remain read-only research sensors."
            : "Source mix: \(sources). Signals stay read-only until a human approves a proposal."
    }

    private func gravityFactorLine(_ edge: DiscoveryGravityEdge) -> String {
        "Semantic \(formatPercent(edge.factors.semantic)) · Temporal \(formatPercent(edge.factors.temporal)) · Evidence \(formatPercent(edge.factors.evidence)) · Residue \(formatPercent(edge.factors.residue))"
    }

    private func gravityMetricCard(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(label.uppercased())
                .font(.jeevesMonoSmall)
                .foregroundStyle(Color.jeevesMutedText)
            Text(value)
                .font(.system(size: 17, weight: .semibold, design: .rounded))
                .foregroundStyle(Color.jeevesInk)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.jeevesCloud.opacity(0.72))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.jeevesLine.opacity(0.56), lineWidth: 1)
        )
    }

    private func trendTint(_ trend: String) -> Color {
        switch trend.lowercased() {
        case "improving":
            return .consentGreen
        case "worsening":
            return .consentOrange
        default:
            return .jeevesSky
        }
    }

    private func transformationState(for step: TransformationStepID, current: TransformationStepID) -> TransformationStepState {
        let currentIndex = transformationSteps.firstIndex(where: { $0.id == current }) ?? 0
        let stepIndex = transformationSteps.firstIndex(where: { $0.id == step }) ?? 0

        if stepIndex < currentIndex {
            return TransformationStepState(
                label: "Proven",
                tint: .consentGreen,
                background: Color.consentGreen.opacity(0.10),
                stroke: Color.consentGreen.opacity(0.24)
            )
        }

        if stepIndex == currentIndex {
            return TransformationStepState(
                label: "Current",
                tint: .jeevesSky,
                background: Color.jeevesSky.opacity(0.12),
                stroke: Color.jeevesSky.opacity(0.24)
            )
        }

        return TransformationStepState(
            label: "Pending",
            tint: .secondary,
            background: Color(.secondarySystemBackground),
            stroke: Color.jeevesLine.opacity(0.42)
        )
    }

    private func transformationCurrentStep(
        intelligence: SystemIntelligenceSnapshot,
        entropy: SystemEntropySnapshot,
        recentKnowledgeCount: Int
    ) -> TransformationStepID {
        if intelligence.stagePhase == .investigate && recentKnowledgeCount > 0 {
            return .knowledge
        }
        if intelligence.stagePhase == .investigate && intelligence.residueStrength > 0 {
            return .residue
        }
        if intelligence.approvalRate > 0 {
            return .approval
        }
        if entropy.proposalCount > 0 {
            return .proposal
        }
        if intelligence.discoveryRate > 0 || entropy.signalVolume > 0 {
            return .signal
        }
        return .noise
    }

    private func transformationExplanation(
        for step: TransformationStepID,
        entropy: SystemEntropySnapshot,
        recentKnowledgeCount: Int
    ) -> String {
        switch step {
        case .noise:
            return "The runtime is mostly reading unresolved pressure. Entropy is visible, but structure has not reached a stable signal path yet."
        case .signal:
            return "Signals are visible and bounded. The system is sensing order, but it has not yet formed enough governed shape to move further down the line."
        case .proposal:
            return "Proposal count is now visible, which means the system has started structuring uncertainty into operator-reviewable intent."
        case .approval:
            return "Approvals are now shaping the field. Human decisions remain the legitimacy boundary that turns interpretation into accountable progress."
        case .residue:
            return "Residue strength is active, so governed decisions are leaving append-only memory that can improve future interpretation."
        case .knowledge:
            return "\(recentKnowledgeCount) recent knowledge object\(recentKnowledgeCount == 1 ? "" : "s") visible. Entropy reduction is now landing as operator-visible structure."
        }
    }

    private var transformationSteps: [TransformationStep] {
        [
            TransformationStep(id: .noise, title: "Noise", subtitle: "Unresolved pressure"),
            TransformationStep(id: .signal, title: "Signal", subtitle: "Detected and bounded"),
            TransformationStep(id: .proposal, title: "Proposal", subtitle: "Structured for review"),
            TransformationStep(id: .approval, title: "Approval", subtitle: "Human decision"),
            TransformationStep(id: .residue, title: "Residue", subtitle: "Append-only memory"),
            TransformationStep(id: .knowledge, title: "Knowledge", subtitle: "Visible structure")
        ]
    }
}

private enum TransformationStepID: String {
    case noise
    case signal
    case proposal
    case approval
    case residue
    case knowledge
}

private struct TransformationStep: Identifiable {
    let id: TransformationStepID
    let title: String
    let subtitle: String
}

private struct TransformationStepState {
    let label: String
    let tint: Color
    let background: Color
    let stroke: Color
}

@MainActor
private final class ObservatorySurfaceModel: ObservableObject {
    @Published var snapshot: SystemIntelligenceSnapshot?
    @Published var entropySnapshot: SystemEntropySnapshot?
    @Published var signalsRuntime: SignalsRuntimeSnapshot?
    @Published var cosmic: SystemCosmicSnapshot?
    @Published var planetary: SystemPlanetarySnapshot?
    @Published var civilization: SystemCivilizationSnapshot?
    @Published var collectiveMemory: SystemCollectiveMemorySnapshot?
    @Published var operatorMemory: SystemOperatorMemorySnapshot?
    @Published var residueField: SystemResidueFieldSnapshot?
    @Published var gapFinder: SystemGapFinderSnapshot?
    @Published var streamFeed: ObservatoryStreamFeed?
    @Published var radarStatus: RadarStatusSnapshot?
    @Published var recentKnowledgeCount = 0
    @Published var isLoading = false
    @Published var errorText: String?

    func refresh(gateway: GatewayManager, connection: GatewayConnection?) async {
        isLoading = true
        errorText = nil

        if gateway.useMock || gateway.host.lowercased() == "mock" {
            snapshot = .demo
            entropySnapshot = .demo
            signalsRuntime = SignalsRuntimeSnapshot(
                started: true,
                startedAtIso: nil,
                lastRunAtIso: nil,
                runCount: 1,
                totalSignals: 12,
                activeSourceCount: 4,
                lastError: nil,
                lastSignals: [],
                lastChallenges: [],
                emergenceClusters: [],
                gravityHotspots: [],
                discoveryCandidates: [],
                researchLane: ResearchLaneSummary(
                    signalCount24h: 6,
                    sourceCount: 3,
                    highConfidenceCount: 4,
                    activitySpikeCount: 2,
                    topDomains: ["artificial intelligence", "biology", "governance"],
                    topCategories: ["research-work"],
                    sourceBreakdown: [
                        ResearchLaneSourceSummary(source: "openalex", signalCount: 2),
                        ResearchLaneSourceSummary(source: "pubmed", signalCount: 2),
                        ResearchLaneSourceSummary(source: "europepmc", signalCount: 2)
                    ],
                    latestDetectedAtIso: "now"
                ),
                gravityEdges: [
                    DiscoveryGravityEdge(
                        edgeId: "demo-edge-1",
                        fromId: "demo-signal-1",
                        toId: "demo-residue-1",
                        fromType: "signal",
                        toType: "residue",
                        score: 0.82,
                        factors: DiscoveryGravityFactors(
                            semantic: 0.84,
                            temporal: 0.73,
                            regional: 0.55,
                            evidence: 0.76,
                            humanAttention: 0,
                            residue: 0.88
                        ),
                        timestamp: "now",
                        active: true,
                        domainTags: ["ai", "biology"],
                        region: "global",
                        crossDomain: true,
                        explanation: "signal links with residue through shared domains, evidence, and cross-domain pull.",
                        recurrenceCount: 2
                    )
                ],
                gravitySummary: DiscoveryGravitySummary(
                    activeEdgeCount: 4,
                    crossDomainPullCount: 2,
                    strongestEdge: DiscoveryGravityStrongestEdge(
                        edgeId: "demo-edge-1",
                        score: 0.82,
                        explanation: "signal links with residue through shared domains, evidence, and cross-domain pull.",
                        crossDomain: true
                    ),
                    persistenceTrend: "rising",
                    anomalyMagnetScore: 0.74
                )
            )
            cosmic = .demo
            planetary = .demo
            civilization = .demo
            collectiveMemory = .demo
            operatorMemory = .demo
            residueField = .demo
            gapFinder = .demo
            streamFeed = nil
            radarStatus = nil
            recentKnowledgeCount = 8
            isLoading = false
            return
        }

        let endpoint = await gateway.resolveEndpoint(connection: connection)
        guard let builder = endpoint.makeRequestBuilder() else {
            snapshot = nil
            entropySnapshot = nil
            signalsRuntime = nil
            cosmic = nil
            planetary = nil
            civilization = nil
            collectiveMemory = nil
            operatorMemory = nil
            residueField = nil
            gapFinder = nil
            streamFeed = nil
            radarStatus = nil
            recentKnowledgeCount = 0
            errorText = "Missing token"
            isLoading = false
            return
        }

        do {
            async let intelligenceTask = ObservatoryAPI.systemIntelligence(builder: builder)
            async let entropyTask = try? ObservatoryAPI.systemEntropy(builder: builder)
            async let signalsRuntimeTask = try? ObservatoryAPI.signalsRuntime(builder: builder)
            async let cosmicTask = try? ObservatoryAPI.systemCosmic(builder: builder)
            async let planetaryTask = try? ObservatoryAPI.systemPlanetary(builder: builder)
            async let civilizationTask = try? ObservatoryAPI.systemCivilization(builder: builder)
            async let collectiveMemoryTask = try? ObservatoryAPI.systemCollectiveMemory(builder: builder)
            async let operatorMemoryTask = try? ObservatoryAPI.systemOperatorMemory(builder: builder)
            async let residueFieldTask = try? ObservatoryAPI.systemResidueField(builder: builder)
            async let gapFinderTask = try? ObservatoryAPI.systemGapFinder(builder: builder)
            async let streamTask = try? ObservatoryAPI.observatoryStream(builder: builder, limit: 20)
            async let radarTask = try? ObservatoryAPI.radarStatus(builder: builder)
            async let knowledgeTask = try? ObservatoryAPI.recentKnowledgeObjects(builder: builder, limit: 12)

            snapshot = try await intelligenceTask
            entropySnapshot = await entropyTask
            signalsRuntime = await signalsRuntimeTask
            cosmic = await cosmicTask
            planetary = await planetaryTask
            civilization = await civilizationTask
            collectiveMemory = await collectiveMemoryTask
            operatorMemory = await operatorMemoryTask
            residueField = await residueFieldTask
            gapFinder = await gapFinderTask
            streamFeed = await streamTask
            radarStatus = await radarTask
            recentKnowledgeCount = (await knowledgeTask)?.count ?? 0
        } catch {
            snapshot = nil
            entropySnapshot = nil
            signalsRuntime = nil
            cosmic = nil
            planetary = nil
            civilization = nil
            collectiveMemory = nil
            operatorMemory = nil
            residueField = nil
            gapFinder = nil
            streamFeed = nil
            radarStatus = nil
            recentKnowledgeCount = 0
            errorText = "The intelligence read model is unavailable."
        }

        isLoading = false
    }
}
