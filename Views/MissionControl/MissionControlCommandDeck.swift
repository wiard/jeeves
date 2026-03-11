import SwiftUI

struct MissionControlCommandDeck: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Command Deck")
                .font(.headline)

            Text("Mission Control command surface placeholder")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.secondarySystemBackground))
        )
    }
}

#Preview {
    MissionControlCommandDeck()
}
