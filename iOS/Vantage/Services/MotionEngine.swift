import CoreMotion
import SwiftUI

/// Reads the device's own attitude and turns it into the live plumb-line/grid
/// overlay's rotation and "steady" state. The pure geometry (`plumbRotation`,
/// `isSteady`, `alignmentScore`) is exposed as static functions so it can be
/// unit-tested without spinning up `CMMotionManager` or a device.
@MainActor
final class MotionEngine: ObservableObject {
    @Published private(set) var roll: Double = 0       // radians, device tilt about its long axis
    @Published private(set) var pitch: Double = 0       // radians, device tilt forward/back
    @Published private(set) var isSteady: Bool = false

    private let manager = CMMotionManager()
    private var rollHistory: [Double] = []
    private var pitchHistory: [Double] = []
    private static let historyLength = 6

    var isAvailable: Bool { manager.isDeviceMotionAvailable }

    func start() {
        guard manager.isDeviceMotionAvailable, !manager.isDeviceMotionActive else { return }
        manager.deviceMotionUpdateInterval = 1.0 / 30.0
        manager.startDeviceMotionUpdates(to: .main) { [weak self] motion, _ in
            guard let self, let motion else { return }
            self.ingest(roll: motion.attitude.roll, pitch: motion.attitude.pitch)
        }
    }

    func stop() {
        manager.stopDeviceMotionUpdates()
    }

    private func ingest(roll newRoll: Double, pitch newPitch: Double) {
        rollHistory.append(newRoll)
        pitchHistory.append(newPitch)
        if rollHistory.count > Self.historyLength { rollHistory.removeFirst() }
        if pitchHistory.count > Self.historyLength { pitchHistory.removeFirst() }

        let wasSteady = isSteady
        let steady = Self.isSteady(rollHistory: rollHistory, pitchHistory: pitchHistory)
        // Values are assigned plainly; the owning view applies its own
        // `.animation(.interpolatingSpring, value:)` so the spring timeline is driven
        // by SwiftUI's view-level animation system rather than nested here.
        roll = newRoll
        pitch = newPitch
        isSteady = steady
        if steady && !wasSteady { Haptics.click() }
    }

    // MARK: Pure geometry (unit-tested)

    /// Counter-rotation so the plumb crosshair stays world-vertical regardless of how
    /// the phone is held, clamped to a usable range so it never flips upside down.
    /// `nonisolated` (and stateless) so it's directly unit-testable without hopping
    /// to the main actor.
    nonisolated static func plumbRotation(roll: Double) -> Angle {
        let clamped = max(-.pi / 2.4, min(.pi / 2.4, roll))
        return Angle(radians: -clamped)
    }

    /// True once recent roll/pitch samples vary less than `threshold` radians —
    /// i.e. the artist is holding the phone still enough to sight against it.
    nonisolated static func isSteady(rollHistory: [Double], pitchHistory: [Double], threshold: Double = 0.035) -> Bool {
        guard rollHistory.count >= 3, pitchHistory.count >= 3 else { return false }
        let rollSpread = (rollHistory.max() ?? 0) - (rollHistory.min() ?? 0)
        let pitchSpread = (pitchHistory.max() ?? 0) - (pitchHistory.min() ?? 0)
        return rollSpread < threshold && pitchSpread < threshold
    }

    /// 0...1 score, 1 = phone held dead level. Drives the overlay's brighten/dim.
    nonisolated static func alignmentScore(roll: Double, pitch: Double) -> Double {
        let magnitude = sqrt(roll * roll + pitch * pitch)
        let normalized = 1 - min(1, magnitude / (.pi / 6))
        return max(0, normalized)
    }
}
