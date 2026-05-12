import SwiftUI

struct ContentView: View {
    @StateObject private var state = AppState()

    var body: some View {
        NavigationStack(path: $state.path) {
            HomeView()
                .navigationDestination(for: AppScreen.self) { screen in
                    switch screen {
                    case .sim:      PremiumSimulatorView()
                    case .coord:    CoordinateView()
                    case .behavior: BehaviorView()
                    case .chat:     ChatbotView()
                    case .fnol:     FNOLView()
                    }
                }
        }
        .tint(.iosBlue)
        .environmentObject(state)
        // Subtitle on top — narrates screen changes / slider moves
        .overlay(alignment: .top) {
            if let narration = state.advisorNarration {
                NarrationBanner(text: narration, dim: false)
                    .padding(.top, 8)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        // "AI auto demo" pill watermark at center — emphasizes to the audience, never overlaps narration
        .overlay(alignment: .center) {
            if state.advisorActive {
                AdvisorWatermark()
                    .transition(.opacity.combined(with: .scale(scale: 0.92)))
                    .allowsHitTesting(false)
            }
        }
        .animation(.snappy(duration: 0.3), value: state.advisorNarration)
        .animation(.snappy(duration: 0.3), value: state.advisorActive)
    }
}

private struct AdvisorWatermark: View {
    @State private var pulse: Bool = false

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "sparkles")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.white.opacity(0.85))
                .opacity(pulse ? 1 : 0.55)
                .animation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true), value: pulse)
            Text("AI 자동 시연 중")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.white.opacity(0.9))
                .tracking(0.8)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(
            Capsule(style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(
                    Capsule(style: .continuous)
                        .fill(Color.iosBlue.opacity(0.10))
                )
        )
        .overlay(
            Capsule(style: .continuous)
                .strokeBorder(Color.iosBlue.opacity(0.35), lineWidth: 0.8)
        )
        .shadow(color: .iosBlue.opacity(0.20), radius: 10, x: 0, y: 4)
        .opacity(0.78)
        .onAppear { pulse = true }
    }
}

private struct NarrationBanner: View {
    let text: String
    var dim: Bool = false

    @State private var pulse: Bool = false

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "sparkles")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.white)
                .opacity(pulse ? 1 : 0.55)
                .animation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true), value: pulse)
            Text(text)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.white)
                .multilineTextAlignment(.leading)
                .lineLimit(2)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(
            Capsule()
                .fill(dim
                    ? AnyShapeStyle(Color.iosBlue.opacity(0.35))
                    : AnyShapeStyle(LinearGradient(colors: [.iosBlue, Color(hex: "2563EB")], startPoint: .leading, endPoint: .trailing))
                )
        )
        .overlay(
            Capsule().strokeBorder(.white.opacity(dim ? 0.12 : 0.25), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.3), radius: 12, x: 0, y: 6)
        .padding(.horizontal, 24)
        .onAppear { pulse = true }
    }
}

#Preview {
    ContentView()
        .preferredColorScheme(.dark)
}
