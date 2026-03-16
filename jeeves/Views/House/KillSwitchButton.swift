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
                Text(isActive ? "ON" : "OFF")
                    .font(.jeevesMono)
                    .foregroundStyle(isActive ? Color.consentRed : Color.consentGreen)
            }

            Button(action: { showConfirmation = true }) {
                HStack {
                    Image(systemName: isActive ? "checkmark.shield" : "exclamationmark.octagon.fill")
                    Text(isActive ? "DEACTIVATE KILL SWITCH" : "ACTIVATE KILL SWITCH")
                        .fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(isActive ? .consentGreen : .consentRed)
            .accessibilityLabel(isActive ? "Deactivate kill switch" : "Activate kill switch")
            .alert(
                isActive ? "Deactivate kill switch?" : "Are you sure?",
                isPresented: $showConfirmation
            ) {
                Button(isActive ? "Deactivate" : "Activate", role: isActive ? nil : .destructive) {
                    JeevesHaptics.killSwitch()
                    if isActive {
                        onDeactivate()
                    } else {
                        onActivate()
                    }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text(isActive
                    ? "Jeeves will resume normal operations."
                    : "All running actions will be stopped immediately. Jeeves will be fully shut down."
                )
            }
        }
        .padding()
        .background(Color(.secondarySystemFill))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}
