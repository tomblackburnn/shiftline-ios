import Foundation
import Testing
@testable import Shiftline

struct DragRaceTests {
    private func race( length : Double = Units.quarterMile ) -> DragRace {
        DragRace(
            length : length,
            player : TestSupport.entrant( "veltra-aria", player : true ),
            opponent : TestSupport.entrant( "veltra-aria", player : false, profile : Opponents.pool[ 0 ] ),
            opponentSkill : 0.6,
            seed : "test"
        )
    }

    private func runUntilGreen( _ race : DragRace, rpm : Double ) {
        while race.greenTime == nil {
            race.player.throttle = race.player.state.engineRPM < rpm ? 1 : 0
            race.step()
        }
    }

    @Test func launchingBeforeGreenIsAFoul() {
        let drag = race()

        for _ in 0 ..< 60 {
            drag.step()
        }

        drag.launchPlayer()
        #expect( drag.player.isFoul )
    }

    @Test func launchRatingFollowsRPM() {
        let perfectRace = race()
        runUntilGreen( perfectRace, rpm : perfectRace.player.model.idealLaunchRPM )
        perfectRace.player.state.engineRPM = perfectRace.player.model.idealLaunchRPM
        perfectRace.launchPlayer()
        #expect( perfectRace.player.launchRating == .perfect )

        let bogRace = race()
        runUntilGreen( bogRace, rpm : 1_000 )
        bogRace.player.state.engineRPM = bogRace.player.model.spec.idleRPM
        bogRace.launchPlayer()
        #expect( bogRace.player.launchRating == .bogged )

        let spinRace = race()
        runUntilGreen( spinRace, rpm : 7_000 )
        spinRace.player.state.engineRPM = spinRace.player.model.spec.redlineRPM * 0.98
        spinRace.launchPlayer()
        #expect( spinRace.player.launchRating == .wheelspin )
    }

    @Test func reactionTimeIsMeasuredFromGreen() {
        let drag = race()
        runUntilGreen( drag, rpm : drag.player.model.idealLaunchRPM )

        for _ in 0 ..< 30 {
            drag.step()
        }

        drag.launchPlayer()
        let result = drag.player.result( greenTime : drag.greenTime ?? 0 )
        #expect( abs( result.reactionTime - 0.25 ) < 0.02 )
    }

    @Test func fullPassProducesTimeslip() {
        let drag = race()
        runUntilGreen( drag, rpm : drag.player.model.idealLaunchRPM )
        drag.launchPlayer()
        var steps = 0

        while !drag.isComplete && steps < 120 * 60 {
            drag.player.throttle = 1

            if drag.player.state.engineRPM >= drag.player.model.idealUpshiftRPM( fromGear : max( drag.player.state.gear, 1 ) ) {
                drag.shiftUpPlayer()
            }

            drag.step()
            steps += 1
        }

        let result = drag.player.result( greenTime : drag.greenTime ?? 0 )
        #expect( drag.isComplete )
        #expect( result.elapsedTime > 11 && result.elapsedTime < 17 )
        #expect( result.trapSpeedKPH > 140 && result.trapSpeedKPH < 200 )
        #expect( result.sixtyFoot != nil )
        #expect( result.eighthMile != nil )
        #expect( result.perfectShifts >= 1 )
    }

    @Test func simulatedPassFinishes() {
        let result = DragRace.simulatedPass(
            entrant : TestSupport.entrant( "brannock-tempest", player : false, profile : Opponents.pool[ 1 ] ),
            length : Units.quarterMile,
            skill : 0.7,
            seed : "sim"
        )
        #expect( result.elapsedTime > 10 && result.elapsedTime < 17 )
    }

    @Test func fasterCarWinsSimulatedPasses() {
        let slow = DragRace.simulatedPass( entrant : TestSupport.entrant( "hayase-pip", player : false, profile : Opponents.pool[ 1 ] ), length : Units.quarterMile, skill : 0.8, seed : "a" )
        let fast = DragRace.simulatedPass( entrant : TestSupport.entrant( "veltra-spectre-rs", player : false, profile : Opponents.pool[ 1 ] ), length : Units.quarterMile, skill : 0.8, seed : "a" )
        #expect( fast.elapsedTime < slow.elapsedTime )
    }
}
