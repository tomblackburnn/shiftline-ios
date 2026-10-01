import Foundation

nonisolated enum TuningPreset : String, CaseIterable, Identifiable {
    case drag
    case grip
    case drift
    case topSpeed

    var id : String {
        rawValue
    }

    var title : String {
        switch self {
        case .drag:
            return "Drag"
        case .grip:
            return "Grip"
        case .drift:
            return "Drift"
        case .topSpeed:
            return "Top Speed"
        }
    }

    var summary : String {
        switch self {
        case .drag:
            return "Short gearing, locked diff, soft tyres for launch."
        case .grip:
            return "Neutral balance and low pressures for corners."
        case .drift:
            return "Locked diff, loose rear, quick steering."
        case .topSpeed:
            return "Long gearing and hard tyres for the highway."
        }
    }
}

/// Player-adjustable setup. Every value is relative so it works on any car.
nonisolated struct TuningSetup : Codable, Equatable {
    /// Multiplier on the final drive (higher = shorter gearing, quicker acceleration).
    var finalDrive : Double = 1
    /// Per-gear multipliers.
    var gearScales : [Double] = []
    /// Absolute diff lock, clamped to the range the diff upgrade allows.
    var differentialLock : Double?
    var brakeBias : Double = 0.62
    /// -1 understeer (stable) ... 1 oversteer (loose).
    var suspensionBalance : Double = 0
    /// -1 soft (more grip, more drag) ... 1 hard.
    var tyrePressure : Double = 0
    var steeringSensitivity : Double = 1
    /// -1 low ... 1 high.
    var rideHeight : Double = 0
    /// AWD only.
    var frontTorqueSplit : Double?

    static let finalDriveRange = 0.82 ... 1.22
    static let gearScaleRange = 0.88 ... 1.12
    static let brakeBiasRange = 0.5 ... 0.75
    static let steeringRange = 0.75 ... 1.3
    static let torqueSplitRange = 0.2 ... 0.6

    func applying( _ preset : TuningPreset ) -> TuningSetup {
        var updatedSetup = TuningSetup()
        updatedSetup.gearScales = gearScales.map { _ in 1 }

        switch preset {
        case .drag:
            updatedSetup.finalDrive = 1.1
            updatedSetup.differentialLock = 1
            updatedSetup.tyrePressure = -0.7
            updatedSetup.rideHeight = -0.3
            updatedSetup.frontTorqueSplit = 0.3
        case .grip:
            updatedSetup.finalDrive = 1.02
            updatedSetup.differentialLock = 0.35
            updatedSetup.tyrePressure = -0.3
            updatedSetup.suspensionBalance = -0.1
            updatedSetup.rideHeight = -0.6
            updatedSetup.brakeBias = 0.6
        case .drift:
            updatedSetup.finalDrive = 1.06
            updatedSetup.differentialLock = 1
            updatedSetup.suspensionBalance = 0.75
            updatedSetup.tyrePressure = 0.5
            updatedSetup.steeringSensitivity = 1.25
            updatedSetup.brakeBias = 0.55
            updatedSetup.frontTorqueSplit = 0.2
        case .topSpeed:
            updatedSetup.finalDrive = 0.86
            updatedSetup.differentialLock = 0.3
            updatedSetup.tyrePressure = 0.6
            updatedSetup.rideHeight = -0.8
        }

        return updatedSetup
    }
}
