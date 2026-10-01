import Foundation

nonisolated struct VehicleInput : Equatable {
    /// 0...1
    var throttle = 0.0
    /// 0...1
    var brake = 0.0
    /// -1 (full right) ... 1 (full left)
    var steering = 0.0
    var handbrake = false
    var nitrous = false
}

nonisolated enum ShiftQuality : String, Codable {
    case perfect
    case good
    case early
    case late

    var title : String {
        rawValue.uppercased()
    }

    /// Multiplier applied to the car's base shift duration.
    var durationMultiplier : Double {
        switch self {
        case .perfect:
            return 0.55
        case .good:
            return 1.0
        case .early:
            return 1.35
        case .late:
            return 1.1
        }
    }
}

nonisolated struct VehicleEvents : OptionSet {
    let rawValue : Int

    static let upshift = VehicleEvents( rawValue : 1 << 0 )
    static let downshift = VehicleEvents( rawValue : 1 << 1 )
    static let blowOff = VehicleEvents( rawValue : 1 << 2 )
    static let backfire = VehicleEvents( rawValue : 1 << 3 )
    static let limiter = VehicleEvents( rawValue : 1 << 4 )
    static let nitrousStart = VehicleEvents( rawValue : 1 << 5 )
    static let lockup = VehicleEvents( rawValue : 1 << 6 )
}

/// Everything about a car that changes while driving.
nonisolated struct VehicleState : Equatable {
    var position : Vec2 = .zero
    var heading : Double = 0
    var velocity : Vec2 = .zero
    var yawRate : Double = 0
    var steeringAngle : Double = 0

    /// -1 reverse, 0 neutral, 1...n forward gears.
    var gear : Int = 1
    var engineRPM : Double = 900
    var throttle : Double = 0
    var brake : Double = 0
    var shiftTimeRemaining : Double = 0
    var lastShiftQuality : ShiftQuality?
    var perfectShiftBoostRemaining : Double = 0
    var limiterTime : Double = 0
    var reverseHoldTime : Double = 0

    var turboSpool : Double = 0
    var nitrousRemaining : Double = 0
    var isNitrousActive = false

    /// Clutch-dump RPM that decays after a standing launch.
    var launchRPM : Double = 0
    var launchBogRemaining : Double = 0

    /// 0...1 wheelspin of the driven axle.
    var wheelspin : Double = 0
    /// 0...1 how saturated each axle's lateral grip is (1 = sliding).
    var frontSlide : Double = 0
    var rearSlide : Double = 0
    var isLockingWheels = false

    var longitudinalAcceleration : Double = 0
    var lateralAcceleration : Double = 0
    var tyreWear : Double = 0
    var distanceTravelled : Double = 0
    var gripUsed : Double = 1

    var events : VehicleEvents = []

    var forward : Vec2 {
        Vec2( angle : heading )
    }

    var speed : Double {
        velocity.length
    }

    var forwardSpeed : Double {
        velocity.dot( forward )
    }

    var lateralSpeed : Double {
        velocity.dot( forward.perpendicular )
    }

    /// Signed angle between where the car points and where it travels. Positive = sliding left of the nose.
    var slipAngle : Double {
        guard speed > 1.5 else {
            return 0
        }

        return wrapAngle( velocity.angle - heading )
    }

    var driftAngleDegrees : Double {
        abs( slipAngle ) * 180 / .pi
    }
}
