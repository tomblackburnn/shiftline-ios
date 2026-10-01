import Foundation

/// Where a race came from, so its outcome can be credited to the right event, championship and car.
nonisolated struct RaceContext {
    var eventID : String?
    var championshipID : String?
    var tier : CareerTier?
    var discipline : Discipline
    var rivalID : String?
    var ownedCarID : UUID?
    var prize : Int?
    var tutorial : TutorialKind?

    static func discipline( for kind : RaceKind, trackID : TrackID ) -> Discipline {
        switch kind {
        case .drag:
            return .drag
        case .drift:
            return .drift
        default:
            switch Tracks.named( trackID )?.environment {
            case .serpentRidge?:
                return .mountain
            case .neonMeridian?, .oldTown?:
                return .street
            default:
                return Tracks.named( trackID )?.isClosed == true ? .circuit : .sprint
            }
        }
    }
}

nonisolated enum OutcomeBuilder {
    static func driverID( for car : RaceCar ) -> String {
        car.isPlayer ? "player" : ( car.entrant.profile?.id ?? car.name )
    }

    static func outcome( from session : RaceSession, context : RaceContext ) -> RaceOutcome {
        let config = session.config
        let player = session.player
        let standings = session.standings
        let score = session.mode.playerScore( session )
        var placement = player.position
        var didFinish = player.isFinished

        switch config.kind {
        case .elimination:
            didFinish = true
        case .tutorial:
            placement = 1
            didFinish = session.mode.isComplete( session )
        case .practice:
            placement = 1
            didFinish = true
        default:
            break
        }

        if config.kind.isScored {
            if let score, let targets = config.targets {
                placement = targets.placement( for : score )
            } else {
                placement = 4
                didFinish = score != nil
            }
        }

        let fastest = session.cars.compactMap { $0.bestLap }.min()

        return RaceOutcome(
            eventID : context.eventID,
            championshipID : context.championshipID,
            title : config.title,
            kind : config.kind,
            discipline : context.discipline,
            trackID : config.trackID,
            carID : player.entrant.carID,
            ownedCarID : context.ownedCarID,
            tier : context.tier,
            rivalID : context.rivalID,
            difficulty : config.difficulty,
            placement : placement,
            fieldSize : session.cars.count,
            didFinish : didFinish,
            score : score,
            time : player.totalTime,
            bestLap : player.bestLap,
            isFastestLap : player.bestLap != nil && player.bestLap == fastest,
            collisions : player.collisions,
            trackLimitCount : player.trackLimitCount,
            cleanOvertakes : player.cleanOvertakes,
            perfectShifts : player.perfectShifts,
            shifts : player.shifts,
            topSpeedKPH : player.topSpeed * Units.metresPerSecondToKPH,
            distance : player.state.distanceTravelled,
            driftScore : session.drift.bankedScore,
            driftBestChain : session.drift.bestChain,
            drag : nil,
            ghost : session.bestGhost,
            finishingOrder : standings.map { driverID( for : $0 ) }
        )
    }

    static func outcome(
        from race : DragRace,
        config : RaceConfig,
        context : RaceContext,
        fieldResults : [( id : String, result : DragRunResult )] = []
    ) -> RaceOutcome {
        let playerResult = race.player.result( greenTime : race.greenTime ?? 0 )
        let opponentID = race.opponent.entrant.profile?.id ?? race.opponent.name
        let opponentResult = race.opponent.result( greenTime : race.greenTime ?? 0 )

        // Order the whole field (heads-up opponent plus any off-screen passes) by total time; fouls last.
        var runs = [ ( "player", playerResult ), ( opponentID, opponentResult ) ] + fieldResults.map { ( $0.id, $0.result ) }
        runs.sort { lhs, rhs in
            if lhs.1.isFoul != rhs.1.isFoul {
                return !lhs.1.isFoul
            }

            return lhs.1.totalTime < rhs.1.totalTime
        }

        let order = runs.map { $0.0 }
        let placement = fieldResults.isEmpty ? ( race.playerWon ? 1 : 2 ) : ( order.firstIndex( of : "player" ) ?? 0 ) + 1

        return RaceOutcome(
            eventID : context.eventID,
            championshipID : context.championshipID,
            title : config.title,
            kind : .drag,
            discipline : .drag,
            trackID : config.trackID,
            carID : race.player.entrant.carID,
            ownedCarID : context.ownedCarID,
            tier : context.tier,
            rivalID : context.rivalID,
            difficulty : config.difficulty,
            placement : placement,
            fieldSize : max( runs.count, 2 ),
            didFinish : true,
            score : nil,
            time : playerResult.totalTime,
            bestLap : nil,
            collisions : 0,
            perfectShifts : playerResult.perfectShifts,
            shifts : playerResult.shifts,
            topSpeedKPH : race.player.state.speed * Units.metresPerSecondToKPH,
            distance : race.length,
            drag : playerResult,
            finishingOrder : order
        )
    }
}
