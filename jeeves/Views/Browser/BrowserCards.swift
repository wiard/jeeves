import SwiftUI

// MARK: - Featured Card (large, horizontal scroll)

struct BrowserFeaturedCard: View {
    let card: BrowserCard
    let isDeploying: Bool
    let onInspect: () -> Void
    let onDeploy: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Spacer()
                uncertaintyBadge(card.uncertaintyState)
                certificationBadge(card.bestConfiguration.certificationLevel)
            }

            Text(card.title)
                .font(.jeevesTitle.weight(.semibold))
                .foregroundStyle(.white)
                .lineLimit(2)

            Text(card.intentionPath)
                .font(.jeevesMono)
                .foregroundStyle(.secondary)
                .lineLimit(1)

            Text(card.shortDescription)
                .font(.jeevesBody)
                .foregroundStyle(.secondary)
                .lineLimit(2)

            if let explanation = card.rankingExplanation ?? card.whyRecommended as String?, !explanation.isEmpty {
                Text(explanation)
                    .font(.jeevesCaption)
                    .italic()
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            HStack(spacing: 8) {
                statChip("score \(String(format: "%.2f", card.rankingScore))", tint: .cyan)
                statChip(card.benchmarkSummary, tint: .blue)
                statChip(card.bestConfiguration.model, tint: .secondary)
            }

            Text(card.deployReady ? "Ready for governed deployment." : "Awaiting certification envelope.")
                .font(.jeevesCaption2)
                .foregroundStyle(card.deployReady ? Color.consentGreen : .consentOrange)

            HStack(spacing: 8) {
                Button("Inspect") { onInspect() }
                    .buttonStyle(.bordered)

                Button("Propose Deployment") { onDeploy() }
                    .buttonStyle(.borderedProminent)
                    .tint(Color.consentGreen)
                    .disabled(isDeploying || !card.deployReady)

                if isDeploying {
                    ProgressView().controlSize(.small)
                }
            }
        }
        .browserPanel(padding: 14)
    }
}

// MARK: - Certified Card (compact, vertical list)

struct BrowserCertifiedCard: View {
    let card: BrowserCard
    let isBookmarked: Bool
    let onInspect: () -> Void
    let onDeploy: () -> Void
    let onBookmark: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                HStack(spacing: 6) {
                    Image(systemName: "checkmark.seal.fill")
                        .foregroundStyle(certificationColor(card.bestConfiguration.certificationLevel))
                        .font(.jeevesCaption)
                    Text(card.title)
                        .font(.jeevesHeadline)
                        .foregroundStyle(.white)
                        .lineLimit(1)
                }
                Spacer()
                certificationBadge(card.bestConfiguration.certificationLevel)
            }

            Text(card.intentionPath)
                .font(.jeevesMono)
                .foregroundStyle(.secondary)
                .lineLimit(1)

            HStack(spacing: 12) {
                Text("Benchmark: \(String(format: "%.0f", card.bestConfiguration.benchmarkScore * 100))/100")
                    .font(.jeevesCaption)
                    .foregroundStyle(.secondary)
                if let cert = card.certificateReference {
                    Text("Certificate: \(cert)")
                        .font(.jeevesCaption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            if let explanation = card.rankingExplanation {
                Text(explanation)
                    .font(.jeevesCaption2)
                    .italic()
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            HStack(spacing: 8) {
                Button("Inspect") { onInspect() }
                    .buttonStyle(.bordered)

                Button("Propose Deployment") { onDeploy() }
                    .buttonStyle(.borderedProminent)
                    .tint(Color.consentGreen)
                    .disabled(!card.deployReady)

                Spacer()

                Button {
                    onBookmark()
                } label: {
                    Image(systemName: isBookmarked ? "bookmark.fill" : "bookmark")
                        .foregroundStyle(isBookmarked ? Color.jeevesGold : Color.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .browserPanel(padding: 12)
        .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .onTapGesture { onInspect() }
    }
}

// MARK: - Emerging Card (distinct visual)

struct BrowserEmergingCard: View {
    let intention: EmergingIntentionProfile
    let isWatched: Bool
    let onExplore: () -> Void
    let onWatch: () -> Void

    var body: some View {
        Button(action: onExplore) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .firstTextBaseline) {
                    HStack(spacing: 6) {
                        Image(systemName: "circle")
                            .foregroundStyle(Color.consentOrange)
                            .font(.jeevesCaption2)
                        Text(intention.title)
                            .font(.jeevesHeadline)
                            .foregroundStyle(.white)
                            .lineLimit(2)
                    }
                    Spacer()
                    emergingStateBadge(intention.state)
                }

                Text("\(intention.domain) / \(intention.subdomain)")
                    .font(.jeevesMono)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                Text(intention.description)
                    .font(.jeevesCaption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)

                HStack(spacing: 12) {
                    Text("Confidence: \(String(format: "%.0f", intention.confidenceScore * 100))%")
                        .font(.jeevesCaption)
                        .foregroundStyle(.cyan)

                    if !intention.sourceClusters.isEmpty {
                        Text("Sources: \(intention.sourceClusters.joined(separator: ", "))")
                            .font(.jeevesCaption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }

                Text(intention.uncertaintyNarrative)
                    .font(.jeevesCaption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)

                HStack(spacing: 8) {
                    Button("Explore") { onExplore() }
                        .buttonStyle(.bordered)

                    Button {
                        onWatch()
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: isWatched ? "eye.fill" : "eye")
                            Text(isWatched ? "Watching" : "Watch")
                        }
                    }
                    .buttonStyle(.bordered)
                    .tint(isWatched ? Color.jeevesGold : Color.secondary)
                }
            }
            .browserPanel(padding: 12)
        }
        .buttonStyle(.plain)
    }

    private func emergingStateBadge(_ state: IntentionCatalogState) -> some View {
        let (label, tint): (String, Color) = {
            switch state {
            case .promoted: return ("PROMOTED", .consentGreen)
            case .certified: return ("CERTIFIED", .cyan)
            case .emerging: return ("EMERGING", .consentOrange)
            }
        }()
        return Text(label)
            .font(.jeevesCaption2.weight(.semibold))
            .foregroundStyle(tint)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(tint.opacity(0.16))
            .clipShape(Capsule())
    }
}

// MARK: - Category Tile

struct BrowserCategoryTile: View {
    let category: BrowserViewModel.BrowserDomain
    let certifiedCount: Int
    let emergingCount: Int
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 8) {
                Image(systemName: category.icon)
                    .font(.jeevesTitle)
                    .foregroundStyle(isSelected ? .white : .cyan)

                Text(category.title)
                    .font(.jeevesCaption.weight(.semibold))
                    .foregroundStyle(.white)
                    .lineLimit(1)

                VStack(alignment: .leading, spacing: 2) {
                    Text("\(certifiedCount) certified")
                        .font(.jeevesCaption2)
                        .foregroundStyle(Color.consentGreen)
                    Text("\(emergingCount) emerging")
                        .font(.jeevesCaption2)
                        .foregroundStyle(Color.consentOrange)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
            .background(isSelected ? Color.cyan.opacity(0.18) : Color.white.opacity(0.04))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(isSelected ? Color.cyan.opacity(0.6) : Color.white.opacity(0.08), lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Lifecycle Timeline

struct LifecycleTimelineView: View {
    let steps: [LifecycleStep]

    struct LifecycleStep: Identifiable {
        let id = UUID()
        let title: String
        let detail: String
        let timestamp: String?
        let isComplete: Bool
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(steps.enumerated()), id: \.element.id) { index, step in
                HStack(alignment: .top, spacing: 12) {
                    VStack(spacing: 0) {
                        Circle()
                            .fill(step.isComplete ? Color.jeevesGold : Color.white.opacity(0.2))
                            .frame(width: 12, height: 12)
                            .overlay(
                                Circle()
                                    .stroke(step.isComplete ? Color.jeevesGold.opacity(0.5) : Color.white.opacity(0.1), lineWidth: 2)
                            )

                        if index < steps.count - 1 {
                            Rectangle()
                                .fill(step.isComplete ? Color.jeevesGold.opacity(0.4) : Color.white.opacity(0.1))
                                .frame(width: 2, height: 32)
                        }
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text(step.title)
                            .font(.jeevesCaption.weight(.semibold))
                            .foregroundStyle(step.isComplete ? .white : .secondary)

                        Text(step.detail)
                            .font(.jeevesCaption2)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)

                        if let ts = step.timestamp {
                            Text(ts)
                                .font(.jeevesCaption2)
                                .foregroundStyle(.secondary.opacity(0.7))
                        }
                    }
                    .padding(.bottom, index < steps.count - 1 ? 8 : 0)

                    Spacer()
                }
            }
        }
    }
}

// MARK: - Guidance Brief

struct BrowserGuidanceBriefView: View {
    let brief: BrowserGuidanceBrief

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Text("Jeeves Guidance")
                    .font(.jeevesHeadline)
                    .foregroundStyle(.white)
                Spacer()
                Text(brief.state.rawValue.uppercased())
                    .font(.jeevesCaption2.weight(.semibold))
                    .foregroundStyle(stateTint)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(stateTint.opacity(0.18))
                    .clipShape(Capsule())
            }

            guidanceSection(title: "WHAT SEEMS CLEAR", rows: brief.clear)
            guidanceSection(title: "WHAT IS UNCERTAIN", rows: brief.uncertain)
            guidanceSection(title: "BEST OPTIONS", rows: brief.options)
            guidanceSection(title: "WHY THESE APPEAR", rows: brief.why)
            guidanceSection(title: "WHAT SHOULD HAPPEN NEXT", rows: brief.next)
        }
        .browserPanel(padding: 12)
    }

    private var stateTint: Color {
        switch brief.state {
        case .confirmed: return .consentGreen
        case .strongCandidate: return .cyan
        case .exploratory: return .consentOrange
        case .unknown: return .secondary
        }
    }

    private func guidanceSection(title: String, rows: [String]) -> some View {
        Group {
            if !rows.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.jeevesCaption2.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.8))
                    ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                        Text(row)
                            .font(.jeevesCaption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }
}

// MARK: - Deployment Proposal Sheet

struct DeploymentProposalSheet: View {
    let request: DeployConfigurationRequest
    let isDeploying: Bool
    let error: String?
    let onSubmit: () -> Void
    let onCancel: () -> Void

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Configuration")
                            .font(.jeevesCaption2.weight(.semibold))
                            .foregroundStyle(.secondary)
                        Text(request.intentionTitle)
                            .font(.jeevesHeadline)
                            .foregroundStyle(.white)
                        if let cert = request.certificateId {
                            Text("Certificate: \(cert)")
                                .font(.jeevesMono)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .browserPanel(padding: 12)

                    VStack(alignment: .leading, spacing: 8) {
                        sectionTitle("Deployment Context")
                        metadataRow("Domain", request.domain)
                        metadataRow("Subdomain", request.subdomain)
                        metadataRow("Risk", request.riskProfile)
                        metadataRow("Model", request.model)
                        metadataRow("Certification", request.certificationLevel)
                    }
                    .browserPanel(padding: 12)

                    VStack(alignment: .leading, spacing: 8) {
                        sectionTitle("Benchmark")
                        metadataRow("Score", String(format: "%.2f", request.benchmarkScore))
                        metadataRow("Ranking", String(format: "%.2f", request.rankingScore))
                        if let contract = request.benchmarkContractId {
                            metadataRow("Contract", contract)
                        }
                    }
                    .browserPanel(padding: 12)

                    VStack(alignment: .leading, spacing: 6) {
                        Image(systemName: "info.circle")
                            .foregroundStyle(.cyan)
                        Text("This will create a proposal in the governance queue. You or another operator must approve it before the configuration becomes active.")
                            .font(.jeevesCaption)
                            .foregroundStyle(.secondary)
                    }
                    .browserPanel(padding: 12)

                    if let error {
                        Text(error)
                            .font(.jeevesCaption)
                            .foregroundStyle(Color.consentRed)
                            .browserPanel(padding: 10)
                    }

                    Button {
                        onSubmit()
                    } label: {
                        HStack {
                            if isDeploying {
                                ProgressView().controlSize(.small)
                            }
                            Text("Submit Proposal")
                                .font(.jeevesHeadline)
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(Color.consentGreen)
                    .disabled(isDeploying)
                    .controlSize(.large)
                }
                .padding()
            }
            .background(Color.houseDark)
            .navigationTitle("New Deployment Proposal")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { onCancel() }
                }
            }
        }
    }

    private func sectionTitle(_ title: String) -> some View {
        Text(title.uppercased())
            .font(.jeevesCaption2.weight(.semibold))
            .foregroundStyle(.secondary)
    }

    private func metadataRow(_ label: String, _ value: String) -> some View {
        HStack(alignment: .top) {
            Text(label)
                .font(.jeevesCaption)
                .foregroundStyle(.secondary)
                .frame(width: 100, alignment: .leading)
            Text(value)
                .font(.jeevesMono)
                .foregroundStyle(.white)
        }
    }
}

// MARK: - Shared Helpers

func uncertaintyBadge(_ state: BrowserUncertaintyState) -> some View {
    let tint: Color = {
        switch state {
        case .confirmed: return .consentGreen
        case .strongCandidate: return .cyan
        case .exploratory: return .consentOrange
        case .unknown: return .secondary
        }
    }()
    return Text(state.rawValue.uppercased())
        .font(.jeevesCaption2.weight(.semibold))
        .foregroundStyle(tint)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(tint.opacity(0.16))
        .clipShape(Capsule())
}

func certificationBadge(_ level: String) -> some View {
    let tint = certificationColor(level)
    return Text(level.uppercased())
        .font(.jeevesCaption2.weight(.semibold))
        .foregroundStyle(tint)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(tint.opacity(0.16))
        .clipShape(Capsule())
}

func certificationColor(_ level: String) -> Color {
    switch level.lowercased() {
    case "gold", "platinum": return .consentGreen
    case "silver": return .cyan
    case "bronze": return .consentOrange
    default: return .secondary
    }
}

func statChip(_ text: String, tint: Color) -> some View {
    Text(text)
        .font(.jeevesCaption2.weight(.medium))
        .foregroundStyle(tint)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(tint.opacity(0.14))
        .clipShape(Capsule())
}
