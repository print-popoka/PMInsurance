import Foundation
import Combine
import CoreMotion

@MainActor
final class MotionManager: ObservableObject {
    private let manager = CMMotionManager()
    @Published private(set) var magnitude: Double = 0
    @Published private(set) var spike: Bool = false
    @Published private(set) var crashDetected: Bool = false
    @Published private(set) var isAvailable: Bool = false

    /// FNOL auto-trigger threshold — acceleration magnitude in g units.
    /// Light shake (2g) only fires `spike`; strong shake / drop (4g+) fires `crashDetected`.
    var crashThreshold: Double = 4.0

    init() {
        isAvailable = manager.isDeviceMotionAvailable
    }

    func start() {
        guard manager.isDeviceMotionAvailable, !manager.isDeviceMotionActive else { return }
        manager.deviceMotionUpdateInterval = 1.0 / 30.0
        manager.startDeviceMotionUpdates(to: .main) { [weak self] motion, _ in
            guard let self, let motion else { return }
            let a = motion.userAcceleration
            let m = sqrt(a.x * a.x + a.y * a.y + a.z * a.z)
            self.magnitude = m
            if m > 2.0 && !self.spike {
                self.spike = true
                Task { @MainActor [weak self] in
                    try? await Task.sleep(for: .milliseconds(1400))
                    self?.spike = false
                }
            }
            if m > self.crashThreshold && !self.crashDetected {
                self.crashDetected = true
                Task { @MainActor [weak self] in
                    try? await Task.sleep(for: .milliseconds(1200))
                    self?.crashDetected = false
                }
            }
        }
    }

    func stop() {
        manager.stopDeviceMotionUpdates()
    }
}
