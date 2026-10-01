import Foundation
import Testing
@testable import Shiftline

struct DriftScorerTests {
    /// A car travelling at `speed` with its nose `angle` degrees away from the direction of travel.
    private func sliding( angle : Double, speed : Double = 20 ) -> VehicleState {
        var state = VehicleState()
        state.heading = angle * .pi / 180
        state.velocity = Vec2( speed, 0 )
        return state
    }

    private func run( _ scorer : inout DriftScorer, _ state : VehicleState, seconds : Double, context : DriftContext = DriftContext() ) -> [DriftEvent] {
        var events : [DriftEvent] = []

        for _ in 0 ..< Int( seconds * 120 ) {
            events += scorer.update( state, context : context, timeStep : 1.0 / 120 )
        }

        return events
    }

    @Test func slidingAccumulatesAndBanksAfterGrace() {
        var scorer = DriftScorer()
        _ = run( &scorer, sliding( angle : 30 ), seconds : 2 )
        #expect( scorer.pendingScore > 0 )
        #expect( scorer.bankedScore == 0 )

        let events = run( &scorer, sliding( angle : 0 ), seconds : 1.5 )
        #expect( scorer.bankedScore > 0 )
        #expect( events.contains { if case .banked = $0 { return true } else { return false } } )
    }

    @Test func biggerAnglesAndSpeedsScoreMore() {
        var gentle = DriftScorer()
        var wild = DriftScorer()
        _ = run( &gentle, sliding( angle : 15, speed : 12 ), seconds : 2 )
        _ = run( &wild, sliding( angle : 45, speed : 25 ), seconds : 2 )
        #expect( wild.pendingScore > gentle.pendingScore * 3 )
    }

    @Test func transitionsAwardBonusAndMultiplier() {
        var scorer = DriftScorer()
        _ = run( &scorer, sliding( angle : 30 ), seconds : 1 )
        _ = run( &scorer, sliding( angle : 0 ), seconds : 0.3 )
        let events = run( &scorer, sliding( angle : -30 ), seconds : 1 )
        #expect( scorer.transitions == 1 )
        #expect( scorer.multiplier > 1 )
        #expect( events.contains { if case .transition = $0 { return true } else { return false } } )
    }

    @Test func sustainedDriftRaisesMultiplierUpToCap() {
        var scorer = DriftScorer()
        _ = run( &scorer, sliding( angle : 30 ), seconds : 60 )
        #expect( scorer.multiplier == DriftScorer.maximumMultiplier )
    }

    @Test func spinningOutLosesTheChain() {
        var scorer = DriftScorer()
        _ = run( &scorer, sliding( angle : 30 ), seconds : 2 )
        let events = run( &scorer, sliding( angle : 150 ), seconds : 0.2 )
        #expect( scorer.pendingScore == 0 )
        #expect( scorer.bankedScore == 0 )
        #expect( events.contains { if case .failed = $0 { return true } else { return false } } )
    }

    @Test func heavyCollisionLosesTheChain() {
        var scorer = DriftScorer()
        _ = run( &scorer, sliding( angle : 30 ), seconds : 2 )
        #expect( scorer.registerCollision( intensity : 10 ) != nil )
        #expect( scorer.pendingScore == 0 )
        #expect( scorer.registerCollision( intensity : 10 ) == nil )
    }

    @Test func leavingTheCourseLosesTheChain() {
        var scorer = DriftScorer()
        _ = run( &scorer, sliding( angle : 30 ), seconds : 1 )
        var context = DriftContext()
        context.isOffTrack = true
        _ = run( &scorer, sliding( angle : 30 ), seconds : 0.1, context : context )
        #expect( scorer.pendingScore == 0 )
    }

    @Test func outsideZonesDoNotScore() {
        var scorer = DriftScorer()
        var context = DriftContext()
        context.isInZone = false
        _ = run( &scorer, sliding( angle : 30 ), seconds : 2, context : context )
        #expect( scorer.pendingScore == 0 )
    }

    @Test func wallProximityAndTandemMultiplyPoints() {
        var open = DriftScorer()
        var close = DriftScorer()
        var context = DriftContext()
        context.wallDistance = 0.5
        context.tandemProximity = 1
        _ = run( &open, sliding( angle : 30 ), seconds : 1 )
        _ = run( &close, sliding( angle : 30 ), seconds : 1, context : context )
        #expect( close.pendingScore > open.pendingScore * 3 )
    }

    @Test func clippingPointAwardsBonusOnce() {
        var scorer = DriftScorer()
        var context = DriftContext()
        context.isClipping = true
        let events = run( &scorer, sliding( angle : 30 ), seconds : 0.5, context : context )
        let clips = events.filter { if case .clip = $0 { return true } else { return false } }
        #expect( clips.count == 1 )
    }
}

struct AIDriftTests {
    private func driftConfig( rivals : [DriverProfile] ) -> RaceConfig {
        let entrants = [ TestSupport.entrant( "hayase-kite-s", player : true ) ]
            + rivals.map { TestSupport.entrant( "veltra-aria", player : false, profile : $0 ) }
        var config = RaceConfig( title : "drift", trackID : "harbour-yard", kind : .drift( .scoreAttack, duration : 60 ), entrants : entrants )
        config.opponentSkill = 0.6
        return config
    }

    @Test func aiDriftsThroughCornersAndScores() {
        let config = driftConfig( rivals : [ Opponents.pool[ 2 ] ] )
        var solo = config
        solo.entrants = [ config.entrants[ 1 ] ]
        let session = RaceSession( config : solo )
        var longestSlide = 0.0

        while session.phase != .finished {
            session.step()
            longestSlide = max( longestSlide, session.drift.longestDrift )
        }

        #expect( session.cars[ 0 ].assists.tractionControl == false )
        #expect( longestSlide > 1.5 )
        #expect( session.drift.bankedScore > 500 )
    }

    @Test func driftEventsRunOnDriftTyres() {
        let drift = RaceSession( config : driftConfig( rivals : [] ) )
        #expect( drift.player.model.spec.tyre == .drift )

        var circuit = driftConfig( rivals : [] )
        circuit.kind = .circuit
        #expect( RaceSession( config : circuit ).player.model.spec.tyre == TestSupport.spec( "hayase-kite-s" ).tyre )
        #expect( RaceKind.tutorial( .drifting ).usesDriftTyres )
        #expect( !RaceKind.timeAttack.usesDriftTyres )
    }

    @Test func championshipDriftRoundsRunTheFieldOffscreen() {
        let context = RaceContext( championshipID : "ch-drift", discipline : .drift )
        let config = driftConfig( rivals : Array( Opponents.pool.prefix( 2 ) ) )

        #expect( OffscreenField.runsFieldOffscreen( config, context : context ) )
        #expect( !OffscreenField.runsFieldOffscreen( config, context : RaceContext( discipline : .drift ) ) )
        #expect( OffscreenField.onTrackConfig( for : config, context : context ).entrants.count == 1 )
        #expect( !OffscreenField.lowerIsBetter( config.kind ) )

        let scores = OffscreenField.scores( for : config )
        #expect( scores.map { $0.0 } == Opponents.pool.prefix( 2 ).map { $0.id } )
        #expect( scores.allSatisfy { $0.1 > 0 } )
        #expect( OffscreenField.scores( for : config ).map { $0.1 } == scores.map { $0.1 } )
    }
}
