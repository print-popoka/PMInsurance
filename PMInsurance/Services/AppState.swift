import SwiftUI
import Foundation
import Combine

/// Shared app state. Holds navigation, slider values, trigger signals,
/// and the advisor flag. The advisor writes here to run the automated demo.
enum AppScreen: Hashable, Sendable {
    case sim, coord, behavior, chat, fnol
}

@MainActor
final class AppState: ObservableObject {
    // Navigation stack
    @Published var path: [AppScreen] = []

    // Shared sliders for PremiumSimulator + Coordinate views
    @Published var pmShare: Double = UserRideHistory.averagePMShare
    @Published var rs: Double = UserRideHistory.averageRS

    // BehaviorView's 5-feature sliders
    @Published var risks: [String: Double] = AppState.initialRisks()

    // External FNOL trigger signal (from advisor or crash auto-detection)
    @Published var pendingFNOLStart: Bool = false

    // Auto-sent query on chatbot entry (used by Home advisor card suggestions)
    @Published var pendingChatQuery: String? = nil

    // Subtitle shown during advisor auto-demo
    @Published var advisorNarration: String? = nil

    // Whether advisor is currently driving the demo (for UI watermark)
    @Published var advisorActive: Bool = false

    static func initialRisks() -> [String: Double] {
        [
            "accel":    38,
            "swerve":   20,
            "sidewalk": Double(UserRideHistory.totalSidewalkAlerts) * 5,
            "night":    UserRideHistory.averageNightRatio,
            "distance": min(100, (UserRideHistory.totalDistanceKm / 7) * 3),
        ]
    }

    // MARK: - Advisor command dispatch

    func navigate(to screen: AppScreen) {
        if path.last != screen {
            path.append(screen)
        }
    }

    func setSliders(pmShare newPM: Double? = nil, rs newRS: Double? = nil) {
        withAnimation(.spring(response: 0.7, dampingFraction: 0.75)) {
            if let newPM { pmShare = max(0, min(100, newPM)) }
            if let newRS { rs = max(0, min(100, newRS)) }
        }
    }

    func setRisk(_ key: String, value: Double) {
        withAnimation(.spring(response: 0.7, dampingFraction: 0.75)) {
            risks[key] = max(0, min(100, value))
        }
    }

    func requestFNOLStart() {
        pendingFNOLStart = true
    }

    func acknowledgeFNOLStart() {
        pendingFNOLStart = false
    }

    /// Set a query to auto-send the moment ChatbotView appears.
    func navigateToChat(with query: String? = nil) {
        pendingChatQuery = query
        navigate(to: .chat)
    }

    func acknowledgeChatQuery() {
        pendingChatQuery = nil
    }

    // MARK: - Advisor subtitle

    func showNarration(_ text: String, duration: TimeInterval = 3.5) {
        advisorNarration = text
        Task {
            try? await Task.sleep(for: .seconds(duration))
            await MainActor.run {
                if self.advisorNarration == text {
                    self.advisorNarration = nil
                }
            }
        }
    }

    func startAdvisorMode() {
        advisorActive = true
    }

    func stopAdvisorMode() {
        advisorActive = false
        advisorNarration = nil
    }

    // MARK: - Zone presets (common demo shortcuts)

    func applyZonePreset(_ zone: Zone) {
        switch zone {
        case .I:   setSliders(pmShare: 18, rs: 82)
        case .II:  setSliders(pmShare: 60, rs: 85)
        case .III: setSliders(pmShare: 18, rs: 55)
        case .IV:  setSliders(pmShare: 65, rs: 45)
        }
    }
}
