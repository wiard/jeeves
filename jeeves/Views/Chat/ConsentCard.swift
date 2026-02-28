import SwiftUI

struct ConsentCard: View {
    let tool: String
    let risk: RiskLevel
    let reason: String
    let approved: Bool?
    let onApprove: () -> Void
    let onDeny: () -> Void

    private var isBlocked: Bool { risk == .red }
    private var isPending: Bool { !isBlocked && approved == nil }
    private var isResolved: Bool { approved != nil }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Header
            HStack {
                Image(systemName: headerIcon)
                    .foregroundStyle(headerColor)
                Text(headerText)
                    .font(.jeevesHeadline)
                    .foregroundStyle(headerColor)
                Spacer()
            }

            // Reason
            Text(reason)
                .font(.jeevesBody)

            // Tool info
            HStack {
                Text("Tool:")
                    .font(.jeevesCaption)
                    .foregroundStyle(.secondary)
                Text(tool)
                    .font(.jeevesMono)
            }

            // Buttons or status
            if isPending {
                HStack(spacing: 12) {
                    Button(action: onApprove) {
                        Text("Ja, meneer")
                            .font(.jeevesBody)
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.consentGreen)

                    Button(action: onDeny) {
                        Text("Nee")
                            .font(.jeevesBody)
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                }
            } else if isResolved {
                HStack {
                    Image(systemName: approved == true ? "checkmark.circle.fill" : "xmark.circle.fill")
                    Text(approved == true ? "Goedgekeurd" : "Geweigerd")
                        .font(.jeevesCaption)
                }
                .foregroundStyle(approved == true ? .consentGreen : .secondary)
            } else if isBlocked {
                HStack {
                    Image(systemName: "lock.fill")
                    Text("Geblokkeerd")
                        .font(.jeevesCaption)
                }
                .foregroundStyle(.consentRed)
            }
        }
        .padding()
        .background(cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(borderColor, lineWidth: 1.5)
        )
    }

    private var headerIcon: String {
        switch risk {
        case .green: "checkmark.shield.fill"
        case .orange: "exclamationmark.triangle.fill"
        case .red: "xmark.shield.fill"
        }
    }

    private var headerText: String {
        switch risk {
        case .green: "GROEN"
        case .orange: "ORANJE"
        case .red: "ROOD"
        }
    }

    private var headerColor: Color {
        switch risk {
        case .green: .consentGreen
        case .orange: .consentOrange
        case .red: .consentRed
        }
    }

    private var cardBackground: Color {
        switch risk {
        case .green: .consentGreen.opacity(0.08)
        case .orange: .consentOrange.opacity(0.08)
        case .red: .consentRed.opacity(0.08)
        }
    }

    private var borderColor: Color {
        switch risk {
        case .green: .consentGreen.opacity(0.3)
        case .orange: .consentOrange.opacity(0.3)
        case .red: .consentRed.opacity(0.3)
        }
    }
}
