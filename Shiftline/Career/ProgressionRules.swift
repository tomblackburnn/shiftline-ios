import Foundation

nonisolated enum EventAvailability : Equatable {
    case available
    /// Event is open, but the selected car doesn't fit.
    case carIneligible( [String] )
    case locked( [String] )

    var isAvailable : Bool {
        self == .available
    }

    var isUnlocked : Bool {
        if case .locked = self {
            return false
        }

        return true
    }

    var reasons : [String] {
        switch self {
        case .available:
            return []
        case .carIneligible( let reasons ), .locked( let reasons ):
            return reasons
        }
    }
}

nonisolated struct ProgressionRules {
    static let maximumLevel = 40
    private let rewards : RewardCalculator

    init( rewards : RewardCalculator = RewardCalculator() ) {
        self.rewards = rewards
    }

    // MARK: - Levels

    static func experienceToNext( level : Int ) -> Int {
        350 + level * 150
    }

    static func level( forExperience experience : Int ) -> Int {
        var level = 1
        var remaining = experience

        while level < maximumLevel && remaining >= experienceToNext( level : level ) {
            remaining -= experienceToNext( level : level )
            level += 1
        }

        return level
    }

    static func experienceIntoLevel( _ experience : Int ) -> ( current : Int, needed : Int ) {
        var level = 1
        var remaining = experience

        while level < maximumLevel && remaining >= experienceToNext( level : level ) {
            remaining -= experienceToNext( level : level )
            level += 1
        }

        return ( remaining, experienceToNext( level : level ) )
    }

    // MARK: - Tiers and events

    func wins( in tier : CareerTier, save : SaveData ) -> Int {
        Events.events( in : tier ).filter { ( save.events[ $0.id ]?.wins ?? 0 ) > 0 }.count
    }

    func isTierUnlocked( _ tier : CareerTier, in save : SaveData ) -> Bool {
        guard tier != .rookie else {
            return true
        }

        guard let previous = CareerTier( rawValue : tier.rawValue - 1 ) else {
            return true
        }

        return save.profile.level >= tier.requiredLevel
            && wins( in : previous, save : save ) >= tier.requiredPreviousWins
    }

    func tierLockReasons( _ tier : CareerTier, in save : SaveData ) -> [String] {
        guard let previous = CareerTier( rawValue : tier.rawValue - 1 ) else {
            return []
        }

        var reasons : [String] = []

        if save.profile.level < tier.requiredLevel {
            reasons.append( "Reach driver level \( tier.requiredLevel )" )
        }

        let previousWins = wins( in : previous, save : save )

        if previousWins < tier.requiredPreviousWins {
            reasons.append( "Win \( tier.requiredPreviousWins ) \( previous.title ) events (\( previousWins )/\( tier.requiredPreviousWins ))" )
        }

        return reasons
    }

    /// Prerequisite events count once finished on the podium (or with a medal).
    func hasCleared( _ eventID : String, in save : SaveData ) -> Bool {
        guard let placement = save.events[ eventID ]?.bestPlacement else {
            return false
        }

        return placement <= 3
    }

    func lockReasons( for requirements : EventRequirements, tier : CareerTier?, in save : SaveData ) -> [String] {
        var reasons : [String] = []

        if let tier {
            reasons += tierLockReasons( tier, in : save ).filter { _ in !isTierUnlocked( tier, in : save ) }
        }

        if save.profile.level < requirements.minimumLevel {
            reasons.append( "Reach driver level \( requirements.minimumLevel )" )
        }

        for eventID in requirements.requiredEventIDs where !hasCleared( eventID, in : save ) {
            let name = Events.named( eventID )?.name ?? eventID
            reasons.append( "Podium in \"\( name )\"" )
        }

        if let tutorial = requirements.requiresTutorial, !save.profile.completedTutorials.contains( tutorial ) {
            reasons.append( "Complete the \"\( tutorial.title )\" tutorial" )
        }

        return reasons
    }

    func carIssues( for requirements : EventRequirements, tier : CareerTier?, car : OwnedCar ) -> [String] {
        var issues : [String] = []
        let performance = PerformanceProfile.measure( CarBuild( owned : car ).spec )

        if let cap = requirements.maximumClass ?? tier?.classCap, performance.performanceClass > cap {
            issues.append( "Class \( cap.rawValue ) or lower (yours is \( performance.performanceClass.rawValue ) \( performance.index ))" )
        }

        if let drivetrain = requirements.drivetrain, car.drivetrain != drivetrain {
            issues.append( "\( drivetrain.title ) cars only" )
        }

        if let categories = requirements.categories, !categories.contains( car.definition.category ) {
            issues.append( categories.map { $0.title }.joined( separator : " / " ) + " only" )
        }

        return issues
    }

    /// Every requirement for an event, each marked met or unmet, for display.
    func requirementChecks(
        for requirements : EventRequirements,
        tier : CareerTier?,
        car : OwnedCar?,
        in save : SaveData
    ) -> [( text : String, isMet : Bool )] {
        var checks : [( text : String, isMet : Bool )] = []

        if let tier, !isTierUnlocked( tier, in : save ) {
            checks += tierLockReasons( tier, in : save ).map { ( $0, false ) }
        }

        if let cap = requirements.maximumClass ?? tier?.classCap {
            let carClass = car.map { PerformanceProfile.measure( CarBuild( owned : $0 ).spec ).performanceClass }
            checks.append( ( "Class \( cap.rawValue ) or lower", carClass.map { $0 <= cap } ?? false ) )
        }

        if let drivetrain = requirements.drivetrain {
            checks.append( ( "\( drivetrain.title ) cars only", car?.drivetrain == drivetrain ) )
        }

        if let categories = requirements.categories {
            let isMet = car.map { categories.contains( $0.definition.category ) } ?? false
            checks.append( ( categories.map { $0.title }.joined( separator : " / " ) + " only", isMet ) )
        }

        if requirements.minimumLevel > 1 {
            checks.append( ( "Driver level \( requirements.minimumLevel )", save.profile.level >= requirements.minimumLevel ) )
        }

        for eventID in requirements.requiredEventIDs {
            checks.append( ( "Podium in \"\( Events.named( eventID )?.name ?? eventID )\"", hasCleared( eventID, in : save ) ) )
        }

        if let tutorial = requirements.requiresTutorial {
            checks.append( ( "Complete the \"\( tutorial.title )\" tutorial", save.profile.completedTutorials.contains( tutorial ) ) )
        }

        return checks
    }

    func availability( of event : EventDefinition, car : OwnedCar?, in save : SaveData ) -> EventAvailability {
        let locks = lockReasons( for : event.requirements, tier : event.tier, in : save )

        guard locks.isEmpty else {
            return .locked( locks )
        }

        guard let car else {
            return .carIneligible( [ "Select a car" ] )
        }

        let issues = carIssues( for : event.requirements, tier : event.tier, car : car )
        return issues.isEmpty ? .available : .carIneligible( issues )
    }

    func unlockedEventIDs( in save : SaveData ) -> Set<String> {
        Set( Events.all.filter { lockReasons( for : $0.requirements, tier : $0.tier, in : save ).isEmpty }.map { $0.id } )
    }

    // MARK: - Applying results

    static func personalBestKeys( for outcome : RaceOutcome ) -> [String] {
        [ "\( outcome.trackID )|\( outcome.kind.statisticsKey )", "\( outcome.trackID )|\( outcome.kind.statisticsKey )|\( outcome.carID )" ]
    }

    /// The value tracked as a personal best for this kind of event, and whether lower is better.
    static func personalBestValue( for outcome : RaceOutcome ) -> ( Double, Bool )? {
        guard outcome.didFinish else {
            return nil
        }

        switch outcome.kind {
        case .drag:
            return outcome.drag.map { ( $0.elapsedTime, true ) }
        case .drift, .speedTrap, .checkpoint:
            return outcome.score.map { ( $0, false ) }
        case .timeAttack, .circuit, .endurance, .practice, .elimination:
            return outcome.bestLap.map { ( $0, true ) }
        case .sprint:
            return outcome.time.map { ( $0, true ) }
        case .tutorial:
            return nil
        }
    }

    func applying( _ outcome : RaceOutcome, to save : SaveData, prize : Int? ) -> ( SaveData, RaceRewards ) {
        var updatedSave = save
        var result = RaceRewards()
        result.levelBefore = save.profile.level
        let unlockedBefore = unlockedEventIDs( in : save )
        let isReplay = outcome.eventID.map { ( save.events[ $0 ]?.wins ?? 0 ) > 0 } ?? false

        // Personal bests.
        var isNewPersonalBest = false

        if let ( value, lowerIsBetter ) = ProgressionRules.personalBestValue( for : outcome ) {
            for key in ProgressionRules.personalBestKeys( for : outcome ) {
                let existing = save.personalBests[ key ]
                let beats = existing.map { lowerIsBetter ? value < $0.value : value > $0.value } ?? true

                if beats {
                    updatedSave.personalBests[ key ] = PersonalBest( value : value, lowerIsBetter : lowerIsBetter, carID : outcome.carID )

                    if existing != nil || key.split( separator : "|" ).count == 2 {
                        isNewPersonalBest = true
                    }
                }
            }
        }

        if isNewPersonalBest {
            result.newPersonalBests.append( Tracks.named( outcome.trackID )?.fullName ?? outcome.trackID )
            updatedSave.statistics.increment( .personalBests )
        }

        // Credits and experience.
        result.lines = rewards.lines(
            for : outcome,
            prize : prize,
            isReplay : isReplay,
            isNewPersonalBest : isNewPersonalBest
        )

        // Event and rival records.
        if let eventID = outcome.eventID {
            var record = updatedSave.events[ eventID ] ?? EventRecord()
            record.completions += outcome.didFinish ? 1 : 0
            record.wins += outcome.isWin ? 1 : 0

            if outcome.didFinish {
                record.bestPlacement = min( record.bestPlacement ?? outcome.placement, outcome.placement )
            }

            if let score = outcome.score {
                record.bestScore = max( record.bestScore ?? score, score )
            }

            updatedSave.events[ eventID ] = record
        }

        if let rivalID = outcome.rivalID, outcome.isWin {
            updatedSave.rivalWins[ rivalID, default : 0 ] += 1
            result.rivalDefeated = Opponents.rival( rivalID )?.profile.name
            updatedSave.statistics.increment( .rivalWins )
        }

        updatedSave.statistics = StatisticsRules().recording( outcome, in : updatedSave.statistics )

        if let ownedID = outcome.ownedCarID, var car = updatedSave.ownedCar( ownedID ) {
            car.racesEntered += 1
            car.wins += outcome.isWin ? 1 : 0
            car.odometer += outcome.distance
            updatedSave.updateCar( car )
        }

        // Daily challenges progress alongside racing.
        let daily = DailyChallengeRules().recording( outcome, isNewPersonalBest : isNewPersonalBest, in : updatedSave, date : Date() )
        updatedSave = daily.save
        result.lines += daily.rewards
        result.completedChallenges = daily.completed

        updatedSave = crediting( result.lines, to : updatedSave )

        // Achievements can pay out too, then level may rise again.
        let achievements = AchievementRules().evaluating( updatedSave )
        updatedSave = achievements.save
        result.unlockedAchievements = achievements.unlocked.map { $0.title }
        let achievementLines = achievements.unlocked.map {
            RewardLine( label : "Achievement: \( $0.title )", credits : $0.credits, experience : $0.experience )
        }
        updatedSave = crediting( achievementLines, to : updatedSave )
        result.lines += achievementLines

        result.levelAfter = updatedSave.profile.level
        result.unlockedEvents = unlockedEventIDs( in : updatedSave )
            .subtracting( unlockedBefore )
            .compactMap { Events.named( $0 )?.name }
            .sorted()
        updatedSave.profile.lastPlayed = Date()
        return ( updatedSave, result )
    }

    /// Adds credits and experience and applies level-ups (each level pays a small bonus).
    func crediting( _ lines : [RewardLine], to save : SaveData ) -> SaveData {
        var updatedSave = save
        let credits = lines.reduce( 0 ) { $0 + $1.credits }
        let experience = lines.reduce( 0 ) { $0 + $1.experience }
        updatedSave.profile.credits += credits
        updatedSave.profile.experience += experience
        updatedSave.statistics.add( Double( max( credits, 0 ) ), to : .creditsEarned )

        let newLevel = ProgressionRules.level( forExperience : updatedSave.profile.experience )

        if newLevel > save.profile.level {
            let bonus = ( save.profile.level + 1 ... newLevel ).reduce( 0 ) { $0 + $1 * 400 }
            updatedSave.profile.credits += bonus
            updatedSave.statistics.add( Double( bonus ), to : .creditsEarned )
        }

        updatedSave.profile.level = newLevel
        return updatedSave
    }

    func completingTutorial( _ tutorial : TutorialKind, in save : SaveData ) -> SaveData {
        guard !save.profile.completedTutorials.contains( tutorial ) else {
            return save
        }

        var updatedSave = save
        updatedSave.profile.completedTutorials.insert( tutorial )
        updatedSave.statistics.increment( .tutorialsCompleted )
        return crediting( [ RewardLine( label : "Tutorial", credits : 1_000, experience : 120 ) ], to : updatedSave )
    }
}

nonisolated struct StatisticsRules {
    func recording( _ outcome : RaceOutcome, in statistics : Statistics ) -> Statistics {
        var updated = statistics

        if case .tutorial = outcome.kind {
            return updated
        }

        if case .practice = outcome.kind {
            updated.add( outcome.distance, to : .distanceDriven )
            updated.recordMaximum( outcome.topSpeedKPH, for : .topSpeedKPH )
            return updated
        }

        updated.increment( .racesEntered )
        updated.add( outcome.distance, to : .distanceDriven )
        updated.recordMaximum( outcome.topSpeedKPH, for : .topSpeedKPH )
        updated.add( Double( outcome.perfectShifts ), to : .perfectShifts )
        updated.add( Double( outcome.shifts ), to : .totalShifts )
        updated.add( Double( outcome.cleanOvertakes ), to : .cleanOvertakes )
        updated.add( Double( outcome.collisions ), to : .collisions )

        if outcome.isWin {
            updated.increment( .wins )
        } else if outcome.fieldSize > 1 || outcome.kind.isScored {
            updated.increment( .losses )
        }

        if outcome.isPodium {
            updated.increment( .podiums )
        }

        if outcome.isClean {
            updated.increment( .cleanRaces )
        }

        switch outcome.kind {
        case .drag:
            updated.increment( .dragRaces )

            if outcome.isWin {
                updated.increment( .dragWins )
            }

            if let drag = outcome.drag, !drag.isFoul {
                updated.recordMinimum( drag.reactionTime, for : .bestReactionTime )

                if drag.launch == .perfect {
                    updated.increment( .perfectLaunches )
                }

                if abs( ( Tracks.named( outcome.trackID ).map { TrackGeometry.dragLength( of : $0 ) } ?? 0 ) - Units.quarterMile ) < 1 {
                    updated.recordMinimum( drag.elapsedTime, for : .fastestQuarterMile )
                }
            }
        case .drift:
            updated.increment( .driftEvents )
            updated.add( Double( outcome.driftScore ), to : .driftTotalScore )
            updated.recordMaximum( Double( outcome.driftBestChain ), for : .highestDriftChain )

            if outcome.isWin {
                updated.increment( .driftGolds )
            }
        case .elimination where outcome.isWin:
            updated.increment( .eliminationWins )
        case .timeAttack where outcome.isWin:
            updated.increment( .timeAttackGolds )
        case .checkpoint where outcome.isWin:
            updated.increment( .checkpointGolds )
        case .speedTrap where outcome.isWin:
            updated.increment( .speedTrapGolds )
        case .endurance where outcome.isWin:
            updated.increment( .enduranceWins )
        default:
            break
        }

        if outcome.isWin {
            switch outcome.discipline {
            case .circuit:
                updated.increment( .circuitWins )
            case .sprint:
                updated.increment( .sprintWins )
            case .street:
                updated.increment( .streetWins )
            case .mountain:
                updated.increment( .mountainWins )
            case .drag, .drift:
                break
            }
        }

        return updated
    }
}

nonisolated extension TrackGeometry {
    static func dragLength( of layout : TrackLayout ) -> Double {
        if case .dragStrip( let length ) = layout.shape {
            return length
        }

        return 0
    }
}
