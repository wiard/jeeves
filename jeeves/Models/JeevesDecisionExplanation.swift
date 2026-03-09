import Foundation

/// A compact, operator-grade explanation section.
struct JeevesExplanationSection: Sendable, Equatable {
    let title: String
    let lines: [String]
}

/// Structured explanation model for inspectable Jeeves routing decisions.
struct JeevesDecisionExplanation: Sendable, Equatable {
    let headline: String
    let sections: [JeevesExplanationSection]

    /// String form used by chat output (compact and operator-readable).
    var text: String {
        var output: [String] = [headline]
        for section in sections {
            guard !section.lines.isEmpty else { continue }
            output.append("\(section.title):")
            for line in section.lines {
                output.append("- \(line)")
            }
        }
        return output.joined(separator: "\n")
    }
}
