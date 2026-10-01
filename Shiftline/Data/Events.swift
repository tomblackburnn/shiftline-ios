import Foundation

nonisolated enum CareerTier : Int, Codable, CaseIterable, Identifiable, Comparable {
    case rookie
    case street
    case club
    case regional
    case professional
    case elite
    case legend

    var id : Int {
        rawValue
    }

    var title : String {
        switch self {
        case .rookie:
            return "Rookie Cup"
        case .street:
            return "Street Scene"
        case .club:
            return "Club Series"
        case .regional:
            return "Regional Tour"
        case .professional:
            return "Pro Circuit"
        case .elite:
            return "Elite Masters"
        case .legend:
            return "Legend Series"
        }
    }

    var tagline : String {
        switch self {
        case .rookie:
            return "Learn the ropes in modest machinery."
        case .street:
            return "Night meets on closed city streets."
        case .club:
            return "Proper circuits, proper racing."
        case .regional:
            return "Bigger fields, faster cars, real rivals."
        case .professional:
            return "The paddock is watching."
        case .elite:
            return "Only the quickest get an invitation."
        case .legend:
            return "Where names are made permanent."
        }
    }

    var requiredLevel : Int {
        [ 1, 3, 6, 10, 15, 21, 27 ][ rawValue ]
    }

    /// Wins needed in the previous tier to open this one.
    var requiredPreviousWins : Int {
        self == .rookie ? 0 : 4
    }

    var basePayout : Int {
        [ 2_600, 4_200, 6_800, 10_500, 16_500, 26_000, 42_000 ][ rawValue ]
    }

    var opponentSkill : Double {
        [ 0.36, 0.46, 0.55, 0.63, 0.71, 0.79, 0.87 ][ rawValue ]
    }

    var classCap : PerformanceClass {
        [ PerformanceClass.d, .c, .b, .a, .s, .s, .x ][ rawValue ]
    }

    var baseXP : Int {
        [ 140, 190, 250, 320, 400, 480, 580 ][ rawValue ]
    }

    static func < ( lhs : CareerTier, rhs : CareerTier ) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

nonisolated struct EventRequirements : Equatable {
    var minimumLevel = 1
    var maximumClass : PerformanceClass?
    var drivetrain : Drivetrain?
    var categories : [CarCategory]?
    var requiredEventIDs : [String] = []
    var requiresTutorial : TutorialKind?
}

nonisolated struct EventDefinition : Identifiable {
    let id : String
    let name : String
    let tier : CareerTier
    let discipline : Discipline
    let kind : RaceKind
    let trackID : TrackID
    var laps = 1
    var opponents = 5
    var weather = Weather.clear
    var timeOfDay = TimeOfDay.day
    var requirements = EventRequirements()
    var rivalID : String?
    var isSpecial = false
    var summary = ""

    var track : TrackLayout? {
        Tracks.named( trackID )
    }

    var isRival : Bool {
        rivalID != nil
    }

    var firstPlacePrize : Int {
        let base = Double( tier.basePayout )
        let lengthBonus = kind == .endurance ? 1.8 : ( laps >= 4 ? 1.3 : 1 )
        let rivalBonus = isRival ? 1.6 : 1
        let specialBonus = isSpecial ? 1.2 : 1
        return Int( base * lengthBonus * rivalBonus * specialBonus / 50 ) * 50
    }

    /// Recommended performance index, shown to the player.
    var recommendedIndex : Int {
        let cap = requirements.maximumClass ?? tier.classCap
        return max( cap.ceiling - 50, 150 )
    }
}

nonisolated enum Events {
    static func named( _ id : String ) -> EventDefinition? {
        lookup[ id ]
    }

    private static let lookup : [String : EventDefinition] = Dictionary(
        uniqueKeysWithValues : all.map { ( $0.id, $0 ) }
    )

    static func events( in tier : CareerTier ) -> [EventDefinition] {
        all.filter { $0.tier == tier }
    }

    static let firstEventID = "r-sprint-1"

    private static let scoreAttack60 = RaceKind.drift( .scoreAttack, duration : 60 )
    private static let scoreAttack90 = RaceKind.drift( .scoreAttack, duration : 90 )
    private static let sections = RaceKind.drift( .sections, duration : 0 )
    private static let chain = RaceKind.drift( .chain, duration : 0 )
    private static let tandem = RaceKind.drift( .tandem, duration : 0 )
    private static let checkpoint = RaceKind.checkpoint( startTime : 0, bonusPerCheckpoint : 0 )

    private static func needs( _ ids : String..., level : Int = 1 ) -> EventRequirements {
        EventRequirements( minimumLevel : level, requiredEventIDs : ids )
    }

    static let all : [EventDefinition] = rookie + street + club + regional + professional + elite + legend

    // MARK: - Rookie Cup

    static let rookie : [EventDefinition] = [
        EventDefinition(
            id : "r-sprint-1", name : "First Gear", tier : .rookie, discipline : .sprint, kind : .sprint,
            trackID : "harbour-sprint", opponents : 4,
            requirements : EventRequirements( requiresTutorial : .basics ),
            summary : "Your first real race. Five cars, one quayside, no pressure."
        ),
        EventDefinition(
            id : "r-drag-1", name : "Airfield Nights", tier : .rookie, discipline : .drag, kind : .drag,
            trackID : "kestrel-eighth", opponents : 1, timeOfDay : .night,
            requirements : needs( "r-sprint-1" ),
            summary : "An eighth-mile under the floodlights. Nail the launch."
        ),
        EventDefinition(
            id : "r-circuit-1", name : "National Debut", tier : .rookie, discipline : .circuit, kind : .circuit,
            trackID : "velocity-national", laps : 3,
            requirements : needs( "r-sprint-1" ),
            summary : "Three laps of the club loop against a full grid."
        ),
        EventDefinition(
            id : "r-drift-1", name : "Container Kickoff", tier : .rookie, discipline : .drift, kind : scoreAttack60,
            trackID : "harbour-yard", opponents : 0, timeOfDay : .sunset,
            requirements : needs( "r-circuit-1" ),
            summary : "Sixty seconds, one concrete yard. Get sideways."
        ),
        EventDefinition(
            id : "r-ta-1", name : "Taxiway Hotlap", tier : .rookie, discipline : .circuit, kind : .timeAttack,
            trackID : "kestrel-circuit", laps : 3, opponents : 0,
            requirements : needs( "r-circuit-1" ),
            summary : "Three laps to set your best time. Cut the track and the lap is void."
        ),
        EventDefinition(
            id : "r-cp-1", name : "Beat the Tide", tier : .rookie, discipline : .sprint, kind : checkpoint,
            trackID : "coast-road", opponents : 0,
            requirements : needs( "r-sprint-1" ),
            summary : "Reach each checkpoint before the clock hits zero."
        ),
        EventDefinition(
            id : "r-elim-1", name : "Last Car Standing", tier : .rookie, discipline : .circuit, kind : .elimination,
            trackID : "velocity-national",
            requirements : needs( "r-circuit-1" ),
            summary : "Last place at the end of every lap is out."
        ),
        EventDefinition(
            id : "r-mountain-1", name : "Summit Sprint", tier : .rookie, discipline : .mountain, kind : .sprint,
            trackID : "ridge-summit", opponents : 3, timeOfDay : .sunset,
            requirements : needs( "r-sprint-1", level : 2 ),
            summary : "Four hairpins over the summit. Brake early, exit fast."
        ),
        EventDefinition(
            id : "r-trap-1", name : "Mesa Speed Check", tier : .rookie, discipline : .sprint, kind : .speedTrap,
            trackID : "mesa-speedrun", opponents : 0,
            requirements : needs( "r-sprint-1" ),
            summary : "Hit the radar traps as fast as you can."
        ),
        EventDefinition(
            id : "r-street-1", name : "Neon Welcome", tier : .rookie, discipline : .street, kind : .sprint,
            trackID : "neon-downtown", timeOfDay : .night,
            requirements : needs( "r-sprint-1", level : 2 ),
            summary : "The city's closed-road night series says hello."
        ),
        EventDefinition(
            id : "r-drag-2", name : "Quarter Mile Club", tier : .rookie, discipline : .drag, kind : .drag,
            trackID : "kestrel-quarter", opponents : 1,
            requirements : needs( "r-drag-1" ),
            summary : "The classic distance. Four shifts, twelve-ish seconds."
        ),
        EventDefinition(
            id : "r-special-fwd", name : "Front-Drive Frenzy", tier : .rookie, discipline : .circuit, kind : .circuit,
            trackID : "oldtown-circuit", laps : 3,
            requirements : EventRequirements( drivetrain : .fwd, requiredEventIDs : [ "r-circuit-1" ] ),
            isSpecial : true,
            summary : "Front-wheel drive only. Tight streets reward a planted nose."
        ),
        EventDefinition(
            id : "r-rival-voss", name : "Redline's Challenge", tier : .rookie, discipline : .drag, kind : .drag,
            trackID : "kestrel-quarter", opponents : 1, timeOfDay : .night,
            requirements : needs( "r-drag-2", level : 3 ),
            rivalID : "rival-voss",
            summary : "Mara Voss runs the airfield. Beat her at her own game."
        )
    ]

    // MARK: - Street Scene

    static let street : [EventDefinition] = [
        EventDefinition(
            id : "s-street-1", name : "Downtown Dash", tier : .street, discipline : .street, kind : .sprint,
            trackID : "neon-downtown", timeOfDay : .night,
            summary : "Block by block through the financial district."
        ),
        EventDefinition(
            id : "s-street-2", name : "Ring Road", tier : .street, discipline : .street, kind : .circuit,
            trackID : "neon-expressway", laps : 3, timeOfDay : .night,
            summary : "Three laps of the elevated expressway at full chat."
        ),
        EventDefinition(
            id : "s-drag-1", name : "Bridge Run", tier : .street, discipline : .drag, kind : .drag,
            trackID : "neon-quarter", opponents : 1, timeOfDay : .night,
            summary : "A quarter mile across the harbour bridge."
        ),
        EventDefinition(
            id : "s-drift-1", name : "Harbour Lights", tier : .street, discipline : .drift, kind : sections,
            trackID : "harbour-yard", laps : 2, opponents : 0, timeOfDay : .night,
            summary : "Only the marked corners score. Make them count."
        ),
        EventDefinition(
            id : "s-elim-1", name : "Dockside Knockout", tier : .street, discipline : .street, kind : .elimination,
            trackID : "harbour-loop", timeOfDay : .sunset,
            summary : "Six cars, five laps, one survivor."
        ),
        EventDefinition(
            id : "s-mountain-1", name : "Ridge Climb", tier : .street, discipline : .mountain, kind : .sprint,
            trackID : "ridge-uphill", opponents : 3, timeOfDay : .sunset,
            summary : "Up the switchbacks. Traction wins."
        ),
        EventDefinition(
            id : "s-cp-1", name : "Market Rush", tier : .street, discipline : .street, kind : checkpoint,
            trackID : "oldtown-sprint", opponents : 0,
            summary : "Beat the clock through the old town lanes."
        ),
        EventDefinition(
            id : "s-ta-1", name : "Citadel Hotlap", tier : .street, discipline : .circuit, kind : .timeAttack,
            trackID : "oldtown-circuit", laps : 3, opponents : 0,
            summary : "Precision around the citadel walls."
        ),
        EventDefinition(
            id : "s-sprint-1", name : "Pine Dash", tier : .street, discipline : .sprint, kind : .sprint,
            trackID : "pines-stage",
            summary : "Through the forest, flat out where you dare."
        ),
        EventDefinition(
            id : "s-trap-1", name : "Highway Radar", tier : .street, discipline : .sprint, kind : .speedTrap,
            trackID : "mesa-highway", opponents : 0, timeOfDay : .sunset,
            summary : "Three radar traps on Highway 9."
        ),
        EventDefinition(
            id : "s-special-rwd", name : "Tail Happy", tier : .street, discipline : .drift, kind : scoreAttack60,
            trackID : "kestrel-pad", opponents : 0,
            requirements : EventRequirements( drivetrain : .rwd ),
            isSpecial : true,
            summary : "Rear-wheel drive only. The whole apron is yours."
        ),
        EventDefinition(
            id : "s-rival-arata", name : "Sidewinder's Yard", tier : .street, discipline : .drift, kind : tandem,
            trackID : "harbour-yard", laps : 2, opponents : 1, timeOfDay : .night,
            requirements : needs( "s-drift-1", level : 4 ),
            rivalID : "rival-arata",
            summary : "Chase Kenji Arata through the container yard. Stay close, stay sideways."
        ),
        EventDefinition(
            id : "s-rival-calloway", name : "Switchback Duel", tier : .street, discipline : .mountain, kind : .sprint,
            trackID : "ridge-uphill", opponents : 1, timeOfDay : .sunset,
            requirements : needs( "s-mountain-1", level : 4 ),
            rivalID : "rival-calloway",
            summary : "One on one up Serpent Ridge against the local legend."
        ),
        EventDefinition(
            id : "s-rival-okafor", name : "Neon's Invitation", tier : .street, discipline : .street, kind : .sprint,
            trackID : "neon-downtown", opponents : 1, timeOfDay : .night,
            requirements : needs( "s-street-1", level : 5 ),
            rivalID : "rival-okafor",
            summary : "Ravi Okafor wants to see what you've got downtown."
        )
    ]

    // MARK: - Club Series

    static let club : [EventDefinition] = [
        EventDefinition(
            id : "c-circuit-1", name : "Velocity Club Race", tier : .club, discipline : .circuit, kind : .circuit,
            trackID : "velocity-gp", laps : 3,
            summary : "The full Grand Prix layout for the first time."
        ),
        EventDefinition(
            id : "c-circuit-2", name : "Foundry Cup", tier : .club, discipline : .circuit, kind : .circuit,
            trackID : "ashgrove-foundry", laps : 4,
            summary : "Dusty tarmac and blast furnaces. Grip is precious."
        ),
        EventDefinition(
            id : "c-drag-1", name : "Half-Mile Heat", tier : .club, discipline : .drag, kind : .drag,
            trackID : "kestrel-half", opponents : 1,
            summary : "Twice the distance, twice the top-end."
        ),
        EventDefinition(
            id : "c-drift-1", name : "Smelter Chain", tier : .club, discipline : .drift, kind : chain,
            trackID : "ashgrove-smelter", laps : 2, opponents : 0,
            summary : "Link every corner. Your best unbroken chain is your score."
        ),
        EventDefinition(
            id : "c-elim-1", name : "Taxiway Takedown", tier : .club, discipline : .circuit, kind : .elimination,
            trackID : "kestrel-circuit",
            summary : "Elimination on the airfield's giant straight."
        ),
        EventDefinition(
            id : "c-sprint-1", name : "Rail Yard Rush", tier : .club, discipline : .sprint, kind : .sprint,
            trackID : "ashgrove-run",
            summary : "Sidings, sheds and a dusty finish."
        ),
        EventDefinition(
            id : "c-ta-1", name : "GP Hotlap", tier : .club, discipline : .circuit, kind : .timeAttack,
            trackID : "velocity-gp", laps : 3, opponents : 0,
            summary : "Learn the Grand Prix circuit one sector at a time."
        ),
        EventDefinition(
            id : "c-endurance-1", name : "Lighthouse 8", tier : .club, discipline : .circuit, kind : .endurance,
            trackID : "coast-lighthouse", laps : 8,
            summary : "Eight laps. Tyres wear. Pace yourself."
        ),
        EventDefinition(
            id : "c-mountain-1", name : "Downhill Nerve", tier : .club, discipline : .mountain, kind : .sprint,
            trackID : "ridge-downhill", opponents : 3, timeOfDay : .night,
            summary : "Descend the pass in the dark."
        ),
        EventDefinition(
            id : "c-cp-1", name : "Forest Chase", tier : .club, discipline : .sprint, kind : checkpoint,
            trackID : "pines-stage-rev", opponents : 0, weather : .rain,
            summary : "Wet roads, tight clock."
        ),
        EventDefinition(
            id : "c-special-hatch", name : "Hot Hatch Heroes", tier : .club, discipline : .circuit, kind : .circuit,
            trackID : "harbour-loop", laps : 4,
            requirements : EventRequirements( categories : [ .hatchback ] ),
            isSpecial : true,
            summary : "Hatchbacks only. Door handles will touch."
        ),
        EventDefinition(
            id : "c-rival-lindqvist", name : "The Professor's Test", tier : .club, discipline : .circuit, kind : .circuit,
            trackID : "velocity-national", laps : 3, opponents : 1,
            requirements : needs( "c-circuit-1", level : 7 ),
            rivalID : "rival-lindqvist",
            summary : "Sofia Lindqvist sets the curriculum. Three laps, one opponent."
        ),
        EventDefinition(
            id : "c-rival-voss", name : "Redline Rematch", tier : .club, discipline : .drag, kind : .drag,
            trackID : "kestrel-quarter", opponents : 1, timeOfDay : .night,
            requirements : needs( "c-drag-1", "r-rival-voss", level : 8 ),
            rivalID : "rival-voss",
            summary : "Voss has a bigger engine and a grudge."
        )
    ]

    // MARK: - Regional Tour

    static let regional : [EventDefinition] = [
        EventDefinition(
            id : "g-circuit-1", name : "Harbour Grand Prix", tier : .regional, discipline : .circuit, kind : .circuit,
            trackID : "harbour-loop-rev", laps : 5, weather : .rain,
            summary : "Five wet laps between the walls."
        ),
        EventDefinition(
            id : "g-sprint-1", name : "Coast Road Classic", tier : .regional, discipline : .sprint, kind : .sprint,
            trackID : "coast-road", timeOfDay : .sunset,
            summary : "The most beautiful road in the game, at the least sensible speed."
        ),
        EventDefinition(
            id : "g-drag-1", name : "Salt Flat Half", tier : .regional, discipline : .drag, kind : .drag,
            trackID : "mesa-half", opponents : 1,
            summary : "Half a mile of dusty salt. Traction is scarce."
        ),
        EventDefinition(
            id : "g-drift-1", name : "Airfield Tandem", tier : .regional, discipline : .drift, kind : tandem,
            trackID : "kestrel-pad", laps : 2, opponents : 1,
            summary : "Follow the lead car around the apron. Proximity multiplies."
        ),
        EventDefinition(
            id : "g-elim-1", name : "Outer Ring Elimination", tier : .regional, discipline : .street, kind : .elimination,
            trackID : "neon-expressway-rev", timeOfDay : .night,
            summary : "The outer expressway, one car fewer each lap."
        ),
        EventDefinition(
            id : "g-trap-1", name : "Salt Flat Speedway", tier : .regional, discipline : .sprint, kind : .speedTrap,
            trackID : "mesa-speedrun", opponents : 0,
            summary : "The fastest road in Shiftline. How brave is your right foot?"
        ),
        EventDefinition(
            id : "g-ta-1", name : "Expressway Hotlap", tier : .regional, discipline : .street, kind : .timeAttack,
            trackID : "neon-expressway", laps : 3, opponents : 0, timeOfDay : .night,
            summary : "The ring road with nobody in your way."
        ),
        EventDefinition(
            id : "g-mountain-1", name : "Serpent Uphill", tier : .regional, discipline : .mountain, kind : .sprint,
            trackID : "ridge-uphill", opponents : 5, weather : .fog,
            summary : "A full field up the pass in fog."
        ),
        EventDefinition(
            id : "g-cp-1", name : "Highway 9 Pursuit", tier : .regional, discipline : .sprint, kind : checkpoint,
            trackID : "mesa-highway", opponents : 0,
            summary : "Four kilometres of desert against the clock."
        ),
        EventDefinition(
            id : "g-endurance-1", name : "Foundry 10", tier : .regional, discipline : .circuit, kind : .endurance,
            trackID : "ashgrove-foundry-rev", laps : 10,
            summary : "Ten laps of the reversed foundry. Manage your tyres."
        ),
        EventDefinition(
            id : "g-special-awd", name : "All-Wheel Assault", tier : .regional, discipline : .sprint, kind : .sprint,
            trackID : "pines-stage-rev", weather : .rain,
            requirements : EventRequirements( drivetrain : .awd ),
            isSpecial : true,
            summary : "All-wheel drive only, wet forest stage."
        ),
        EventDefinition(
            id : "g-rival-arata", name : "Apron Lesson", tier : .regional, discipline : .drift, kind : tandem,
            trackID : "kestrel-pad", laps : 2, opponents : 1, timeOfDay : .night,
            requirements : needs( "s-rival-arata", level : 11 ),
            rivalID : "rival-arata",
            summary : "Arata returns with more boost. Follow him, if you can."
        ),
        EventDefinition(
            id : "g-rival-calloway", name : "Midnight Descent", tier : .regional, discipline : .mountain, kind : .sprint,
            trackID : "ridge-downhill", opponents : 1, timeOfDay : .night,
            requirements : needs( "s-rival-calloway", level : 11 ),
            rivalID : "rival-calloway",
            summary : "Downhill in the dark with Dex Calloway."
        ),
        EventDefinition(
            id : "g-rival-moreau", name : "The Champion Calls", tier : .regional, discipline : .sprint, kind : .sprint,
            trackID : "coast-road", opponents : 1, timeOfDay : .sunset,
            requirements : needs( "g-sprint-1", level : 12 ),
            rivalID : "rival-moreau",
            summary : "Inès Moreau has noticed you. That is not necessarily good news."
        )
    ]

    // MARK: - Pro Circuit

    static let professional : [EventDefinition] = [
        EventDefinition(
            id : "p-circuit-1", name : "Velocity Grand Prix", tier : .professional, discipline : .circuit, kind : .circuit,
            trackID : "velocity-gp", laps : 5,
            summary : "Five laps of the full Grand Prix. The big one."
        ),
        EventDefinition(
            id : "p-circuit-2", name : "Reverse Grand Prix", tier : .professional, discipline : .circuit, kind : .circuit,
            trackID : "velocity-gp-rev", laps : 4, timeOfDay : .sunset,
            summary : "Clockwise at dusk. Everything you know, backwards."
        ),
        EventDefinition(
            id : "p-drag-1", name : "Standing Kilometre", tier : .professional, discipline : .drag, kind : .drag,
            trackID : "kestrel-kilometre", opponents : 1,
            summary : "A full kilometre from a standstill."
        ),
        EventDefinition(
            id : "p-drift-1", name : "Harbour Masters", tier : .professional, discipline : .drift, kind : sections,
            trackID : "harbour-yard", laps : 2, opponents : 0, weather : .rain, timeOfDay : .night,
            summary : "Wet concrete sections. Less grip, more angle."
        ),
        EventDefinition(
            id : "p-sprint-1", name : "Pines Rally Stage", tier : .professional, discipline : .sprint, kind : .sprint,
            trackID : "pines-stage-rev", weather : .rain,
            summary : "The forest stage in the rain against a pro field."
        ),
        EventDefinition(
            id : "p-elim-1", name : "Citadel Survivor", tier : .professional, discipline : .street, kind : .elimination,
            trackID : "oldtown-circuit",
            summary : "Elimination on cobbles. Every mistake is final."
        ),
        EventDefinition(
            id : "p-ta-1", name : "Taxiway Time Trial", tier : .professional, discipline : .circuit, kind : .timeAttack,
            trackID : "kestrel-circuit", laps : 3, opponents : 0,
            summary : "Pro-level times on the airfield."
        ),
        EventDefinition(
            id : "p-endurance-1", name : "Velocity 12", tier : .professional, discipline : .circuit, kind : .endurance,
            trackID : "velocity-national", laps : 12,
            summary : "Twelve laps of the National loop."
        ),
        EventDefinition(
            id : "p-trap-1", name : "Coastal Radar", tier : .professional, discipline : .sprint, kind : .speedTrap,
            trackID : "coast-road-rev", opponents : 0,
            summary : "Speed traps between the cliffs."
        ),
        EventDefinition(
            id : "p-cp-1", name : "Downtown Pursuit", tier : .professional, discipline : .street, kind : checkpoint,
            trackID : "neon-downtown", opponents : 0, weather : .rain, timeOfDay : .night,
            summary : "Wet city streets and a merciless clock."
        ),
        EventDefinition(
            id : "p-special-track", name : "Track Day Club", tier : .professional, discipline : .circuit, kind : .circuit,
            trackID : "velocity-gp", laps : 4,
            requirements : EventRequirements( categories : [ .trackCar ] ),
            isSpecial : true,
            summary : "Lightweight track cars only. Downforce and nerve."
        ),
        EventDefinition(
            id : "p-rival-voss", name : "Redline's Last Stand", tier : .professional, discipline : .drag, kind : .drag,
            trackID : "kestrel-half", opponents : 1, timeOfDay : .night,
            requirements : needs( "c-rival-voss", level : 16 ),
            rivalID : "rival-voss",
            summary : "Goliath X versus you. Half a mile. Winner takes the strip."
        ),
        EventDefinition(
            id : "p-rival-lindqvist", name : "The Professor's Thesis", tier : .professional, discipline : .circuit, kind : .circuit,
            trackID : "velocity-gp", laps : 3, opponents : 1,
            requirements : needs( "c-rival-lindqvist", level : 16 ),
            rivalID : "rival-lindqvist",
            summary : "Lindqvist in a Hawk R on the Grand Prix circuit."
        ),
        EventDefinition(
            id : "p-rival-okafor", name : "City at 280", tier : .professional, discipline : .street, kind : .circuit,
            trackID : "neon-expressway", laps : 2, opponents : 1, timeOfDay : .night,
            requirements : needs( "s-rival-okafor", level : 17 ),
            rivalID : "rival-okafor",
            summary : "Okafor on his home expressway in a Spectre RS."
        )
    ]

    // MARK: - Elite Masters

    static let elite : [EventDefinition] = [
        EventDefinition(
            id : "e-circuit-1", name : "Expressway 500", tier : .elite, discipline : .street, kind : .circuit,
            trackID : "neon-expressway", laps : 6, timeOfDay : .night,
            summary : "Six laps of the ring road with the elite."
        ),
        EventDefinition(
            id : "e-sprint-1", name : "Mesa Marathon", tier : .elite, discipline : .sprint, kind : .sprint,
            trackID : "mesa-highway",
            summary : "The desert highway at supercar pace."
        ),
        EventDefinition(
            id : "e-drag-1", name : "Night Kilometre", tier : .elite, discipline : .drag, kind : .drag,
            trackID : "kestrel-kilometre", opponents : 1, timeOfDay : .night,
            summary : "A kilometre in the dark at 300+."
        ),
        EventDefinition(
            id : "e-drift-1", name : "Smelter Showdown", tier : .elite, discipline : .drift, kind : scoreAttack90,
            trackID : "ashgrove-smelter", opponents : 0, timeOfDay : .sunset,
            summary : "Ninety seconds, endless transitions."
        ),
        EventDefinition(
            id : "e-elim-1", name : "Harbour Knockout", tier : .elite, discipline : .street, kind : .elimination,
            trackID : "harbour-loop", weather : .rain, timeOfDay : .night,
            summary : "Wet, dark and walled in. Five eliminations."
        ),
        EventDefinition(
            id : "e-mountain-1", name : "Downhill Masters", tier : .elite, discipline : .mountain, kind : .sprint,
            trackID : "ridge-downhill", opponents : 5,
            summary : "A full elite grid down Serpent Ridge."
        ),
        EventDefinition(
            id : "e-ta-1", name : "Lighthouse Hotlap", tier : .elite, discipline : .circuit, kind : .timeAttack,
            trackID : "coast-lighthouse", laps : 3, opponents : 0, timeOfDay : .sunset,
            summary : "Elite times around the headland."
        ),
        EventDefinition(
            id : "e-endurance-1", name : "Coast 10", tier : .elite, discipline : .circuit, kind : .endurance,
            trackID : "coast-lighthouse", laps : 10,
            summary : "Ten laps by the sea."
        ),
        EventDefinition(
            id : "e-cp-1", name : "Cliff Chase", tier : .elite, discipline : .sprint, kind : checkpoint,
            trackID : "coast-road", opponents : 0, timeOfDay : .night,
            summary : "Checkpoints along the cliffs at night."
        ),
        EventDefinition(
            id : "e-special-muscle", name : "Muscle Mayhem", tier : .elite, discipline : .drag, kind : .drag,
            trackID : "mesa-half", opponents : 1,
            requirements : EventRequirements( categories : [ .muscle ] ),
            isSpecial : true,
            summary : "Muscle cars only. Half a mile of smoke."
        ),
        EventDefinition(
            id : "e-rival-arata", name : "Sidewinder's Finale", tier : .elite, discipline : .drift, kind : tandem,
            trackID : "ashgrove-smelter", laps : 2, opponents : 1, timeOfDay : .night,
            requirements : needs( "g-rival-arata", level : 22 ),
            rivalID : "rival-arata",
            summary : "Arata in his Hikari RS. The last lesson."
        ),
        EventDefinition(
            id : "e-rival-calloway", name : "Summit Showdown", tier : .elite, discipline : .mountain, kind : .sprint,
            trackID : "ridge-uphill", opponents : 1, weather : .fog, timeOfDay : .night,
            requirements : needs( "g-rival-calloway", level : 22 ),
            rivalID : "rival-calloway",
            summary : "Uphill, foggy, midnight. Calloway's favourite conditions."
        ),
        EventDefinition(
            id : "e-rival-okafor", name : "My Streets", tier : .elite, discipline : .street, kind : .circuit,
            trackID : "neon-expressway-rev", laps : 3, opponents : 1, timeOfDay : .night,
            requirements : needs( "p-rival-okafor", level : 23 ),
            rivalID : "rival-okafor",
            summary : "Okafor's final defence of the city."
        ),
        EventDefinition(
            id : "e-rival-moreau", name : "Champion's Pace", tier : .elite, discipline : .sprint, kind : .sprint,
            trackID : "mesa-highway", opponents : 1,
            requirements : needs( "g-rival-moreau", level : 24 ),
            rivalID : "rival-moreau",
            summary : "Moreau in a Vortex. Four kilometres. No excuses."
        )
    ]

    // MARK: - Legend Series

    static let legend : [EventDefinition] = [
        EventDefinition(
            id : "l-circuit-1", name : "Legend Grand Prix", tier : .legend, discipline : .circuit, kind : .circuit,
            trackID : "velocity-gp", laps : 6,
            summary : "The fastest field in Shiftline on the full GP circuit."
        ),
        EventDefinition(
            id : "l-sprint-1", name : "Coast to Cliff", tier : .legend, discipline : .sprint, kind : .sprint,
            trackID : "coast-road-rev", weather : .rain,
            summary : "Hypercars on a wet coast road."
        ),
        EventDefinition(
            id : "l-drag-1", name : "Hypercar Half", tier : .legend, discipline : .drag, kind : .drag,
            trackID : "mesa-half", opponents : 1,
            summary : "Over a thousand horsepower each, half a mile of salt."
        ),
        EventDefinition(
            id : "l-drift-1", name : "Legend Chain", tier : .legend, discipline : .drift, kind : chain,
            trackID : "harbour-yard", laps : 3, opponents : 0, timeOfDay : .night,
            summary : "Three laps, one chain. Don't drop it."
        ),
        EventDefinition(
            id : "l-elim-1", name : "Final Elimination", tier : .legend, discipline : .circuit, kind : .elimination,
            trackID : "velocity-gp-rev",
            summary : "The last elimination: reversed Grand Prix."
        ),
        EventDefinition(
            id : "l-ta-1", name : "The Perfect Lap", tier : .legend, discipline : .circuit, kind : .timeAttack,
            trackID : "velocity-gp", laps : 3, opponents : 0,
            summary : "Legend times on the GP circuit. Perfection required."
        ),
        EventDefinition(
            id : "l-endurance-1", name : "Velocity 10", tier : .legend, discipline : .circuit, kind : .endurance,
            trackID : "velocity-gp", laps : 10, timeOfDay : .sunset,
            summary : "Ten laps of the Grand Prix into the night."
        ),
        EventDefinition(
            id : "l-trap-1", name : "Terminal Velocity", tier : .legend, discipline : .sprint, kind : .speedTrap,
            trackID : "mesa-speedrun", opponents : 0, timeOfDay : .night,
            summary : "Top speed runs across the salt at night."
        ),
        EventDefinition(
            id : "l-rival-lindqvist", name : "Final Exam", tier : .legend, discipline : .circuit, kind : .circuit,
            trackID : "velocity-gp", laps : 3, opponents : 1,
            requirements : needs( "p-rival-lindqvist", level : 28 ),
            rivalID : "rival-lindqvist",
            summary : "Lindqvist in the Peregrine. The last lecture."
        ),
        EventDefinition(
            id : "l-rival-moreau", name : "For the Crown", tier : .legend, discipline : .circuit, kind : .circuit,
            trackID : "velocity-gp-rev", laps : 4, opponents : 1, timeOfDay : .night,
            requirements : needs( "e-rival-moreau", level : 30 ),
            rivalID : "rival-moreau",
            summary : "Inès Moreau. The Fulmine. The crown."
        )
    ]
}
