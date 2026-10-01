import Foundation

/// Builds race configurations for career events, championship rounds, quick races and tutorials,
/// including fair opponent matchmaking and physics-derived targets.
nonisolated struct RaceFactory {
    let save : SaveData

    // MARK: - Entrants

    func playerEntrant( for car : OwnedCar ) -> RaceEntrant {
        RaceEntrant(
            name : save.profile.name,
            carID : car.carID,
            spec : CarBuild( owned : car ).spec,
            appearance : car.appearance,
            profile : nil,
            isPlayer : true
        )
    }

    /// Upgrade level AI cars carry in each tier.
    static func aiBuildLevel( for tier : CareerTier? ) -> Int {
        guard let tier else {
            return 0
        }

        return [ 0, 0, 1, 1, 2, 2, 3 ][ tier.rawValue ]
    }

    static func aiCar( _ carID : CarID, buildLevel : Int ) -> OwnedCar {
        var car = OwnedCar( carID : carID )

        guard buildLevel > 0 else {
            return car
        }

        for category in [ UpgradeCategory.engine, .ecu, .exhaust, .intake, .transmission, .tyres, .brakes, .suspension, .weightReduction ] {
            car.upgrades[ category ] = buildLevel
        }

        car.tyreCompound = buildLevel >= 3 ? .semiSlick : ( buildLevel >= 1 ? .sport : .street )
        return car
    }

    static func aiEntrant( profile : DriverProfile, car : OwnedCar, seed : String ) -> RaceEntrant {
        var generator = SeededGenerator( text : seed + profile.id )
        var appearance = car.appearance
        appearance.paintHex = CarAppearance.palette.randomElement( using : &generator ) ?? car.appearance.paintHex
        appearance.accentHex = profile.colourHex
        appearance.livery = Livery.allCases.randomElement( using : &generator ) ?? .none
        appearance.raceNumber = Int( generator.next() % 98 ) + 1
        return RaceEntrant(
            name : profile.name,
            carID : car.carID,
            spec : CarBuild( owned : car ).spec,
            appearance : appearance,
            profile : profile,
            isPlayer : false
        )
    }

    /// Picks an opponent car near the target performance that satisfies the event rules.
    static func opponentCarID(
        index : Int,
        classCap : PerformanceClass,
        seed : String,
        targetIndex : Int? = nil,
        requirements : EventRequirements = EventRequirements(),
        buildLevel : Int = 0
    ) -> CarID {
        let target = min( targetIndex ?? classCap.ceiling - 40, classCap.ceiling )
        let eligible = Cars.all.filter { car in
            let performance = PerformanceProfile.measure( CarBuild( owned : aiCar( car.id, buildLevel : buildLevel ) ).spec )
            return performance.performanceClass <= classCap
                && ( requirements.drivetrain.map { car.drivetrain == $0 } ?? true )
                && ( requirements.categories.map { $0.contains( car.category ) } ?? true )
        }

        let pool = eligible.isEmpty ? Cars.all : eligible
        let ranked = pool.sorted {
            let lhs = PerformanceProfile.measure( CarBuild( owned : aiCar( $0.id, buildLevel : buildLevel ) ).spec ).index
            let rhs = PerformanceProfile.measure( CarBuild( owned : aiCar( $1.id, buildLevel : buildLevel ) ).spec ).index
            return abs( lhs - target ) < abs( rhs - target )
        }

        let shortlist = Array( ranked.prefix( max( 4, min( ranked.count, 6 ) ) ) )
        var generator = SeededGenerator( text : seed + "\( index )" )
        return shortlist.shuffled( using : &generator ).first?.id ?? Cars.all[ 0 ].id
    }

    private func field(
        count : Int,
        seed : String,
        tier : CareerTier?,
        classCap : PerformanceClass,
        playerIndex : Int,
        requirements : EventRequirements
    ) -> [RaceEntrant] {
        let buildLevel = RaceFactory.aiBuildLevel( for : tier )
        let target = min( playerIndex + 25, classCap.ceiling )

        return Opponents.field( count : count, seed : seed ).enumerated().map { index, profile in
            let carID = RaceFactory.opponentCarID(
                index : index,
                classCap : classCap,
                seed : seed,
                targetIndex : target,
                requirements : requirements,
                buildLevel : buildLevel
            )
            return RaceFactory.aiEntrant( profile : profile, car : RaceFactory.aiCar( carID, buildLevel : buildLevel ), seed : seed )
        }
    }

    private func rivalEntrant( _ rival : Rival, tier : CareerTier ) -> RaceEntrant {
        let encounter = rival.encounters.first { $0.tier == tier } ?? rival.encounters[ 0 ]
        let buildLevel = min( RaceFactory.aiBuildLevel( for : tier ) + 1, 4 )
        var entrant = RaceFactory.aiEntrant( profile : rival.profile, car : RaceFactory.aiCar( encounter.carID, buildLevel : buildLevel ), seed : rival.id )
        entrant.appearance.paintHex = rival.profile.colourHex
        entrant.appearance.livery = .shiftlineWorks
        entrant.isRival = true
        return entrant
    }

    // MARK: - Configurations

    func config( for event : EventDefinition, car : OwnedCar ) -> RaceConfig {
        let player = playerEntrant( for : car )
        let playerIndex = PerformanceProfile.measure( player.spec ).index
        var entrants = [ player ]

        if let rivalID = event.rivalID, let rival = Opponents.rival( rivalID ) {
            entrants.append( rivalEntrant( rival, tier : event.tier ) )
        } else if event.opponents > 0 {
            entrants += field(
                count : event.opponents,
                seed : event.id,
                tier : event.tier,
                classCap : event.requirements.maximumClass ?? event.tier.classCap,
                playerIndex : playerIndex,
                requirements : event.requirements
            )
        }

        var config = RaceConfig(
            eventID : event.id,
            title : event.name,
            trackID : event.trackID,
            kind : event.kind,
            laps : event.laps,
            weather : event.weather,
            timeOfDay : event.timeOfDay,
            entrants : entrants,
            assists : save.settings.assists,
            difficulty : save.settings.difficulty
        )
        config.opponentSkill = event.tier.opponentSkill + ( event.isRival ? 0.06 : 0 )
        applyTargets( to : &config, recommendedIndex : event.recommendedIndex, requirements : event.requirements )
        return config
    }

    func config(
        for round : ChampionshipRound,
        in championship : ChampionshipDefinition,
        progress : ChampionshipProgress,
        car : OwnedCar
    ) -> RaceConfig {
        let buildLevel = RaceFactory.aiBuildLevel( for : championship.tier )
        let profiles = ChampionshipRules().field( for : championship )
        var entrants = [ playerEntrant( for : car ) ]

        for standing in progress.standings where !standing.isPlayer {
            guard let profile = profiles.first( where : { $0.id == standing.id } ) else {
                continue
            }

            entrants.append( RaceFactory.aiEntrant( profile : profile, car : RaceFactory.aiCar( standing.carID, buildLevel : buildLevel ), seed : championship.id ) )
        }

        // Drag rounds race heads-up against the championship leader; the rest of the field runs real passes off-screen.
        if case .drag = round.kind {
            let leader = progress.standings.first { !$0.isPlayer }?.id
            entrants = [ entrants[ 0 ] ] + entrants.dropFirst().filter { $0.profile?.id == leader }
        }

        var config = RaceConfig(
            eventID : nil,
            title : "\( championship.name ) · \( round.name )",
            trackID : round.trackID,
            kind : round.kind,
            laps : round.laps,
            weather : round.weather,
            timeOfDay : round.timeOfDay,
            entrants : entrants,
            assists : save.settings.assists,
            difficulty : save.settings.difficulty
        )
        config.opponentSkill = championship.tier.opponentSkill
        return config
    }

    func quickRace(
        trackID : TrackID,
        kind : RaceKind,
        laps : Int,
        opponents : Int,
        weather : Weather,
        timeOfDay : TimeOfDay,
        car : OwnedCar
    ) -> RaceConfig {
        let player = playerEntrant( for : car )
        let performance = PerformanceProfile.measure( player.spec )
        let tier = CareerTier.allCases.last { $0.classCap <= performance.performanceClass } ?? .rookie
        var entrants = [ player ]
        let seed = "quick-\( trackID )-\( Int( Date().timeIntervalSince1970 / 3_600 ) )"

        if opponents > 0 {
            entrants += field(
                count : opponents,
                seed : seed,
                tier : tier,
                classCap : performance.performanceClass,
                playerIndex : performance.index,
                requirements : EventRequirements()
            )
        }

        var config = RaceConfig(
            eventID : nil,
            title : Tracks.named( trackID )?.fullName ?? "Quick Race",
            trackID : trackID,
            kind : kind,
            laps : laps,
            weather : weather,
            timeOfDay : timeOfDay,
            entrants : entrants,
            assists : save.settings.assists,
            difficulty : save.settings.difficulty
        )
        config.opponentSkill = clamp( 0.35 + Double( save.profile.level ) * 0.013, 0.3, 0.85 )
        applyTargets( to : &config, recommendedIndex : performance.index, requirements : EventRequirements() )
        return config
    }

    func tutorial( _ kind : TutorialKind, car : OwnedCar ) -> RaceConfig {
        var assists = DrivingAssists()
        var trackID : TrackID = "mesa-speedrun"
        var entrants = [ playerEntrant( for : car ) ]
        var laps = 1

        switch kind {
        case .basics, .tuning:
            trackID = "mesa-speedrun"
        case .steering:
            trackID = "pines-stage"
            assists.racingLine = true
            assists.brakingAssist = true
        case .shifting:
            trackID = "velocity-national"
            assists.automaticTransmission = false
        case .drifting:
            trackID = "kestrel-pad"
            assists.tractionControl = false
            assists.stabilityControl = false
        case .circuitRacing:
            trackID = "velocity-national"
            laps = 2
            let pace = DriverProfile( id : "pace-car", name : "Pace Car", style : .clean, skill : -0.2, colourHex : 0xF1C40F )
            var paceEntrant = RaceFactory.aiEntrant( profile : pace, car : OwnedCar( carID : car.carID ), seed : "pace" )
            paceEntrant.appearance.paintHex = 0xF1C40F
            entrants.append( paceEntrant )
        case .dragLaunch:
            trackID = "kestrel-quarter"
        }

        var config = RaceConfig(
            eventID : nil,
            title : kind.title,
            trackID : trackID,
            kind : kind == .dragLaunch ? .drag : .tutorial( kind ),
            laps : laps,
            entrants : entrants,
            assists : assists,
            difficulty : .rookie
        )
        config.opponentSkill = 0.3
        return config
    }

    /// Drag opponent for a drag config: the rival or a matched pool driver.
    func dragOpponent( for config : RaceConfig ) -> ( entrant : RaceEntrant, skill : Double ) {
        if let opponent = config.entrants.first( where : { !$0.isPlayer } ) {
            let skill = clamp( config.opponentSkill + ( opponent.profile?.skill ?? 0 ) + config.difficulty.skillOffset, 0, 1 )
            return ( opponent, skill )
        }

        let profile = Opponents.pool[ 0 ]
        let entrant = RaceFactory.aiEntrant( profile : profile, car : OwnedCar( carID : config.player?.carID ?? Cars.starterIDs[ 0 ] ), seed : "drag" )
        return ( entrant, clamp( 0.4 + config.difficulty.skillOffset, 0, 1 ) )
    }

    private func applyTargets( to config : inout RaceConfig, recommendedIndex : Int, requirements : EventRequirements ) {
        let targets = EventTargets.targets(
            kind : config.kind,
            trackID : config.trackID,
            laps : config.laps,
            weather : config.weather,
            recommendedIndex : recommendedIndex,
            requirements : requirements
        )
        config.targets = targets.medals

        if case .checkpoint = config.kind {
            config.kind = .checkpoint( startTime : targets.checkpointStart, bonusPerCheckpoint : targets.checkpointBonus )
        }
    }
}
