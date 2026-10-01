import Foundation

/// An idealised run of a spec over a track: braking-limited corners plus power-limited acceleration.
nonisolated struct ReferenceRun {
    let totalTime : Double
    /// Speed (m/s) at each sample.
    let speeds : [Double]
    /// Elapsed time at each sample.
    let times : [Double]

    init( spec : VehicleSpec, track : TrackGeometry, surfaceGrip : Double, flyingLap : Bool ) {
        let grip = spec.tyreGrip * spec.tyre.lateralGrip * surfaceGrip
        let braking = min( spec.brakeDecelerationG, spec.tyreGrip * spec.tyre.longitudinalGrip * surfaceGrip ) * Units.gravity * 0.9
        let limits = track.speedProfile(
            grip : grip,
            brakingDeceleration : braking,
            topSpeed : 150,
            mass : spec.massKilograms,
            downforce : spec.downforceCoefficient
        )
        let power = spec.displayedPowerKilowatts * 1_000 * spec.drivelineEfficiency * 0.92
        let tractionLimit = spec.tyreGrip * spec.tyre.longitudinalGrip * surfaceGrip * Units.gravity * ( spec.drivetrain == .awd ? 1 : 0.7 )
        let count = track.sampleCount
        let startIndex = track.isClosed ? 0 : track.index( forDistance : track.startDistance )
        let endIndex = track.isClosed ? count : track.index( forDistance : track.finishDistance )
        var speed = flyingLap ? limits[ startIndex ] : 0
        var speeds = [Double]( repeating : 0, count : count )
        var times = [Double]( repeating : 0, count : count )
        var elapsed = 0.0
        let passes = track.isClosed && flyingLap ? 2 : 1

        for pass in 0 ..< passes {
            elapsed = 0

            for step in startIndex ..< endIndex {
                let index = step % count
                speeds[ index ] = speed
                times[ index ] = elapsed
                let drag = spec.dragCoefficient * speed * speed / spec.massKilograms
                let acceleration = max( min( power / ( spec.massKilograms * max( speed, 4 ) ), tractionLimit ) - drag, 0 )
                let next = min( ( speed * speed + 2 * acceleration * track.spacing ).squareRoot(), limits[ ( index + 1 ) % count ] )
                elapsed += track.spacing / max( ( speed + next ) / 2, 0.5 )
                speed = next
            }

            if pass == 0 && passes == 2 {
                speed = speeds[ ( endIndex - 1 ) % count ]
            }
        }

        totalTime = elapsed
        self.speeds = speeds
        self.times = times
    }
}

nonisolated struct EventTargetSet : Equatable {
    var medals : MedalTargets?
    var checkpointStart : Double = 0
    var checkpointBonus : Double = 0
}

/// Medal thresholds derived from physics, using a stock reference car at the event's recommended performance.
nonisolated enum EventTargets {
    /// Real drivers are slower than the ideal run; this is "expert" pace.
    static let expertFactor = 1.06

    static func referenceCar( forIndex index : Int, requirements : EventRequirements ) -> CarDefinition {
        let candidates = Cars.all.filter { car in
            ( requirements.drivetrain.map { car.drivetrain == $0 } ?? true )
                && ( requirements.categories.map { $0.contains( car.category ) } ?? true )
        }

        let pool = candidates.isEmpty ? Cars.all : candidates
        return pool.min {
            abs( PerformanceProfile.measure( $0.baseSpec ).index - index ) < abs( PerformanceProfile.measure( $1.baseSpec ).index - index )
        } ?? Cars.all[ 0 ]
    }

    static func targets(
        kind : RaceKind,
        trackID : TrackID,
        laps : Int,
        weather : Weather,
        recommendedIndex : Int,
        requirements : EventRequirements
    ) -> EventTargetSet {
        guard kind.isScored, let layout = Tracks.named( trackID ) else {
            return EventTargetSet()
        }

        let track = TrackGeometry( layout : layout )
        let spec = referenceCar( forIndex : recommendedIndex, requirements : requirements ).baseSpec
        let surfaceGrip = layout.surface.grip * weather.gripMultiplier

        switch kind {
        case .timeAttack:
            let lap = ReferenceRun( spec : spec, track : track, surfaceGrip : surfaceGrip, flyingLap : true ).totalTime * expertFactor
            return EventTargetSet( medals : MedalTargets( gold : lap * 1.02, silver : lap * 1.07, bronze : lap * 1.14, lowerIsBetter : true ) )
        case .checkpoint:
            let route = ReferenceRun( spec : spec, track : track, surfaceGrip : surfaceGrip, flyingLap : false ).totalTime * expertFactor
            let bonuses = Double( max( track.checkpoints.count - 1, 1 ) )
            let start = ( route * 0.45 ).rounded()
            let bonus = ( route * 0.8 / bonuses ).rounded()
            return EventTargetSet(
                medals : MedalTargets( gold : route * 0.14, silver : route * 0.07, bronze : 0.01, lowerIsBetter : false ),
                checkpointStart : start,
                checkpointBonus : bonus
            )
        case .speedTrap:
            let run = ReferenceRun( spec : spec, track : track, surfaceGrip : surfaceGrip, flyingLap : false )
            let session = RaceSession.previewTraps( track : track )
            let trapSpeeds = session.map { run.speeds[ track.index( forDistance : $0 ) ] * Units.metresPerSecondToKPH }
            var total = trapSpeeds.reduce( 0, + )

            if let first = session.first, let last = session.last, last > first {
                let span = run.times[ track.index( forDistance : last ) ] - run.times[ track.index( forDistance : first ) ]
                total += ( last - first ) / max( span, 0.1 ) * Units.metresPerSecondToKPH
            }

            return EventTargetSet( medals : MedalTargets( gold : total * 0.96, silver : total * 0.9, bronze : total * 0.83, lowerIsBetter : false ) )
        case .drift( let format, let duration ):
            let lapTime = ReferenceRun( spec : spec, track : track, surfaceGrip : surfaceGrip, flyingLap : false ).totalTime
            let seconds = format == .scoreAttack ? duration : lapTime * Double( max( laps, 1 ) ) * 1.45
            let formatScale : Double

            switch format {
            case .scoreAttack:
                formatScale = 1
            case .sections:
                formatScale = 0.6
            case .chain:
                formatScale = 0.4
            case .tandem:
                formatScale = 1.1
            }

            // Calibrated from play: a newcomer's best 60 s run is about 1,200; a strong run is 3,500+.
            let rate = seconds * formatScale
            return EventTargetSet( medals : MedalTargets( gold : rate * 60, silver : rate * 35, bronze : rate * 17, lowerIsBetter : false ) )
        default:
            return EventTargetSet()
        }
    }
}
