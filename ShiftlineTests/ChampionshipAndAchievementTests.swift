import Foundation
import Testing
@testable import Shiftline

struct ChampionshipTests {
    private let rules = ChampionshipRules()

    private func enteredSave( _ championship : ChampionshipDefinition ) throws -> SaveData {
        var save = TestSupport.saveWithStarter()
        save.profile.level = 40

        for eventID in championship.requirements.requiredEventIDs {
            save.events[ eventID ] = EventRecord( bestPlacement : 1, completions : 1, wins : 1 )
        }

        for tier in CareerTier.allCases {
            for event in Events.events( in : tier ).prefix( 4 ) {
                save.events[ event.id ] = EventRecord( bestPlacement : 1, completions : 1, wins : 1 )
            }
        }

        return try rules.entering( championship, with : save.garage[ 0 ], in : save )
    }

    @Test func pointsTableMatchesSpecification() {
        #expect( ChampionshipScoring.points( forPosition : 1 ) == 25 )
        #expect( ChampionshipScoring.points( forPosition : 2 ) == 18 )
        #expect( ChampionshipScoring.points( forPosition : 3 ) == 15 )
        #expect( ChampionshipScoring.points( forPosition : 8 ) == 4 )
        #expect( ChampionshipScoring.points( forPosition : 9 ) == 0 )
    }

    @Test func enteringCreatesAFullField() throws {
        let championship = Championships.named( "ch-rookie" )!
        let save = try enteredSave( championship )
        let progress = save.championships[ championship.id ]!
        #expect( progress.standings.count == championship.fieldSize )
        #expect( progress.standings.filter { $0.isPlayer }.count == 1 )
        #expect( progress.nextRound == 0 )
    }

    @Test func championshipFieldsFollowTheCarRules() throws {
        var save = TestSupport.saveWithStarter( "hayase-kite-s" )
        save.profile.level = 40
        save.events[ "c-drift-1" ] = EventRecord( bestPlacement : 1, completions : 1, wins : 1 )

        for tier in CareerTier.allCases {
            for event in Events.events( in : tier ).prefix( 4 ) {
                save.events[ event.id ] = EventRecord( bestPlacement : 1, completions : 1, wins : 1 )
            }
        }

        let entered = try rules.entering( Championships.named( "ch-drift" )!, with : save.garage[ 0 ], in : save )
        let field = entered.championships[ "ch-drift" ]!.standings.filter { !$0.isPlayer }
        #expect( !field.isEmpty )
        #expect( field.allSatisfy { Cars.named( $0.carID )?.drivetrain == .rwd } )
    }

    @Test func lockedChampionshipsCannotBeEntered() {
        let save = TestSupport.saveWithStarter()
        #expect( throws : ChampionshipError.locked ) {
            try rules.entering( Championships.named( "ch-legend" )!, with : save.garage[ 0 ], in : save )
        }
    }

    @Test func roundsAwardPointsAndTheSeasonCompletes() throws {
        let championship = Championships.named( "ch-rookie" )!
        var save = try enteredSave( championship )
        let others = save.championships[ championship.id ]!.standings.filter { !$0.isPlayer }.map { $0.id }
        var finalPosition : Int?

        for _ in championship.rounds {
            let result = try rules.applyingRound( order : [ "player" ] + others, to : championship, in : save )
            save = result.save
            finalPosition = result.finalPosition
        }

        let progress = save.championships[ championship.id ]!
        #expect( progress.isComplete )
        #expect( finalPosition == 1 )
        #expect( progress.standings[ 0 ].isPlayer )
        #expect( progress.standings[ 0 ].points == 25 * championship.rounds.count )
        #expect( progress.standings[ 0 ].wins == championship.rounds.count )
        #expect( save.statistics[ .championshipsWon ] == 1 )
        #expect( throws : ChampionshipError.alreadyComplete ) {
            try rules.applyingRound( order : [ "player" ], to : championship, in : save )
        }
    }

    @Test func tiesAreBrokenByWinsThenCountBack() {
        let a = ChampionshipStanding( id : "a", name : "A", carID : "x", isPlayer : false, points : 40, wins : 1, podiums : 2, finishes : [ 1, 3 ] )
        let b = ChampionshipStanding( id : "b", name : "B", carID : "x", isPlayer : false, points : 40, wins : 0, podiums : 2, finishes : [ 2, 2 ] )
        let c = ChampionshipStanding( id : "c", name : "C", carID : "x", isPlayer : false, points : 40, wins : 1, podiums : 2, finishes : [ 1, 2 ] )
        let sorted = rules.sorted( [ a, b, c ] )
        #expect( sorted.map { $0.id } == [ "c", "a", "b" ] )
    }

    @Test func finalPrizeScalesWithPosition() {
        let championship = Championships.named( "ch-pro" )!
        #expect( rules.finalPrize( for : championship, position : 1 ).credits == championship.prize )
        #expect( rules.finalPrize( for : championship, position : 2 ).credits < championship.prize )
    }
}

struct AchievementTests {
    @Test func thereAreAtLeastThirtyUniqueAchievements() {
        #expect( Achievements.all.count >= 30 )
        #expect( Set( Achievements.all.map { $0.id } ).count == Achievements.all.count )
    }

    @Test func achievementsUnlockOnceFromStatistics() {
        var save = TestSupport.saveWithStarter()
        save.statistics[ .wins ] = 1
        save.statistics[ .perfectShifts ] = 5
        let first = AchievementRules().evaluating( save )
        let ids = Set( first.unlocked.map { $0.id } )
        #expect( ids.contains( "first-flag" ) )
        #expect( ids.contains( "perfect-5" ) )
        #expect( !ids.contains( "ten-wins" ) )

        let second = AchievementRules().evaluating( first.save )
        #expect( second.unlocked.isEmpty )
    }

    @Test func progressIsFractional() {
        var save = TestSupport.saveWithStarter()
        save.statistics[ .wins ] = 5
        let tenWins = Achievements.all.first { $0.id == "ten-wins" }!
        #expect( abs( tenWins.progress( save ) - 0.5 ) < 1e-9 )
    }

    @Test func garageAchievementUsesPeakOwnership() {
        var save = TestSupport.saveWithStarter()
        save.statistics[ .carsOwnedPeak ] = 10
        let unlocked = AchievementRules().evaluating( save ).unlocked.map { $0.id }
        #expect( unlocked.contains( "garage-10" ) )
    }
}
