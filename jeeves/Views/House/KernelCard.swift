import SwiftUI

struct KernelCard: View {
    let consent: ConsentStatus

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Kernel", systemImage: "cpu")
                .font(.jeevesHeadline)

            HStack {
                Text("Policy:")
                    .font(.jeevesCaption)
                    .foregroundStyle(.secondary)
                Text("strict")
                    .font(.jeevesMono)
                Text("[ORANJE]")
                    .font(.jeevesMono)
                    .foregroundStyle(.consentOrange)
            }

            HStack {
                Text("Consent TTL:")
                    .font(.jeevesCaption)
                    .foregroundStyle(.secondary)
                Text("15 min")
                    .font(.jeevesMono)
            }

            HStack {
                Text("Actieve approvals:")
                    .font(.jeevesCaption)
                    .foregroundStyle(.secondary)
                Text("\(consent.active)")
                    .font(.jeevesMono)
            }
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}
