import Foundation

nonisolated enum Drivetrain : String, Codable, CaseIterable, Identifiable {
    case fwd
    case rwd
    case awd

    var id : String {
        rawValue
    }

    var title : String {
        rawValue.uppercased()
    }

    var summary : String {
        switch self {
        case .fwd:
            return "Front-wheel drive. Stable and forgiving, but pushes wide under power."
        case .rwd:
            return "Rear-wheel drive. Rotates on the throttle and loves to drift."
        case .awd:
            return "All-wheel drive. Brutal launches and planted corner exits."
        }
    }
}

nonisolated enum TyreCompound : String, Codable, CaseIterable, Identifiable {
    case street
    case sport
    case semiSlick
    case drag
    case drift

    var id : String {
        rawValue
    }

    var title : String {
        switch self {
        case .street:
            return "Street"
        case .sport:
            return "Sport"
        case .semiSlick:
            return "Semi-Slick"
        case .drag:
            return "Drag Radial"
        case .drift:
            return "Drift"
        }
    }

    var summary : String {
        switch self {
        case .street:
            return "Balanced all-rounder."
        case .sport:
            return "More grip everywhere."
        case .semiSlick:
            return "Maximum cornering grip with a sharp limit."
        case .drag:
            return "Huge straight-line traction, vague in corners."
        case .drift:
            return "Low, progressive grip and a loose rear for long controllable slides."
        }
    }

    /// Multiplier on lateral (cornering) grip.
    var lateralGrip : Double {
        switch self {
        case .street:
            return 1.00
        case .sport:
            return 1.08
        case .semiSlick:
            return 1.18
        case .drag:
            return 0.88
        case .drift:
            return 0.90
        }
    }

    /// Multiplier on longitudinal (traction / braking) grip.
    var longitudinalGrip : Double {
        switch self {
        case .street:
            return 1.00
        case .sport:
            return 1.07
        case .semiSlick:
            return 1.12
        case .drag:
            return 1.40
        case .drift:
            return 0.92
        }
    }

    /// Pacejka-style B term: how quickly force builds with slip angle.
    var stiffness : Double {
        switch self {
        case .street:
            return 11
        case .sport:
            return 12.5
        case .semiSlick:
            return 15
        case .drag:
            return 9
        case .drift:
            return 9.5
        }
    }

    /// Pacejka-style C term: higher values drop off harder past the limit.
    var falloff : Double {
        switch self {
        case .street:
            return 1.40
        case .sport:
            return 1.42
        case .semiSlick:
            return 1.55
        case .drag:
            return 1.45
        case .drift:
            return 1.22
        }
    }

    /// Drift tyres are built to let go: a neutral balance, and power fully breaks the rear loose.
    /// Every other compound keeps the rear planted so the car pushes wide at the limit instead of spinning.
    var isLoose : Bool {
        self == .drift
    }

    /// Rear cornering grip relative to the front.
    var rearGripBias : Double {
        isLoose ? 1 : 1.16
    }

    /// How much of a tyre's cornering grip drive torque takes with an open differential (a locked one takes it all).
    var openDifferentialCoupling : Double {
        isLoose ? 1 : 0.4
    }

    /// Share of cornering grip a fully spinning driven tyre loses.
    var wheelspinGripLoss : Double {
        isLoose ? 0.5 : 0.35
    }

    var wearRate : Double {
        switch self {
        case .street:
            return 0.6
        case .sport:
            return 0.8
        case .semiSlick:
            return 1.3
        case .drag:
            return 1.1
        case .drift:
            return 1.0
        }
    }
}

/// The complete physical definition of a car as driven (base car + upgrades + tuning).
nonisolated struct VehicleSpec : Codable, Hashable {
    var massKilograms : Double
    var peakPowerKilowatts : Double
    var peakTorqueNewtonMetres : Double
    var peakTorqueRPM : Double
    var peakPowerRPM : Double
    var redlineRPM : Double
    var idleRPM : Double = 900
    var cylinders : Int = 4

    var gearRatios : [Double]
    var finalDrive : Double
    var shiftDuration : Double
    var drivetrain : Drivetrain
    var frontTorqueSplit : Double = 0.4
    var drivelineEfficiency : Double = 0.86

    var wheelbase : Double
    var length : Double
    var width : Double
    var frontWeightFraction : Double
    var centreOfGravityHeight : Double
    var wheelRadius : Double = 0.32

    var tyreGrip : Double
    var tyre : TyreCompound = .street
    var tyrePressure : Double = 0
    var brakeDecelerationG : Double
    var brakeBias : Double = 0.62
    var dragCoefficient : Double
    var downforceCoefficient : Double = 0
    var rollingResistance : Double = 0.015

    var steeringLock : Double = 0.58
    var steeringSensitivity : Double = 1
    var differentialLock : Double = 0.2
    var suspensionBalance : Double = 0
    var suspensionStiffness : Double = 0

    var turboBoost : Double = 0
    var turboLag : Double = 0.9
    var superchargerBoost : Double = 0
    var nitrousCapacity : Double = 0
    var nitrousBoost : Double = 0.35

    var gearCount : Int {
        gearRatios.count
    }

    /// Naturally-aspirated torque at the crank, before boost or nitrous.
    func baseTorque( atRPM rpm : Double ) -> Double {
        let powerRPMTorque = min(
            peakTorqueNewtonMetres,
            peakPowerKilowatts * 1_000 / ( peakPowerRPM * 2 * .pi / 60 )
        )

        if rpm <= peakTorqueRPM {
            return peakTorqueNewtonMetres
                * ( 0.62 + 0.38 * smoothstep( idleRPM, peakTorqueRPM, rpm ) )
        }

        if rpm <= peakPowerRPM {
            let amount = ( rpm - peakTorqueRPM ) / max( peakPowerRPM - peakTorqueRPM, 1 )
            return lerp( peakTorqueNewtonMetres, powerRPMTorque, amount )
        }

        let amount = clamp( ( rpm - peakPowerRPM ) / max( redlineRPM - peakPowerRPM, 1 ), 0, 1.2 )
        return powerRPMTorque * ( 1 - 0.18 * amount )
    }

    /// Torque including forced induction at a given spool level (0...1).
    func torque( atRPM rpm : Double, boost : Double ) -> Double {
        let superchargerGain = superchargerBoost * ( 0.6 + 0.4 * rpm / redlineRPM )
        return baseTorque( atRPM : rpm ) * ( 1 + turboBoost * boost + superchargerGain )
    }

    func overallRatio( forGear gear : Int ) -> Double {
        switch gear {
        case 1 ... gearCount:
            return gearRatios[ gear - 1 ] * finalDrive
        case -1:
            return -gearRatios[ 0 ] * finalDrive * 1.1
        default:
            return 0
        }
    }

    func wheelRPM( forSpeed speed : Double, gear : Int ) -> Double {
        let wheelRadiansPerSecond : Double = speed / wheelRadius
        let radiansPerSecondToRPM : Double = 60 / ( 2 * Double.pi )
        return abs( wheelRadiansPerSecond * overallRatio( forGear : gear ) * radiansPerSecondToRPM )
    }

    func speedAtRPM( _ rpm : Double, gear : Int ) -> Double {
        let ratio = abs( overallRatio( forGear : gear ) )

        guard ratio > 0 else {
            return 0
        }

        return rpm * 2 * .pi / 60 * wheelRadius / ratio
    }

    /// Peak power figure shown in the UI (includes full boost).
    var displayedPowerKilowatts : Double {
        let radiansPerSecondPerRPM : Double = 2 * Double.pi / 60
        let powers : [Double] = stride( from : idleRPM, through : redlineRPM, by : 50 ).map { rpm in
            torque( atRPM : rpm, boost : 1 ) * rpm * radiansPerSecondPerRPM / 1_000
        }
        return powers.max() ?? peakPowerKilowatts
    }

    var displayedTorqueNewtonMetres : Double {
        stride( from : idleRPM, through : redlineRPM, by : 50 )
            .map { torque( atRPM : $0, boost : 1 ) }
            .max() ?? peakTorqueNewtonMetres
    }

    /// Generates a progressive gear set whose top gear reaches `topSpeed` (m/s) at redline.
    static func gearRatios(
        count : Int,
        topSpeed : Double,
        redlineRPM : Double,
        finalDrive : Double,
        wheelRadius : Double = 0.32,
        spread : Double = 3.4
    ) -> [Double] {
        let topOverall = redlineRPM * 2 * .pi / 60 * wheelRadius / topSpeed
        let top = topOverall / finalDrive
        let first = top * spread

        return ( 0 ..< count ).map { index in
            let amount = pow( Double( index ) / Double( max( count - 1, 1 ) ), 0.82 )
            return first * pow( top / first, amount )
        }
    }
}
