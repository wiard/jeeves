import SwiftUI

struct ChannelsCard: View {
    let channels: [ChannelInfo]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Kanalen", systemImage: "antenna.radiowaves.left.and.right")
                .font(.jeevesHeadline)

            ForEach(channels) { channel in
                HStack {
                    Image(systemName: iconFor(channel.id))
                        .frame(width: 24)
                    Text(channel.id)
                        .font(.jeevesBody)
                    Spacer()
                    Text(channel.trust.rawValue)
                        .font(.jeevesMono)
                        .foregroundStyle(colorFor(channel.trust))
                    Circle()
                        .fill(channel.connected ? Color.consentGreen : Color.secondary.opacity(0.3))
                        .frame(width: 8, height: 8)
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel("\(channel.id), \(channel.trust.rawValue), \(channel.connected ? "verbonden" : "niet verbonden")")
            }
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func iconFor(_ channelId: String) -> String {
        switch channelId {
        case "ios-app": "iphone"
        case "webchat": "desktopcomputer"
        case "whatsapp": "phone"
        case "ussd": "antenna.radiowaves.left.and.right"
        case "telegram": "paperplane"
        default: "questionmark.circle"
        }
    }

    private func colorFor(_ trust: TrustLevel) -> Color {
        switch trust {
        case .trusted: .consentGreen
        case .semi: .consentOrange
        case .untrusted: .consentRed
        }
    }
}
