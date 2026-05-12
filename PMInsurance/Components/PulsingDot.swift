import SwiftUI

struct PulsingDot: View {
    var color: Color = .white
    var size: CGFloat = 18
    var ringColor: Color = .white

    @State private var pulse: Bool = false

    var body: some View {
        ZStack {
            Circle()
                .stroke(ringColor.opacity(pulse ? 0 : 0.6), lineWidth: 3)
                .frame(width: size + (pulse ? 28 : 0), height: size + (pulse ? 28 : 0))
            Circle()
                .fill(color)
                .frame(width: size, height: size)
                .overlay(Circle().strokeBorder(.white, lineWidth: 2))
                .shadow(color: ringColor.opacity(0.6), radius: 8)
        }
        .onAppear { pulse = true }
        .animation(.easeOut(duration: 1.6).repeatForever(autoreverses: false), value: pulse)
    }
}
