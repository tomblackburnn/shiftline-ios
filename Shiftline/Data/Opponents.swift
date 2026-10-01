import Foundation

nonisolated enum DrivingStyle : String, Codable {
    case aggressive
    case defensive
    case clean
    case lateBraker
    case metronome

    var title : String {
        switch self {
        case .aggressive:
            return "Aggressive"
        case .defensive:
            return "Defensive"
        case .clean:
            return "Clean"
        case .lateBraker:
            return "Late Braker"
        case .metronome:
            return "Metronome"
        }
    }
}

/// How an AI driver behaves. Skill is added to the event's base skill.
nonisolated struct DriverProfile : Identifiable, Codable, Equatable {
    let id : String
    let name : String
    let style : DrivingStyle
    /// -0.1 ... 0.15 relative to the event.
    let skill : Double
    let aggression : Double
    let consistency : Double
    let brakingLateness : Double
    let defensiveness : Double
    let colourHex : UInt32

    init(
        id : String,
        name : String,
        style : DrivingStyle,
        skill : Double,
        colourHex : UInt32
    ) {
        self.id = id
        self.name = name
        self.style = style
        self.skill = skill
        self.colourHex = colourHex

        switch style {
        case .aggressive:
            aggression = 0.9
            consistency = 0.75
            brakingLateness = 0.6
            defensiveness = 0.4
        case .defensive:
            aggression = 0.35
            consistency = 0.85
            brakingLateness = 0.4
            defensiveness = 0.95
        case .clean:
            aggression = 0.3
            consistency = 0.9
            brakingLateness = 0.35
            defensiveness = 0.3
        case .lateBraker:
            aggression = 0.7
            consistency = 0.7
            brakingLateness = 1
            defensiveness = 0.5
        case .metronome:
            aggression = 0.45
            consistency = 1
            brakingLateness = 0.5
            defensiveness = 0.5
        }
    }
}

nonisolated struct RivalEncounter {
    let tier : CareerTier
    let carID : CarID
    let taunt : String
}

nonisolated struct Rival : Identifiable {
    let id : String
    let profile : DriverProfile
    let nickname : String
    let specialty : Discipline
    let bio : String
    let encounters : [RivalEncounter]
    let defeatLine : String
}

nonisolated enum Opponents {
    static let pool : [DriverProfile] = [
        DriverProfile( id : "ai-okoro", name : "Tobi Okoro", style : .clean, skill : 0.02, colourHex : 0x2ECC71 ),
        DriverProfile( id : "ai-vance", name : "Harriet Vance", style : .defensive, skill : 0.0, colourHex : 0x3498DB ),
        DriverProfile( id : "ai-marchetti", name : "Luca Marchetti", style : .lateBraker, skill : 0.04, colourHex : 0xE74C3C ),
        DriverProfile( id : "ai-sato", name : "Rin Sato", style : .metronome, skill : 0.03, colourHex : 0xF1C40F ),
        DriverProfile( id : "ai-brandt", name : "Jonas Brandt", style : .aggressive, skill : 0.01, colourHex : 0x9B59B6 ),
        DriverProfile( id : "ai-reyes", name : "Camila Reyes", style : .clean, skill : 0.05, colourHex : 0x1ABC9C ),
        DriverProfile( id : "ai-kowal", name : "Piotr Kowal", style : .defensive, skill : -0.03, colourHex : 0xE67E22 ),
        DriverProfile( id : "ai-achebe", name : "Zara Achebe", style : .aggressive, skill : 0.06, colourHex : 0xECF0F1 ),
        DriverProfile( id : "ai-lindgren", name : "Elsa Lindgren", style : .metronome, skill : 0.0, colourHex : 0x5DADE2 ),
        DriverProfile( id : "ai-dubois", name : "Mathis Dubois", style : .lateBraker, skill : -0.02, colourHex : 0xAF7AC5 ),
        DriverProfile( id : "ai-park", name : "Min-jun Park", style : .clean, skill : -0.04, colourHex : 0x48C9B0 ),
        DriverProfile( id : "ai-oconnell", name : "Aoife O'Connell", style : .aggressive, skill : -0.01, colourHex : 0x58D68D ),
        DriverProfile( id : "ai-haddad", name : "Karim Haddad", style : .defensive, skill : 0.02, colourHex : 0xF5B041 ),
        DriverProfile( id : "ai-novak", name : "Petra Novak", style : .metronome, skill : 0.04, colourHex : 0xEC7063 ),
        DriverProfile( id : "ai-silva", name : "Rafael Silva", style : .lateBraker, skill : 0.03, colourHex : 0x52BE80 ),
        DriverProfile( id : "ai-mbeki", name : "Thandi Mbeki", style : .clean, skill : 0.01, colourHex : 0xF4D03F ),
        DriverProfile( id : "ai-rossi", name : "Gianna Rossi", style : .aggressive, skill : 0.03, colourHex : 0xCB4335 ),
        DriverProfile( id : "ai-walsh", name : "Declan Walsh", style : .defensive, skill : -0.05, colourHex : 0x85C1E9 ),
        DriverProfile( id : "ai-yamada", name : "Kaito Yamada", style : .metronome, skill : 0.02, colourHex : 0xD7DBDD ),
        DriverProfile( id : "ai-fischer", name : "Lena Fischer", style : .clean, skill : 0.0, colourHex : 0x7FB3D5 ),
        DriverProfile( id : "ai-castillo", name : "Diego Castillo", style : .aggressive, skill : -0.02, colourHex : 0xDC7633 ),
        DriverProfile( id : "ai-nair", name : "Anika Nair", style : .lateBraker, skill : 0.05, colourHex : 0xBB8FCE ),
        DriverProfile( id : "ai-holm", name : "Viktor Holm", style : .defensive, skill : 0.01, colourHex : 0x566573 ),
        DriverProfile( id : "ai-ade", name : "Femi Ade", style : .clean, skill : 0.03, colourHex : 0x45B39D )
    ]

    static let rivals : [Rival] = [
        Rival(
            id : "rival-voss",
            profile : DriverProfile( id : "rival-voss", name : "Mara \"Redline\" Voss", style : .aggressive, skill : 0.12, colourHex : 0xFF3B30 ),
            nickname : "Redline",
            specialty : .drag,
            bio : "Runs the airfield drag nights. Never lifts, never loses, never lets you forget it.",
            encounters : [
                RivalEncounter( tier : .rookie, carID : "brannock-saddleback", taunt : "Cute car. Does it come in fast?" ),
                RivalEncounter( tier : .club, carID : "brannock-tempest", taunt : "You got lucky once. Luck doesn't do quarter miles." ),
                RivalEncounter( tier : .professional, carID : "brannock-goliath", taunt : "Seven hundred horsepower says you're done." )
            ],
            defeatLine : "...Fine. Run it back sometime. I'll be waiting at the tree."
        ),
        Rival(
            id : "rival-arata",
            profile : DriverProfile( id : "rival-arata", name : "Kenji Arata", style : .metronome, skill : 0.12, colourHex : 0x5AC8FA ),
            nickname : "Sidewinder",
            specialty : .drift,
            bio : "Harbour drift king. Treats every corner like a brushstroke and every opponent like a smudge.",
            encounters : [
                RivalEncounter( tier : .street, carID : "hayase-kite-s", taunt : "Angle is free. Style is earned." ),
                RivalEncounter( tier : .regional, carID : "hayase-arc-s", taunt : "Follow me through the yard. If you can." ),
                RivalEncounter( tier : .elite, carID : "kazeru-hikari", taunt : "One more lesson, then." )
            ],
            defeatLine : "Clean. Very clean. The harbour is yours tonight."
        ),
        Rival(
            id : "rival-lindqvist",
            profile : DriverProfile( id : "rival-lindqvist", name : "Sofia Lindqvist", style : .clean, skill : 0.13, colourHex : 0x34C759 ),
            nickname : "The Professor",
            specialty : .circuit,
            bio : "A former works driver who treats every lap as data. Her racing line is a lecture.",
            encounters : [
                RivalEncounter( tier : .club, carID : "hayase-tempo-z", taunt : "Your braking points are a suggestion. Mine are a rule." ),
                RivalEncounter( tier : .professional, carID : "wrenfield-hawk-r", taunt : "Let's see if you have been studying." ),
                RivalEncounter( tier : .legend, carID : "wrenfield-peregrine", taunt : "Final exam." )
            ],
            defeatLine : "Impressive. I'll need to rewrite my notes."
        ),
        Rival(
            id : "rival-calloway",
            profile : DriverProfile( id : "rival-calloway", name : "Dex Calloway", style : .lateBraker, skill : 0.12, colourHex : 0xFF9500 ),
            nickname : "Switchback",
            specialty : .mountain,
            bio : "Grew up on Serpent Ridge. Knows every guardrail by its dents — most of them are his.",
            encounters : [
                RivalEncounter( tier : .street, carID : "wrenfield-linnet", taunt : "The mountain doesn't care how much power you've got." ),
                RivalEncounter( tier : .regional, carID : "hayase-zenith-r", taunt : "Downhill this time. Try not to fly." ),
                RivalEncounter( tier : .elite, carID : "aurex-brezza", taunt : "Last run of the night. Loser buys the coffee." )
            ],
            defeatLine : "Ha! Didn't think anyone could hold that line through the hairpins."
        ),
        Rival(
            id : "rival-okafor",
            profile : DriverProfile( id : "rival-okafor", name : "Ravi Okafor", style : .defensive, skill : 0.12, colourHex : 0xAF52DE ),
            nickname : "Neon",
            specialty : .street,
            bio : "Owns the Neon Meridian night scene. Races the expressway like he built it.",
            encounters : [
                RivalEncounter( tier : .street, carID : "norrvik-saga-tr", taunt : "Welcome downtown. Try to keep up." ),
                RivalEncounter( tier : .professional, carID : "veltra-spectre-rs", taunt : "The city looks different at 280." ),
                RivalEncounter( tier : .elite, carID : "kazeru-tsurugi", taunt : "My streets. My rules." )
            ],
            defeatLine : "Alright, alright. The city's got a new name tonight."
        ),
        Rival(
            id : "rival-moreau",
            profile : DriverProfile( id : "rival-moreau", name : "Inès Moreau", style : .metronome, skill : 0.15, colourHex : 0xFFD60A ),
            nickname : "Champion",
            specialty : .sprint,
            bio : "Reigning Shiftline Legend. Wins in anything, anywhere, and has never been beaten twice.",
            encounters : [
                RivalEncounter( tier : .regional, carID : "veltra-corsa-gt", taunt : "I've heard about you. Let's see if it's true." ),
                RivalEncounter( tier : .elite, carID : "veltra-vortex", taunt : "You're getting good. That's a problem." ),
                RivalEncounter( tier : .legend, carID : "aurex-fulmine", taunt : "For the crown, then." )
            ],
            defeatLine : "The crown suits you. Wear it well — I'll be coming for it."
        )
    ]

    static func rival( _ id : String ) -> Rival? {
        rivals.first { $0.id == id }
    }

    /// Deterministic opponent selection for an event, so reruns face the same field.
    static func field( count : Int, seed : String ) -> [DriverProfile] {
        var generator = SeededGenerator( text : seed )
        return Array( pool.shuffled( using : &generator ).prefix( count ) )
    }
}
