import Foundation

@MainActor
final class DisciplineViewModel: ObservableObject {
    @Published var disciplines: [Discipline] = []
    @Published var selectedDiscipline: Discipline?
    @Published var gaps: [DisciplineGap] = []
    @Published var selectedProperty: String?
    @Published var isLoading = false
    @Published var error: String?
    @Published var exportingGapId: String?

    let baseURL = "https://clashd27.com"

    private let session: URLSession

    init() {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 8
        configuration.timeoutIntervalForResource = 8
        configuration.waitsForConnectivity = false
        session = URLSession(configuration: configuration)
    }

    var featuredDiscipline: Discipline? {
        disciplines.max { lhs, rhs in
            if lhs.effectiveAverageScore == rhs.effectiveAverageScore {
                return lhs.displayGapCount < rhs.displayGapCount
            }
            return lhs.effectiveAverageScore < rhs.effectiveAverageScore
        }
    }

    var filteredGaps: [DisciplineGap] {
        guard let selectedProperty, !selectedProperty.isEmpty else {
            return gaps
        }
        return gaps.filter {
            $0.propertyName?
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .localizedCaseInsensitiveCompare(selectedProperty) == .orderedSame
        }
    }

    var availableProperties: [String] {
        Array(Set(gaps.compactMap {
            $0.propertyName?.trimmingCharacters(in: .whitespacesAndNewlines)
        }))
        .filter { !$0.isEmpty }
        .sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
    }

    func loadDisciplines() async {
        isLoading = true
        defer { isLoading = false }

        do {
            let data = try await fetch(path: "/api/disciplines")
            let decoded = try decodeDisciplines(from: data)
            disciplines = decoded.sorted { lhs, rhs in
                if lhs.effectiveAverageScore == rhs.effectiveAverageScore {
                    return lhs.displayLabel.localizedCaseInsensitiveCompare(rhs.displayLabel) == .orderedAscending
                }
                return lhs.effectiveAverageScore > rhs.effectiveAverageScore
            }
            if let selectedDiscipline {
                self.selectedDiscipline = disciplines.first(where: { $0.id == selectedDiscipline.id }) ?? selectedDiscipline
            }
            error = nil
        } catch {
            disciplines = []
            self.error = friendlyError(error, fallback: "De disciplines konden niet worden geladen.")
        }
    }

    func loadGaps(for disciplineId: String) async {
        isLoading = true
        defer { isLoading = false }

        do {
            let data = try await fetch(path: "/api/disciplines/\(disciplineId)/gaps", queryItems: [
                URLQueryItem(name: "minScore", value: "0.80")
            ])
            let decoded = try decodeGaps(from: data)
            gaps = decoded.sorted { $0.scoreFraction > $1.scoreFraction }
            selectedDiscipline = disciplines.first(where: { $0.id == disciplineId }) ?? selectedDiscipline
            if let selectedProperty, !availableProperties.contains(where: { $0.localizedCaseInsensitiveCompare(selectedProperty) == .orderedSame }) {
                self.selectedProperty = nil
            }
            error = nil
        } catch {
            gaps = []
            selectedProperty = nil
            self.error = friendlyError(error, fallback: "De gaps voor deze discipline konden niet worden geladen.")
        }
    }

    func filterByProperty(_ property: String?) {
        let normalized = property?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .nilIfEmpty
        selectedProperty = normalized
    }

    func exportPDF(disciplineId: String, gapId: String) async -> URL? {
        exportingGapId = gapId
        defer { exportingGapId = nil }

        do {
            let data = try await fetch(path: "/api/disciplines/\(disciplineId)/gaps/\(gapId)/pdf", accept: "application/pdf")
            let directory = FileManager.default.temporaryDirectory.appendingPathComponent("DisciplineExports", isDirectory: true)
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            let fileURL = directory.appendingPathComponent("\(gapId).pdf")
            try data.write(to: fileURL, options: [.atomic])
            error = nil
            return fileURL
        } catch {
            self.error = friendlyError(error, fallback: "De PDF kon niet worden gedownload.")
            return nil
        }
    }

    private func decodeDisciplines(from data: Data) throws -> [Discipline] {
        let decoder = JSONDecoder()
        if let array = try? decoder.decode([Discipline].self, from: data) {
            return array
        }
        if let envelope = try? decoder.decode(DisciplineEnvelope.self, from: data), let disciplines = envelope.disciplines {
            return disciplines
        }
        throw OperatorSurfacesError(message: "De discipline-feed gaf een onleesbaar antwoord terug.")
    }

    private func decodeGaps(from data: Data) throws -> [DisciplineGap] {
        let decoder = JSONDecoder()
        if let array = try? decoder.decode([DisciplineGap].self, from: data) {
            return array
        }
        if let envelope = try? decoder.decode(DisciplineGapEnvelope.self, from: data), let gaps = envelope.gaps {
            return gaps
        }
        throw OperatorSurfacesError(message: "De discipline-gapfeed gaf een onleesbaar antwoord terug.")
    }

    private func fetch(
        path: String,
        queryItems: [URLQueryItem] = [],
        accept: String = "application/json"
    ) async throws -> Data {
        guard var components = URLComponents(string: baseURL + path) else {
            throw OperatorSurfacesError(message: "De discipline-route kon niet worden opgebouwd.")
        }
        components.queryItems = queryItems.isEmpty ? nil : queryItems

        guard let url = components.url else {
            throw OperatorSurfacesError(message: "De discipline-route kon niet worden opgebouwd.")
        }

        var request = URLRequest(url: url, timeoutInterval: 8)
        request.httpMethod = "GET"
        request.setValue(accept, forHTTPHeaderField: "Accept")

        do {
            let (data, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse else {
                throw OperatorSurfacesError(message: "Geen geldig antwoord van de discipline-server.")
            }
            guard (200...299).contains(http.statusCode) else {
                let text = String(data: data, encoding: .utf8)?
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                throw OperatorSurfacesError(message: text?.nilIfEmpty ?? "De discipline-server weigerde deze aanvraag.")
            }
            return data
        } catch {
            throw error
        }
    }

    private func friendlyError(_ error: Error, fallback: String) -> String {
        if let operatorError = error as? OperatorSurfacesError {
            return operatorError.localizedDescription
        }
        if let urlError = error as? URLError {
            switch urlError.code {
            case .timedOut:
                return "De discipline-server reageert te langzaam. Probeer het zo opnieuw."
            case .notConnectedToInternet, .cannotFindHost, .cannotConnectToHost, .networkConnectionLost:
                return "De discipline-feed is nu niet bereikbaar."
            default:
                break
            }
        }
        let localized = error.localizedDescription.trimmingCharacters(in: .whitespacesAndNewlines)
        return localized.isEmpty ? fallback : localized
    }
}

@MainActor
final class DisciplineSelectionStore: ObservableObject {
    static let shared = DisciplineSelectionStore()

    @Published var requestedDisciplineId: String?

    private init() {}
}

private struct DisciplineEnvelope: Decodable {
    let disciplines: [Discipline]?
}

private struct DisciplineGapEnvelope: Decodable {
    let gaps: [DisciplineGap]?
}

private extension String {
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}
