import Foundation

typealias CarID = String

nonisolated enum CarCategory : String, Codable, CaseIterable, Identifiable {
    case hatchback
    case coupe
    case sedan
    case muscle
    case sports
    case roadster
    case supercar
    case hypercar
    case trackCar

    var id : String {
        rawValue
    }

    var title : String {
        switch self {
        case .hatchback:
            return "Hatchback"
        case .coupe:
            return "Coupe"
        case .sedan:
            return "Sedan"
        case .muscle:
            return "Muscle"
        case .sports:
            return "Sports"
        case .roadster:
            return "Roadster"
        case .supercar:
            return "Supercar"
        case .hypercar:
            return "Hypercar"
        case .trackCar:
            return "Track Car"
        }
    }
}

nonisolated enum Aspiration : Codable, Equatable {
    case natural
    case turbo( boost : Double )
    case supercharged( boost : Double )

    var title : String {
        switch self {
        case .natural:
            return "Naturally aspirated"
        case .turbo:
            return "Turbocharged"
        case .supercharged:
            return "Supercharged"
        }
    }
}

nonisolated struct Manufacturer : Identifiable {
    let id : String
    let name : String
    let origin : String
    let tagline : String
    let colourHex : UInt32
}

nonisolated struct CarDefinition : Identifiable {
    let id : CarID
    let manufacturerID : String
    let model : String
    let year : Int
    let category : CarCategory
    let drivetrain : Drivetrain
    let horsepower : Double
    let torqueNewtonMetres : Double
    let massKilograms : Double
    let redlineRPM : Double
    let peakTorqueRPM : Double
    let peakPowerRPM : Double
    let gears : Int
    let designTopSpeedKPH : Double
    let tyreGrip : Double
    let brakeDecelerationG : Double
    let dragCoefficient : Double
    let downforceCoefficient : Double
    let frontWeightFraction : Double
    let wheelbase : Double
    let length : Double
    let width : Double
    let cylinders : Int
    let aspiration : Aspiration
    let differentialLock : Double
    let frontTorqueSplit : Double
    let price : Int
    let unlockLevel : Int
    let strengths : [Discipline]
    let blurb : String
    let defaultPaintHex : UInt32

    var manufacturer : Manufacturer {
        Manufacturers.named( manufacturerID )
    }

    var fullName : String {
        "\( manufacturer.name ) \( model )"
    }

    /// Stock physical spec before upgrades and tuning.
    var baseSpec : VehicleSpec {
        let turboBoost : Double
        let superchargerBoost : Double

        switch aspiration {
        case .natural:
            turboBoost = 0
            superchargerBoost = 0
        case .turbo( let boost ):
            turboBoost = boost
            superchargerBoost = 0
        case .supercharged( let boost ):
            turboBoost = 0
            superchargerBoost = boost
        }

        // Advertised figures are at full boost, so the base engine is the NA share.
        let boostDivisor = 1 + turboBoost + superchargerBoost * 0.96
        let finalDrive = 3.7
        let ratios = VehicleSpec.gearRatios(
            count : gears,
            topSpeed : designTopSpeedKPH / Units.metresPerSecondToKPH,
            redlineRPM : redlineRPM,
            finalDrive : finalDrive,
            spread : gears >= 7 ? 3.9 : 3.4
        )

        return VehicleSpec(
            massKilograms : massKilograms,
            peakPowerKilowatts : horsepower / Units.kilowattsToHorsepower / boostDivisor,
            peakTorqueNewtonMetres : torqueNewtonMetres / boostDivisor,
            peakTorqueRPM : peakTorqueRPM,
            peakPowerRPM : peakPowerRPM,
            redlineRPM : redlineRPM,
            idleRPM : 850,
            cylinders : cylinders,
            gearRatios : ratios,
            finalDrive : finalDrive,
            shiftDuration : 0.32,
            drivetrain : drivetrain,
            frontTorqueSplit : frontTorqueSplit,
            wheelbase : wheelbase,
            length : length,
            width : width,
            frontWeightFraction : frontWeightFraction,
            centreOfGravityHeight : category == .trackCar ? 0.38 : ( category == .sedan ? 0.52 : 0.47 ),
            tyreGrip : tyreGrip,
            brakeDecelerationG : brakeDecelerationG,
            dragCoefficient : dragCoefficient,
            downforceCoefficient : downforceCoefficient,
            differentialLock : differentialLock,
            turboBoost : turboBoost,
            turboLag : turboBoost > 0.55 ? 1.1 : 0.8,
            superchargerBoost : superchargerBoost
        )
    }
}

nonisolated enum Manufacturers {
    static let all : [Manufacturer] = [
        Manufacturer(
            id : "hayase",
            name : "Hayase",
            origin : "Kobe-inspired small car maker",
            tagline : "Light cars. Loud hearts.",
            colourHex : 0xE8453C
        ),
        Manufacturer(
            id : "norrvik",
            name : "Norrvik",
            origin : "Nordic engineering house",
            tagline : "Built for every road, in every weather.",
            colourHex : 0x3C7BE8
        ),
        Manufacturer(
            id : "veltra",
            name : "Veltra",
            origin : "Premium European grand tourers",
            tagline : "Precision, perfected.",
            colourHex : 0xC9CED6
        ),
        Manufacturer(
            id : "brannock",
            name : "Brannock",
            origin : "Midwest V8 foundry",
            tagline : "Displacement is a feeling.",
            colourHex : 0xF2A31B
        ),
        Manufacturer(
            id : "wrenfield",
            name : "Wrenfield",
            origin : "Hand-built lightweight sports cars",
            tagline : "Add lightness. Then add more.",
            colourHex : 0x2FA36B
        ),
        Manufacturer(
            id : "kazeru",
            name : "Kazeru",
            origin : "Technology-led performance marque",
            tagline : "The wind answers.",
            colourHex : 0x9B5CF0
        ),
        Manufacturer(
            id : "aurex",
            name : "Aurex",
            origin : "Coachbuilt exotic atelier",
            tagline : "Nothing ordinary survives here.",
            colourHex : 0xD8B04A
        )
    ]

    static func named( _ id : String ) -> Manufacturer {
        all.first { $0.id == id } ?? all[ 0 ]
    }
}

nonisolated enum Cars {
    static let starterIDs : [CarID] = [ "hayase-pip", "hayase-kite-s", "norrvik-fjell" ]

    static func named( _ id : CarID ) -> CarDefinition? {
        lookup[ id ]
    }

    private static let lookup : [CarID : CarDefinition] = Dictionary(
        uniqueKeysWithValues : all.map { ( $0.id, $0 ) }
    )

    static let all : [CarDefinition] = [
        CarDefinition(
            id : "hayase-pip", manufacturerID : "hayase", model : "Pip 1.4", year : 2019,
            category : .hatchback, drivetrain : .fwd,
            horsepower : 102, torqueNewtonMetres : 132, massKilograms : 985,
            redlineRPM : 6_800, peakTorqueRPM : 4_200, peakPowerRPM : 6_300, gears : 5, designTopSpeedKPH : 188,
            tyreGrip : 0.98, brakeDecelerationG : 1.0, dragCoefficient : 0.40, downforceCoefficient : 0.04,
            frontWeightFraction : 0.62, wheelbase : 2.45, length : 3.9, width : 1.7, cylinders : 4,
            aspiration : .natural, differentialLock : 0.1, frontTorqueSplit : 1,
            price : 9_000, unlockLevel : 1, strengths : [ .circuit, .sprint ],
            blurb : "A friendly, grippy city hatch that never bites. The perfect place to learn racing lines.",
            defaultPaintHex : 0xF4D03F
        ),
        CarDefinition(
            id : "hayase-kite-s", manufacturerID : "hayase", model : "Kite S", year : 2016,
            category : .coupe, drivetrain : .rwd,
            horsepower : 128, torqueNewtonMetres : 152, massKilograms : 1_015,
            redlineRPM : 7_600, peakTorqueRPM : 5_000, peakPowerRPM : 7_200, gears : 5, designTopSpeedKPH : 200,
            tyreGrip : 0.97, brakeDecelerationG : 1.02, dragCoefficient : 0.38, downforceCoefficient : 0.04,
            frontWeightFraction : 0.53, wheelbase : 2.40, length : 4.1, width : 1.7, cylinders : 4,
            aspiration : .natural, differentialLock : 0.45, frontTorqueSplit : 0,
            price : 11_000, unlockLevel : 1, strengths : [ .drift, .mountain ],
            blurb : "Featherweight, rear-driven and eager to rotate. Rewards smooth hands and punishes greed.",
            defaultPaintHex : 0xF5F5F5
        ),
        CarDefinition(
            id : "norrvik-fjell", manufacturerID : "norrvik", model : "Fjell 2.0T", year : 2018,
            category : .sedan, drivetrain : .awd,
            horsepower : 168, torqueNewtonMetres : 255, massKilograms : 1_430,
            redlineRPM : 6_300, peakTorqueRPM : 2_500, peakPowerRPM : 5_500, gears : 5, designTopSpeedKPH : 218,
            tyreGrip : 1.0, brakeDecelerationG : 1.0, dragCoefficient : 0.42, downforceCoefficient : 0.05,
            frontWeightFraction : 0.58, wheelbase : 2.65, length : 4.6, width : 1.8, cylinders : 4,
            aspiration : .turbo( boost : 0.4 ), differentialLock : 0.35, frontTorqueSplit : 0.45,
            price : 12_000, unlockLevel : 1, strengths : [ .drag, .sprint ],
            blurb : "A turbocharged all-weather saloon. Heavy, but launches hard and never loses traction.",
            defaultPaintHex : 0x2E4A7D
        ),
        CarDefinition(
            id : "wrenfield-linnet", manufacturerID : "wrenfield", model : "Linnet 1.6", year : 2012,
            category : .roadster, drivetrain : .rwd,
            horsepower : 122, torqueNewtonMetres : 150, massKilograms : 860,
            redlineRPM : 7_200, peakTorqueRPM : 4_600, peakPowerRPM : 6_800, gears : 5, designTopSpeedKPH : 195,
            tyreGrip : 1.02, brakeDecelerationG : 1.05, dragCoefficient : 0.40, downforceCoefficient : 0.05,
            frontWeightFraction : 0.50, wheelbase : 2.25, length : 3.8, width : 1.65, cylinders : 4,
            aspiration : .natural, differentialLock : 0.3, frontTorqueSplit : 0,
            price : 16_500, unlockLevel : 2, strengths : [ .mountain, .circuit ],
            blurb : "An open-top featherweight with perfect balance. Slow on paper, quick on a twisty road.",
            defaultPaintHex : 0x1E6B45
        ),
        CarDefinition(
            id : "brannock-saddleback", manufacturerID : "brannock", model : "Saddleback 350", year : 1998,
            category : .muscle, drivetrain : .rwd,
            horsepower : 205, torqueNewtonMetres : 360, massKilograms : 1_620,
            redlineRPM : 5_200, peakTorqueRPM : 2_800, peakPowerRPM : 4_600, gears : 4, designTopSpeedKPH : 200,
            tyreGrip : 0.93, brakeDecelerationG : 0.92, dragCoefficient : 0.46, downforceCoefficient : 0.02,
            frontWeightFraction : 0.56, wheelbase : 2.90, length : 5.0, width : 1.9, cylinders : 8,
            aspiration : .natural, differentialLock : 0.5, frontTorqueSplit : 0,
            price : 15_000, unlockLevel : 2, strengths : [ .drag, .drift ],
            blurb : "A rumbling old V8 cruiser. Lazy in the bends, but torque for days off the line.",
            defaultPaintHex : 0x7A1F1F
        ),
        CarDefinition(
            id : "hayase-tempo-z", manufacturerID : "hayase", model : "Tempo Type-Z", year : 2021,
            category : .hatchback, drivetrain : .fwd,
            horsepower : 228, torqueNewtonMetres : 275, massKilograms : 1_195,
            redlineRPM : 8_300, peakTorqueRPM : 5_500, peakPowerRPM : 7_800, gears : 6, designTopSpeedKPH : 245,
            tyreGrip : 1.04, brakeDecelerationG : 1.1, dragCoefficient : 0.39, downforceCoefficient : 0.12,
            frontWeightFraction : 0.61, wheelbase : 2.55, length : 4.2, width : 1.75, cylinders : 4,
            aspiration : .natural, differentialLock : 0.45, frontTorqueSplit : 1,
            price : 28_000, unlockLevel : 4, strengths : [ .circuit, .sprint ],
            blurb : "A screaming high-revving hot hatch with a limited-slip front end. Lives above 7,000 RPM.",
            defaultPaintHex : 0xE8453C
        ),
        CarDefinition(
            id : "hayase-arc-s", manufacturerID : "hayase", model : "Arc S", year : 2003,
            category : .coupe, drivetrain : .rwd,
            horsepower : 245, torqueNewtonMetres : 320, massKilograms : 1_240,
            redlineRPM : 7_400, peakTorqueRPM : 3_600, peakPowerRPM : 6_600, gears : 6, designTopSpeedKPH : 248,
            tyreGrip : 1.0, brakeDecelerationG : 1.08, dragCoefficient : 0.39, downforceCoefficient : 0.06,
            frontWeightFraction : 0.54, wheelbase : 2.55, length : 4.4, width : 1.75, cylinders : 4,
            aspiration : .turbo( boost : 0.5 ), differentialLock : 0.65, frontTorqueSplit : 0,
            price : 32_000, unlockLevel : 5, strengths : [ .drift, .mountain ],
            blurb : "The drift scene's favourite turbo coupe. Welded-feeling diff, big boost, endless angle.",
            defaultPaintHex : 0x5DADE2
        ),
        CarDefinition(
            id : "veltra-aria", manufacturerID : "veltra", model : "Aria 3.0", year : 2020,
            category : .sedan, drivetrain : .rwd,
            horsepower : 255, torqueNewtonMetres : 310, massKilograms : 1_510,
            redlineRPM : 7_000, peakTorqueRPM : 3_500, peakPowerRPM : 6_600, gears : 6, designTopSpeedKPH : 252,
            tyreGrip : 1.02, brakeDecelerationG : 1.1, dragCoefficient : 0.37, downforceCoefficient : 0.06,
            frontWeightFraction : 0.51, wheelbase : 2.80, length : 4.7, width : 1.8, cylinders : 6,
            aspiration : .natural, differentialLock : 0.3, frontTorqueSplit : 0,
            price : 36_000, unlockLevel : 5, strengths : [ .circuit, .sprint ],
            blurb : "A silky straight-six sports saloon with textbook weight distribution.",
            defaultPaintHex : 0x1B2631
        ),
        CarDefinition(
            id : "norrvik-saga-tr", manufacturerID : "norrvik", model : "Saga TR", year : 2022,
            category : .hatchback, drivetrain : .awd,
            horsepower : 290, torqueNewtonMetres : 390, massKilograms : 1_470,
            redlineRPM : 6_800, peakTorqueRPM : 2_600, peakPowerRPM : 6_000, gears : 6, designTopSpeedKPH : 255,
            tyreGrip : 1.04, brakeDecelerationG : 1.1, dragCoefficient : 0.40, downforceCoefficient : 0.1,
            frontWeightFraction : 0.60, wheelbase : 2.62, length : 4.4, width : 1.8, cylinders : 4,
            aspiration : .turbo( boost : 0.55 ), differentialLock : 0.4, frontTorqueSplit : 0.5,
            price : 40_000, unlockLevel : 6, strengths : [ .drag, .sprint, .mountain ],
            blurb : "A rally-bred all-wheel-drive hot hatch. Fires out of corners like nothing else in its class.",
            defaultPaintHex : 0x2874A6
        ),
        CarDefinition(
            id : "brannock-tempest", manufacturerID : "brannock", model : "Tempest SS", year : 2015,
            category : .muscle, drivetrain : .rwd,
            horsepower : 355, torqueNewtonMetres : 510, massKilograms : 1_660,
            redlineRPM : 6_200, peakTorqueRPM : 4_000, peakPowerRPM : 5_700, gears : 5, designTopSpeedKPH : 258,
            tyreGrip : 0.97, brakeDecelerationG : 1.0, dragCoefficient : 0.44, downforceCoefficient : 0.04,
            frontWeightFraction : 0.55, wheelbase : 2.75, length : 4.8, width : 1.9, cylinders : 8,
            aspiration : .natural, differentialLock : 0.55, frontTorqueSplit : 0,
            price : 34_000, unlockLevel : 5, strengths : [ .drag, .drift ],
            blurb : "Big-block thunder with a live rear axle attitude. Straight lines are its native language.",
            defaultPaintHex : 0xD35400
        ),
        CarDefinition(
            id : "wrenfield-merlin", manufacturerID : "wrenfield", model : "Merlin", year : 2018,
            category : .trackCar, drivetrain : .rwd,
            horsepower : 240, torqueNewtonMetres : 245, massKilograms : 790,
            redlineRPM : 8_500, peakTorqueRPM : 6_000, peakPowerRPM : 8_000, gears : 6, designTopSpeedKPH : 238,
            tyreGrip : 1.12, brakeDecelerationG : 1.25, dragCoefficient : 0.42, downforceCoefficient : 0.6,
            frontWeightFraction : 0.44, wheelbase : 2.30, length : 3.8, width : 1.7, cylinders : 4,
            aspiration : .natural, differentialLock : 0.4, frontTorqueSplit : 0,
            price : 58_000, unlockLevel : 8, strengths : [ .circuit, .mountain ],
            blurb : "Barely legal and barely there. A mid-engined go-kart that humiliates cars with twice the power.",
            defaultPaintHex : 0x27AE60
        ),
        CarDefinition(
            id : "hayase-zenith-r", manufacturerID : "hayase", model : "Zenith R", year : 2008,
            category : .sedan, drivetrain : .awd,
            horsepower : 330, torqueNewtonMetres : 430, massKilograms : 1_460,
            redlineRPM : 7_200, peakTorqueRPM : 3_600, peakPowerRPM : 6_400, gears : 6, designTopSpeedKPH : 268,
            tyreGrip : 1.06, brakeDecelerationG : 1.15, dragCoefficient : 0.40, downforceCoefficient : 0.2,
            frontWeightFraction : 0.58, wheelbase : 2.65, length : 4.6, width : 1.8, cylinders : 4,
            aspiration : .turbo( boost : 0.6 ), differentialLock : 0.5, frontTorqueSplit : 0.4,
            price : 60_000, unlockLevel : 9, strengths : [ .sprint, .mountain, .drag ],
            blurb : "A winged, boosted, all-wheel-drive street legend. Point it at a mountain and hold on.",
            defaultPaintHex : 0x1F3A93
        ),
        CarDefinition(
            id : "veltra-corsa-gt", manufacturerID : "veltra", model : "Corsa GT", year : 2021,
            category : .coupe, drivetrain : .rwd,
            horsepower : 400, torqueNewtonMetres : 470, massKilograms : 1_560,
            redlineRPM : 7_500, peakTorqueRPM : 4_000, peakPowerRPM : 7_000, gears : 7, designTopSpeedKPH : 292,
            tyreGrip : 1.06, brakeDecelerationG : 1.18, dragCoefficient : 0.37, downforceCoefficient : 0.15,
            frontWeightFraction : 0.52, wheelbase : 2.70, length : 4.6, width : 1.85, cylinders : 6,
            aspiration : .turbo( boost : 0.35 ), differentialLock : 0.45, frontTorqueSplit : 0,
            price : 72_000, unlockLevel : 10, strengths : [ .circuit, .sprint ],
            blurb : "A composed twin-turbo grand tourer. Fast everywhere, flustered nowhere.",
            defaultPaintHex : 0x7F8C8D
        ),
        CarDefinition(
            id : "brannock-outlaw", manufacturerID : "brannock", model : "Outlaw GT", year : 2023,
            category : .muscle, drivetrain : .rwd,
            horsepower : 470, torqueNewtonMetres : 580, massKilograms : 1_720,
            redlineRPM : 7_000, peakTorqueRPM : 4_500, peakPowerRPM : 6_600, gears : 6, designTopSpeedKPH : 292,
            tyreGrip : 1.0, brakeDecelerationG : 1.1, dragCoefficient : 0.42, downforceCoefficient : 0.08,
            frontWeightFraction : 0.54, wheelbase : 2.72, length : 4.8, width : 1.92, cylinders : 8,
            aspiration : .natural, differentialLock : 0.55, frontTorqueSplit : 0,
            price : 64_000, unlockLevel : 9, strengths : [ .drag, .drift, .sprint ],
            blurb : "A modern muscle car that learned to turn. Still happiest leaving two black lines.",
            defaultPaintHex : 0x145A32
        ),
        CarDefinition(
            id : "kazeru-hikari", manufacturerID : "kazeru", model : "Hikari RS", year : 2002,
            category : .sports, drivetrain : .rwd,
            horsepower : 340, torqueNewtonMetres : 400, massKilograms : 1_390,
            redlineRPM : 8_000, peakTorqueRPM : 4_400, peakPowerRPM : 7_200, gears : 6, designTopSpeedKPH : 282,
            tyreGrip : 1.07, brakeDecelerationG : 1.18, dragCoefficient : 0.38, downforceCoefficient : 0.2,
            frontWeightFraction : 0.53, wheelbase : 2.55, length : 4.45, width : 1.8, cylinders : 6,
            aspiration : .turbo( boost : 0.55 ), differentialLock : 0.5, frontTorqueSplit : 0,
            price : 66_000, unlockLevel : 10, strengths : [ .drift, .mountain, .circuit ],
            blurb : "A twin-turbo straight-six icon. Tunable, balanced and devastating in the right hands.",
            defaultPaintHex : 0x8E44AD
        ),
        CarDefinition(
            id : "aurex-brezza", manufacturerID : "aurex", model : "Brezza Spider", year : 2019,
            category : .roadster, drivetrain : .rwd,
            horsepower : 420, torqueNewtonMetres : 460, massKilograms : 1_380,
            redlineRPM : 8_200, peakTorqueRPM : 4_800, peakPowerRPM : 7_600, gears : 7, designTopSpeedKPH : 300,
            tyreGrip : 1.08, brakeDecelerationG : 1.22, dragCoefficient : 0.42, downforceCoefficient : 0.25,
            frontWeightFraction : 0.45, wheelbase : 2.55, length : 4.4, width : 1.9, cylinders : 8,
            aspiration : .turbo( boost : 0.4 ), differentialLock : 0.4, frontTorqueSplit : 0,
            price : 98_000, unlockLevel : 12, strengths : [ .mountain, .sprint ],
            blurb : "Aurex's open-top entry point. Mid-mounted V8, no roof, no excuses.",
            defaultPaintHex : 0xC0392B
        ),
        CarDefinition(
            id : "veltra-spectre-rs", manufacturerID : "veltra", model : "Spectre RS", year : 2024,
            category : .sedan, drivetrain : .awd,
            horsepower : 580, torqueNewtonMetres : 700, massKilograms : 1_860,
            redlineRPM : 7_200, peakTorqueRPM : 2_800, peakPowerRPM : 6_200, gears : 8, designTopSpeedKPH : 308,
            tyreGrip : 1.08, brakeDecelerationG : 1.2, dragCoefficient : 0.40, downforceCoefficient : 0.2,
            frontWeightFraction : 0.55, wheelbase : 2.95, length : 5.0, width : 1.95, cylinders : 8,
            aspiration : .turbo( boost : 0.5 ), differentialLock : 0.45, frontTorqueSplit : 0.35,
            price : 118_000, unlockLevel : 14, strengths : [ .drag, .sprint ],
            blurb : "A four-door missile. Two tonnes of executive calm until you ask for everything.",
            defaultPaintHex : 0x34495E
        ),
        CarDefinition(
            id : "kazeru-shiden", manufacturerID : "kazeru", model : "Shiden R", year : 2020,
            category : .sports, drivetrain : .awd,
            horsepower : 560, torqueNewtonMetres : 640, massKilograms : 1_740,
            redlineRPM : 7_100, peakTorqueRPM : 3_600, peakPowerRPM : 6_600, gears : 6, designTopSpeedKPH : 318,
            tyreGrip : 1.1, brakeDecelerationG : 1.22, dragCoefficient : 0.39, downforceCoefficient : 0.35,
            frontWeightFraction : 0.55, wheelbase : 2.78, length : 4.7, width : 1.9, cylinders : 6,
            aspiration : .turbo( boost : 0.6 ), differentialLock : 0.5, frontTorqueSplit : 0.35,
            price : 126_000, unlockLevel : 15, strengths : [ .circuit, .drag, .sprint ],
            blurb : "Kazeru's computer-controlled giant killer. Torque-vectoring AWD makes the impossible routine.",
            defaultPaintHex : 0xBDC3C7
        ),
        CarDefinition(
            id : "brannock-goliath", manufacturerID : "brannock", model : "Goliath X", year : 2022,
            category : .muscle, drivetrain : .rwd,
            horsepower : 720, torqueNewtonMetres : 880, massKilograms : 1_900,
            redlineRPM : 6_500, peakTorqueRPM : 4_200, peakPowerRPM : 6_100, gears : 6, designTopSpeedKPH : 322,
            tyreGrip : 0.98, brakeDecelerationG : 1.12, dragCoefficient : 0.44, downforceCoefficient : 0.15,
            frontWeightFraction : 0.55, wheelbase : 2.90, length : 5.0, width : 1.95, cylinders : 8,
            aspiration : .supercharged( boost : 0.5 ), differentialLock : 0.6, frontTorqueSplit : 0,
            price : 108_000, unlockLevel : 14, strengths : [ .drag ],
            blurb : "A supercharged, 720-horsepower wrecking ball. Traction is a rumour.",
            defaultPaintHex : 0x17202A
        ),
        CarDefinition(
            id : "wrenfield-hawk-r", manufacturerID : "wrenfield", model : "Hawk R", year : 2021,
            category : .trackCar, drivetrain : .rwd,
            horsepower : 360, torqueNewtonMetres : 390, massKilograms : 920,
            redlineRPM : 8_800, peakTorqueRPM : 6_000, peakPowerRPM : 8_300, gears : 6, designTopSpeedKPH : 278,
            tyreGrip : 1.18, brakeDecelerationG : 1.35, dragCoefficient : 0.46, downforceCoefficient : 1.2,
            frontWeightFraction : 0.43, wheelbase : 2.40, length : 4.0, width : 1.85, cylinders : 6,
            aspiration : .natural, differentialLock : 0.45, frontTorqueSplit : 0,
            price : 122_000, unlockLevel : 16, strengths : [ .circuit, .mountain ],
            blurb : "Wings, slicks and a screaming V6. The fastest way around a corner that money can buy — for now.",
            defaultPaintHex : 0xF39C12
        ),
        CarDefinition(
            id : "aurex-nova", manufacturerID : "aurex", model : "Nova S", year : 2023,
            category : .sports, drivetrain : .rwd,
            horsepower : 540, torqueNewtonMetres : 560, massKilograms : 1_460,
            redlineRPM : 8_600, peakTorqueRPM : 5_500, peakPowerRPM : 8_000, gears : 7, designTopSpeedKPH : 322,
            tyreGrip : 1.12, brakeDecelerationG : 1.3, dragCoefficient : 0.39, downforceCoefficient : 0.5,
            frontWeightFraction : 0.42, wheelbase : 2.62, length : 4.5, width : 1.93, cylinders : 8,
            aspiration : .natural, differentialLock : 0.4, frontTorqueSplit : 0,
            price : 142_000, unlockLevel : 16, strengths : [ .circuit, .sprint, .drift ],
            blurb : "A mid-engined naturally aspirated V8 that sings to 8,600 RPM. Sharp, playful, alive.",
            defaultPaintHex : 0xF1C40F
        ),
        CarDefinition(
            id : "veltra-vortex", manufacturerID : "veltra", model : "Vortex", year : 2025,
            category : .supercar, drivetrain : .awd,
            horsepower : 660, torqueNewtonMetres : 720, massKilograms : 1_570,
            redlineRPM : 8_300, peakTorqueRPM : 5_000, peakPowerRPM : 7_800, gears : 7, designTopSpeedKPH : 342,
            tyreGrip : 1.14, brakeDecelerationG : 1.35, dragCoefficient : 0.40, downforceCoefficient : 0.7,
            frontWeightFraction : 0.42, wheelbase : 2.65, length : 4.5, width : 1.95, cylinders : 10,
            aspiration : .natural, differentialLock : 0.45, frontTorqueSplit : 0.3,
            price : 245_000, unlockLevel : 20, strengths : [ .circuit, .drag, .sprint ],
            blurb : "A V10 all-wheel-drive supercar with the manners of a saloon and the pace of a missile.",
            defaultPaintHex : 0x16A085
        ),
        CarDefinition(
            id : "aurex-serpa", manufacturerID : "aurex", model : "Serpa V12", year : 2024,
            category : .supercar, drivetrain : .rwd,
            horsepower : 740, torqueNewtonMetres : 720, massKilograms : 1_510,
            redlineRPM : 9_000, peakTorqueRPM : 6_000, peakPowerRPM : 8_500, gears : 7, designTopSpeedKPH : 352,
            tyreGrip : 1.14, brakeDecelerationG : 1.35, dragCoefficient : 0.39, downforceCoefficient : 0.8,
            frontWeightFraction : 0.42, wheelbase : 2.70, length : 4.7, width : 2.0, cylinders : 12,
            aspiration : .natural, differentialLock : 0.5, frontTorqueSplit : 0,
            price : 285_000, unlockLevel : 22, strengths : [ .circuit, .drift, .sprint ],
            blurb : "A rear-driven V12 opera. Demands respect, repays courage.",
            defaultPaintHex : 0xB03A2E
        ),
        CarDefinition(
            id : "kazeru-tsurugi", manufacturerID : "kazeru", model : "Tsurugi R", year : 2025,
            category : .supercar, drivetrain : .awd,
            horsepower : 690, torqueNewtonMetres : 800, massKilograms : 1_690,
            redlineRPM : 7_400, peakTorqueRPM : 3_800, peakPowerRPM : 6_800, gears : 7, designTopSpeedKPH : 338,
            tyreGrip : 1.13, brakeDecelerationG : 1.3, dragCoefficient : 0.40, downforceCoefficient : 0.6,
            frontWeightFraction : 0.52, wheelbase : 2.78, length : 4.7, width : 1.95, cylinders : 6,
            aspiration : .turbo( boost : 0.65 ), differentialLock : 0.5, frontTorqueSplit : 0.4,
            price : 235_000, unlockLevel : 20, strengths : [ .drag, .mountain, .sprint ],
            blurb : "A twin-turbo technological fortress. Launch control that feels like a catapult.",
            defaultPaintHex : 0xECF0F1
        ),
        CarDefinition(
            id : "wrenfield-peregrine", manufacturerID : "wrenfield", model : "Peregrine", year : 2025,
            category : .trackCar, drivetrain : .rwd,
            horsepower : 520, torqueNewtonMetres : 500, massKilograms : 1_020,
            redlineRPM : 9_000, peakTorqueRPM : 6_500, peakPowerRPM : 8_600, gears : 6, designTopSpeedKPH : 305,
            tyreGrip : 1.22, brakeDecelerationG : 1.45, dragCoefficient : 0.50, downforceCoefficient : 2.0,
            frontWeightFraction : 0.42, wheelbase : 2.50, length : 4.2, width : 1.95, cylinders : 8,
            aspiration : .natural, differentialLock : 0.5, frontTorqueSplit : 0,
            price : 255_000, unlockLevel : 22, strengths : [ .circuit, .mountain ],
            blurb : "A road-registered prototype. More downforce than sense, and the lap times to prove it.",
            defaultPaintHex : 0x2C3E50
        ),
        CarDefinition(
            id : "brannock-leviathan", manufacturerID : "brannock", model : "Leviathan", year : 2026,
            category : .hypercar, drivetrain : .rwd,
            horsepower : 1_020, torqueNewtonMetres : 1_180, massKilograms : 1_760,
            redlineRPM : 7_000, peakTorqueRPM : 4_500, peakPowerRPM : 6_600, gears : 7, designTopSpeedKPH : 385,
            tyreGrip : 1.1, brakeDecelerationG : 1.3, dragCoefficient : 0.40, downforceCoefficient : 0.6,
            frontWeightFraction : 0.50, wheelbase : 2.85, length : 4.9, width : 2.0, cylinders : 8,
            aspiration : .turbo( boost : 0.8 ), differentialLock : 0.6, frontTorqueSplit : 0,
            price : 620_000, unlockLevel : 28, strengths : [ .drag ],
            blurb : "Brannock's answer to physics: a twin-turbo 1,020 hp V8 aimed exclusively at the horizon.",
            defaultPaintHex : 0x0B0B0B
        ),
        CarDefinition(
            id : "aurex-fulmine", manufacturerID : "aurex", model : "Fulmine", year : 2026,
            category : .hypercar, drivetrain : .awd,
            horsepower : 1_110, torqueNewtonMetres : 1_150, massKilograms : 1_620,
            redlineRPM : 9_200, peakTorqueRPM : 6_000, peakPowerRPM : 8_600, gears : 8, designTopSpeedKPH : 405,
            tyreGrip : 1.2, brakeDecelerationG : 1.45, dragCoefficient : 0.40, downforceCoefficient : 1.2,
            frontWeightFraction : 0.43, wheelbase : 2.70, length : 4.7, width : 2.03, cylinders : 12,
            aspiration : .natural, differentialLock : 0.5, frontTorqueSplit : 0.3,
            price : 850_000, unlockLevel : 30, strengths : [ .circuit, .drag, .sprint ],
            blurb : "The lightning bolt. A V12 hybrid hypercar and the final word in the Shiftline world.",
            defaultPaintHex : 0xD4AC0D
        )
    ]
}
