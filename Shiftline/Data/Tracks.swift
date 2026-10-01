import Foundation

nonisolated enum TrackEnvironment : String, Codable, CaseIterable, Identifiable {
    case velocityPark
    case solanoHarbour
    case neonMeridian
    case ashgrove
    case redMesa
    case hollowPines
    case serpentRidge
    case brightwater
    case kestrelAirfield
    case oldTown

    var id : String {
        rawValue
    }

    var title : String {
        switch self {
        case .velocityPark:
            return "Velocity Park"
        case .solanoHarbour:
            return "Solano Harbour"
        case .neonMeridian:
            return "Neon Meridian"
        case .ashgrove:
            return "Ashgrove Works"
        case .redMesa:
            return "Red Mesa"
        case .hollowPines:
            return "Hollow Pines"
        case .serpentRidge:
            return "Serpent Ridge"
        case .brightwater:
            return "Brightwater Coast"
        case .kestrelAirfield:
            return "Kestrel Airfield"
        case .oldTown:
            return "Castellane Old Town"
        }
    }

    var summary : String {
        switch self {
        case .velocityPark:
            return "A purpose-built grand prix venue with grandstands, tyre walls and generous run-off."
        case .solanoHarbour:
            return "Container stacks, gantry cranes and slick concrete on a working waterfront."
        case .neonMeridian:
            return "An elevated downtown expressway wrapped in glass towers and neon."
        case .ashgrove:
            return "A decommissioned steelworks turned private test ground. Dusty, tight and unforgiving."
        case .redMesa:
            return "Endless desert highway beneath red rock mesas. Flat out, all the time."
        case .hollowPines:
            return "A narrow forest stage through towering pines. Blind crests and fast sweepers."
        case .serpentRidge:
            return "A switchback mountain pass clinging to the cliffs. Hairpins, guardrails, no margin."
        case .brightwater:
            return "A coastal road carved between palms and sea cliffs, with a lighthouse loop."
        case .kestrelAirfield:
            return "A retired airbase: runway drag strips, a taxiway circuit and a wide drift pad."
        case .oldTown:
            return "Cobbled lanes and stone walls through a hillside old town. Tight and technical."
        }
    }

    var groundHex : UInt32 {
        switch self {
        case .velocityPark:
            return 0x3E7B3A
        case .solanoHarbour:
            return 0x5B6168
        case .neonMeridian:
            return 0x23262E
        case .ashgrove:
            return 0x6B6256
        case .redMesa:
            return 0xC0703F
        case .hollowPines:
            return 0x2F5A2C
        case .serpentRidge:
            return 0x5E6B4A
        case .brightwater:
            return 0xD9C58E
        case .kestrelAirfield:
            return 0x7B8A55
        case .oldTown:
            return 0x8A7A66
        }
    }

    var roadHex : UInt32 {
        switch self {
        case .solanoHarbour, .ashgrove:
            return 0x5A5A5C
        case .redMesa:
            return 0x4A4644
        case .oldTown:
            return 0x6E6760
        case .kestrelAirfield:
            return 0x545658
        default:
            return 0x3C3D40
        }
    }

    var runoffHex : UInt32 {
        switch self {
        case .velocityPark:
            return 0x4E8F46
        case .redMesa, .brightwater:
            return 0xD8B67A
        case .ashgrove:
            return 0x7C7263
        case .hollowPines, .serpentRidge:
            return 0x4F6B3A
        case .kestrelAirfield:
            return 0x8E9C66
        default:
            return 0x6A6D72
        }
    }
}

nonisolated enum Tracks {
    static func named( _ id : TrackID ) -> TrackLayout? {
        lookup[ id ]
    }

    private static let lookup : [TrackID : TrackLayout] = Dictionary(
        uniqueKeysWithValues : all.map { ( $0.id, $0 ) }
    )

    static func layouts( in environment : TrackEnvironment ) -> [TrackLayout] {
        all.filter { $0.environment == environment }
    }

    private static func points( _ pairs : [( Double, Double )] ) -> [Vec2] {
        pairs.map { Vec2( $0.0, $0.1 ) }
    }

    // MARK: - Velocity Park

    static let velocityParkGP = TrackLayout(
        id : "velocity-gp",
        name : "Velocity Park",
        variant : "Grand Prix",
        environment : .velocityPark,
        shape : .loop( points( [
            ( 0, 0 ), ( 300, 0 ), ( 560, 0 ), ( 650, 40 ), ( 670, 130 ), ( 610, 200 ), ( 640, 290 ),
            ( 720, 340 ), ( 760, 430 ), ( 700, 520 ), ( 600, 520 ), ( 520, 460 ), ( 420, 470 ),
            ( 300, 560 ), ( 160, 560 ), ( 60, 500 ), ( -40, 520 ), ( -120, 460 ), ( -110, 360 ),
            ( -40, 300 ), ( -60, 200 ), ( -140, 150 ), ( -140, 60 ), ( -80, 10 )
        ] ) ),
        width : 15,
        runoffWidth : 14,
        runoff : .gravel,
        barrier : .tyres,
        summary : "The full championship layout. A long pit straight, a fast esse complex and a heavy-braking hairpin."
    )

    static let velocityParkNational = TrackLayout(
        id : "velocity-national",
        name : "Velocity Park",
        variant : "National",
        environment : .velocityPark,
        shape : .loop( points( [
            ( 0, 0 ), ( 300, 0 ), ( 560, 0 ), ( 650, 40 ), ( 670, 130 ), ( 600, 210 ), ( 460, 240 ),
            ( 300, 230 ), ( 150, 260 ), ( 0, 300 ), ( -100, 250 ), ( -130, 130 ), ( -80, 20 )
        ] ) ),
        width : 15,
        runoffWidth : 14,
        runoff : .paved,
        barrier : .tyres,
        summary : "The short club loop cuts through the infield link road. Quick laps, constant traffic."
    )

    // MARK: - Solano Harbour

    static let harbourLoop = TrackLayout(
        id : "harbour-loop",
        name : "Solano Harbour",
        variant : "Dockside Loop",
        environment : .solanoHarbour,
        shape : .loop( points( [
            ( 0, 0 ), ( 400, 0 ), ( 460, 30 ), ( 470, 100 ), ( 470, 260 ), ( 440, 300 ), ( 360, 310 ),
            ( 320, 350 ), ( 300, 420 ), ( 250, 450 ), ( 60, 450 ), ( 0, 420 ), ( -20, 360 ),
            ( -80, 330 ), ( -150, 300 ), ( -170, 240 ), ( -150, 180 ), ( -60, 150 ), ( -40, 100 ),
            ( -60, 40 ), ( -30, 5 )
        ] ) ),
        width : 13,
        runoffWidth : 3,
        runoff : .pavement,
        barrier : .concrete,
        surface : .concrete,
        summary : "Right-angle corners between container stacks. Concrete walls reward precision."
    )

    static let containerYard = TrackLayout(
        id : "harbour-yard",
        name : "Solano Harbour",
        variant : "Container Yard",
        environment : .solanoHarbour,
        shape : .loop( points( [
            ( 0, 0 ), ( 160, 0 ), ( 240, 60 ), ( 240, 160 ), ( 170, 220 ), ( 90, 200 ), ( 40, 260 ),
            ( -60, 300 ), ( -160, 250 ), ( -170, 150 ), ( -100, 90 ), ( -90, 20 )
        ] ) ),
        width : 18,
        runoffWidth : 4,
        runoff : .paved,
        barrier : .concrete,
        surface : .concrete,
        summary : "A wide open concrete drift yard with walls close enough to kiss."
    )

    static let harbourSprint = TrackLayout(
        id : "harbour-sprint",
        name : "Solano Harbour",
        variant : "Quayside Sprint",
        environment : .solanoHarbour,
        shape : .road( [
            .straight( 250 ), .right( radius : 40, degrees : 90 ), .straight( 200 ), .left( radius : 35, degrees : 90 ),
            .straight( 300 ), .left( radius : 80, degrees : 40 ), .right( radius : 80, degrees : 40 ), .straight( 250 ),
            .right( radius : 30, degrees : 90 ), .straight( 180 ), .left( radius : 45, degrees : 90 ), .straight( 300 )
        ] ),
        width : 13,
        runoffWidth : 3,
        runoff : .pavement,
        barrier : .concrete,
        surface : .concrete,
        summary : "From the ferry terminal to the dry docks along the quays."
    )

    // MARK: - Neon Meridian

    static let expresswayLoop = TrackLayout(
        id : "neon-expressway",
        name : "Neon Meridian",
        variant : "Expressway Loop",
        environment : .neonMeridian,
        shape : .loop( points( [
            ( 0, 0 ), ( 500, 0 ), ( 800, 60 ), ( 950, 220 ), ( 930, 420 ), ( 780, 520 ), ( 560, 500 ),
            ( 420, 560 ), ( 220, 600 ), ( 0, 560 ), ( -160, 440 ), ( -200, 260 ), ( -140, 100 )
        ] ) ),
        width : 16,
        runoffWidth : 2,
        runoff : .pavement,
        barrier : .concrete,
        summary : "A flat-out elevated ring road. Big speed, long sweepers, walls everywhere."
    )

    static let downtownRun = TrackLayout(
        id : "neon-downtown",
        name : "Neon Meridian",
        variant : "Downtown Run",
        environment : .neonMeridian,
        shape : .road( [
            .straight( 300 ), .left( radius : 25, degrees : 90 ), .straight( 180 ), .right( radius : 25, degrees : 90 ),
            .straight( 250 ), .right( radius : 30, degrees : 90 ), .straight( 120 ), .left( radius : 30, degrees : 90 ),
            .straight( 300 ), .left( radius : 60, degrees : 45 ), .right( radius : 60, degrees : 45 ), .straight( 200 ),
            .right( radius : 25, degrees : 90 ), .straight( 150 ), .left( radius : 25, degrees : 90 ), .straight( 250 )
        ] ),
        width : 12,
        runoffWidth : 2,
        runoff : .pavement,
        barrier : .concrete,
        summary : "Block-by-block through the financial district. Brake late, turn in sharp."
    )

    // MARK: - Ashgrove

    static let foundryCircuit = TrackLayout(
        id : "ashgrove-foundry",
        name : "Ashgrove Works",
        variant : "Foundry Circuit",
        environment : .ashgrove,
        shape : .loop( points( [
            ( 0, 0 ), ( 350, 0 ), ( 420, 40 ), ( 420, 150 ), ( 350, 200 ), ( 250, 200 ), ( 200, 250 ),
            ( 220, 350 ), ( 320, 380 ), ( 420, 360 ), ( 500, 420 ), ( 480, 520 ), ( 350, 560 ),
            ( 150, 540 ), ( 40, 470 ), ( -60, 380 ), ( -80, 250 ), ( -40, 150 ), ( -60, 60 ), ( -30, 10 )
        ] ) ),
        width : 13,
        runoffWidth : 6,
        runoff : .gravel,
        barrier : .concrete,
        surface : .dusty,
        summary : "Dusty tarmac around the old blast furnaces. Grip is at a premium."
    )

    static let smelterDrift = TrackLayout(
        id : "ashgrove-smelter",
        name : "Ashgrove Works",
        variant : "Smelter Drift",
        environment : .ashgrove,
        shape : .loop( points( [
            ( 0, 0 ), ( 200, 0 ), ( 280, 80 ), ( 250, 180 ), ( 160, 200 ), ( 120, 280 ), ( 180, 360 ),
            ( 120, 440 ), ( 0, 440 ), ( -80, 360 ), ( -60, 260 ), ( -140, 190 ), ( -130, 80 ), ( -60, 20 )
        ] ) ),
        width : 17,
        runoffWidth : 5,
        runoff : .paved,
        barrier : .concrete,
        surface : .concrete,
        summary : "A flowing chain of linked corners built for transitions."
    )

    static let industrialRun = TrackLayout(
        id : "ashgrove-run",
        name : "Ashgrove Works",
        variant : "Rail Yard Run",
        environment : .ashgrove,
        shape : .road( [
            .straight( 250 ), .left( radius : 50, degrees : 90 ), .straight( 200 ), .right( radius : 35, degrees : 120 ),
            .straight( 150 ), .left( radius : 40, degrees : 60 ), .straight( 300 ), .right( radius : 60, degrees : 90 ),
            .left( radius : 70, degrees : 90 ), .straight( 250 )
        ] ),
        width : 12,
        runoffWidth : 5,
        runoff : .gravel,
        barrier : .concrete,
        surface : .dusty,
        summary : "Along the rail sidings and through the loading sheds."
    )

    // MARK: - Red Mesa

    static let mesaHighway = TrackLayout(
        id : "mesa-highway",
        name : "Red Mesa",
        variant : "Highway 9",
        environment : .redMesa,
        shape : .road( [
            .straight( 600 ), .left( radius : 400, degrees : 25 ), .straight( 500 ), .right( radius : 300, degrees : 35 ),
            .straight( 400 ), .left( radius : 250, degrees : 40 ), .right( radius : 500, degrees : 20 ),
            .straight( 800 ), .left( radius : 350, degrees : 30 ), .straight( 400 )
        ] ),
        width : 14,
        runoffWidth : 12,
        runoff : .sand,
        barrier : .guardrail,
        speedTraps : [ 0.16, 0.52, 0.8 ],
        summary : "Four kilometres of desert highway. Keep it pinned."
    )

    static let mesaSpeedRun = TrackLayout(
        id : "mesa-speedrun",
        name : "Red Mesa",
        variant : "Salt Flat Run",
        environment : .redMesa,
        shape : .road( [
            .straight( 900 ), .right( radius : 600, degrees : 15 ), .straight( 1_000 ), .left( radius : 500, degrees : 20 ),
            .straight( 900 )
        ] ),
        width : 16,
        runoffWidth : 16,
        runoff : .sand,
        barrier : .guardrail,
        speedTraps : [ 0.27, 0.6, 0.93 ],
        summary : "Three long straights and gentle kinks. Built for top speed."
    )

    // MARK: - Hollow Pines

    static let forestStage = TrackLayout(
        id : "pines-stage",
        name : "Hollow Pines",
        variant : "Forest Stage",
        environment : .hollowPines,
        shape : .road( [
            .straight( 200 ), .right( radius : 120, degrees : 40 ), .left( radius : 90, degrees : 60 ), .straight( 150 ),
            .right( radius : 70, degrees : 80 ), .left( radius : 150, degrees : 30 ), .straight( 250 ),
            .left( radius : 60, degrees : 90 ), .right( radius : 80, degrees : 70 ), .straight( 120 ),
            .right( radius : 45, degrees : 110 ), .left( radius : 100, degrees : 50 ), .straight( 300 ),
            .left( radius : 130, degrees : 45 ), .right( radius : 90, degrees : 60 ), .straight( 180 )
        ] ),
        width : 11,
        runoffWidth : 4,
        runoff : .grass,
        barrier : .guardrail,
        surface : .asphalt,
        summary : "A narrow ribbon of tarmac between the pines. Commit to the fast stuff."
    )

    // MARK: - Serpent Ridge

    static let ridgeUphill = TrackLayout(
        id : "ridge-uphill",
        name : "Serpent Ridge",
        variant : "Uphill",
        environment : .serpentRidge,
        shape : .road( [
            .straight( 120 ), .left( radius : 40, degrees : 70 ), .right( radius : 60, degrees : 50 ), .straight( 80 ),
            .left( radius : 18, degrees : 170 ), .straight( 150 ), .right( radius : 18, degrees : 175 ), .straight( 120 ),
            .left( radius : 50, degrees : 60 ), .right( radius : 35, degrees : 90 ), .straight( 60 ),
            .left( radius : 20, degrees : 160 ), .straight( 140 ), .right( radius : 22, degrees : 165 ), .straight( 90 ),
            .left( radius : 45, degrees : 80 ), .right( radius : 60, degrees : 40 ), .straight( 110 ),
            .left( radius : 25, degrees : 150 ), .straight( 100 ), .right( radius : 30, degrees : 120 ),
            .left( radius : 70, degrees : 50 ), .straight( 150 )
        ] ),
        width : 10,
        runoffWidth : 2,
        runoff : .grass,
        barrier : .guardrail,
        grade : 0.07,
        summary : "Climb the switchbacks to the summit. Traction and patience win."
    )

    static let summitSprint = TrackLayout(
        id : "ridge-summit",
        name : "Serpent Ridge",
        variant : "Summit Run",
        environment : .serpentRidge,
        shape : .road( [
            .straight( 80 ), .left( radius : 30, degrees : 90 ), .right( radius : 20, degrees : 160 ), .straight( 100 ),
            .left( radius : 22, degrees : 170 ), .straight( 120 ), .right( radius : 40, degrees : 70 ),
            .left( radius : 50, degrees : 60 ), .straight( 100 )
        ] ),
        width : 10,
        runoffWidth : 2,
        runoff : .grass,
        barrier : .rock,
        grade : 0.05,
        summary : "The short sprint over the summit ridge. Four hairpins, zero room."
    )

    // MARK: - Brightwater Coast

    static let coastRoad = TrackLayout(
        id : "coast-road",
        name : "Brightwater Coast",
        variant : "Cliff Road",
        environment : .brightwater,
        shape : .road( [
            .straight( 250 ), .left( radius : 150, degrees : 35 ), .right( radius : 110, degrees : 50 ), .straight( 200 ),
            .left( radius : 80, degrees : 70 ), .right( radius : 200, degrees : 30 ), .straight( 350 ),
            .right( radius : 90, degrees : 65 ), .left( radius : 120, degrees : 55 ), .straight( 250 ),
            .left( radius : 70, degrees : 85 ), .right( radius : 160, degrees : 40 ), .straight( 300 )
        ] ),
        width : 12,
        runoffWidth : 5,
        runoff : .sand,
        barrier : .guardrail,
        speedTraps : [ 0.3, 0.62, 0.92 ],
        summary : "Sweeping bends above the surf. Stunning views, if you dare to look."
    )

    static let lighthouseLoop = TrackLayout(
        id : "coast-lighthouse",
        name : "Brightwater Coast",
        variant : "Lighthouse Loop",
        environment : .brightwater,
        shape : .loop( points( [
            ( 0, 0 ), ( 300, -20 ), ( 520, 40 ), ( 640, 160 ), ( 620, 300 ), ( 520, 360 ), ( 420, 330 ),
            ( 330, 380 ), ( 300, 480 ), ( 180, 540 ), ( 40, 500 ), ( -60, 400 ), ( -60, 260 ),
            ( -120, 160 ), ( -90, 50 )
        ] ) ),
        width : 13,
        runoffWidth : 8,
        runoff : .sand,
        barrier : .tyres,
        summary : "A seaside circuit around the old lighthouse headland."
    )

    // MARK: - Kestrel Airfield

    static let airfieldCircuit = TrackLayout(
        id : "kestrel-circuit",
        name : "Kestrel Airfield",
        variant : "Taxiway Circuit",
        environment : .kestrelAirfield,
        shape : .loop( points( [
            ( 0, 0 ), ( 900, 0 ), ( 980, 40 ), ( 990, 120 ), ( 920, 160 ), ( 600, 160 ), ( 540, 200 ),
            ( 520, 300 ), ( 460, 340 ), ( 200, 340 ), ( 140, 300 ), ( 120, 200 ), ( 60, 160 ),
            ( -60, 150 ), ( -110, 100 ), ( -90, 30 )
        ] ) ),
        width : 18,
        runoffWidth : 16,
        runoff : .grass,
        barrier : .tyres,
        surface : .concrete,
        summary : "The main runway joined to the taxiways. An enormous straight, then slow and tricky."
    )

    static let airfieldDriftPad = TrackLayout(
        id : "kestrel-pad",
        name : "Kestrel Airfield",
        variant : "Drift Pad",
        environment : .kestrelAirfield,
        shape : .loop( points( [
            ( 0, 0 ), ( 200, 0 ), ( 290, 70 ), ( 280, 170 ), ( 190, 220 ), ( 100, 190 ), ( 0, 230 ),
            ( -100, 190 ), ( -170, 110 ), ( -140, 30 )
        ] ) ),
        width : 20,
        runoffWidth : 10,
        runoff : .paved,
        barrier : .tyres,
        surface : .concrete,
        summary : "A vast apron marked with cones. Room to hold huge angle."
    )

    static let kestrelEighth = TrackLayout(
        id : "kestrel-eighth",
        name : "Kestrel Airfield",
        variant : "1/8 Mile",
        environment : .kestrelAirfield,
        shape : .dragStrip( Units.eighthMile ),
        width : 14,
        surface : .concrete
    )

    static let kestrelQuarter = TrackLayout(
        id : "kestrel-quarter",
        name : "Kestrel Airfield",
        variant : "1/4 Mile",
        environment : .kestrelAirfield,
        shape : .dragStrip( Units.quarterMile ),
        width : 14,
        surface : .concrete
    )

    static let kestrelHalf = TrackLayout(
        id : "kestrel-half",
        name : "Kestrel Airfield",
        variant : "1/2 Mile",
        environment : .kestrelAirfield,
        shape : .dragStrip( Units.halfMile ),
        width : 14,
        surface : .concrete
    )

    static let kestrelKilometre = TrackLayout(
        id : "kestrel-kilometre",
        name : "Kestrel Airfield",
        variant : "Standing Kilometre",
        environment : .kestrelAirfield,
        shape : .dragStrip( Units.kilometre ),
        width : 14,
        surface : .concrete
    )

    static let meridianQuarter = TrackLayout(
        id : "neon-quarter",
        name : "Neon Meridian",
        variant : "Harbour Bridge 1/4",
        environment : .neonMeridian,
        shape : .dragStrip( Units.quarterMile ),
        width : 14
    )

    static let mesaHalf = TrackLayout(
        id : "mesa-half",
        name : "Red Mesa",
        variant : "Salt Flat 1/2 Mile",
        environment : .redMesa,
        shape : .dragStrip( Units.halfMile ),
        width : 16,
        surface : .dusty
    )

    // MARK: - Castellane Old Town

    static let oldTownCircuit = TrackLayout(
        id : "oldtown-circuit",
        name : "Castellane Old Town",
        variant : "Citadel Circuit",
        environment : .oldTown,
        shape : .loop( points( [
            ( 0, 0 ), ( 200, 0 ), ( 230, 20 ), ( 240, 60 ), ( 240, 160 ), ( 260, 190 ), ( 330, 200 ),
            ( 360, 230 ), ( 360, 330 ), ( 330, 360 ), ( 200, 360 ), ( 170, 340 ), ( 150, 300 ),
            ( 100, 280 ), ( 40, 300 ), ( 0, 330 ), ( -80, 330 ), ( -110, 300 ), ( -110, 200 ),
            ( -60, 160 ), ( -60, 60 ), ( -40, 15 )
        ] ) ),
        width : 11,
        runoffWidth : 1.5,
        runoff : .pavement,
        barrier : .concrete,
        surface : .cobbles,
        summary : "Stone walls, cobbles and ninety-degree corners around the citadel."
    )

    static let oldTownSprint = TrackLayout(
        id : "oldtown-sprint",
        name : "Castellane Old Town",
        variant : "Market Dash",
        environment : .oldTown,
        shape : .road( [
            .straight( 150 ), .left( radius : 18, degrees : 90 ), .straight( 90 ), .right( radius : 18, degrees : 90 ),
            .straight( 120 ), .right( radius : 20, degrees : 90 ), .left( radius : 20, degrees : 90 ), .straight( 150 ),
            .left( radius : 30, degrees : 60 ), .right( radius : 30, degrees : 60 ), .straight( 100 ),
            .right( radius : 18, degrees : 90 ), .straight( 200 )
        ] ),
        width : 10,
        runoffWidth : 1.5,
        runoff : .pavement,
        barrier : .concrete,
        surface : .cobbles,
        summary : "From the harbour steps to the market square. Every metre is a corner."
    )

    // MARK: - Variants

    static let velocityParkReverse = velocityParkGP.reversed(
        id : "velocity-gp-rev",
        variant : "Grand Prix Reverse",
        summary : "The GP layout run clockwise. The old hairpin becomes a flat-out kink into a brutal stop."
    )

    static let harbourLoopReverse = harbourLoop.reversed(
        id : "harbour-loop-rev",
        variant : "Dockside Reverse",
        summary : "The dockside loop run against the flow of the forklifts."
    )

    static let expresswayReverse = expresswayLoop.reversed(
        id : "neon-expressway-rev",
        variant : "Expressway Outer",
        summary : "The outer carriageway: the same sweepers, opposite commitment."
    )

    static let ridgeDownhill = ridgeUphill.reversed(
        id : "ridge-downhill",
        variant : "Downhill",
        summary : "Descend the pass. Gravity is free speed and free trouble."
    )

    static let forestStageReverse = forestStage.reversed(
        id : "pines-stage-rev",
        variant : "Forest Stage Reverse",
        summary : "The stage run from the lumber mill back to the lake."
    )

    static let coastRoadReverse = coastRoad.reversed(
        id : "coast-road-rev",
        variant : "Cliff Road Northbound",
        summary : "Northbound along the cliffs, with the sea on your left."
    )

    static let foundryReverse = foundryCircuit.reversed(
        id : "ashgrove-foundry-rev",
        variant : "Foundry Reverse",
        summary : "The foundry loop turned inside out."
    )

    static let all : [TrackLayout] = [
        velocityParkGP, velocityParkNational, velocityParkReverse,
        harbourLoop, harbourLoopReverse, containerYard, harbourSprint,
        expresswayLoop, expresswayReverse, downtownRun, meridianQuarter,
        foundryCircuit, foundryReverse, smelterDrift, industrialRun,
        mesaHighway, mesaSpeedRun, mesaHalf,
        forestStage, forestStageReverse,
        ridgeUphill, ridgeDownhill, summitSprint,
        coastRoad, coastRoadReverse, lighthouseLoop,
        airfieldCircuit, airfieldDriftPad, kestrelEighth, kestrelQuarter, kestrelHalf, kestrelKilometre,
        oldTownCircuit, oldTownSprint
    ]
}
