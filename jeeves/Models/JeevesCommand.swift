import Foundation

/// A structured command parsed from "jeeves verb target arg=value ..." syntax.
struct JeevesCommand: Sendable, Equatable {
    enum Verb: String, CaseIterable, Sendable {
        case open
        case show
        case inspect
        case explain
    }

    let verb: Verb
    let target: String
    let arguments: [String: String]
}
