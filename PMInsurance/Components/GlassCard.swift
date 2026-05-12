import SwiftUI

struct GlassCard<Content: View>: View {
    var strong: Bool = false
    var cornerRadius: CGFloat = Radius.xl
    @ViewBuilder var content: () -> Content

    var body: some View {
        content()
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
            .glassEffect(
                .regular.tint(Color.white.opacity(strong ? 0.10 : 0.05)),
                in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            )
    }
}
