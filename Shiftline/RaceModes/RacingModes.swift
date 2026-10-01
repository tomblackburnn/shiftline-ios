import Foundation

/// Multi-lap race against the field. Endurance adds tyre wear.
nonisolated final class CircuitRaceMode : RaceMode {
    let totalLaps : Int
    let isEndurance : Bool

    init( laps : Int, isEndurance : Bool ) {
        totalLaps = max( laps, 1 )
        self.isEndurance = isEndurance
    }

    func prepare( _ session : RaceSession ) {
        session.tyreWearRate = isEndurance ? 1 : 0
    }

    func hudItems( _ session : RaceSession ) -> [HUDItem] {
        var items = [ positionItem( session ), lapItem( session ), lapTimeItem( session ), bestLapItem( session ) ]

        if isEndurance {
            let tyres = Int( ( 1 - session.player.state.tyreWear ) * 100 )
            items.append( HUDItem( label : "TYRES", value : "\( tyres )%", isWarning : tyres < 40 ) )
        }

        return items + penaltyItems( session )
    }
}

/// Point-to-point race: first to the finish. Also used for street, touge and rival duels.
nonisolated final class SprintRaceMode : RaceMode {
    let totalLaps = 1

    func trackLimitsBroken( by car : RaceCar, in session : RaceSession ) {}

    func hudItems( _ session : RaceSession ) -> [HUDItem] {
        [
            positionItem( session ),
            remainingItem( session ),
            HUDItem( label : "TIME", value : RaceFormat.time( session.elapsed ) )
        ]
    }
}

/// Last place is knocked out every time the leader completes a lap, until one car remains.
nonisolated final class EliminationMode : RaceMode {
    private( set ) var totalLaps = 1
    private var eliminationLaps = Set<Int>()

    func prepare( _ session : RaceSession ) {
        totalLaps = max( session.cars.count - 1, 1 )
    }

    func lapCompleted( by car : RaceCar, lapTime : Double, in session : RaceSession ) {
        guard !eliminationLaps.contains( car.lapsCompleted ) else {
            return
        }

        eliminationLaps.insert( car.lapsCompleted )
        let running = session.standings.filter { !$0.isEliminated }

        guard running.count > 1, let last = running.last else {
            return
        }

        session.eliminate( last )
        let remaining = session.cars.filter { !$0.isEliminated }

        if remaining.count == 1, let winner = remaining.first {
            winner.finishTime = session.elapsed

            if winner.isPlayer {
                session.events.append( .finished( position : 1 ) )
            }
        }
    }

    func isFinished( _ car : RaceCar, in session : RaceSession ) -> Bool {
        false
    }

    func isComplete( _ session : RaceSession ) -> Bool {
        session.player.isEliminated || session.cars.filter { !$0.isEliminated }.count <= 1
    }

    func hudItems( _ session : RaceSession ) -> [HUDItem] {
        let running = session.standings.filter { !$0.isEliminated }
        let isInDanger = running.last === session.player && running.count > 1
        return [
            positionItem( session ),
            lapItem( session ),
            lapTimeItem( session ),
            HUDItem( label : "OUT NEXT", value : isInDanger ? "YOU" : ( running.last?.name ?? "-" ), isWarning : isInDanger )
        ]
    }
}

/// Free drive: unlimited laps with timing, never finishes on its own.
nonisolated final class PracticeMode : RaceMode {
    let totalLaps = 999

    func trackLimitsBroken( by car : RaceCar, in session : RaceSession ) {
        car.isLapValid = false

        if car.isPlayer {
            session.events.append( .trackLimits( car : car.id, penalty : 0, invalidated : true ) )
        }
    }

    func isFinished( _ car : RaceCar, in session : RaceSession ) -> Bool {
        false
    }

    func isComplete( _ session : RaceSession ) -> Bool {
        false
    }

    func hudItems( _ session : RaceSession ) -> [HUDItem] {
        var items = [
            HUDItem( label : "LAP", value : "\( session.player.lapsCompleted + 1 )" ),
            lapTimeItem( session ),
            bestLapItem( session )
        ]

        if let last = session.player.lapTimes.last {
            items.append( HUDItem( label : "LAST", value : RaceFormat.time( last ) ) )
        }

        return items
    }
}
