import Foundation

/// Parses raw chat text into a structured JeevesCommand.
///
/// Command mode activates when a message begins with "jeeves " (case-insensitive).
/// Format: `jeeves verb target [arg=value ...]`
///
/// Examples:
///   jeeves open browser domain=financial
///   jeeves show radar
///   jeeves inspect system
///   jeeves explain signals
enum JeevesCommandParser {

    /// Returns nil if the text is not a command.
    static func parse(_ text: String) -> JeevesCommand? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let lower = trimmed.lowercased()

        // Must start with "jeeves " prefix
        guard lower.hasPrefix("jeeves ") else { return nil }

        // Strip the "jeeves " prefix (length 7)
        let remainder = String(trimmed.dropFirst(7)).trimmingCharacters(in: .whitespaces)
        guard !remainder.isEmpty else { return nil }

        let tokens = tokenize(remainder)
        guard tokens.count >= 2 else { return nil }

        // First token must be a known verb
        guard let verb = JeevesCommand.Verb(rawValue: tokens[0].lowercased()) else {
            return nil
        }

        // Second token is the target
        let target = tokens[1].lowercased()

        // Remaining tokens are key=value arguments
        var arguments: [String: String] = [:]
        for token in tokens.dropFirst(2) {
            if let eqIndex = token.firstIndex(of: "=") {
                let key = String(token[token.startIndex..<eqIndex]).lowercased()
                let value = String(token[token.index(after: eqIndex)...])
                if !key.isEmpty, !value.isEmpty {
                    arguments[key] = value
                }
            }
        }

        return JeevesCommand(verb: verb, target: target, arguments: arguments)
    }

    /// Split on whitespace, respecting quoted values (e.g. domain="some value").
    private static func tokenize(_ text: String) -> [String] {
        var tokens: [String] = []
        var current = ""
        var inQuote = false

        for char in text {
            if char == "\"" {
                inQuote.toggle()
            } else if char == " " && !inQuote {
                if !current.isEmpty {
                    tokens.append(current)
                    current = ""
                }
            } else {
                current.append(char)
            }
        }
        if !current.isEmpty {
            tokens.append(current)
        }
        return tokens
    }
}
