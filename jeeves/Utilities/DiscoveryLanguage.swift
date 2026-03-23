import Foundation

struct DiscoveryLanguage {
    static func headline(for discovery: ClassifiedDiscovery) -> String {
        headline(
            outcomeType: discovery.outcomeType,
            firstDomain: humanWhat(discovery.axes.first),
            secondDomain: humanWhat(discovery.axes.dropFirst().first),
            firstTime: humanTime(discovery.axes.first?.time),
            secondTime: humanTime(discovery.axes.dropFirst().first?.time)
        )
    }

    static func headline(for candidate: RadarDiscoveryCandidate) -> String {
        let firstDomain = humanWhat(candidate.axes.first)
        let secondDomain = humanWhat(candidate.axes.dropFirst().first)
        let firstTime = humanTime(candidate.axes.first?.time)
        let secondTime = humanTime(candidate.axes.dropFirst().first?.time)
        let outcomeType = inferredOutcomeType(from: candidate)

        if let outcomeType {
            return headline(
                outcomeType: outcomeType,
                firstDomain: firstDomain,
                secondDomain: secondDomain,
                firstTime: firstTime,
                secondTime: secondTime
            )
        }

        let explanation = candidate.explanation.trimmingCharacters(in: .whitespacesAndNewlines)
        if !explanation.isEmpty, candidate.axes.count < 2 {
            return explanation
        }

        if candidate.axes.count >= 2 {
            if !firstTime.isEmpty, !secondTime.isEmpty, firstTime != secondTime {
                return "Verschuiving tussen \(firstDomain) (\(firstTime)) en \(secondDomain) (\(secondTime))"
            }
            return "Signaal tussen \(firstDomain) × \(secondDomain)"
        }

        return candidate.candidateId
    }

    static func domainLabel(_ domainType: String) -> String {
        switch domainType {
        case "single":
            return "Binnen een domein"
        case "dual":
            return "Twee domeinen raken elkaar"
        case "cross":
            return "Domeingrens overschreden"
        default:
            return domainType
        }
    }

    static func actionHint(_ outcomeType: String) -> String {
        switch outcomeType {
        case "GAP":
            return "Dit gebied wordt gemist — wilt u het onderzoeken?"
        case "DISCOVERY":
            return "Nieuw verband — keur goed om het te bewaren."
        case "OPPORTUNITY":
            return "Kansrijk — meerdere bronnen bevestigen dit."
        case "SURPRISE":
            return "Onverwacht sterk signaal in dunbevolkt gebied."
        case "SURE_WIN":
            return "Bewezen door eerdere beslissingen."
        default:
            return ""
        }
    }

    static func actionHint(for candidate: RadarDiscoveryCandidate) -> String {
        if let outcomeType = inferredOutcomeType(from: candidate) {
            return actionHint(outcomeType)
        }

        if candidate.crossDomain {
            return "Twee domeinen raken elkaar. Bekijk of dit aandacht vraagt."
        }

        return "Een nieuw signaal vraagt om een korte beoordeling."
    }

    static func humanDomain(_ axis: DiscoveryAxis?) -> String {
        guard let axis else { return "onbekend" }
        let what = humanWhat(axis)
        let whereValue = translatedWhere(axis.where_)
        let time = humanTime(axis.time)
        return "\(what) (\(whereValue), \(time))"
    }

    static func humanDomain(_ axis: RadarAxes?) -> String {
        guard let axis else { return "onbekend" }
        let what = humanWhat(axis)
        let whereValue = translatedWhere(axis.whereValue)
        let time = humanTime(axis.time)
        return "\(what) (\(whereValue), \(time))"
    }

    static func humanWhat(_ axis: DiscoveryAxis?) -> String {
        guard let axis else { return "onbekend" }
        return translatedWhat(axis.what)
    }

    static func humanWhat(_ axis: RadarAxes?) -> String {
        guard let axis else { return "onbekend" }
        return translatedWhat(axis.what)
    }

    static func humanTime(_ time: String?) -> String {
        switch time {
        case "historical":
            return "historisch"
        case "current":
            return "actueel"
        case "emerging":
            return "opkomend"
        default:
            return time ?? ""
        }
    }

    private static func headline(
        outcomeType: String,
        firstDomain: String,
        secondDomain: String,
        firstTime: String,
        secondTime: String
    ) -> String {
        switch outcomeType {
        case "GAP":
            if !firstTime.isEmpty, !secondTime.isEmpty, firstTime != secondTime {
                return "Kloof tussen \(firstDomain) (\(firstTime)) en \(secondDomain) (\(secondTime))"
            }
            return "Ontbrekend terrein: \(firstDomain) × \(secondDomain)"
        case "DISCOVERY":
            return "Nieuw verband: \(firstDomain) × \(secondDomain)"
        case "OPPORTUNITY":
            return "Kans: \(firstDomain) raakt \(secondDomain)"
        case "SURPRISE":
            return "Onverwacht: \(firstDomain) × \(secondDomain)"
        case "SURE_WIN":
            return "Bewezen: \(firstDomain) × \(secondDomain)"
        default:
            return "\(firstDomain) × \(secondDomain)"
        }
    }

    private static func inferredOutcomeType(from candidate: RadarDiscoveryCandidate) -> String? {
        let normalized = candidate.candidateType
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .uppercased()

        if normalized.contains("GAP") {
            return "GAP"
        }
        if normalized.contains("DISCOVERY") {
            return "DISCOVERY"
        }
        if normalized.contains("OPPORTUNITY") {
            return "OPPORTUNITY"
        }
        if normalized.contains("SURPRISE") {
            return "SURPRISE"
        }
        if normalized.contains("SURE_WIN") || normalized.contains("SUREWIN") {
            return "SURE_WIN"
        }

        return nil
    }

    private static func translatedWhat(_ value: String) -> String {
        let whatMap: [String: String] = [
            "architecture": "architectuur",
            "trust-model": "vertrouwensmodel",
            "surface": "oppervlak",
            "model": "model",
            "engine": "kern",
            "governance": "governance",
            "signal": "signaal",
            "knowledge": "kennis",
            "fabric": "weefsel"
        ]

        return whatMap[value] ?? cleanDomainName(value)
    }

    private static func translatedWhere(_ value: String) -> String {
        let whereMap: [String: String] = [
            "internal": "intern",
            "external": "extern",
            "engine": "kern"
        ]

        return whereMap[value] ?? cleanDomainName(value)
    }

    private static func cleanDomainName(_ value: String) -> String {
        value
            .replacingOccurrences(of: "-", with: " ")
            .replacingOccurrences(of: "_", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
