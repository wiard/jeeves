import SwiftUI

struct ControlRoomPanelStyle: ViewModifier {
    var padding: CGFloat = 16

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [Color.jeevesPanelStrong, Color.jeevesPanel],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(Color.jeevesLine.opacity(0.6), lineWidth: 1)
                    )
            )
            .shadow(color: Color.jeevesSky.opacity(0.10), radius: 16, y: 8)
    }
}

struct BriefingPanelStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.white,
                                Color.jeevesPanelStrong
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(Color.jeevesLine.opacity(0.55), lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .shadow(color: Color.jeevesSky.opacity(0.09), radius: 16, y: 8)
    }
}

extension View {
    func browserPanel(padding: CGFloat = 16) -> some View {
        modifier(ControlRoomPanelStyle(padding: padding))
    }

    func briefingPanel() -> some View {
        modifier(BriefingPanelStyle())
    }
}
