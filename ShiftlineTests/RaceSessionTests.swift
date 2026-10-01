import Foundation
import Testing
@testable import Shiftline

struct RaceSessionTests {
    private func soloConfig( track : TrackID, kind : RaceKind, laps : Int = 1, car : CarID = "veltra-aria" ) -> RaceConfig {
        RaceConfig( title : "test", trackID : track, kind : kind, laps : laps, entrants : [ TestSupport.entrant( car, player : true ) ] )
    }

    @Test func countdownHoldsCarsThenStartsRace() {
        let session = RaceSession( config : soloConfig( track : "velocity-national", kind : .circuit ) )
        let start = session.player.state.position

        for _ in 0 ..< 120 * 3 {
            session.controls.throttle = 1
            session.step()
        }

        #expect( session.phase == .countdown )
        #expect( ( session.player.state.position - start ).length < 0.01 )

        for _ in 0 ..< 120 {
            session.step()
        }

        #expect( session.phase == .racing )
        #expect( session.drainEvents().contains { if case .go = $0 { return true } else { return false } } )
    }

    /// Distance covered three seconds after the green, with the throttle pressed `pressAt` seconds before it.
    private func launchDistance( pressAt : Double ) -> ( distance : Double, events : [RaceEvent] ) {
        let session = RaceSession( config : soloConfig( track : "mesa-speedrun", kind : .sprint ) )
        let start = session.player.state.position
        var events : [RaceEvent] = []

        while session.phase == .countdown {
            session.controls.throttle = session.countdownRemaining <= pressAt ? 1 : 0
            session.step()
        }

        for _ in 0 ..< 120 * 3 {
            session.step()
            events += session.drainEvents()
        }

        return ( ( session.player.state.position - start ).length, events )
    }

    @Test func startQualityDependsOnWhenTheThrottleGoesDown() {
        #expect( StartQuality( holdBegan : nil ) == .normal )
        #expect( StartQuality( holdBegan : 3.2 ) == .tooEarly )
        #expect( StartQuality( holdBegan : 1.9 ) == .perfect )
        #expect( StartQuality( holdBegan : 1.2 ) == .good )
        #expect( StartQuality( holdBegan : 0.4 ) == .normal )
        #expect( StartQuality( skill : 1, roll : 0.45 ) == .perfect )
        #expect( StartQuality( skill : 0, roll : 0.45 ) == .normal )
    }

    @Test func hittingTheGasOnTwoBoostsTheStart() {
        let perfect = launchDistance( pressAt : 1.95 )
        let good = launchDistance( pressAt : 1.3 )
        let normal = launchDistance( pressAt : 0.5 )
        let early = launchDistance( pressAt : 3.5 )

        #expect( perfect.distance > good.distance + 2 )
        #expect( good.distance > normal.distance + 1 )
        #expect( early.distance < normal.distance )
        #expect( perfect.events.contains { if case .start( .perfect ) = $0 { return true } else { return false } } )
        #expect( early.events.contains { if case .start( .tooEarly ) = $0 { return true } else { return false } } )
        #expect( !normal.events.contains { if case .start = $0 { return true } else { return false } } )
    }

    @Test func draftingChargesASlingshot() {
        var charge = SlipstreamCharge()
        let step = 1.0 / 120
        var fired = false

        for _ in 0 ..< 120 * 2 {
            fired = charge.update( tow : 0.6, isBoosting : false, timeStep : step ) || fired
        }

        #expect( !fired )
        #expect( charge.level > 0.7 )

        // Pulling out of the tow drains it.
        for _ in 0 ..< 60 {
            _ = charge.update( tow : 0, isBoosting : false, timeStep : step )
        }

        #expect( charge.level < 0.6 )

        for _ in 0 ..< 120 * 3 where !fired {
            fired = charge.update( tow : 0.6, isBoosting : false, timeStep : step )
        }

        #expect( fired )
        #expect( charge.level == 0 )

        // No charging while the slingshot is burning.
        _ = charge.update( tow : 0.9, isBoosting : true, timeStep : step )
        #expect( charge.level == 0 )
    }

    @Test func lapsAreCountedAndTheRaceFinishes() {
        let session = RaceSession( config : soloConfig( track : "velocity-national", kind : .circuit, laps : 2 ) )
        TestSupport.runAutopilot( session )
        #expect( session.phase == .finished )
        #expect( session.player.lapsCompleted == 2 )
        #expect( session.player.lapTimes.count == 2 )
        #expect( session.player.bestLap != nil )
        #expect( session.player.lapTimes[ 1 ] < session.player.lapTimes[ 0 ] )
    }

    @Test func checkpointsArePassedInOrder() {
        let session = RaceSession( config : soloConfig( track : "harbour-sprint", kind : .sprint ) )
        var passed : [Int] = []
        session.player.ai = AIDriver( profile : Opponents.pool[ 3 ], skill : 0.8, seed : "test" )

        while session.phase != .finished {
            session.step()

            for event in session.drainEvents() {
                if case .sector( let index, _, _ ) = event {
                    passed.append( index )
                }
            }
        }

        #expect( session.player.isFinished )
        #expect( passed == Array( 0 ..< session.track.checkpoints.count ) )
    }

    @Test func drivingBackwardsIsFlaggedWrongWay() {
        let session = RaceSession( config : soloConfig( track : "velocity-national", kind : .practice ) )

        while session.phase == .countdown {
            session.step()
        }

        let car = session.player
        car.state.heading += .pi
        var input = PlayerControls()
        input.throttle = 1
        session.controls = input
        var flagged = false

        for _ in 0 ..< 120 * 4 {
            session.step()
            flagged = flagged || session.drainEvents().contains { if case .wrongWay = $0 { return true } else { return false } }
        }

        #expect( flagged )
        #expect( car.raceDistance < 0 )
    }

    @Test func fixedTimestepIsIndependentOfFrameRate() {
        let steady = RaceSession( config : soloConfig( track : "mesa-speedrun", kind : .sprint ) )
        let choppy = RaceSession( config : soloConfig( track : "mesa-speedrun", kind : .sprint ) )
        steady.controls.throttle = 1
        choppy.controls.throttle = 1
        var elapsed = 0.0

        while elapsed < 8 {
            steady.advance( by : 1.0 / 60 )
            elapsed += 1.0 / 60
        }

        var choppyElapsed = 0.0
        let frames = [ 1.0 / 30, 1.0 / 120, 1.0 / 45, 1.0 / 90 ]
        var index = 0

        while choppyElapsed < elapsed - 1e-9 {
            let frame = min( frames[ index % frames.count ], elapsed - choppyElapsed )
            choppy.advance( by : frame )
            choppyElapsed += frame
            index += 1
        }

        #expect( ( steady.player.state.position - choppy.player.state.position ).length < 0.5 )
    }

    @Test func wallsKeepCarsOnTheCircuit() {
        let session = RaceSession( config : soloConfig( track : "harbour-loop", kind : .practice ) )

        while session.phase == .countdown {
            session.step()
        }

        // Flat out with no steering: the first bend puts the car into the barrier.
        session.controls.throttle = 1

        for _ in 0 ..< 120 * 15 {
            session.step()
            #expect( abs( session.player.lateral ) < session.track.barrierOffset + 1 )
        }

        #expect( session.player.wallHits > 0 )
    }

    @Test func aiFieldCompletesACircuitRaceWithResults() {
        let field = Opponents.field( count : 5, seed : "results" )
        var entrants = [ TestSupport.entrant( "hayase-pip", player : true ) ]
        entrants += field.map { TestSupport.entrant( "hayase-pip", player : false, profile : $0 ) }
        var config = RaceConfig( title : "results", trackID : "velocity-national", kind : .circuit, laps : 2, entrants : entrants )
        config.opponentSkill = 0.5
        let session = RaceSession( config : config )
        TestSupport.runAutopilot( session )
        let standings = session.standings
        #expect( session.phase == .finished )
        #expect( Set( standings.map { $0.position } ) == Set( 1 ... 6 ) )

        let times = standings.compactMap { $0.totalTime }
        #expect( times == times.sorted() )

        let outcome = OutcomeBuilder.outcome( from : session, context : RaceContext( discipline : .circuit ) )
        #expect( outcome.finishingOrder.count == 6 )
        #expect( outcome.placement == session.player.position )
    }

    @Test func eliminationRemovesLastPlaceEachLap() {
        let field = Opponents.field( count : 3, seed : "elimination" )
        var entrants = [ TestSupport.entrant( "veltra-corsa-gt", player : true ) ]
        entrants += field.map { TestSupport.entrant( "hayase-pip", player : false, profile : $0 ) }
        let session = RaceSession( config : RaceConfig( title : "elim", trackID : "velocity-national", kind : .elimination, entrants : entrants ) )
        TestSupport.runAutopilot( session, maximumSeconds : 900 )
        #expect( session.phase == .finished )
        #expect( session.cars.filter { $0.isEliminated }.count == 3 )
        #expect( !session.player.isEliminated )
    }

    @Test func timeAttackInvalidatesLapsForTrackLimits() {
        let session = RaceSession( config : soloConfig( track : "velocity-national", kind : .timeAttack, laps : 2 ) )
        let car = session.player
        car.offTrackTime = 1
        car.state.velocity = Vec2( 20, 0 )
        session.mode.trackLimitsBroken( by : car, in : session )
        #expect( !car.isLapValid )
    }

    @Test func circuitTrackLimitsAddPenalty() {
        let session = RaceSession( config : soloConfig( track : "velocity-national", kind : .circuit, laps : 1 ) )
        session.mode.trackLimitsBroken( by : session.player, in : session )
        #expect( session.player.penaltySeconds == 1 )
    }

    @Test func checkpointModeAddsTimeAndRunsOut() {
        let mode = CheckpointMode( startTime : 1, bonusPerCheckpoint : 5 )
        let session = RaceSession( config : soloConfig( track : "coast-road", kind : .checkpoint( startTime : 1, bonusPerCheckpoint : 5 ) ) )
        mode.checkpointPassed( by : session.player, index : 0, in : session )
        #expect( mode.timeRemaining == 6 )

        for _ in 0 ..< 120 * 7 {
            mode.update( session, timeStep : RaceSession.timeStep )
        }

        #expect( mode.isComplete( session ) )
        #expect( mode.playerScore( session ) == nil )
    }

    @Test func speedTrapsRecordSpeeds() {
        let session = RaceSession( config : soloConfig( track : "mesa-speedrun", kind : .speedTrap, car : "veltra-vortex" ) )
        TestSupport.runAutopilot( session )
        let mode = session.mode as? SpeedTrapMode
        #expect( session.player.isFinished )
        #expect( ( mode?.trapSpeeds.count ?? 0 ) == session.speedTraps.count )
        #expect( ( mode?.totalScore ?? 0 ) > 500 )
    }

    @Test func ghostIsRecordedForBestLap() {
        let session = RaceSession( config : soloConfig( track : "velocity-national", kind : .timeAttack, laps : 2 ) )
        TestSupport.runAutopilot( session )
        let ghost = session.bestGhost
        #expect( ghost != nil )
        #expect( ( ghost?.samples.count ?? 0 ) > 100 )
        #expect( ghost?.lapTime == session.player.bestLap )
        #expect( ghost?.sample( at : ( ghost?.lapTime ?? 0 ) / 2 ) != nil )
    }
}
