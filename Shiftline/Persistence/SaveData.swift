import Foundation

nonisolated enum SteeringMode : String, Codable, CaseIterable, Identifiable {
    case buttons
    case wheel
    case tilt
    case swipe

    var id : String {
        rawValue
    }

    var title : String {
        switch self {
        case .buttons:
            return "Touch Zones"
        case .wheel:
            return "Steering Wheel"
        case .tilt:
            return "Tilt"
        case .swipe:
            return "Swipe"
        }
    }
}

nonisolated enum SpeedUnit : String, Codable, CaseIterable, Identifiable {
    case kph
    case mph

    var id : String {
        rawValue
    }

    var title : String {
        self == .kph ? "km/h" : "mph"
    }

    func value( fromMetresPerSecond speed : Double ) -> Double {
        self == .kph ? speed * Units.metresPerSecondToKPH : speed * Units.metresPerSecondToMPH
    }

    func value( fromKPH speed : Double ) -> Double {
        self == .kph ? speed : speed / 1.609_344
    }
}

nonisolated struct GameSettings : Codable, Equatable {
    var steeringMode = SteeringMode.buttons
    var assists = DrivingAssists()
    var difficulty = Difficulty.amateur
    var speedUnit = SpeedUnit.kph
    var musicVolume = 0.6
    var effectsVolume = 0.9
    var engineVolume = 0.9
    var hapticsEnabled = true
    var cameraShake = true
    var showMinimap = true
    var tiltSensitivity = 1.0
    var leftHandedControls = false

    init() {}

    init( from decoder : Decoder ) throws {
        let container = try decoder.container( keyedBy : CodingKeys.self )
        let defaults = GameSettings()
        steeringMode = try container.decodeIfPresent( SteeringMode.self, forKey : .steeringMode ) ?? defaults.steeringMode
        assists = try container.decodeIfPresent( DrivingAssists.self, forKey : .assists ) ?? defaults.assists
        difficulty = try container.decodeIfPresent( Difficulty.self, forKey : .difficulty ) ?? defaults.difficulty
        speedUnit = try container.decodeIfPresent( SpeedUnit.self, forKey : .speedUnit ) ?? defaults.speedUnit
        musicVolume = try container.decodeIfPresent( Double.self, forKey : .musicVolume ) ?? defaults.musicVolume
        effectsVolume = try container.decodeIfPresent( Double.self, forKey : .effectsVolume ) ?? defaults.effectsVolume
        engineVolume = try container.decodeIfPresent( Double.self, forKey : .engineVolume ) ?? defaults.engineVolume
        hapticsEnabled = try container.decodeIfPresent( Bool.self, forKey : .hapticsEnabled ) ?? defaults.hapticsEnabled
        cameraShake = try container.decodeIfPresent( Bool.self, forKey : .cameraShake ) ?? defaults.cameraShake
        showMinimap = try container.decodeIfPresent( Bool.self, forKey : .showMinimap ) ?? defaults.showMinimap
        tiltSensitivity = try container.decodeIfPresent( Double.self, forKey : .tiltSensitivity ) ?? defaults.tiltSensitivity
        leftHandedControls = try container.decodeIfPresent( Bool.self, forKey : .leftHandedControls ) ?? defaults.leftHandedControls
    }
}

nonisolated struct PlayerProfile : Codable, Equatable {
    var name : String
    var createdAt = Date()
    var lastPlayed = Date()
    var level = 1
    var experience = 0
    var credits = 0
    var hasChosenStarter = false
    var completedTutorials : Set<TutorialKind> = []
}

nonisolated struct EventRecord : Codable, Equatable {
    var bestPlacement : Int?
    var bestScore : Double?
    var completions = 0
    var wins = 0
}

nonisolated struct ChampionshipStanding : Codable, Equatable, Identifiable {
    var id : String
    var name : String
    var carID : CarID
    var isPlayer : Bool
    var points = 0
    var wins = 0
    var podiums = 0
    /// Finishing position in each completed round, used to break ties.
    var finishes : [Int] = []
}

nonisolated struct ChampionshipProgress : Codable, Equatable {
    var championshipID : String
    var nextRound = 0
    var standings : [ChampionshipStanding]
    var isComplete = false
    var finalPosition : Int?
    var timesWon = 0
}

nonisolated struct PersonalBest : Codable, Equatable {
    var value : Double
    var lowerIsBetter : Bool
    var carID : CarID
    var date = Date()
}

nonisolated enum StatisticKey : String, Codable, CaseIterable, CodingKeyRepresentable {
    case racesEntered
    case wins
    case podiums
    case losses
    case circuitWins
    case sprintWins
    case streetWins
    case mountainWins
    case dragRaces
    case dragWins
    case driftEvents
    case driftGolds
    case driftTotalScore
    case highestDriftChain
    case eliminationWins
    case timeAttackGolds
    case checkpointGolds
    case speedTrapGolds
    case enduranceWins
    case rivalWins
    case championshipsEntered
    case championshipsWon
    case cleanRaces
    case perfectShifts
    case totalShifts
    case perfectLaunches
    case bestReactionTime
    case fastestQuarterMile
    case topSpeedKPH
    case distanceDriven
    case carsOwnedPeak
    case upgradesPurchased
    case creditsEarned
    case creditsSpent
    case cleanOvertakes
    case collisions
    case personalBests
    case dailyChallengesCompleted
    case tutorialsCompleted
    case liveriesApplied
    case tuningsSaved

    var title : String {
        switch self {
        case .racesEntered:
            return "Events entered"
        case .wins:
            return "Wins"
        case .podiums:
            return "Podiums"
        case .losses:
            return "Losses"
        case .circuitWins:
            return "Circuit wins"
        case .sprintWins:
            return "Sprint wins"
        case .streetWins:
            return "Street wins"
        case .mountainWins:
            return "Mountain wins"
        case .dragRaces:
            return "Drag races"
        case .dragWins:
            return "Drag wins"
        case .driftEvents:
            return "Drift events"
        case .driftGolds:
            return "Drift golds"
        case .driftTotalScore:
            return "Total drift score"
        case .highestDriftChain:
            return "Highest drift chain"
        case .eliminationWins:
            return "Elimination wins"
        case .timeAttackGolds:
            return "Time attack golds"
        case .checkpointGolds:
            return "Checkpoint golds"
        case .speedTrapGolds:
            return "Speed trap golds"
        case .enduranceWins:
            return "Endurance wins"
        case .rivalWins:
            return "Rival victories"
        case .championshipsEntered:
            return "Championships entered"
        case .championshipsWon:
            return "Championships won"
        case .cleanRaces:
            return "Clean races"
        case .perfectShifts:
            return "Perfect shifts"
        case .totalShifts:
            return "Manual shifts"
        case .perfectLaunches:
            return "Perfect launches"
        case .bestReactionTime:
            return "Best reaction time"
        case .fastestQuarterMile:
            return "Fastest quarter mile"
        case .topSpeedKPH:
            return "Top speed"
        case .distanceDriven:
            return "Distance driven"
        case .carsOwnedPeak:
            return "Cars owned"
        case .upgradesPurchased:
            return "Upgrades purchased"
        case .creditsEarned:
            return "Credits earned"
        case .creditsSpent:
            return "Credits spent"
        case .cleanOvertakes:
            return "Clean overtakes"
        case .collisions:
            return "Collisions"
        case .personalBests:
            return "Personal bests set"
        case .dailyChallengesCompleted:
            return "Daily challenges"
        case .tutorialsCompleted:
            return "Tutorials completed"
        case .liveriesApplied:
            return "Liveries applied"
        case .tuningsSaved:
            return "Tunes saved"
        }
    }
}

nonisolated struct Statistics : Codable, Equatable {
    var values : [StatisticKey : Double] = [:]

    subscript( _ key : StatisticKey ) -> Double {
        get {
            values[ key ] ?? 0
        }
        set {
            values[ key ] = newValue
        }
    }

    mutating func add( _ amount : Double, to key : StatisticKey ) {
        self[ key ] += amount
    }

    mutating func increment( _ key : StatisticKey ) {
        self[ key ] += 1
    }

    mutating func recordMaximum( _ value : Double, for key : StatisticKey ) {
        self[ key ] = max( self[ key ], value )
    }

    /// For "best time" statistics where zero means unset.
    mutating func recordMinimum( _ value : Double, for key : StatisticKey ) {
        let current = self[ key ]
        self[ key ] = current == 0 ? value : min( current, value )
    }

    var winPercentage : Double {
        self[ .racesEntered ] > 0 ? self[ .wins ] / self[ .racesEntered ] * 100 : 0
    }
}

nonisolated struct DailyChallengeState : Codable, Equatable {
    var day : String = ""
    var progress : [String : Double] = [:]
    var claimed : Set<String> = []
}

/// Everything persisted for one profile. Unknown or missing fields fall back to defaults.
nonisolated struct SaveData : Codable, Equatable {
    static let currentVersion = 2

    var version = SaveData.currentVersion
    var profile : PlayerProfile
    var garage : [OwnedCar] = []
    var selectedCarID : UUID?
    var events : [String : EventRecord] = [:]
    var championships : [String : ChampionshipProgress] = [:]
    var achievements : [String : Date] = [:]
    var statistics = Statistics()
    var personalBests : [String : PersonalBest] = [:]
    var settings = GameSettings()
    var daily = DailyChallengeState()
    var rivalWins : [String : Int] = [:]
    var favouriteDealershipCars : Set<CarID> = []

    init( profileName : String ) {
        profile = PlayerProfile( name : profileName )
    }

    enum CodingKeys : String, CodingKey {
        case version
        case profile
        case garage
        case selectedCarID
        case events
        case championships
        case achievements
        case statistics
        case personalBests
        case settings
        case daily
        case rivalWins
        case favouriteDealershipCars
    }

    init( from decoder : Decoder ) throws {
        let container = try decoder.container( keyedBy : CodingKeys.self )
        version = try container.decodeIfPresent( Int.self, forKey : .version ) ?? 1
        profile = try container.decode( PlayerProfile.self, forKey : .profile )
        garage = try container.decodeIfPresent( [OwnedCar].self, forKey : .garage ) ?? []
        selectedCarID = try container.decodeIfPresent( UUID.self, forKey : .selectedCarID )
        events = try container.decodeIfPresent( [String : EventRecord].self, forKey : .events ) ?? [:]
        championships = try container.decodeIfPresent( [String : ChampionshipProgress].self, forKey : .championships ) ?? [:]
        achievements = try container.decodeIfPresent( [String : Date].self, forKey : .achievements ) ?? [:]
        statistics = try container.decodeIfPresent( Statistics.self, forKey : .statistics ) ?? Statistics()
        personalBests = try container.decodeIfPresent( [String : PersonalBest].self, forKey : .personalBests ) ?? [:]
        settings = try container.decodeIfPresent( GameSettings.self, forKey : .settings ) ?? GameSettings()
        daily = try container.decodeIfPresent( DailyChallengeState.self, forKey : .daily ) ?? DailyChallengeState()
        rivalWins = try container.decodeIfPresent( [String : Int].self, forKey : .rivalWins ) ?? [:]
        favouriteDealershipCars = try container.decodeIfPresent( Set<CarID>.self, forKey : .favouriteDealershipCars ) ?? []
    }

    var selectedCar : OwnedCar? {
        garage.first { $0.id == selectedCarID } ?? garage.first
    }

    func ownedCar( _ id : UUID ) -> OwnedCar? {
        garage.first { $0.id == id }
    }

    func owns( _ carID : CarID ) -> Bool {
        garage.contains { $0.carID == carID }
    }

    mutating func updateCar( _ car : OwnedCar ) {
        guard let index = garage.firstIndex( where : { $0.id == car.id } ) else {
            return
        }

        garage[ index ] = car
    }

    /// Brings an older save up to the current schema and repairs anything inconsistent.
    func migrated() -> SaveData {
        var updatedSave = self

        if updatedSave.version < 2 {
            // v1 stored no peak car count; derive it from the garage.
            updatedSave.statistics.recordMaximum( Double( garage.count ), for : .carsOwnedPeak )
        }

        updatedSave.garage.removeAll { Cars.named( $0.carID ) == nil }

        if let selected = updatedSave.selectedCarID, updatedSave.ownedCar( selected ) == nil {
            updatedSave.selectedCarID = updatedSave.garage.first?.id
        }

        updatedSave.profile.credits = max( updatedSave.profile.credits, 0 )
        updatedSave.profile.level = max( updatedSave.profile.level, 1 )
        updatedSave.version = SaveData.currentVersion
        return updatedSave
    }
}

nonisolated extension TutorialKind : CodingKeyRepresentable {}
