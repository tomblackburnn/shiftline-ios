import Foundation
import Observation

/// A race waiting to be driven, with everything needed to credit its result.
struct PendingRace : Identifiable {
    let id = UUID()
    var config : RaceConfig
    var context : RaceContext
    var championshipRound : ChampionshipRound?
}

/// Single source of truth for the active profile. Applies rules, persists every change.
@Observable
final class GameStore {
    private( set ) var save : SaveData
    private( set ) var profileID : UUID?
    private( set ) var profiles : [ProfileSummary] = []
    private( set ) var loadOutcome : SaveLoadOutcome = .loaded
    var activeRace : PendingRace?
    var message : String?

    @ObservationIgnored let store : SaveStore
    @ObservationIgnored private let garageRules = GarageRules()
    @ObservationIgnored private let progressionRules = ProgressionRules()
    @ObservationIgnored private let championshipRules = ChampionshipRules()
    @ObservationIgnored private let defaults : UserDefaults

    private static let activeProfileKey = "activeProfileID"

    init( store : SaveStore = SaveStore(), defaults : UserDefaults = .standard ) {
        self.store = store
        self.defaults = defaults
        save = SaveData( profileName : "Driver" )
        profiles = store.profiles()

        if let stored = defaults.string( forKey : GameStore.activeProfileKey ),
           let id = UUID( uuidString : stored ),
           profiles.contains( where : { $0.id == id } ) {
            loadProfile( id )
        }
    }

    var hasActiveProfile : Bool {
        profileID != nil
    }

    var settings : GameSettings {
        save.settings
    }

    var selectedCar : OwnedCar? {
        save.selectedCar
    }

    // MARK: - Profiles

    func createProfile( named name : String ) {
        let trimmed = name.trimmingCharacters( in : .whitespacesAndNewlines )
        let ( id, created ) = store.createProfile( named : trimmed.isEmpty ? "Driver" : String( trimmed.prefix( 18 ) ) )
        profileID = id
        save = created
        defaults.set( id.uuidString, forKey : GameStore.activeProfileKey )
        profiles = store.profiles()
    }

    func loadProfile( _ id : UUID ) {
        let name = profiles.first { $0.id == id }?.name ?? "Driver"
        let ( loaded, outcome ) = store.load( id, fallbackName : name )
        save = loaded
        profileID = id
        loadOutcome = outcome
        defaults.set( id.uuidString, forKey : GameStore.activeProfileKey )
        profiles = store.profiles()

        if outcome == .recoveredFromBackup {
            message = "Your save was damaged and has been restored from a backup."
        } else if outcome == .resetAfterCorruption {
            message = "Your save could not be read. A fresh profile was started and the damaged file kept aside."
        }
    }

    func signOut() {
        profileID = nil
        defaults.removeObject( forKey : GameStore.activeProfileKey )
        profiles = store.profiles()
    }

    func deleteProfile( _ id : UUID ) {
        store.deleteProfile( id )

        if id == profileID {
            signOut()
        }

        profiles = store.profiles()
    }

    // MARK: - Mutation

    private func commit( _ updatedSave : SaveData ) {
        save = updatedSave

        if let profileID {
            store.write( updatedSave, for : profileID )
        }
    }

    /// Runs a throwing rule; on failure shows a player-facing message instead of changing anything.
    @discardableResult
    func perform( _ change : ( SaveData ) throws -> SaveData ) -> Bool {
        do {
            commit( try change( save ) )
            return true
        } catch let error as GarageError {
            message = GameStore.describe( error )
        } catch {
            message = "That didn't work."
        }

        return false
    }

    static func describe( _ error : GarageError ) -> String {
        switch error {
        case .carNotFound:
            return "That car doesn't exist."
        case .carNotOwned:
            return "You don't own that car."
        case .alreadyOwned:
            return "You already own this car."
        case .insufficientCredits:
            return "Not enough credits."
        case .levelTooLow( let required ):
            return "Requires driver level \( required )."
        case .maximumLevelReached:
            return "Already fully upgraded."
        case .notAvailable:
            return "Not available for this car."
        case .lastCar:
            return "You can't sell your only car."
        }
    }

    func updateSettings( _ change : ( inout GameSettings ) -> Void ) {
        var updatedSave = save
        change( &updatedSave.settings )
        commit( updatedSave )
    }

    // MARK: - Garage

    func chooseStarter( _ carID : CarID ) {
        perform { try garageRules.choosingStarter( carID, in : $0 ) }
    }

    func buy( _ carID : CarID ) -> Bool {
        let bought = perform { try garageRules.purchasing( carID, from : $0 ) }

        if bought {
            evaluateAchievements()
        }

        return bought
    }

    func sell( _ ownedID : UUID ) {
        perform { try garageRules.selling( ownedID, from : $0 ) }
    }

    func select( _ ownedID : UUID ) {
        perform { try garageRules.selecting( ownedID, in : $0 ) }
    }

    func toggleFavourite( _ ownedID : UUID ) {
        commit( garageRules.togglingFavourite( ownedID, in : save ) )
    }

    func toggleDealershipFavourite( _ carID : CarID ) {
        var updatedSave = save

        if updatedSave.favouriteDealershipCars.contains( carID ) {
            updatedSave.favouriteDealershipCars.remove( carID )
        } else {
            updatedSave.favouriteDealershipCars.insert( carID )
        }

        commit( updatedSave )
    }

    func buyUpgrade( _ category : UpgradeCategory, for ownedID : UUID ) {
        if perform( { try garageRules.purchasing( category, for : ownedID, from : $0 ) } ) {
            evaluateAchievements()
        }
    }

    func removeUpgrade( _ category : UpgradeCategory, for ownedID : UUID ) {
        perform { try garageRules.downgrading( category, for : ownedID, from : $0 ) }
    }

    func setCompound( _ compound : TyreCompound, for ownedID : UUID ) {
        perform { try garageRules.settingCompound( compound, for : ownedID, in : $0 ) }
    }

    func setInduction( _ kit : InductionKit, for ownedID : UUID ) {
        perform { try garageRules.settingInduction( kit, for : ownedID, in : $0 ) }
    }

    func setDrivetrain( _ drivetrain : Drivetrain, for ownedID : UUID ) {
        perform { try garageRules.settingDrivetrain( drivetrain, for : ownedID, in : $0 ) }
    }

    func saveTuning( _ setup : TuningSetup, for ownedID : UUID ) {
        if perform( { try garageRules.tuning( setup, for : ownedID, in : $0 ) } ) {
            evaluateAchievements()
        }
    }

    func customise( _ appearance : CarAppearance, for ownedID : UUID ) {
        if perform( { try garageRules.customising( appearance, for : ownedID, in : $0 ) } ) {
            evaluateAchievements()
        }
    }

    private func evaluateAchievements() {
        let evaluated = AchievementRules().evaluating( save )

        guard !evaluated.unlocked.isEmpty else {
            return
        }

        let lines = evaluated.unlocked.map { RewardLine( label : $0.title, credits : $0.credits, experience : $0.experience ) }
        commit( progressionRules.crediting( lines, to : evaluated.save ) )
        message = "Achievement unlocked: " + evaluated.unlocked.map { $0.title }.joined( separator : ", " )
        Haptics.shared.play( .achievement )
        GameAudio.shared.play( .reward )
    }

    // MARK: - Racing

    func availability( of event : EventDefinition ) -> EventAvailability {
        progressionRules.availability( of : event, car : selectedCar, in : save )
    }

    func startEvent( _ event : EventDefinition ) {
        guard let car = selectedCar, availability( of : event ).isAvailable else {
            return
        }

        var config = RaceFactory( save : save ).config( for : event, car : car )
        attachGhost( to : &config )
        activeRace = PendingRace(
            config : config,
            context : RaceContext(
                eventID : event.id,
                tier : event.tier,
                discipline : event.discipline,
                rivalID : event.rivalID,
                ownedCarID : car.id,
                prize : event.firstPlacePrize
            )
        )
    }

    func startQuickRace(
        trackID : TrackID,
        kind : RaceKind,
        laps : Int,
        opponents : Int,
        weather : Weather,
        timeOfDay : TimeOfDay
    ) {
        guard let car = selectedCar else {
            return
        }

        var config = RaceFactory( save : save ).quickRace(
            trackID : trackID,
            kind : kind,
            laps : laps,
            opponents : opponents,
            weather : weather,
            timeOfDay : timeOfDay,
            car : car
        )
        attachGhost( to : &config )
        let index = PerformanceProfile.measure( CarBuild( owned : car ).spec ).index
        activeRace = PendingRace(
            config : config,
            context : RaceContext(
                discipline : RaceContext.discipline( for : kind, trackID : trackID ),
                ownedCarID : car.id,
                prize : RewardCalculator.quickRacePrize( performanceIndex : index )
            )
        )
    }

    func startTutorial( _ kind : TutorialKind ) {
        guard let car = selectedCar else {
            return
        }

        let config = RaceFactory( save : save ).tutorial( kind, car : car )
        activeRace = PendingRace(
            config : config,
            context : RaceContext( discipline : kind == .dragLaunch ? .drag : .sprint, ownedCarID : car.id, tutorial : kind )
        )
    }

    func completeTutorial( _ kind : TutorialKind ) {
        let alreadyDone = save.profile.completedTutorials.contains( kind )
        commit( progressionRules.completingTutorial( kind, in : save ) )

        if !alreadyDone {
            message = "Tutorial complete: \( kind.title )"
            evaluateAchievements()
        }
    }

    /// Replays the same race with the same field (fast restart).
    func restart( _ race : PendingRace ) {
        var config = race.config

        if let car = selectedCar, let index = config.entrants.firstIndex( where : { $0.isPlayer } ) {
            config.entrants[ index ] = RaceFactory( save : save ).playerEntrant( for : car )
        }

        attachGhost( to : &config )
        activeRace = PendingRace( config : config, context : race.context, championshipRound : race.championshipRound )
    }

    private static func ghostKey( trackID : TrackID ) -> String {
        "timeattack-\( trackID )"
    }

    private func attachGhost( to config : inout RaceConfig ) {
        guard case .timeAttack = config.kind, let profileID else {
            return
        }

        config.ghost = store.loadGhost( profileID, key : GameStore.ghostKey( trackID : config.trackID ) )
    }

    /// Credits a finished race and returns the itemised rewards.
    func complete( _ outcome : RaceOutcome, race : PendingRace ) -> RaceRewards {
        if let tutorial = race.context.tutorial {
            let levelBefore = save.profile.level

            if outcome.didFinish {
                commit( progressionRules.completingTutorial( tutorial, in : save ) )
            }

            return RaceRewards( levelBefore : levelBefore, levelAfter : save.profile.level )
        }

        var prize = race.context.prize
        var championshipLines : [RewardLine] = []
        var updatedSave = save

        if let championshipID = race.context.championshipID, let championship = Championships.named( championshipID ) {
            prize = championshipRules.roundPrize( for : championship )

            if let applied = try? championshipRules.applyingRound( order : outcome.finishingOrder, to : championship, in : updatedSave ) {
                updatedSave = applied.save

                if let position = applied.finalPosition {
                    championshipLines.append( championshipRules.finalPrize( for : championship, position : position ) )
                }
            }
        }

        var ( appliedSave, rewards ) = progressionRules.applying( outcome, to : updatedSave, prize : prize )

        if !championshipLines.isEmpty {
            appliedSave = progressionRules.crediting( championshipLines, to : appliedSave )
            rewards.lines += championshipLines
            let evaluated = AchievementRules().evaluating( appliedSave )
            appliedSave = evaluated.save
            rewards.unlockedAchievements += evaluated.unlocked.map { $0.title }
            appliedSave = progressionRules.crediting(
                evaluated.unlocked.map { RewardLine( label : $0.title, credits : $0.credits, experience : $0.experience ) },
                to : appliedSave
            )
            rewards.levelAfter = appliedSave.profile.level
        }

        commit( appliedSave )

        // Game Center keeps each player's best, so every counted result is sent.
        if let board = GlobalLeaderboards.board( for : outcome.kind, trackID : outcome.trackID ),
           let ( value, _ ) = ProgressionRules.personalBestValue( for : outcome ) {
            GameCenterService.shared.submit( value, to : board )
        }

        // Keep the fastest time attack lap as the ghost to chase next time.
        if let ghost = outcome.ghost, let profileID, case .timeAttack = outcome.kind {
            let key = GameStore.ghostKey( trackID : outcome.trackID )
            let existing = store.loadGhost( profileID, key : key )

            if existing.map( { ghost.lapTime < $0.lapTime } ) ?? true {
                store.writeGhost( ghost, for : profileID, key : key )
            }
        }

        return rewards
    }

    // MARK: - Championships

    func enterChampionship( _ championship : ChampionshipDefinition ) {
        guard let car = selectedCar else {
            return
        }

        do {
            commit( try championshipRules.entering( championship, with : car, in : save ) )
        } catch {
            message = "You can't enter this championship yet."
        }
    }

    func startNextRound( of championship : ChampionshipDefinition ) {
        guard let car = selectedCar,
              let progress = save.championships[ championship.id ],
              !progress.isComplete,
              progress.nextRound < championship.rounds.count else {
            return
        }

        let round = championship.rounds[ progress.nextRound ]
        let config = RaceFactory( save : save ).config( for : round, in : championship, progress : progress, car : car )
        activeRace = PendingRace(
            config : config,
            context : RaceContext(
                championshipID : championship.id,
                tier : championship.tier,
                discipline : round.discipline,
                ownedCarID : car.id
            ),
            championshipRound : round
        )
    }

    // MARK: - Debug

    #if DEBUG
    func debugGiveCredits( _ amount : Int ) {
        var updatedSave = save
        updatedSave.profile.credits += amount
        commit( updatedSave )
    }

    func debugSetLevel( _ level : Int ) {
        var updatedSave = save
        var experience = 0

        for current in 1 ..< max( level, 1 ) {
            experience += ProgressionRules.experienceToNext( level : current )
        }

        updatedSave.profile.experience = experience
        updatedSave.profile.level = ProgressionRules.level( forExperience : experience )
        commit( updatedSave )
    }

    func debugUnlockAllCars() {
        var updatedSave = save

        for car in Cars.all where !updatedSave.owns( car.id ) {
            updatedSave.garage.append( OwnedCar( carID : car.id ) )
        }

        commit( updatedSave )
    }

    func debugUnlockAllEvents() {
        var updatedSave = save

        for event in Events.all {
            var record = updatedSave.events[ event.id ] ?? EventRecord()
            record.bestPlacement = 1
            record.wins = max( record.wins, 1 )
            record.completions = max( record.completions, 1 )
            updatedSave.events[ event.id ] = record
        }

        updatedSave.profile.completedTutorials = Set( TutorialKind.allCases )
        commit( updatedSave )
    }

    func debugResetProfile() {
        var fresh = SaveData( profileName : save.profile.name )
        fresh.settings = save.settings
        commit( fresh )
    }
    #endif
}
