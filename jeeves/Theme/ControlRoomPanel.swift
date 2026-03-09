import SwiftUI

struct ControlRoomPanelStyle: ViewModifier {
    var padding: CGFloat = 16

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color.white.opacity(0.06))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(Color.white.opacity(0.14), lineWidth: 1)
                    )
            )
    }
}

extension View {
    func browserPanel(padding: CGFloat = 16) -> some View {
        modifier(ControlRoomPanelStyle(padding: padding))
    }
}
