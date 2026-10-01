import Foundation

nonisolated struct HUDItem : Identifiable, Equatable {
    let label : String
    let value : String
    var isEmphasised = false
    var isWarning = false

    var id : String {
        label
    }
}

/// Rules layered on top of the shared RaceSession simulation.
nonisolated protocol RaceMode : AnyObject {
    var totalLaps : Int { get }

    func prepare( _ session : RaceSession )
    func update( _ session : RaceSession, timeStep : Double )
    func lapCompleted( by car : RaceCar, lapTime : Double, in session : RaceSession )
    func checkpointPassed( by car : RaceCar, index : Int, in session : RaceSession )
    func trackLimitsBroken( by car : RaceCar, in session : RaceSession )
    func isFinished( _ car : RaceCar, in session : RaceSession ) -> Bool
    func isComplete( _ session : RaceSession ) -> Bool
    func hudItems( _ session : RaceSession ) -> [HUDItem]
    /// Player's score for medal-scored modes (drift points, trap total, time left, best lap).
    func playerScore( _ session : RaceSession ) -> Double?
}

nonisolated extension RaceMode {
    func prepare( _ session : RaceSession ) {}

    func update( _ session : RaceSession, timeStep : Double ) {}

    func lapCompleted( by car : RaceCar, lapTime : Double, in session : RaceSession ) {}

    func checkpointPassed( by car : RaceCar, index : Int, in session : RaceSession ) {}

    /// Default circuit rule: a one-second penalty per cut.
    func trackLimitsBroken( by car : RaceCar, in session : RaceSession ) {
        car.penaltySeconds += 1
        session.events.append( .trackLimits( car : car.id, penalty : 1, invalidated : false ) )
    }

    func isFinished( _ car : RaceCar, in session : RaceSession ) -> Bool {
        session.track.isClosed
            ? car.lapsCompleted >= totalLaps
            : car.raceDistance >= session.track.raceLength
    }

    func isComplete( _ session : RaceSession ) -> Bool {
        session.player.isFinished || session.player.isEliminated
    }

    func playerScore( _ session : RaceSession ) -> Double? {
        nil
    }

    /// Distance a car must cover to finish.
    func raceDistance( _ session : RaceSession ) -> Double {
        session.track.isClosed
            ? Double( totalLaps ) * session.track.length
            : session.track.raceLength
    }

    // MARK: - Shared HUD pieces

    func positionItem( _ session : RaceSession ) -> HUDItem {
        let active = session.cars.filter { !$0.isEliminated }.count
        return HUDItem( label : "POS", value : "\( session.player.position )/\( active )", isEmphasised : true )
    }

    func lapItem( _ session : RaceSession ) -> HUDItem {
        let lap = min( session.player.lapsCompleted + 1, totalLaps )
        return HUDItem( label : "LAP", value : "\( lap )/\( totalLaps )" )
    }

    func lapTimeItem( _ session : RaceSession ) -> HUDItem {
        let current = session.phase == .racing ? session.elapsed - session.player.lapStartTime : 0
        return HUDItem( label : "TIME", value : RaceFormat.time( current ) )
    }

    func bestLapItem( _ session : RaceSession ) -> HUDItem {
        HUDItem( label : "BEST", value : session.player.bestLap.map { RaceFormat.time( $0 ) } ?? "--:--.---" )
    }

    func remainingItem( _ session : RaceSession ) -> HUDItem {
        let remaining = max( raceDistance( session ) - session.player.raceDistance, 0 )
        return HUDItem( label : "TO GO", value : RaceFormat.distance( remaining ) )
    }

    func penaltyItems( _ session : RaceSession ) -> [HUDItem] {
        session.player.penaltySeconds > 0
            ? [ HUDItem( label : "PEN", value : "+\( Int( session.player.penaltySeconds ) )s", isWarning : true ) ]
            : []
    }
}

nonisolated enum RaceFormat {
    static func time( _ seconds : Double ) -> String {
        guard seconds.isFinite else {
            return "--:--.---"
        }

        let clamped = max( seconds, 0 )
        let minutes = Int( clamped / 60 )
        let remainder = clamped - Double( minutes * 60 )
        return String( format : "%d:%06.3f", minutes, remainder )
    }

    static func shortTime( _ seconds : Double ) -> String {
        String( format : "%.3f", seconds )
    }

    static func delta( _ seconds : Double ) -> String {
        String( format : "%@%.3f", seconds >= 0 ? "+" : "−", abs( seconds ) )
    }

    static func distance( _ metres : Double ) -> String {
        metres >= 1_000 ? String( format : "%.2f km", metres / 1_000 ) : "\( Int( metres ) ) m"
    }

    static func points( _ value : Int ) -> String {
        value.formatted( .number )
    }
}

nonisolated enum RaceModes {
    static func make( for config : RaceConfig ) -> RaceMode {
        switch config.kind {
        case .circuit:
            return CircuitRaceMode( laps : config.laps, isEndurance : false )
        case .endurance:
            return CircuitRaceMode( laps : config.laps, isEndurance : true )
        case .sprint:
            return SprintRaceMode()
        case .elimination:
            return EliminationMode()
        case .checkpoint( let startTime, let bonus ):
            return CheckpointMode( startTime : startTime, bonusPerCheckpoint : bonus )
        case .speedTrap:
            return SpeedTrapMode()
        case .timeAttack:
            return TimeAttackMode( laps : config.laps )
        case .drift( let format, let duration ):
            return DriftRaceMode( format : format, duration : duration, laps : config.laps )
        case .practice, .drag:
            return PracticeMode()
        case .tutorial( let kind ):
            return TutorialMode( kind : kind )
        }
    }
}
