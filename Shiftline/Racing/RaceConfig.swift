import Foundation

nonisolated enum Weather : String, Codable, CaseIterable, Identifiable {
    case clear
    case rain
    case fog

    var id : String {
        rawValue
    }

    var title : String {
        rawValue.capitalized
    }

    /// Rain genuinely lowers grip; fog only limits visibility.
    var gripMultiplier : Double {
        switch self {
        case .clear, .fog:
            return 1
        case .rain:
            return 0.78
        }
    }

    var symbol : String {
        switch self {
        case .clear:
            return "sun.max.fill"
        case .rain:
            return "cloud.rain.fill"
        case .fog:
            return "cloud.fog.fill"
        }
    }
}

nonisolated enum TimeOfDay : String, Codable, CaseIterable, Identifiable {
    case day
    case sunset
    case night

    var id : String {
        rawValue
    }

    var title : String {
        rawValue.capitalized
    }

    var symbol : String {
        switch self {
        case .day:
            return "sun.max"
        case .sunset:
            return "sunset.fill"
        case .night:
            return "moon.stars.fill"
        }
    }
}

nonisolated enum DriftFormat : String, Codable, CaseIterable {
    /// Highest score before the clock runs out.
    case scoreAttack
    /// Only marked zones score.
    case sections
    /// One unbroken combo: dropping the chain banks nothing.
    case chain
    /// Follow a lead car; proximity multiplies the score.
    case tandem

    var title : String {
        switch self {
        case .scoreAttack:
            return "Score Attack"
        case .sections:
            return "Drift Sections"
        case .chain:
            return "Drift Chain"
        case .tandem:
            return "Tandem"
        }
    }
}

nonisolated enum RaceKind : Codable, Equatable {
    case circuit
    case sprint
    case elimination
    case checkpoint( startTime : Double, bonusPerCheckpoint : Double )
    case speedTrap
    case timeAttack
    case drift( DriftFormat, duration : Double )
    case drag
    case endurance
    case practice
    case tutorial( TutorialKind )

    var title : String {
        switch self {
        case .circuit:
            return "Circuit"
        case .sprint:
            return "Sprint"
        case .elimination:
            return "Elimination"
        case .checkpoint:
            return "Checkpoint"
        case .speedTrap:
            return "Speed Trap"
        case .timeAttack:
            return "Time Attack"
        case .drift( let format, _ ):
            return "Drift · \( format.title )"
        case .drag:
            return "Drag"
        case .endurance:
            return "Endurance"
        case .practice:
            return "Free Drive"
        case .tutorial( let kind ):
            return kind.title
        }
    }

    /// Drift events and the drift tutorial are run on drift tyres, whatever the car wears in the garage.
    var usesDriftTyres : Bool {
        switch self {
        case .drift, .tutorial( .drifting ):
            return true
        default:
            return false
        }
    }

    /// Solo modes are scored against medal targets instead of finishing position.
    var isScored : Bool {
        switch self {
        case .checkpoint, .speedTrap, .timeAttack, .drift:
            return true
        default:
            return false
        }
    }

    var usesLaps : Bool {
        switch self {
        case .circuit, .elimination, .timeAttack, .endurance, .practice, .drift:
            return true
        default:
            return false
        }
    }

    var statisticsKey : String {
        switch self {
        case .circuit:
            return "circuit"
        case .sprint:
            return "sprint"
        case .elimination:
            return "elimination"
        case .checkpoint:
            return "checkpoint"
        case .speedTrap:
            return "speedTrap"
        case .timeAttack:
            return "timeAttack"
        case .drift:
            return "drift"
        case .drag:
            return "drag"
        case .endurance:
            return "endurance"
        case .practice:
            return "practice"
        case .tutorial:
            return "tutorial"
        }
    }
}

nonisolated enum TutorialKind : String, Codable, CaseIterable, Identifiable {
    case basics
    case steering
    case shifting
    case dragLaunch
    case drifting
    case circuitRacing
    case tuning

    var id : String {
        rawValue
    }

    var title : String {
        switch self {
        case .basics:
            return "Throttle & Brakes"
        case .steering:
            return "Steering & Lines"
        case .shifting:
            return "Manual Shifting"
        case .dragLaunch:
            return "Drag Launch"
        case .drifting:
            return "Drifting"
        case .circuitRacing:
            return "Circuit Racing"
        case .tuning:
            return "Tuning Basics"
        }
    }

    var summary : String {
        switch self {
        case .basics:
            return "Accelerate, brake and stop in the box."
        case .steering:
            return "Follow the racing line through a sprint route."
        case .shifting:
            return "Shift up in the green zone to gain speed."
        case .dragLaunch:
            return "Hold the revs in the launch window and go on green."
        case .drifting:
            return "Kick the rear out and hold the slide."
        case .circuitRacing:
            return "Complete a lap cleanly against a pace car."
        case .tuning:
            return "Learn what each tuning slider does."
        }
    }
}

nonisolated enum Difficulty : String, Codable, CaseIterable, Identifiable {
    case rookie
    case amateur
    case pro
    case elite
    case legend

    var id : String {
        rawValue
    }

    var title : String {
        rawValue.capitalized
    }

    /// Added to every AI driver's skill. Never changes their car.
    var skillOffset : Double {
        switch self {
        case .rookie:
            return -0.3
        case .amateur:
            return -0.14
        case .pro:
            return 0
        case .elite:
            return 0.08
        case .legend:
            return 0.15
        }
    }

    var rewardMultiplier : Double {
        switch self {
        case .rookie:
            return 0.8
        case .amateur:
            return 0.9
        case .pro:
            return 1.0
        case .elite:
            return 1.15
        case .legend:
            return 1.3
        }
    }

    var defaultAssists : DrivingAssists {
        switch self {
        case .rookie, .amateur:
            return DrivingAssists()
        case .pro:
            var assists = DrivingAssists()
            assists.steeringAssist = false
            return assists
        case .elite, .legend:
            var assists = DrivingAssists.none
            assists.antiLockBrakes = true
            assists.automaticTransmission = true
            return assists
        }
    }
}

/// Gold / silver / bronze thresholds for scored modes. `lowerIsBetter` for times.
nonisolated struct MedalTargets : Codable, Equatable {
    var gold : Double
    var silver : Double
    var bronze : Double
    var lowerIsBetter : Bool

    func placement( for value : Double ) -> Int {
        let beats : ( Double ) -> Bool = { target in
            self.lowerIsBetter ? value <= target : value >= target
        }

        if beats( gold ) {
            return 1
        }

        if beats( silver ) {
            return 2
        }

        return beats( bronze ) ? 3 : 4
    }
}

nonisolated struct RaceEntrant {
    var name : String
    var carID : CarID
    var spec : VehicleSpec
    var appearance : CarAppearance
    var profile : DriverProfile?
    var isPlayer : Bool
    var isRival = false
}

nonisolated struct RaceConfig {
    var eventID : String?
    var title : String
    var trackID : TrackID
    var kind : RaceKind
    var laps : Int = 1
    var weather : Weather = .clear
    var timeOfDay : TimeOfDay = .day
    var entrants : [RaceEntrant]
    var assists : DrivingAssists = DrivingAssists()
    var difficulty : Difficulty = .pro
    /// Base AI skill for the event (0...1) before driver and difficulty offsets.
    var opponentSkill = 0.55
    var targets : MedalTargets?
    var ghost : GhostRecording?

    var player : RaceEntrant? {
        entrants.first { $0.isPlayer }
    }
}
