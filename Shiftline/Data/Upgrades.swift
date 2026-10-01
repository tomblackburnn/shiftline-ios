import Foundation

nonisolated enum UpgradeCategory : String, Codable, CaseIterable, Identifiable, CodingKeyRepresentable {
    case engine
    case forcedInduction
    case ecu
    case exhaust
    case intake
    case transmission
    case clutch
    case differential
    case tyres
    case brakes
    case suspension
    case weightReduction
    case aero
    case nitrous
    case drivetrain

    var id : String {
        rawValue
    }

    var title : String {
        switch self {
        case .engine:
            return "Engine"
        case .forcedInduction:
            return "Turbo / Supercharger"
        case .ecu:
            return "ECU"
        case .exhaust:
            return "Exhaust"
        case .intake:
            return "Intake"
        case .transmission:
            return "Transmission"
        case .clutch:
            return "Clutch"
        case .differential:
            return "Differential"
        case .tyres:
            return "Tyres"
        case .brakes:
            return "Brakes"
        case .suspension:
            return "Suspension"
        case .weightReduction:
            return "Weight Reduction"
        case .aero:
            return "Aero"
        case .nitrous:
            return "Nitrous"
        case .drivetrain:
            return "Drivetrain"
        }
    }

    var symbol : String {
        switch self {
        case .engine:
            return "engine.combustion.fill"
        case .forcedInduction:
            return "fanblades.fill"
        case .ecu:
            return "cpu.fill"
        case .exhaust:
            return "flame.fill"
        case .intake:
            return "wind"
        case .transmission:
            return "gearshape.2.fill"
        case .clutch:
            return "circle.circle.fill"
        case .differential:
            return "arrow.triangle.branch"
        case .tyres:
            return "circle.dashed"
        case .brakes:
            return "exclamationmark.octagon.fill"
        case .suspension:
            return "arrow.up.and.down.circle.fill"
        case .weightReduction:
            return "scalemass.fill"
        case .aero:
            return "airplane"
        case .nitrous:
            return "bolt.fill"
        case .drivetrain:
            return "point.3.connected.trianglepath.dotted"
        }
    }

    var summary : String {
        switch self {
        case .engine:
            return "Internals, cams and pistons. Raises power and torque everywhere."
        case .forcedInduction:
            return "Fit or upgrade a turbo or supercharger. Turbos lag, then hit hard."
        case .ecu:
            return "Remap fuel and timing. More power and a higher redline."
        case .exhaust:
            return "Free-flowing manifolds and pipes. A little power, a lot of noise."
        case .intake:
            return "Colder, freer air. More power and quicker turbo spool."
        case .transmission:
            return "Faster shifts. Unlocks individual gear ratio tuning."
        case .clutch:
            return "Stronger clutch plates. Quicker shifts and less driveline loss."
        case .differential:
            return "Limited-slip diff. Better traction and a wider lock range for drifting."
        case .tyres:
            return "Better rubber and new compounds: sport, drift, drag and semi-slick."
        case .brakes:
            return "Bigger discs and callipers. Stop later, stop straighter."
        case .suspension:
            return "Coilovers and bars. Sharper response and unlocks balance tuning."
        case .weightReduction:
            return "Strip interior, carbon panels. Faster everywhere."
        case .aero:
            return "Splitters and wings. Downforce for high-speed grip, at a drag cost."
        case .nitrous:
            return "A bottle of nitrous oxide. Limited, strategic bursts of power."
        case .drivetrain:
            return "Lighter shafts and axles. Higher levels unlock drivetrain conversions."
        }
    }

    /// Relative price of this category against the car's value.
    var costWeight : Double {
        switch self {
        case .engine:
            return 1.2
        case .forcedInduction:
            return 1.3
        case .ecu:
            return 0.5
        case .exhaust:
            return 0.4
        case .intake:
            return 0.35
        case .transmission:
            return 0.7
        case .clutch:
            return 0.4
        case .differential:
            return 0.5
        case .tyres:
            return 0.5
        case .brakes:
            return 0.5
        case .suspension:
            return 0.7
        case .weightReduction:
            return 0.9
        case .aero:
            return 0.8
        case .nitrous:
            return 0.6
        case .drivetrain:
            return 0.6
        }
    }

    /// What one level does, shown in the upgrade shop.
    func effect( atLevel level : Int ) -> String {
        guard level > 0 else {
            return "Stock"
        }

        switch self {
        case .engine:
            return "+\( String( format : "%.1f", 4.5 * Double( level ) ) )% power and torque"
        case .forcedInduction:
            return "+\( level * 8 )% boost, quicker spool"
        case .ecu:
            return "+\( level * 2 )% power, +\( level * 120 ) RPM redline"
        case .exhaust:
            return "+\( String( format : "%.1f", 1.5 * Double( level ) ) )% power, louder"
        case .intake:
            return "+\( String( format : "%.1f", 1.5 * Double( level ) ) )% power, \( level * 6 )% less turbo lag"
        case .transmission:
            return "\( level * 12 )% faster shifts\( level >= 2 ? ", gear tuning" : "" )"
        case .clutch:
            return "\( level * 5 )% faster shifts, less driveline loss"
        case .differential:
            return "Lock range up to \( Int( ( 0.15 * Double( level ) ) * 100 ) )% higher"
        case .tyres:
            return "+\( String( format : "%.1f", 2.5 * Double( level ) ) )% grip, unlocks compounds"
        case .brakes:
            return "+\( level * 8 )% braking force"
        case .suspension:
            return "+\( String( format : "%.1f", 1.2 * Double( level ) ) )% grip, sharper response"
        case .weightReduction:
            return "-\( level * 3 )% weight"
        case .aero:
            return "+downforce level \( level ), +\( level * 2 )% drag"
        case .nitrous:
            return "\( UpgradeRules.nitrousCapacity( level : level ) )s of nitrous"
        case .drivetrain:
            return "+\( Int( Double( level ) * 1.2 ) )% efficiency\( level >= 2 ? ", conversions" : "" )"
        }
    }
}

nonisolated enum UpgradeRules {
    static let maximumLevel = 4
    static let levelNames = [ "Stock", "Street", "Sport", "Race", "Pro" ]
    private static let levelPriceFactors = [ 0, 0.05, 0.10, 0.18, 0.30 ]

    /// Driver level needed to buy each upgrade level.
    static let requiredDriverLevel = [ 0, 1, 3, 6, 12 ]

    static func cost( of category : UpgradeCategory, level : Int, carPrice : Int ) -> Int {
        guard level >= 1 && level <= maximumLevel else {
            return 0
        }

        let scaled = Double( carPrice ) * category.costWeight * levelPriceFactors[ level ]
        let minimum = Double( 350 * level )
        return Int( ( max( scaled, minimum ) / 50 ).rounded() ) * 50
    }

    static func nitrousCapacity( level : Int ) -> Double {
        [ 0, 3, 4.5, 6, 8 ][ clamp( level, 0, maximumLevel ) ]
    }

    static func unlockedCompounds( tyreLevel : Int ) -> [TyreCompound] {
        var compounds : [TyreCompound] = [ .street ]

        if tyreLevel >= 1 {
            compounds += [ .sport, .drift ]
        }

        if tyreLevel >= 2 {
            compounds.append( .drag )
        }

        if tyreLevel >= 3 {
            compounds.append( .semiSlick )
        }

        return compounds
    }

    static func availableDrivetrains( for car : CarDefinition, drivetrainLevel : Int ) -> [Drivetrain] {
        guard drivetrainLevel >= 2 else {
            return [ car.drivetrain ]
        }

        switch car.drivetrain {
        case .awd:
            return [ .awd, .rwd ]
        case .rwd:
            return drivetrainLevel >= 3 ? [ .rwd, .awd ] : [ .rwd ]
        case .fwd:
            return drivetrainLevel >= 3 ? [ .fwd, .awd ] : [ .fwd ]
        }
    }

    static let conversionCost = 6_000
}
