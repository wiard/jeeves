import Foundation

/// A summary of what a screen is currently showing.
struct ScreenStateSummary: Sendable {
    let screen: AppScreen
    let headline: String
    let itemCount: Int
    let highlights: [String]
    let isEmpty: Bool
}

/// ViewModels conform to this so the orchestrator can reason over screen content.
@MainActor
protocol ScreenStateReadable {
    var screenId: AppScreen { get }
    func summary() -> ScreenStateSummary
}
