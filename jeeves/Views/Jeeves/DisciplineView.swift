import SwiftUI

struct DisciplineView: View {
    @StateObject private var viewModel = DisciplineViewModel()
    @StateObject private var selectionStore = DisciplineSelectionStore.shared
    @State private var activeDiscipline: Discipline?

    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]

    var body: some View {
        NavigationStack {
            ZStack {
                InstrumentBackdrop(
                    colors: [
                        Color(red: 0.99, green: 0.97, blue: 0.96),
                        Color(red: 0.98, green: 0.95, blue: 0.93),
                        Color(red: 0.97, green: 0.97, blue: 0.99)
                    ]
                )
                .ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        InstrumentRoleHeader(
                            eyebrow: "Disciplines",
                            title: "Live disciplinekaart",
                            summary: "CLASHD27 laat hier zien waar de sterkste onderzoekslijnen en gaps nu zitten.",
                            accent: .jeevesLogoRed,
                            metrics: [
                                InstrumentRoleMetric(label: "Disciplines", value: "\(viewModel.disciplines.count)"),
                                InstrumentRoleMetric(label: "Open gaps", value: "\(viewModel.disciplines.map(\.displayGapCount).reduce(0, +))")
                            ]
                        )

                        if let error = viewModel.error {
                            Text(error)
                                .font(.jeevesBody)
                                .foregroundStyle(.secondary)
                                .padding(14)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(
                                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                                        .fill(Color.white.opacity(0.9))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                                .stroke(Color.jeevesLogoRed.opacity(0.14), lineWidth: 1)
                                        )
                                )
                        }

                        InstrumentSectionPanel(
                            eyebrow: "Disciplines",
                            title: "Waar de meeste spanning zit",
                            subtitle: "Open een discipline om de live gaplijst, details en PDF-export te bekijken.",
                            accent: .jeevesLogoRed,
                            metric: viewModel.isLoading ? "Laden" : "\(viewModel.disciplines.count)"
                        ) {
                            if viewModel.isLoading && viewModel.disciplines.isEmpty {
                                ProgressView("Disciplines worden geladen...")
                                    .font(.jeevesBody)
                            } else if viewModel.disciplines.isEmpty {
                                Text("Nog geen disciplines beschikbaar.")
                                    .font(.jeevesBody)
                                    .foregroundStyle(.secondary)
                                    .padding(.vertical, 10)
                            } else {
                                LazyVGrid(columns: columns, spacing: 12) {
                                    ForEach(viewModel.disciplines.prefix(5)) { discipline in
                                        Button {
                                            activeDiscipline = discipline
                                        } label: {
                                            disciplineCard(discipline)
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 16)
                }
            }
            .navigationTitle("Disciplines")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .task {
                if viewModel.disciplines.isEmpty {
                    await viewModel.loadDisciplines()
                }
                await applyPendingSelectionIfNeeded()
            }
            .task(id: selectionStore.requestedDisciplineId) {
                await applyPendingSelectionIfNeeded()
            }
            .refreshable {
                await viewModel.loadDisciplines()
                await applyPendingSelectionIfNeeded()
            }
            .navigationDestination(item: $activeDiscipline) { discipline in
                DisciplineGapListScreen(viewModel: viewModel, discipline: discipline)
            }
        }
    }

    @ViewBuilder
    private func disciplineCard(_ discipline: Discipline) -> some View {
        let accent = disciplineAccentColor(discipline)

        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                Text(discipline.displayLabel)
                    .font(.jeevesBody.weight(.semibold))
                    .foregroundStyle(Color.jeevesInk)
                    .multilineTextAlignment(.leading)
                    .lineLimit(2)

                Spacer(minLength: 8)

                Text("\(discipline.displayGapCount)")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(accent)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        Capsule()
                            .fill(accent.opacity(0.12))
                    )
            }

            Text("Gemiddelde score")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(Color.jeevesSubtleText)

            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.jeevesLine.opacity(0.35))
                    Capsule()
                        .fill(accent)
                        .frame(width: max(10, geometry.size.width * discipline.effectiveAverageScore))
                }
            }
            .frame(height: 8)

            HStack {
                Text(scoreLabel(discipline.effectiveAverageScore))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(accent)

                Spacer()

                if let lastRun = discipline.lastRun?.nilIfEmpty {
                    Text(shortDate(lastRun))
                        .font(.caption2)
                        .foregroundStyle(Color.jeevesSubtleText)
                }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, minHeight: 140, alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.white.opacity(0.94))
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(accent.opacity(0.18), lineWidth: 1)
                )
        )
    }

    private func applyPendingSelectionIfNeeded() async {
        guard let requestedId = selectionStore.requestedDisciplineId else { return }
        if viewModel.disciplines.isEmpty {
            await viewModel.loadDisciplines()
        }
        guard let discipline = viewModel.disciplines.first(where: { $0.id == requestedId }) else { return }
        activeDiscipline = discipline
        selectionStore.requestedDisciplineId = nil
    }

    private func disciplineAccentColor(_ discipline: Discipline) -> Color {
        Color(hex: discipline.color) ?? .jeevesLogoRed
    }

    private func scoreLabel(_ score: Double) -> String {
        String(format: "%.0f%%", min(max(score, 0), 1) * 100)
    }

    private func shortDate(_ iso: String) -> String {
        let formatter = ISO8601DateFormatter()
        guard let date = formatter.date(from: iso) else { return iso }
        let output = DateFormatter()
        output.locale = Locale(identifier: "nl_NL")
        output.dateFormat = "d MMM"
        return output.string(from: date)
    }
}

private struct DisciplineGapListScreen: View {
    @ObservedObject var viewModel: DisciplineViewModel
    let discipline: Discipline

    @State private var shareURLs: [URL] = []
    @State private var selectedGap: DisciplineGap?

    var body: some View {
        List {
            if !viewModel.availableProperties.isEmpty {
                propertyFilterRow
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
            }

            if viewModel.isLoading && viewModel.gaps.isEmpty {
                ProgressView("Gaps worden geladen...")
                    .font(.jeevesBody)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .listRowBackground(Color.clear)
            } else if viewModel.filteredGaps.isEmpty {
                Text("Nog geen gaps boven 80% in deze discipline.")
                    .font(.jeevesBody)
                    .foregroundStyle(.secondary)
                    .listRowBackground(Color.clear)
            } else {
                ForEach(viewModel.filteredGaps) { gap in
                    gapRow(gap)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            selectedGap = gap
                        }
                    .swipeActions(edge: .leading, allowsFullSwipe: true) {
                        Button {
                            Task {
                                if let url = await viewModel.exportPDF(disciplineId: discipline.id, gapId: gap.id) {
                                    shareURLs = [url]
                                }
                            }
                        } label: {
                            Label("Exporteer PDF", systemImage: "square.and.arrow.up")
                        }
                        .tint(.consentGreen)
                    }
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(Color.jeevesMist)
        .navigationTitle(discipline.displayLabel)
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .task(id: discipline.id) {
            await viewModel.loadGaps(for: discipline.id)
        }
        .refreshable {
            await viewModel.loadGaps(for: discipline.id)
        }
        #if canImport(UIKit)
        .sheet(isPresented: shareSheetPresented) {
            ActivityShareSheet(items: shareURLs)
        }
        .sheet(item: $selectedGap) { gap in
            NavigationStack {
                DisciplineGapDetailScreen(viewModel: viewModel, discipline: discipline, gap: gap)
            }
        }
        #endif
    }

    @ViewBuilder
    private func gapRow(_ gap: DisciplineGap) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top) {
                Text(gap.displayHypothesis)
                    .font(.jeevesBody.weight(.medium))
                    .foregroundStyle(Color.jeevesInk)
                    .lineLimit(3)

                Spacer(minLength: 8)

                HStack(spacing: 6) {
                    if let propertyName = gap.propertyName?.nilIfEmpty {
                        Button {
                            viewModel.filterByProperty(propertyName)
                        } label: {
                            Text(propertyName)
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(propertyAxisColor(gap))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(
                                    Capsule()
                                        .fill(propertyAxisColor(gap).opacity(0.14))
                                )
                        }
                        .buttonStyle(.plain)
                    }

                    Text(gap.displayScore)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(scoreColor(gap))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            Capsule()
                                .fill(scoreColor(gap).opacity(0.14))
                        )
                }
            }

            HStack(spacing: 10) {
                if let date = gap.date?.nilIfEmpty {
                    detailChip(shortDate(date))
                }
                detailChip("\(gap.displayPaperCount) papers")
                detailChip(opportunityText(for: gap))
            }
        }
        .padding(.vertical, 6)
    }

    @ViewBuilder
    private func detailChip(_ text: String) -> some View {
        Text(text)
            .font(.caption2.weight(.semibold))
            .foregroundStyle(Color.jeevesSubtleText)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                Capsule()
                    .fill(Color.jeevesLine.opacity(0.28))
            )
    }

    @ViewBuilder
    private var propertyFilterRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                propertyFilterChip(title: "Alle", selected: viewModel.selectedProperty == nil) {
                    viewModel.filterByProperty(nil)
                }
                ForEach(viewModel.availableProperties, id: \.self) { property in
                    propertyFilterChip(
                        title: property,
                        selected: viewModel.selectedProperty?.localizedCaseInsensitiveCompare(property) == .orderedSame
                    ) {
                        viewModel.filterByProperty(property)
                    }
                }
            }
            .padding(.vertical, 4)
        }
    }

    @ViewBuilder
    private func propertyFilterChip(title: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(selected ? Color.white : Color.jeevesInk)
                .padding(.horizontal, 10)
                .padding(.vertical, 7)
                .background(
                    Capsule()
                        .fill(selected ? Color.jeevesLogoRed : Color.white.opacity(0.94))
                        .overlay(
                            Capsule()
                                .stroke(Color.jeevesLogoRed.opacity(selected ? 0 : 0.16), lineWidth: 1)
                        )
                )
        }
        .buttonStyle(.plain)
    }

    private func opportunityText(for gap: DisciplineGap) -> String {
        let label = gap.opportunityLabel?.nilIfEmpty ?? derivedOpportunityLabel(for: gap)
        return gap.opportunityScore != nil ? "\(label) · \(gap.displayScore)" : label
    }

    private func derivedOpportunityLabel(for gap: DisciplineGap) -> String {
        switch gap.scoreFraction {
        case 0.85...:
            return "Vroeg stadium"
        case 0.75..<0.85:
            return "Opkomend"
        default:
            return "Verzadigd"
        }
    }

    private func scoreColor(_ gap: DisciplineGap) -> Color {
        switch gap.scoreFraction {
        case 0.85...:
            return .consentGreen
        case 0.75..<0.85:
            return .orange
        default:
            return .gray
        }
    }

    private func propertyAxisColor(_ gap: DisciplineGap) -> Color {
        switch gap.propertyAxis?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
        case "movement":
            return Color(red: 0.16, green: 0.50, blue: 0.73)
        case "structure":
            return Color(red: 0.56, green: 0.27, blue: 0.68)
        case "potential":
            return Color(red: 0.15, green: 0.68, blue: 0.38)
        default:
            return .jeevesSubtleText
        }
    }

    private func shortDate(_ iso: String) -> String {
        let formatter = ISO8601DateFormatter()
        guard let date = formatter.date(from: iso) else { return iso }
        let output = DateFormatter()
        output.locale = Locale(identifier: "nl_NL")
        output.dateFormat = "d MMM yyyy"
        return output.string(from: date)
    }

    private var shareSheetPresented: Binding<Bool> {
        Binding(
            get: { !shareURLs.isEmpty },
            set: { isPresented in
                if !isPresented {
                    shareURLs = []
                }
            }
        )
    }
}

private struct DisciplineGapDetailScreen: View {
    @ObservedObject var viewModel: DisciplineViewModel
    let discipline: Discipline
    let gap: DisciplineGap

    @State private var shareURLs: [URL] = []

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 10) {
                    Text(gap.displayTitle)
                        .font(.jeevesLargeTitle)
                        .foregroundStyle(Color.jeevesInk)

                    HStack(spacing: 10) {
                        Text(discipline.displayLabel.uppercased())
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(accentColor)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(
                                Capsule()
                                    .fill(accentColor.opacity(0.12))
                            )

                        Text(gap.displayScore)
                            .font(.subheadline.monospacedDigit().weight(.semibold))
                            .foregroundStyle(accentColor)
                    }

                    if let date = gap.date?.nilIfEmpty {
                        Text(shortDate(date))
                            .font(.caption)
                            .foregroundStyle(Color.jeevesSubtleText)
                    }
                }

                sectionCard(title: "Hypothese") {
                    Text(gap.displayHypothesis)
                        .font(.jeevesBody)
                        .foregroundStyle(Color.jeevesInk)
                        .fixedSize(horizontal: false, vertical: true)
                }

                sectionCard(title: "Score breakdown") {
                    VStack(alignment: .leading, spacing: 12) {
                        scoreBar(label: "Totaal", value: gap.scoreFraction, tint: accentColor)
                        if let componentScores = gap.componentScores, !componentScores.isEmpty {
                            ForEach(componentScores.keys.sorted(), id: \.self) { key in
                                scoreBar(
                                    label: componentLabel(key),
                                    value: min(max(componentScores[key] ?? 0, 0), 1),
                                    tint: accentColor.opacity(0.78)
                                )
                            }
                        }
                    }
                }

                sectionCard(title: "Evidence chain A → B → C") {
                    if gap.evidenceChain.isEmpty {
                        Text("Nog geen evidence chain beschikbaar voor deze gap.")
                            .font(.jeevesBody)
                            .foregroundStyle(.secondary)
                    } else {
                        VStack(alignment: .leading, spacing: 10) {
                            ForEach(Array(gap.evidenceChain.enumerated()), id: \.offset) { index, evidence in
                                HStack(alignment: .top, spacing: 10) {
                                    Text(["A", "B", "C"][safe: index] ?? "A")
                                        .font(.caption.weight(.bold))
                                        .foregroundStyle(accentColor)
                                        .frame(width: 20, height: 20)
                                        .background(
                                            Circle()
                                                .fill(accentColor.opacity(0.14))
                                        )
                                    Text(evidence)
                                        .font(.jeevesBody)
                                        .foregroundStyle(Color.jeevesInk)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                                if index < gap.evidenceChain.count - 1 {
                                    Image(systemName: "arrow.down")
                                        .foregroundStyle(Color.jeevesSubtleText)
                                        .padding(.leading, 4)
                                }
                            }
                        }
                    }
                }

                sectionCard(title: "Opportunity") {
                    HStack {
                        Text(opportunityText)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(opportunityColor)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(
                                Capsule()
                                    .fill(opportunityColor.opacity(0.14))
                            )
                        Spacer()
                    }
                }

                Button {
                    Task {
                        if let url = await viewModel.exportPDF(disciplineId: discipline.id, gapId: gap.id) {
                            shareURLs = [url]
                        }
                    }
                } label: {
                    HStack {
                        if viewModel.exportingGapId == gap.id {
                            ProgressView()
                                .controlSize(.small)
                                .tint(.white)
                        }
                        Text(viewModel.exportingGapId == gap.id ? "PDF downloaden..." : "Download PDF")
                            .font(.jeevesBody.weight(.semibold))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .foregroundStyle(.white)
                    .background(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(accentColor)
                    )
                }
                .buttonStyle(.plain)
                .disabled(viewModel.exportingGapId == gap.id)
            }
            .padding(20)
        }
        .background(Color.jeevesMist.ignoresSafeArea())
        .navigationTitle("Gap detail")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        #if canImport(UIKit)
        .sheet(isPresented: shareSheetPresented) {
            ActivityShareSheet(items: shareURLs)
        }
        #endif
    }

    @ViewBuilder
    private func sectionCard<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(accentColor)
            content()
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.white.opacity(0.94))
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(accentColor.opacity(0.12), lineWidth: 1)
                )
        )
    }

    @ViewBuilder
    private func scoreBar(label: String, value: Double, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(label)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.jeevesInk)
                Spacer()
                Text(String(format: "%.0f%%", value * 100))
                    .font(.caption.monospacedDigit().weight(.semibold))
                    .foregroundStyle(tint)
            }
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.jeevesLine.opacity(0.35))
                    Capsule()
                        .fill(tint)
                        .frame(width: max(10, geometry.size.width * min(max(value, 0), 1)))
                }
            }
            .frame(height: 8)
        }
    }

    private func componentLabel(_ key: String) -> String {
        switch key.lowercased() {
        case "novelty":
            return "Nieuwheid"
        case "collision":
            return "Botsing"
        case "residue":
            return "Residue"
        case "gravity":
            return "Gravity"
        case "evidence":
            return "Evidence"
        case "entropy":
            return "Entropy"
        case "serendipity":
            return "Serendipity"
        case "total":
            return "Totaal"
        default:
            return key.capitalized
        }
    }

    private var accentColor: Color {
        Color(hex: discipline.color ?? gap.color) ?? .jeevesLogoRed
    }

    private var opportunityText: String {
        let label = gap.opportunityLabel?.nilIfEmpty ?? derivedOpportunityLabel
        let rawScore = gap.opportunityScore ?? gap.scoreFraction
        let normalizedScore = rawScore > 1 ? rawScore / 100 : rawScore
        let scoreText = String(format: "%.0f%%", normalizedScore * 100)
        return "\(label) · \(scoreText)"
    }

    private var opportunityColor: Color {
        switch (gap.opportunityLabel?.nilIfEmpty ?? derivedOpportunityLabel).lowercased() {
        case "vroeg stadium":
            return .consentGreen
        case "opkomend":
            return .orange
        default:
            return .gray
        }
    }

    private var derivedOpportunityLabel: String {
        switch gap.scoreFraction {
        case 0.85...:
            return "Vroeg stadium"
        case 0.75..<0.85:
            return "Opkomend"
        default:
            return "Verzadigd"
        }
    }

    private func shortDate(_ iso: String) -> String {
        let formatter = ISO8601DateFormatter()
        guard let date = formatter.date(from: iso) else { return iso }
        let output = DateFormatter()
        output.locale = Locale(identifier: "nl_NL")
        output.dateFormat = "EEEE d MMMM yyyy"
        return output.string(from: date)
    }

    private var shareSheetPresented: Binding<Bool> {
        Binding(
            get: { !shareURLs.isEmpty },
            set: { isPresented in
                if !isPresented {
                    shareURLs = []
                }
            }
        )
    }
}

private extension Color {
    init?(hex: String?) {
        guard let hex = hex?.trimmingCharacters(in: .whitespacesAndNewlines),
              !hex.isEmpty else {
            return nil
        }

        let cleaned = hex.replacingOccurrences(of: "#", with: "")
        guard cleaned.count == 6, let value = UInt64(cleaned, radix: 16) else {
            return nil
        }

        let red = Double((value & 0xFF0000) >> 16) / 255
        let green = Double((value & 0x00FF00) >> 8) / 255
        let blue = Double(value & 0x0000FF) / 255
        self.init(red: red, green: green, blue: blue)
    }
}

private extension String {
    var nilIfEmpty: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        guard indices.contains(index) else { return nil }
        return self[index]
    }
}
