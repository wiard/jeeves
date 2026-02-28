import SwiftUI

struct KillSwitchButton: View {
    let isActive: Bool
    let onActivate: () -> Void
    let onDeactivate: () -> Void

    @State private var showConfirmation = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Kill Switch", systemImage: "power")
                .font(.jeevesHeadline)

            HStack {
                Text("Status:")
                    .font(.jeevesCaption)
                    .foregroundStyle(.secondary)
                Text(isActive ? "AAN" : "UIT")
                    .font(.jeevesMono)
                    .foregroundStyle(isActive ? .consentRed : .consentGreen)
            }

            Button(action: { showConfirmation = true }) {
                HStack {
                    Image(systemName: isActive ? "checkmark.shield" : "exclamationmark.octagon.fill")
                    Text(isActive ? "NOODSTOP DEACTIVEREN" : "NOODSTOP ACTIVEREN")
                        .fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(isActive ? .consentGreen : .consentRed)
            .accessibilityLabel(isActive ? "Noodstop deactiveren" : "Noodstop activeren")
            .alert(
                isActive ? "Noodstop deactiveren?" : "Weet u het zeker, meneer?",
                isPresented: $showConfirmation
            ) {
                Button(isActive ? "Deactiveren" : "Activeren", role: isActive ? nil : .destructive) {
                    JeevesHaptics.killSwitch()
                    if isActive {
                        onDeactivate()
                    } else {
                        onActivate()
                    }
                }
                Button("Annuleren", role: .cancel) {}
            } message: {
                Text(isActive
                    ? "Jeeves zal weer normale operaties hervatten."
                    : "Alle lopende acties worden onmiddellijk gestopt. Jeeves wordt volledig stilgelegd."
                )
            }
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}
