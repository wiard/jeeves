import SwiftUI

struct BudgetCard: View {
    let budget: BudgetStatus

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Budget", systemImage: "dollarsign.circle")
                .font(.jeevesHeadline)

            BudgetRow(label: "Vandaag", period: budget.daily)
            BudgetRow(label: "Week", period: budget.weekly)
            BudgetRow(label: "Maand", period: budget.monthly)

            HStack {
                Text("Hard-stop:")
                    .font(.jeevesCaption)
                    .foregroundStyle(.secondary)
                Text(budget.hardStop ? "ja" : "nee")
                    .font(.jeevesMono)
                    .foregroundStyle(budget.hardStop ? .consentRed : .consentGreen)
            }
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

private struct BudgetRow: View {
    let label: String
    let period: BudgetPeriod

    private var barColor: Color {
        let ratio = period.ratio
        if ratio < 0.5 { return .consentGreen }
        if ratio < 0.8 { return .consentOrange }
        return .consentRed
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(label)
                    .font(.jeevesCaption)
                Spacer()
                Text(String(format: "$%.2f / $%.2f", period.used, period.limit))
                    .font(.jeevesMono)
            }
            ProgressView(value: min(period.ratio, 1.0))
                .tint(barColor)
        }
    }
}
