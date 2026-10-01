import Foundation

/// Drift events: score attack, zoned sections, one-chain challenges and tandem runs behind a lead car.
nonisolated final class DriftRaceMode : RaceMode {
    let format : DriftFormat
    let duration : Double
    let totalLaps : Int

    init( format : DriftFormat, duration : Double, laps : Int ) {
        self.format = format
        self.duration = duration
        totalLaps = max( laps, 1 )
    }

    var leadCar : RaceCar?

    func prepare( _ session : RaceSession ) {
        // AI cars drift with traction and stability control off (counter-steer help stays), at speeds a slide can hold.
        let surfaceGrip = session.track.layout.surface.grip * session.config.weather.gripMultiplier

        for car in session.cars {
            guard let ai = car.ai else {
                continue
            }

            ai.drifts = true
            car.assists = .none
            car.assists.steeringAssist = true
            car.assists.antiLockBrakes = true
            car.speedProfile = AIDriver.speedProfile(
                for : car.model.spec,
                on : session.track,
                surfaceGrip : surfaceGrip * ( 0.44 + 0.22 * ai.skill ),
                skill : ai.skill,
                brakingLateness : 0.3
            )
        }

        leadCar = session.cars.first { $0 !== session.player }
    }

    func update( _ session : RaceSession, timeStep : Double ) {
        let player = session.player
        let track = session.track
        let halfCarWidth = player.model.spec.width / 2
        var context = DriftContext()

        if format == .sections {
            context.isInZone = session.driftZones.contains { $0.contains( player.trackDistance ) }
        }

        context.wallDistance = track.barrierOffset - abs( player.lateral ) - halfCarWidth
        context.isOffTrack = abs( player.lateral ) > track.halfWidth + 1.5
        context.isClipping = session.clippingPoints.contains { point in
            abs( point.distance - player.trackDistance ) < 6 && abs( point.lateral - player.lateral ) < 2.4
        }

        if format == .tandem, let lead = leadCar {
            let gap = lead.raceDistance - player.raceDistance

            // A tandem lead waits for a chaser who drops back; it never goes faster than it can hold a slide.
            lead.ai?.paceScale = clamp( 1 - ( gap - 8 ) * 0.03, 0.6, 1 )

            if gap > 2 && gap < 18 {
                context.tandemProximity = clamp( 1 - abs( gap - 8 ) / 10, 0, 1 )
            }
        }

        for event in session.drift.update( player.state, context : context, timeStep : timeStep ) {
            session.events.append( .drift( event ) )
        }
    }

    func isFinished( _ car : RaceCar, in session : RaceSession ) -> Bool {
        guard car === session.player else {
            return false
        }

        if format == .scoreAttack {
            return session.elapsed >= duration
        }

        return session.track.isClosed
            ? car.lapsCompleted >= totalLaps
            : car.raceDistance >= session.track.raceLength
    }

    func trackLimitsBroken( by car : RaceCar, in session : RaceSession ) {}

    func playerScore( _ session : RaceSession ) -> Double? {
        Double( format == .chain ? session.drift.bestChain : session.drift.bankedScore )
    }

    func hudItems( _ session : RaceSession ) -> [HUDItem] {
        var items : [HUDItem] = []

        if format == .scoreAttack {
            let remaining = max( duration - session.elapsed, 0 )
            items.append( HUDItem( label : "TIME", value : String( format : "%.1f", remaining ), isWarning : remaining < 10 ) )
        } else if session.track.isClosed {
            items.append( lapItem( session ) )
        } else {
            items.append( remainingItem( session ) )
        }

        if format == .chain {
            items.append( HUDItem( label : "BEST CHAIN", value : RaceFormat.points( session.drift.bestChain ) ) )
        }

        if format == .tandem, let lead = leadCar {
            let gap = lead.raceDistance - session.player.raceDistance
            items.append( HUDItem( label : "GAP", value : String( format : "%.0f m", gap ), isWarning : gap > 18 ) )
        }

        return items
    }
}
