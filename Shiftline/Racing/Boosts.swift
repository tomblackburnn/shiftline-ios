import Foundation

/// How a car got away from the line, decided by when the throttle was pressed during the countdown.
nonisolated enum StartQuality : String, Equatable {
    /// Pressed just as "2" appeared and held to the green.
    case perfect
    /// Pressed later in the "2" beat.
    case good
    /// Held from before "2": the wheels light up.
    case tooEarly
    case normal

    /// `holdBegan` is the countdown time remaining when the unbroken throttle hold started (nil if not held at the green).
    init( holdBegan : Double? ) {
        guard let holdBegan else {
            self = .normal
            return
        }

        if holdBegan > 2 {
            self = .tooEarly
        } else if holdBegan > 1.5 {
            self = .perfect
        } else if holdBegan > 1 {
            self = .good
        } else {
            self = .normal
        }
    }

    /// AI drivers roll for their start: better drivers time it more often.
    init( skill : Double, roll : Double ) {
        let perfectChance = 0.1 + 0.4 * skill

        if roll < perfectChance {
            self = .perfect
        } else if roll < perfectChance + 0.3 {
            self = .good
        } else {
            self = .normal
        }
    }

    var title : String {
        switch self {
        case .perfect:
            return "ROCKET START"
        case .good:
            return "GOOD START"
        case .tooEarly:
            return "WHEELSPIN"
        case .normal:
            return ""
        }
    }

    var boost : Boost? {
        switch self {
        case .perfect:
            return Boost( acceleration : 4, duration : 1.5 )
        case .good:
            return Boost( acceleration : 2.5, duration : 1 )
        case .tooEarly, .normal:
            return nil
        }
    }
}

/// A short push along the car's nose, on top of what the engine is doing.
nonisolated struct Boost : Equatable {
    /// Metres per second squared.
    var acceleration : Double
    var duration : Double

    /// Fired when a slipstream charge is full.
    static let slingshot = Boost( acceleration : 3, duration : 1.5 )
    /// Seconds of wheelspin after jumping on the throttle too early.
    static let earlyStartPenalty = 0.9
}

/// Fills while a car sits in another's tow and drains when it pulls out.
nonisolated struct SlipstreamCharge : Equatable {
    /// Seconds of drafting needed to fill the charge, and to lose a full one.
    static let fillTime = 2.5
    static let drainTime = 1.5
    /// Tow strength (0...1) needed before the charge builds.
    static let minimumTow = 0.25

    /// 0...1.
    var level = 0.0

    /// Returns true on the step a full charge fires the slingshot.
    mutating func update( tow : Double, isBoosting : Bool, timeStep : Double ) -> Bool {
        if tow > SlipstreamCharge.minimumTow && !isBoosting {
            level += timeStep / SlipstreamCharge.fillTime
        } else {
            level = max( level - timeStep / SlipstreamCharge.drainTime, 0 )
        }

        guard level >= 1 else {
            return false
        }

        level = 0
        return true
    }
}
