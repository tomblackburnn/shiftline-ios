import Foundation

nonisolated enum DriftEvent : Equatable {
    case started
    case transition( bonus : Int )
    case clip( bonus : Int )
    case banked( points : Int, multiplier : Double )
    case failed( reason : String )
    case multiplierUp( Double )
}

/// Everything the scorer needs to know about the car's surroundings this step.
nonisolated struct DriftContext {
    var isInZone = true
    /// Distance from the car's side to the nearest barrier, in metres.
    var wallDistance = Double.infinity
    var isOffTrack = false
    /// 0...1 bonus for tailing a lead car (tandem).
    var tandemProximity = 0.0
    /// True when the car is within a metre of an apex clipping point.
    var isClipping = false
}

/// Scores drifts: angle × speed × time × combo, with proximity, clipping and transition bonuses.
nonisolated struct DriftScorer {
    static let minimumAngle = 12.0
    static let maximumAngle = 110.0
    static let minimumSpeed = 8.0
    static let graceTime = 1.1
    static let maximumMultiplier = 6.0

    var bankedScore = 0
    /// Unbanked points in the current drift chain.
    var pendingScore = 0.0
    var multiplier = 1.0
    var chainTime = 0.0
    var graceRemaining = 0.0
    var isDrifting = false
    var lastDirection = 0.0
    var bestChain = 0
    var longestDrift = 0.0
    var transitions = 0
    var clippedRecently = false
    var sustainedTime = 0.0
    /// When true a chain is only banked at the end of the event (drift chain format).
    var bankOnlyAtEnd = false

    var displayScore : Int {
        bankedScore + Int( pendingScore * multiplier )
    }

    mutating func update(
        _ state : VehicleState,
        context : DriftContext,
        timeStep : Double
    ) -> [DriftEvent] {
        var events : [DriftEvent] = []
        let angle = state.driftAngleDegrees
        let direction : Double = state.slipAngle >= 0 ? 1 : -1
        let isSliding = angle >= DriftScorer.minimumAngle
            && angle <= DriftScorer.maximumAngle
            && state.speed >= DriftScorer.minimumSpeed
            && state.forwardSpeed > 0

        if angle > DriftScorer.maximumAngle && state.speed > 4 && pendingScore > 0 {
            events.append( fail( reason : "SPUN OUT" ) )
            return events
        }

        if context.isOffTrack {
            if pendingScore > 0 {
                events.append( fail( reason : "OFF TRACK" ) )
            }

            return events
        }

        guard isSliding && context.isInZone else {
            if isDrifting {
                isDrifting = false
                graceRemaining = DriftScorer.graceTime
            }

            if graceRemaining > 0 {
                graceRemaining -= timeStep

                if graceRemaining <= 0 && !bankOnlyAtEnd {
                    if let banked = bank() {
                        events.append( banked )
                    }
                }
            }

            sustainedTime = 0
            return events
        }

        if !isDrifting {
            if graceRemaining > 0 && lastDirection != 0 && direction != lastDirection {
                transitions += 1
                let bonus = Int( 250 * multiplier )
                pendingScore += Double( bonus ) / multiplier
                events.append( .transition( bonus : bonus ) )
                events.append( contentsOf : raiseMultiplier( by : 0.5 ) )
            } else if graceRemaining <= 0 {
                events.append( .started )
            }

            isDrifting = true
            graceRemaining = 0
        }

        lastDirection = direction
        chainTime += timeStep
        sustainedTime += timeStep
        longestDrift = max( longestDrift, sustainedTime )

        // Core formula: angle × speed per second, with proximity multipliers.
        let clampedAngle = min( angle, 70 )
        var points = clampedAngle * state.speed * 0.12 * timeStep

        if context.wallDistance < 3 {
            points *= 1 + ( 3 - max( context.wallDistance, 0 ) ) / 3
        }

        points *= 1 + context.tandemProximity
        pendingScore += points

        if sustainedTime >= 2.5 {
            sustainedTime = 0
            events.append( contentsOf : raiseMultiplier( by : 0.5 ) )
        }

        if context.isClipping && !clippedRecently {
            clippedRecently = true
            let bonus = Int( 400 * multiplier )
            pendingScore += Double( bonus ) / multiplier
            events.append( .clip( bonus : bonus ) )
        } else if !context.isClipping {
            clippedRecently = false
        }

        return events
    }

    /// Heavy impact: the current chain is lost.
    mutating func registerCollision( intensity : Double ) -> DriftEvent? {
        guard intensity > 4 && ( pendingScore > 0 || isDrifting ) else {
            return nil
        }

        return fail( reason : "CRASHED" )
    }

    /// Banks whatever is pending, e.g. when the event ends.
    mutating func finish() -> DriftEvent? {
        bank()
    }

    private mutating func bank() -> DriftEvent? {
        guard pendingScore > 0 else {
            reset()
            return nil
        }

        let points = Int( pendingScore * multiplier )
        let banked = DriftEvent.banked( points : points, multiplier : multiplier )
        bankedScore += points
        bestChain = max( bestChain, points )
        reset()
        return banked
    }

    private mutating func fail( reason : String ) -> DriftEvent {
        reset()
        return .failed( reason : reason )
    }

    private mutating func reset() {
        pendingScore = 0
        multiplier = 1
        chainTime = 0
        graceRemaining = 0
        isDrifting = false
        lastDirection = 0
        sustainedTime = 0
    }

    private mutating func raiseMultiplier( by amount : Double ) -> [DriftEvent] {
        let raised = min( multiplier + amount, DriftScorer.maximumMultiplier )

        guard raised > multiplier else {
            return []
        }

        multiplier = raised
        return [ .multiplierUp( raised ) ]
    }
}
