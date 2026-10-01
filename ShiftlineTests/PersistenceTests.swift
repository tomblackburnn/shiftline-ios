import Foundation
import Testing
@testable import Shiftline

struct PersistenceTests {
    @Test func saveRoundTripsEverything() throws {
        let store = SaveStore( root : TestSupport.temporaryDirectory() )
        let ( id, _ ) = store.createProfile( named : "Round Trip" )
        var save = TestSupport.saveWithStarter()
        save.profile.level = 7
        save.profile.experience = 4_321
        save.profile.completedTutorials = [ .basics, .drifting ]
        save.garage[ 0 ].upgrades[ .engine ] = 2
        save.garage[ 0 ].tuning.finalDrive = 1.1
        save.garage[ 0 ].appearance.livery = .chevron
        save.events[ "r-sprint-1" ] = EventRecord( bestPlacement : 1, bestScore : nil, completions : 2, wins : 1 )
        save.achievements[ "first-flag" ] = Date( timeIntervalSince1970 : 1_000 )
        save.statistics[ .wins ] = 3
        save.personalBests[ "harbour-sprint|sprint" ] = PersonalBest( value : 70.5, lowerIsBetter : true, carID : "hayase-pip" )
        save.settings.speedUnit = .mph
        save.settings.assists.automaticTransmission = false
        save.rivalWins[ "rival-voss" ] = 1
        save.championships[ "ch-rookie" ] = ChampionshipProgress(
            championshipID : "ch-rookie",
            nextRound : 1,
            standings : [ ChampionshipStanding( id : "player", name : "P", carID : "hayase-pip", isPlayer : true, points : 25 ) ]
        )

        store.write( save, for : id )
        let ( loaded, outcome ) = store.load( id, fallbackName : "x" )
        #expect( outcome == .loaded )
        #expect( loaded == save )
    }

    @Test func corruptSaveRecoversFromBackup() throws {
        let root = TestSupport.temporaryDirectory()
        let store = SaveStore( root : root )
        let ( id, _ ) = store.createProfile( named : "Backup" )
        var save = TestSupport.saveWithStarter()
        save.profile.credits = 1_234
        store.write( save, for : id )
        save.profile.credits = 5_678
        store.write( save, for : id )

        let saveURL = store.profileDirectory( id ).appendingPathComponent( "save.json" )
        try Data( "{ not json".utf8 ).write( to : saveURL )

        let ( recovered, outcome ) = store.load( id, fallbackName : "Backup" )
        #expect( outcome == .recoveredFromBackup )
        #expect( recovered.profile.credits == 1_234 )

        let quarantined = try FileManager.default.contentsOfDirectory( atPath : store.profileDirectory( id ).path )
        #expect( quarantined.contains { $0.hasPrefix( "save.corrupt-" ) } )
    }

    @Test func totallyCorruptSaveFallsBackSafely() throws {
        let store = SaveStore( root : TestSupport.temporaryDirectory() )
        let ( id, _ ) = store.createProfile( named : "Broken" )
        let directory = store.profileDirectory( id )
        try Data( "garbage".utf8 ).write( to : directory.appendingPathComponent( "save.json" ) )
        try? FileManager.default.removeItem( at : directory.appendingPathComponent( "save.backup.json" ) )

        let ( fresh, outcome ) = store.load( id, fallbackName : "Broken" )
        #expect( outcome == .resetAfterCorruption )
        #expect( fresh.profile.name == "Broken" )
        #expect( fresh.garage.isEmpty )
    }

    @Test func olderSavesMigrateAndMissingFieldsDefault() throws {
        let json = """
        {
            "version" : 1,
            "profile" : { "name" : "Old", "createdAt" : 757382400, "lastPlayed" : 757382400,
                          "level" : 4, "experience" : 1000, "credits" : 500, "hasChosenStarter" : true, "completedTutorials" : [] },
            "garage" : [ { "carID" : "hayase-pip" }, { "carID" : "removed-car" } ]
        }
        """
        let decoded = try JSONDecoder().decode( SaveData.self, from : Data( json.utf8 ) )
        let migrated = decoded.migrated()
        #expect( migrated.version == SaveData.currentVersion )
        #expect( migrated.garage.count == 1 )
        #expect( migrated.garage[ 0 ].appearance.paintHex == Cars.named( "hayase-pip" )!.defaultPaintHex )
        #expect( migrated.settings == GameSettings() )
        #expect( migrated.statistics[ .carsOwnedPeak ] == 2 )
    }

    @Test func newerSavesAreNotLoadedAsIfUnderstood() throws {
        let store = SaveStore( root : TestSupport.temporaryDirectory() )
        let ( id, _ ) = store.createProfile( named : "Future" )
        var save = TestSupport.saveWithStarter()
        save.version = SaveData.currentVersion + 5
        try JSONEncoder().encode( save ).write( to : store.profileDirectory( id ).appendingPathComponent( "save.json" ) )
        let ( _, outcome ) = store.load( id, fallbackName : "Future" )
        #expect( outcome != .loaded )
    }

    @Test func profilesAreListedAndDeleted() {
        let store = SaveStore( root : TestSupport.temporaryDirectory() )
        let ( first, _ ) = store.createProfile( named : "One" )
        let ( second, _ ) = store.createProfile( named : "Two" )
        #expect( Set( store.profiles().map { $0.id } ) == [ first, second ] )
        store.deleteProfile( first )
        #expect( store.profiles().map { $0.id } == [ second ] )
    }

    @Test func ghostsPersist() {
        let store = SaveStore( root : TestSupport.temporaryDirectory() )
        let ( id, _ ) = store.createProfile( named : "Ghost" )
        let ghost = GhostRecording(
            trackID : "velocity-gp",
            carID : "hayase-pip",
            driverName : "Ghost",
            lapTime : 90,
            paintHex : 0xFFFFFF,
            samples : [ GhostSample( time : 0, x : 0, y : 0, heading : 0, speed : 0 ), GhostSample( time : 1, x : 10, y : 0, heading : 0, speed : 10 ) ]
        )
        store.writeGhost( ghost, for : id, key : "timeattack-velocity-gp" )
        #expect( store.loadGhost( id, key : "timeattack-velocity-gp" ) == ghost )
        #expect( ghost.sample( at : 0.5 )?.x == 5 )
    }

    @Test func gameStorePersistsAcrossLaunches() throws {
        let root = TestSupport.temporaryDirectory()
        let defaults = UserDefaults( suiteName : "ShiftlinePersistenceTest-\( UUID().uuidString )" )!
        let first = GameStore( store : SaveStore( root : root ), defaults : defaults )
        first.createProfile( named : "Relaunch" )
        first.chooseStarter( "norrvik-fjell" )
        first.updateSettings { $0.speedUnit = .mph }

        let second = GameStore( store : SaveStore( root : root ), defaults : defaults )
        #expect( second.hasActiveProfile )
        #expect( second.save.profile.name == "Relaunch" )
        #expect( second.selectedCar?.carID == "norrvik-fjell" )
        #expect( second.settings.speedUnit == .mph )
    }
}
