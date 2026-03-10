import Foundation

/// A structured command parsed from "jeeves verb target arg=value ..." syntax.
struct JeevesCommand: Sendable, Equatable {
    enum Verb: String, CaseIterable, Sendable {
        case open
        case show
        case recent
        case inspect
        case explain
        case why
        case what
    }

    let verb: Verb
    let target: String
    let modifiers: [String]
    let arguments: [String: String]

    var targetPhrase: String {
        ([target] + modifiers).joined(separator: " ")
    }
}
