import SwiftUI

struct NavyBackground: View {
    var soft: Bool = false

    var body: some View {
        ZStack {
            LinearGradient(
                stops: soft ? [
                    .init(color: .bgNavy,     location: 0.0),
                    .init(color: Color(hex: "0E1B30"), location: 0.6),
                    .init(color: Color(hex: "16284a"), location: 1.0),
                ] : [
                    .init(color: .bgNavy,     location: 0.0),
                    .init(color: .bgNavy,     location: 0.3),
                    .init(color: .bgNavyDeep, location: 1.0),
                ],
                startPoint: .top, endPoint: .bottom
            )
            RadialGradient(
                colors: [.iosBlue.opacity(soft ? 0.18 : 0.25), .clear],
                center: .init(x: 0.5, y: -0.1),
                startRadius: 0, endRadius: 480
            )
            if !soft {
                RadialGradient(
                    colors: [.bgNavyDeep.opacity(0.6), .clear],
                    center: .init(x: 0.8, y: 1.0),
                    startRadius: 0, endRadius: 360
                )
            }
        }
        .ignoresSafeArea()
    }
}

#Preview {
    NavyBackground()
}
