import Foundation

/// Beat the countdown to the finish; each checkpoint adds time. Score = time left.
nonisolated final class CheckpointMode : RaceMode {
    let totalLaps = 1
    let bonusPerCheckpoint : Double
    private( set ) var timeRemaining : Double
    private( set ) var didRunOut = false

    init( startTime : Double, bonusPerCheckpoint : Double ) {
        timeRemaining = startTime
        self.bonusPerCheckpoint = bonusPerCheckpoint
    }

    func update( _ session : RaceSession, timeStep : Double ) {
        guard !session.player.isFinished else {
            return
        }

        timeRemaining -= timeStep

        if timeRemaining <= 0 {
            timeRemaining = 0
            didRunOut = true
            session.events.append( .timeUp )
        }
    }

    func checkpointPassed( by car : RaceCar, index : Int, in session : RaceSession ) {
        guard car.isPlayer && index < session.track.checkpoints.count - 1 else {
            return
        }

        timeRemaining += bonusPerCheckpoint
        session.events.append( .checkpoint( index : index, bonus : bonusPerCheckpoint ) )
    }

    func trackLimitsBroken( by car : RaceCar, in session : RaceSession ) {}

    func isComplete( _ session : RaceSession ) -> Bool {
        session.player.isFinished || didRunOut
    }

    func playerScore( _ session : RaceSession ) -> Double? {
        session.player.isFinished ? timeRemaining : nil
    }

    func hudItems( _ session : RaceSession ) -> [HUDItem] {
        let passed = min( session.player.nextCheckpoint, session.track.checkpoints.count )
        return [
            HUDItem( label : "TIME LEFT", value : String( format : "%.1f", timeRemaining ), isEmphasised : true, isWarning : timeRemaining < 5 ),
            HUDItem( label : "CHECKPOINT", value : "\( passed )/\( session.track.checkpoints.count )" ),
            remainingItem( session )
        ]
    }
}

/// Hit every speed trap as fast as possible, plus an average-speed zone between the first and last trap.
nonisolated final class SpeedTrapMode : RaceMode {
    let totalLaps = 1
    private( set ) var trapSpeeds : [Double] = []
    private( set ) var zoneAverageSpeed : Double?
    private var zoneStartTime : Double?
    private var trapRaceDistances : [Double] = []

    func prepare( _ session : RaceSession ) {
        let origin = session.track.isClosed ? 0 : session.track.startDistance
        trapRaceDistances = session.speedTraps.map { $0 - origin }
    }

    func update( _ session : RaceSession, timeStep : Double ) {
        let player = session.player
        let nextIndex = trapSpeeds.count

        guard nextIndex < trapRaceDistances.count, player.raceDistance >= trapRaceDistances[ nextIndex ] else {
            return
        }

        let speed = player.state.speed * Units.metresPerSecondToKPH
        trapSpeeds.append( speed )
        player.speedTrapSpeeds.append( speed )
        session.events.append( .speedTrap( index : nextIndex, speedKPH : speed ) )

        if nextIndex == 0 {
            zoneStartTime = session.elapsed
        } else if nextIndex == trapRaceDistances.count - 1, let start = zoneStartTime {
            let distance = trapRaceDistances[ nextIndex ] - trapRaceDistances[ 0 ]
            zoneAverageSpeed = distance / max( session.elapsed - start, 0.01 ) * Units.metresPerSecondToKPH
        }
    }

    func trackLimitsBroken( by car : RaceCar, in session : RaceSession ) {}

    var totalScore : Double {
        trapSpeeds.reduce( 0, + ) + ( zoneAverageSpeed ?? 0 )
    }

    func playerScore( _ session : RaceSession ) -> Double? {
        session.player.isFinished ? totalScore : nil
    }

    func hudItems( _ session : RaceSession ) -> [HUDItem] {
        var items = [
            HUDItem( label : "TRAPS", value : "\( trapSpeeds.count )/\( trapRaceDistances.count )" ),
            HUDItem( label : "TOTAL", value : "\( Int( totalScore ) ) km/h", isEmphasised : true ),
            remainingItem( session )
        ]

        if let last = trapSpeeds.last {
            items.insert( HUDItem( label : "LAST", value : "\( Int( last ) ) km/h" ), at : 1 )
        }

        return items
    }
}

/// Solo laps against the clock and a ghost. Cutting the track invalidates the lap. Score = best valid lap.
nonisolated final class TimeAttackMode : RaceMode {
    let totalLaps : Int

    init( laps : Int ) {
        totalLaps = max( laps, 1 )
    }

    func trackLimitsBroken( by car : RaceCar, in session : RaceSession ) {
        guard car.isLapValid else {
            return
        }

        car.isLapValid = false

        if car.isPlayer {
            session.events.append( .trackLimits( car : car.id, penalty : 0, invalidated : true ) )
        }
    }

    func playerScore( _ session : RaceSession ) -> Double? {
        session.player.bestLap
    }

    /// Sum of best sectors: the lap you could do if everything came together.
    func theoreticalBest( _ session : RaceSession ) -> Double? {
        let sectors = session.player.bestSectors

        guard sectors.count == session.track.checkpoints.count else {
            return nil
        }

        return sectors.reduce( 0, + )
    }

    func hudItems( _ session : RaceSession ) -> [HUDItem] {
        var items = [ lapItem( session ), lapTimeItem( session ), bestLapItem( session ) ]

        if let ghost = session.config.ghost {
            items.append( HUDItem( label : "GHOST", value : RaceFormat.time( ghost.lapTime ) ) )
        }

        if let theoretical = theoreticalBest( session ) {
            items.append( HUDItem( label : "IDEAL", value : RaceFormat.time( theoretical ) ) )
        }

        if !session.player.isLapValid {
            items.append( HUDItem( label : "LAP", value : "INVALID", isWarning : true ) )
        }

        return items
    }
}
