import Foundation

nonisolated struct ChampionshipRound : Identifiable {
    let id : String
    let name : String
    let kind : RaceKind
    let trackID : TrackID
    var laps = 1
    var weather = Weather.clear
    var timeOfDay = TimeOfDay.day

    var discipline : Discipline {
        switch kind {
        case .drag:
            return .drag
        case .drift:
            return .drift
        case .sprint:
            return Tracks.named( trackID )?.environment == .serpentRidge ? .mountain : .sprint
        default:
            return .circuit
        }
    }
}

nonisolated struct ChampionshipDefinition : Identifiable {
    let id : String
    let name : String
    let tier : CareerTier
    let summary : String
    let rounds : [ChampionshipRound]
    var fieldSize = 6
    var requirements = EventRequirements()
    var prize : Int
}

nonisolated enum ChampionshipScoring {
    /// Points for 1st, 2nd, 3rd... Positions beyond the table score nothing.
    static let points = [ 25, 18, 15, 12, 10, 8, 6, 4 ]

    static func points( forPosition position : Int ) -> Int {
        position >= 1 && position <= points.count ? points[ position - 1 ] : 0
    }
}

nonisolated enum Championships {
    static func named( _ id : String ) -> ChampionshipDefinition? {
        all.first { $0.id == id }
    }

    static let all : [ChampionshipDefinition] = [
        ChampionshipDefinition(
            id : "ch-rookie",
            name : "Rookie Cup Finals",
            tier : .rookie,
            summary : "Four rounds, four disciplines. Prove you belong.",
            rounds : [
                ChampionshipRound( id : "ch-rookie-1", name : "Quayside Sprint", kind : .sprint, trackID : "harbour-sprint" ),
                ChampionshipRound( id : "ch-rookie-2", name : "National Race", kind : .circuit, trackID : "velocity-national", laps : 3 ),
                ChampionshipRound( id : "ch-rookie-3", name : "Airfield Quarter", kind : .drag, trackID : "kestrel-quarter", timeOfDay : .night ),
                ChampionshipRound( id : "ch-rookie-4", name : "Taxiway Knockout", kind : .elimination, trackID : "kestrel-circuit" )
            ],
            requirements : EventRequirements( minimumLevel : 3, requiredEventIDs : [ "r-circuit-1", "r-drag-1" ] ),
            prize : 12_000
        ),
        ChampionshipDefinition(
            id : "ch-neon",
            name : "Neon Nights Series",
            tier : .street,
            summary : "The city's closed-road night championship.",
            rounds : [
                ChampionshipRound( id : "ch-neon-1", name : "Downtown", kind : .sprint, trackID : "neon-downtown", timeOfDay : .night ),
                ChampionshipRound( id : "ch-neon-2", name : "Ring Road", kind : .circuit, trackID : "neon-expressway", laps : 3, timeOfDay : .night ),
                ChampionshipRound( id : "ch-neon-3", name : "Bridge Quarter", kind : .drag, trackID : "neon-quarter", timeOfDay : .night ),
                ChampionshipRound( id : "ch-neon-4", name : "Docks Elimination", kind : .elimination, trackID : "harbour-loop", timeOfDay : .night )
            ],
            requirements : EventRequirements( minimumLevel : 5, requiredEventIDs : [ "s-street-1", "s-street-2" ] ),
            prize : 20_000
        ),
        ChampionshipDefinition(
            id : "ch-club",
            name : "Club Championship",
            tier : .club,
            summary : "A proper five-round circuit season.",
            rounds : [
                ChampionshipRound( id : "ch-club-1", name : "Velocity", kind : .circuit, trackID : "velocity-gp", laps : 3 ),
                ChampionshipRound( id : "ch-club-2", name : "Foundry", kind : .circuit, trackID : "ashgrove-foundry", laps : 3 ),
                ChampionshipRound( id : "ch-club-3", name : "Taxiway Time Trial", kind : .timeAttack, trackID : "kestrel-circuit", laps : 2 ),
                ChampionshipRound( id : "ch-club-4", name : "Rail Yard", kind : .sprint, trackID : "ashgrove-run" ),
                ChampionshipRound( id : "ch-club-5", name : "Lighthouse", kind : .circuit, trackID : "coast-lighthouse", laps : 4, timeOfDay : .sunset )
            ],
            requirements : EventRequirements( minimumLevel : 8, requiredEventIDs : [ "c-circuit-1" ] ),
            prize : 34_000
        ),
        ChampionshipDefinition(
            id : "ch-drift",
            name : "Drift Masters",
            tier : .club,
            summary : "Four judged drift rounds. Every rival's score comes from a real run.",
            rounds : [
                ChampionshipRound( id : "ch-drift-1", name : "Container Yard", kind : .drift( .scoreAttack, duration : 60 ), trackID : "harbour-yard" ),
                ChampionshipRound( id : "ch-drift-2", name : "Apron Sections", kind : .drift( .sections, duration : 0 ), trackID : "kestrel-pad", laps : 2 ),
                ChampionshipRound( id : "ch-drift-3", name : "Smelter Chain", kind : .drift( .chain, duration : 0 ), trackID : "ashgrove-smelter", laps : 2, timeOfDay : .night ),
                ChampionshipRound( id : "ch-drift-4", name : "Wet Yard", kind : .drift( .scoreAttack, duration : 60 ), trackID : "harbour-yard", weather : .rain, timeOfDay : .sunset )
            ],
            requirements : EventRequirements( minimumLevel : 9, drivetrain : .rwd, requiredEventIDs : [ "c-drift-1" ] ),
            prize : 36_000
        ),
        ChampionshipDefinition(
            id : "ch-mountain",
            name : "Mountain Kings",
            tier : .regional,
            summary : "Four runs on the ridge and in the pines.",
            rounds : [
                ChampionshipRound( id : "ch-mountain-1", name : "Summit", kind : .sprint, trackID : "ridge-summit", timeOfDay : .sunset ),
                ChampionshipRound( id : "ch-mountain-2", name : "Uphill", kind : .sprint, trackID : "ridge-uphill" ),
                ChampionshipRound( id : "ch-mountain-3", name : "Forest", kind : .sprint, trackID : "pines-stage", weather : .rain ),
                ChampionshipRound( id : "ch-mountain-4", name : "Downhill", kind : .sprint, trackID : "ridge-downhill", timeOfDay : .night )
            ],
            fieldSize : 5,
            requirements : EventRequirements( minimumLevel : 11, requiredEventIDs : [ "g-mountain-1" ] ),
            prize : 48_000
        ),
        ChampionshipDefinition(
            id : "ch-drag",
            name : "Strip Kings",
            tier : .regional,
            summary : "Four distances. Every competitor makes a real pass; lowest time wins.",
            rounds : [
                ChampionshipRound( id : "ch-drag-1", name : "Eighth", kind : .drag, trackID : "kestrel-eighth" ),
                ChampionshipRound( id : "ch-drag-2", name : "Quarter", kind : .drag, trackID : "kestrel-quarter", timeOfDay : .night ),
                ChampionshipRound( id : "ch-drag-3", name : "Half", kind : .drag, trackID : "mesa-half" ),
                ChampionshipRound( id : "ch-drag-4", name : "Kilometre", kind : .drag, trackID : "kestrel-kilometre" )
            ],
            requirements : EventRequirements( minimumLevel : 12, requiredEventIDs : [ "g-drag-1" ] ),
            prize : 44_000
        ),
        ChampionshipDefinition(
            id : "ch-pro",
            name : "Pro Tour",
            tier : .professional,
            summary : "Five venues, one title, the whole paddock watching.",
            rounds : [
                ChampionshipRound( id : "ch-pro-1", name : "Velocity GP", kind : .circuit, trackID : "velocity-gp", laps : 4 ),
                ChampionshipRound( id : "ch-pro-2", name : "Wet Harbour", kind : .circuit, trackID : "harbour-loop-rev", laps : 4, weather : .rain ),
                ChampionshipRound( id : "ch-pro-3", name : "Expressway", kind : .circuit, trackID : "neon-expressway", laps : 3, timeOfDay : .night ),
                ChampionshipRound( id : "ch-pro-4", name : "Kilometre", kind : .drag, trackID : "kestrel-kilometre" ),
                ChampionshipRound( id : "ch-pro-5", name : "Coast Road", kind : .sprint, trackID : "coast-road", timeOfDay : .sunset )
            ],
            requirements : EventRequirements( minimumLevel : 17, requiredEventIDs : [ "p-circuit-1" ] ),
            prize : 80_000
        ),
        ChampionshipDefinition(
            id : "ch-elite",
            name : "Elite Grand Prix",
            tier : .elite,
            summary : "The elite season: circuits, a time trial and a knockout.",
            rounds : [
                ChampionshipRound( id : "ch-elite-1", name : "Reverse GP", kind : .circuit, trackID : "velocity-gp-rev", laps : 4 ),
                ChampionshipRound( id : "ch-elite-2", name : "Lighthouse Trial", kind : .timeAttack, trackID : "coast-lighthouse", laps : 2 ),
                ChampionshipRound( id : "ch-elite-3", name : "Outer Ring", kind : .circuit, trackID : "neon-expressway-rev", laps : 4, timeOfDay : .night ),
                ChampionshipRound( id : "ch-elite-4", name : "Citadel Knockout", kind : .elimination, trackID : "oldtown-circuit" ),
                ChampionshipRound( id : "ch-elite-5", name : "Foundry", kind : .circuit, trackID : "ashgrove-foundry-rev", laps : 5, weather : .rain )
            ],
            requirements : EventRequirements( minimumLevel : 23, requiredEventIDs : [ "e-circuit-1" ] ),
            prize : 140_000
        ),
        ChampionshipDefinition(
            id : "ch-legend",
            name : "Shiftline Legends Cup",
            tier : .legend,
            summary : "The final championship. Every discipline, the best drivers alive.",
            rounds : [
                ChampionshipRound( id : "ch-legend-1", name : "Grand Prix", kind : .circuit, trackID : "velocity-gp", laps : 5 ),
                ChampionshipRound( id : "ch-legend-2", name : "Salt Flat Half", kind : .drag, trackID : "mesa-half" ),
                ChampionshipRound( id : "ch-legend-3", name : "Serpent Downhill", kind : .sprint, trackID : "ridge-downhill", timeOfDay : .night ),
                ChampionshipRound( id : "ch-legend-4", name : "Expressway", kind : .circuit, trackID : "neon-expressway", laps : 4, timeOfDay : .night ),
                ChampionshipRound( id : "ch-legend-5", name : "Final Elimination", kind : .elimination, trackID : "velocity-gp-rev" )
            ],
            fieldSize : 7,
            requirements : EventRequirements( minimumLevel : 29, requiredEventIDs : [ "l-circuit-1" ] ),
            prize : 250_000
        )
    ]
}
