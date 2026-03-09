import SwiftUI

// MARK: - Configuration Detail (Certified)

struct ConfigurationDetailView: View {
    let card: BrowserCard
    let cachedConfig: AIConfigurationAtom?
    let isBookmarked: Bool
    let onDeploy: () -> Void
    let onBookmark: () -> Void
    @Environment(\.dismiss) private var dismiss

    private var config: AIConfigurationAtom {
        cachedConfig ?? card.bestConfiguration
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    headerSection
                    descriptionSection
                    intentionPathSection
                    capabilitiesSection
                    constraintsSection
                    benchmarkSection
                    certificateSection
                    deployReadinessSection
                    actionButtons
                }
                .padding()
            }
            .background(Color.houseDark)
            .navigationTitle(card.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        onBookmark()
                    } label: {
                        Image(systemName: isBookmarked ? "bookmark.fill" : "bookmark")
                    }
                }
            }
        }
    }

    private var headerSection: some View {
        HStack {
            HStack(spacing: 8) {
                Image(systemName: "checkmark.seal.fill")
                    .foregroundStyle(certificationColor(config.certificationLevel))
                Text("SafeClash Certified")
                    .font(.jeevesCaption.weight(.semibold))
                    .foregroundStyle(certificationColor(config.certificationLevel))
            }
            Spacer()
            uncertaintyBadge(card.uncertaintyState)
            certificationBadge(config.certificationLevel)
        }
        .browserPanel(padding: 10)
    }

    private var descriptionSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            detailSectionTitle("Description")
            Text(card.shortDescription)
                .font(.jeevesBody)
                .foregroundStyle(.white)
        }
        .browserPanel(padding: 12)
    }

    private var intentionPathSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            detailSectionTitle("Intention Path")
            Text(card.intentionPath)
                .font(.jeevesMono)
                .foregroundStyle(.cyan)
            metadataRow("Risk Profile", card.riskProfile)
        }
        .browserPanel(padding: 12)
    }

    private var capabilitiesSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            detailSectionTitle("Capabilities")
            if config.capabilities.isEmpty {
                Text("No capabilities listed.")
                    .font(.jeevesCaption)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(config.capabilities, id: \.self) { capability in
                    HStack(spacing: 6) {
                        Image(systemName: "circle.fill")
                            .font(.system(size: 4))
                            .foregroundStyle(.cyan)
                        Text(capability)
                            .font(.jeevesCaption)
                            .foregroundStyle(.white)
                    }
                }
            }
        }
        .browserPanel(padding: 12)
    }

    private var constraintsSection: some View {
        Group {
            if let constraints = card.constraintsSummary, !constraints.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    detailSectionTitle("Constraints")
                    Text(constraints)
                        .font(.jeevesCaption)
                        .foregroundStyle(.white)
                }
                .browserPanel(padding: 12)
            }
        }
    }

    private var benchmarkSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            detailSectionTitle("Benchmark Results")
            metadataRow("Score", String(format: "%.0f/100", config.benchmarkScore * 100))
            metadataRow("Ranking", String(format: "%.2f", card.rankingScore))
            if let contract = config.benchmarkContract {
                metadataRow("Contract", contract)
            }
        }
        .browserPanel(padding: 12)
    }

    private var certificateSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            detailSectionTitle("Certificate")
            if let cert = config.certificateId {
                metadataRow("Reference", cert)
            }
            metadataRow("Model", config.model)
            if let hash = config.runtimeEnvelopeHash {
                metadataRow("Runtime Hash", abbreviatedHash(hash))
            }
            if let prompt = config.promptArchitectureReference {
                metadataRow("Prompt Architecture", prompt)
            }
        }
        .browserPanel(padding: 12)
    }

    private var deployReadinessSection: some View {
        HStack(spacing: 8) {
            Image(systemName: card.deployReady ? "checkmark.circle.fill" : "clock")
                .foregroundStyle(card.deployReady ? Color.consentGreen : Color.consentOrange)
            Text(card.deployReady ? "Ready for governed deployment." : "Deploy readiness pending certification envelope.")
                .font(.jeevesCaption)
                .foregroundStyle(card.deployReady ? Color.consentGreen : Color.consentOrange)
        }
        .browserPanel(padding: 10)
    }

    private var actionButtons: some View {
        Button {
            onDeploy()
        } label: {
            Text("Propose Deployment")
                .font(.jeevesHeadline)
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
        .tint(Color.consentGreen)
        .controlSize(.large)
        .disabled(!card.deployReady)
    }

    private func detailSectionTitle(_ title: String) -> some View {
        Text(title.uppercased())
            .font(.caption2.weight(.semibold))
            .foregroundStyle(.secondary)
    }

    private func metadataRow(_ label: String, _ value: String) -> some View {
        HStack(alignment: .top) {
            Text(label)
                .font(.jeevesCaption)
                .foregroundStyle(.secondary)
                .frame(width: 120, alignment: .leading)
            Text(value)
                .font(.jeevesMono)
                .foregroundStyle(.white)
        }
    }

    private func abbreviatedHash(_ value: String) -> String {
        if value.count <= 20 { return value }
        return "\(value.prefix(10))...\(value.suffix(8))"
    }
}

// MARK: - Emerging Detail

struct EmergingDetailView: View {
    let intention: EmergingIntentionProfile
    let relatedCertified: [BrowserCard]
    let isWatched: Bool
    let onWatch: () -> Void
    let onOpenCertified: (BrowserCard) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    headerSection
                    descriptionSection
                    signalSection
                    guidanceSection
                    relatedCertifiedSection
                    actionButtons
                }
                .padding()
            }
            .background(Color.houseDark)
            .navigationTitle(intention.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private var headerSection: some View {
        HStack {
            HStack(spacing: 6) {
                Image(systemName: "circle")
                    .foregroundStyle(Color.consentOrange)
                    .font(.caption2)
                Text("Emerging Intention")
                    .font(.jeevesCaption.weight(.semibold))
                    .foregroundStyle(Color.consentOrange)
            }
            Spacer()
            Text("CONFIDENCE \(String(format: "%.0f", intention.confidenceScore * 100))%")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.cyan)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.cyan.opacity(0.16))
                .clipShape(Capsule())
        }
        .browserPanel(padding: 10)
    }

    private var descriptionSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(intention.description)
                .font(.jeevesBody)
                .foregroundStyle(.white)

            Text("\(intention.domain) / \(intention.subdomain)")
                .font(.jeevesMono)
                .foregroundStyle(.secondary)
        }
        .browserPanel(padding: 12)
    }

    private var signalSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            emergingSectionTitle("Discovery Signal")
            Text(intention.clashdSignalSummary)
                .font(.jeevesCaption)
                .foregroundStyle(.white)

            if !intention.sourceClusters.isEmpty {
                emergingSectionTitle("Sources")
                ForEach(intention.sourceClusters, id: \.self) { source in
                    HStack(spacing: 6) {
                        Image(systemName: "circle.fill")
                            .font(.system(size: 4))
                            .foregroundStyle(.cyan)
                        Text(source)
                            .font(.jeevesMono)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            if !intention.linkedCells.isEmpty {
                emergingSectionTitle("Linked Cells")
                Text(intention.linkedCells.joined(separator: ", "))
                    .font(.jeevesMono)
                    .foregroundStyle(.secondary)
            }
        }
        .browserPanel(padding: 12)
    }

    private var guidanceSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Text("Jeeves Guidance")
                    .font(.jeevesHeadline)
                    .foregroundStyle(.white)
                Spacer()
                Text(intention.uncertaintyState.rawValue.uppercased())
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(uncertaintyTint)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(uncertaintyTint.opacity(0.18))
                    .clipShape(Capsule())
            }

            guidanceRow("WHAT SEEMS CLEAR", "This intention combines signals from \(intention.sourceClusters.count) source(s) with \(String(format: "%.0f", intention.confidenceScore * 100))% confidence.")

            guidanceRow("WHAT IS UNCERTAIN", "No benchmark contract exists yet. Production readiness is unknown.")

            if intention.hasCertifiedConfiguration == true {
                guidanceRow("BEST OPTIONS", "A candidate configuration is available. Consider requesting certification.")
            } else {
                guidanceRow("BEST OPTIONS", "Watch for certification progress or explore related certified tools.")
            }

            guidanceRow("WHY THIS APPEARS", "CLASHD27 detected convergence in the \(intention.domain)/\(intention.subdomain) domain.")

            guidanceRow("WHAT SHOULD HAPPEN NEXT", "Wait for SafeClash evaluation or propose a certification request.")
        }
        .browserPanel(padding: 12)
    }

    private var relatedCertifiedSection: some View {
        Group {
            if !relatedCertified.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    emergingSectionTitle("Related Certified Tools")
                    ForEach(relatedCertified.prefix(3)) { card in
                        Button {
                            onOpenCertified(card)
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "checkmark.seal.fill")
                                    .foregroundStyle(Color.consentGreen)
                                    .font(.caption)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(card.title)
                                        .font(.jeevesCaption.weight(.semibold))
                                        .foregroundStyle(.white)
                                    Text(card.intentionPath)
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
                .browserPanel(padding: 12)
            }
        }
    }

    private var actionButtons: some View {
        VStack(spacing: 8) {
            Button {
                onWatch()
            } label: {
                HStack {
                    Image(systemName: isWatched ? "eye.fill" : "eye")
                    Text(isWatched ? "Watching This Intention" : "Watch This Intention")
                        .font(.jeevesHeadline)
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(isWatched ? Color.jeevesGold : Color.cyan)
            .controlSize(.large)
        }
    }

    private var uncertaintyTint: Color {
        switch intention.uncertaintyState {
        case .confirmed: return .consentGreen
        case .strongCandidate: return .cyan
        case .exploratory: return .consentOrange
        case .unknown: return .secondary
        }
    }

    private func emergingSectionTitle(_ title: String) -> some View {
        Text(title.uppercased())
            .font(.caption2.weight(.semibold))
            .foregroundStyle(.secondary)
    }

    private func guidanceRow(_ title: String, _ content: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.white.opacity(0.8))
            Text(content)
                .font(.jeevesCaption)
                .foregroundStyle(.secondary)
        }
    }
}
