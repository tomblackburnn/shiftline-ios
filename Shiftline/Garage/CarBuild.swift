import Foundation

/// Turns an owned car (base definition + upgrades + tuning) into the physics spec it races with.
nonisolated struct CarBuild {
    let owned : OwnedCar

    var definition : CarDefinition {
        owned.definition
    }

    var maximumDifferentialLock : Double {
        min( definition.differentialLock + 0.15 * Double( owned.level( of : .differential ) ) + 0.1, 1 )
    }

    var minimumDifferentialLock : Double {
        max( definition.differentialLock - 0.25, 0 )
    }

    var allowsGearTuning : Bool {
        owned.level( of : .transmission ) >= 2
    }

    var allowsSuspensionTuning : Bool {
        owned.level( of : .suspension ) >= 1
    }

    var spec : VehicleSpec {
        var spec = definition.baseSpec
        let level : ( UpgradeCategory ) -> Double = { Double( owned.level( of : $0 ) ) }

        // Power.
        let powerGain = ( 1 + 0.045 * level( .engine ) )
            * ( 1 + 0.02 * level( .ecu ) )
            * ( 1 + 0.015 * level( .exhaust ) )
            * ( 1 + 0.015 * level( .intake ) )
        spec.peakPowerKilowatts *= powerGain
        spec.peakTorqueNewtonMetres *= powerGain
        spec.redlineRPM += 120 * level( .ecu )
        spec.peakPowerRPM += 100 * level( .ecu )

        // Forced induction.
        let inductionLevel = level( .forcedInduction )

        switch definition.aspiration {
        case .turbo:
            spec.turboBoost += 0.06 * inductionLevel
            spec.turboLag *= 1 - 0.06 * inductionLevel
        case .supercharged:
            spec.superchargerBoost += 0.05 * inductionLevel
        case .natural:
            switch owned.inductionKit {
            case .turbo where inductionLevel > 0:
                spec.turboBoost = 0.08 * inductionLevel
                spec.turboLag = 1.0 - 0.08 * inductionLevel
            case .supercharger where inductionLevel > 0:
                spec.superchargerBoost = 0.07 * inductionLevel
            default:
                break
            }
        }

        spec.turboLag *= 1 - 0.06 * level( .intake )

        // Driveline.
        spec.shiftDuration *= ( 1 - 0.12 * level( .transmission ) ) * ( 1 - 0.05 * level( .clutch ) )
        spec.drivelineEfficiency += 0.005 * level( .clutch ) + 0.012 * level( .drivetrain )

        if owned.drivetrainOverride != nil && owned.drivetrain != definition.drivetrain {
            spec.drivetrain = owned.drivetrain

            if owned.drivetrain == .awd {
                spec.massKilograms += 45
                spec.frontTorqueSplit = 0.35
            } else if definition.drivetrain == .awd {
                spec.massKilograms -= 35
            }
        }

        // Chassis.
        spec.tyreGrip *= ( 1 + 0.025 * level( .tyres ) ) * ( 1 + 0.012 * level( .suspension ) )
        spec.tyre = owned.tyreCompound
        spec.brakeDecelerationG *= 1 + 0.08 * level( .brakes )
        spec.suspensionStiffness = 0.2 * level( .suspension )
        spec.centreOfGravityHeight *= 1 - 0.05 * level( .suspension )
        spec.massKilograms *= 1 - 0.03 * level( .weightReduction )
        spec.massKilograms -= 3 * level( .exhaust )
        spec.downforceCoefficient += 0.25 * level( .aero ) * ( 1 + definition.downforceCoefficient )
        spec.dragCoefficient *= 1 + 0.02 * level( .aero )

        // Nitrous.
        let nitrousLevel = owned.level( of : .nitrous )
        spec.nitrousCapacity = UpgradeRules.nitrousCapacity( level : nitrousLevel )
        spec.nitrousBoost = 0.25 + 0.05 * Double( nitrousLevel )

        return applyingTuning( to : spec )
    }

    private func applyingTuning( to base : VehicleSpec ) -> VehicleSpec {
        var spec = base
        let tuning = owned.tuning

        spec.finalDrive *= clamp( tuning.finalDrive, TuningSetup.finalDriveRange.lowerBound, TuningSetup.finalDriveRange.upperBound )

        if allowsGearTuning {
            for index in spec.gearRatios.indices where index < tuning.gearScales.count {
                let scale = clamp( tuning.gearScales[ index ], TuningSetup.gearScaleRange.lowerBound, TuningSetup.gearScaleRange.upperBound )
                spec.gearRatios[ index ] *= scale
            }
        }

        if let lock = tuning.differentialLock {
            spec.differentialLock = clamp( lock, minimumDifferentialLock, maximumDifferentialLock )
        }

        spec.brakeBias = clamp( tuning.brakeBias, TuningSetup.brakeBiasRange.lowerBound, TuningSetup.brakeBiasRange.upperBound )
        spec.tyrePressure = clamp( tuning.tyrePressure, -1, 1 )
        spec.steeringSensitivity = clamp( tuning.steeringSensitivity, TuningSetup.steeringRange.lowerBound, TuningSetup.steeringRange.upperBound )

        if allowsSuspensionTuning {
            spec.suspensionBalance = clamp( tuning.suspensionBalance, -1, 1 )
            let height = clamp( tuning.rideHeight, -1, 1 )
            spec.centreOfGravityHeight *= 1 + 0.08 * height
            spec.downforceCoefficient *= 1 - 0.1 * height
        }

        if spec.drivetrain == .awd, let split = tuning.frontTorqueSplit {
            spec.frontTorqueSplit = clamp( split, TuningSetup.torqueSplitRange.lowerBound, TuningSetup.torqueSplitRange.upperBound )
        }

        return spec
    }
}

nonisolated enum PerformanceClass : String, Codable, CaseIterable, Comparable, Identifiable {
    case d = "D"
    case c = "C"
    case b = "B"
    case a = "A"
    case s = "S"
    case x = "X"

    var id : String {
        rawValue
    }

    var ceiling : Int {
        switch self {
        case .d:
            return 329
        case .c:
            return 449
        case .b:
            return 569
        case .a:
            return 689
        case .s:
            return 819
        case .x:
            return 999
        }
    }

    var colourHex : UInt32 {
        switch self {
        case .d:
            return 0x7FB3D5
        case .c:
            return 0x58D68D
        case .b:
            return 0xF4D03F
        case .a:
            return 0xEB984E
        case .s:
            return 0xEC7063
        case .x:
            return 0xBB8FCE
        }
    }

    init( index : Int ) {
        self = PerformanceClass.allCases.first { index <= $0.ceiling } ?? .x
    }

    private var order : Int {
        PerformanceClass.allCases.firstIndex( of : self ) ?? 0
    }

    static func < ( lhs : PerformanceClass, rhs : PerformanceClass ) -> Bool {
        lhs.order < rhs.order
    }
}

/// Measured performance of a spec. Used for classing, UI bars and event recommendations — never for physics.
nonisolated struct PerformanceProfile : Equatable {
    let zeroToHundred : Double
    let topSpeedKPH : Double
    let lateralG : Double
    let brakingDistance : Double
    let horsepower : Double
    let torque : Double
    let mass : Double
    let driftPotential : Double
    let index : Int

    var performanceClass : PerformanceClass {
        PerformanceClass( index : index )
    }

    /// Player-friendly 0...10 bars.
    var accelerationRating : Double {
        clamp( ( 13 - zeroToHundred ) / 1.05, 0, 10 )
    }

    var topSpeedRating : Double {
        clamp( ( topSpeedKPH - 150 ) / 26, 0, 10 )
    }

    var handlingRating : Double {
        clamp( ( lateralG - 0.8 ) / 0.06, 0, 10 )
    }

    var brakingRating : Double {
        clamp( ( 48 - brakingDistance ) / 2.6, 0, 10 )
    }

    var powerRating : Double {
        clamp( horsepower / 110, 0, 10 )
    }

    var driftRating : Double {
        clamp( driftPotential * 10, 0, 10 )
    }

    nonisolated(unsafe) private static var cache : [VehicleSpec : PerformanceProfile] = [:]
    private static let lock = NSLock()

    static func measure( _ spec : VehicleSpec ) -> PerformanceProfile {
        lock.lock()
        let cached = cache[ spec ]
        lock.unlock()

        if let cached {
            return cached
        }

        let profile = compute( spec )
        lock.lock()
        cache[ spec ] = profile
        lock.unlock()
        return profile
    }

    private static func compute( _ spec : VehicleSpec ) -> PerformanceProfile {
        let model = VehicleModel( spec : spec )
        var state = model.initialState( at : .zero, heading : 0 )
        var input = VehicleInput()
        input.throttle = 1
        var assists = DrivingAssists.none
        assists.tractionControl = true
        var time = 0.0
        var zeroToHundred = 30.0
        let step = 1.0 / 60
        var topSpeed = 0.0

        while time < 45 {
            state = model.advancing( state, with : input, assists : assists, by : step )
            time += step

            if state.gear >= 1 && state.engineRPM >= model.idealUpshiftRPM( fromGear : state.gear ) {
                state = model.shiftingUp( state )
            }

            if zeroToHundred == 30 && state.speed * Units.metresPerSecondToKPH >= 100 {
                zeroToHundred = time
            }

            topSpeed = max( topSpeed, state.speed )
        }

        let referenceSpeed = 150 / Units.metresPerSecondToKPH
        let downforceGain = spec.downforceCoefficient * referenceSpeed * referenceSpeed / ( spec.massKilograms * Units.gravity )
        let lateralG = spec.tyreGrip * spec.tyre.lateralGrip * ( 1 + downforceGain ) * ( 1 + 0.03 * spec.suspensionStiffness )
        let deceleration = min( spec.brakeDecelerationG, spec.tyreGrip * spec.tyre.longitudinalGrip ) * Units.gravity
        let brakingDistance = pow( 100 / Units.metresPerSecondToKPH, 2 ) / ( 2 * deceleration )

        let drivetrainDrift : Double
        switch spec.drivetrain {
        case .rwd:
            drivetrainDrift = 1
        case .awd:
            drivetrainDrift = 0.55
        case .fwd:
            drivetrainDrift = 0.12
        }

        let powerToWeight = spec.displayedPowerKilowatts * 1_000 / spec.massKilograms
        let compoundDrift = spec.tyre == .drift ? 1.2 : ( spec.tyre == .semiSlick ? 0.85 : 1 )
        let driftPotential = drivetrainDrift
            * ( 0.55 + 0.45 * spec.differentialLock )
            * clamp( powerToWeight / 220, 0.35, 1 )
            * ( 1 + 0.12 * spec.suspensionBalance )
            * compoundDrift

        let accelerationScore = clamp( ( 12.5 - zeroToHundred ) / 10, 0, 1 )
        let speedScore = clamp( ( topSpeed * Units.metresPerSecondToKPH - 160 ) / 250, 0, 1 )
        let gripScore = clamp( ( lateralG - 0.85 ) / 0.6, 0, 1 )
        let brakeScore = clamp( ( 46 - brakingDistance ) / 22, 0, 1 )
        let blended = 0.4 * accelerationScore + 0.2 * speedScore + 0.28 * gripScore + 0.12 * brakeScore
        let index = Int( ( 1_092 * blended - 59 ).rounded() )

        return PerformanceProfile(
            zeroToHundred : zeroToHundred,
            topSpeedKPH : topSpeed * Units.metresPerSecondToKPH,
            lateralG : lateralG,
            brakingDistance : brakingDistance,
            horsepower : spec.displayedPowerKilowatts * Units.kilowattsToHorsepower,
            torque : spec.displayedTorqueNewtonMetres,
            mass : spec.massKilograms,
            driftPotential : clamp( driftPotential, 0, 1 ),
            index : clamp( index, 100, 999 )
        )
    }
}
