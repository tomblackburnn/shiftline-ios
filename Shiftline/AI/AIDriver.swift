import Foundation

/// Drives a RaceCar through the same physics as the player: racing line, braking points,
/// overtaking offsets, defending, recovery and skill-dependent shifting. No teleporting, no extra power.
nonisolated final class AIDriver {
    let profile : DriverProfile
    /// Effective skill 0...1 after event and difficulty offsets.
    let skill : Double
    /// Gentle pace scaling (tandem lead cars, mild adaptive difficulty). Kept within ±3% for racing.
    var paceScale = 1.0
    /// Drift events: slide through corners instead of taking the grip line.
    var drifts = false

    private var laneOffset = 0.0
    private var reverseTimeRemaining = 0.0
    private var stuckTime = 0.0
    private var mistakeRemaining = 0.0
    private var mistakeScale = 1.0
    private var lastTargetSpeed = 0.0
    private var initiationRemaining = 0.0
    private var lastSlip = 0.0
    private var initiationCooldown = 0.0
    private var generator : SeededGenerator
    private let shiftPoint : Double

    init( profile : DriverProfile, skill : Double, seed : String ) {
        self.profile = profile
        self.skill = clamp( skill, 0, 1 )
        generator = SeededGenerator( text : seed + profile.id )
        shiftPoint = 0.9 + 0.09 * clamp( skill, 0, 1 )
    }

    /// Target speeds for this driver: grip used scales with skill, braking with lateness.
    static func speedProfile(
        for spec : VehicleSpec,
        on track : TrackGeometry,
        surfaceGrip : Double,
        skill : Double,
        brakingLateness : Double
    ) -> [Double] {
        let grip = spec.tyreGrip * spec.tyre.lateralGrip * surfaceGrip * ( 0.76 + 0.16 * skill )
        let braking = min( spec.brakeDecelerationG, spec.tyreGrip * spec.tyre.longitudinalGrip * surfaceGrip )
            * Units.gravity * ( 0.72 + 0.14 * brakingLateness + 0.08 * skill )

        return track.speedProfile(
            grip : grip,
            brakingDeceleration : braking,
            topSpeed : 130,
            mass : spec.massKilograms,
            downforce : spec.downforceCoefficient
        )
    }

    func control( _ car : RaceCar, in session : RaceSession, timeStep : Double ) -> VehicleInput {
        let track = session.track
        let state = car.state
        let speed = state.speed
        var input = VehicleInput()

        // Recovery: reverse away from a wall, steering the nose back towards the road.
        if reverseTimeRemaining > 0 {
            reverseTimeRemaining -= timeStep
            input.brake = 1
            input.steering = car.lateral > 0 ? -1 : 1
            return input
        }

        if speed < 1.5 && car.input.throttle > 0.5 && session.phase == .racing {
            stuckTime += timeStep

            if stuckTime > 1.4 {
                stuckTime = 0
                reverseTimeRemaining = 1.5
            }
        } else {
            stuckTime = 0
        }

        // Slow or off the road: drive normally so recovery works, then pick the slide back up.
        let isFacingDownTheRoad = track.tangent( atDistance : car.trackDistance ).dot( state.velocity.normalized ) > 0.3

        if drifts && speed > 6 && abs( car.lateral ) < track.halfWidth && isFacingDownTheRoad {
            return driftInput( car, in : session, timeStep : timeStep )
        }

        // Steering: pure pursuit towards the racing line plus any overtaking offset.
        let lookahead = 5 + speed * 0.3
        let aheadDistance = car.trackDistance + lookahead
        let limit = track.halfWidth - 1.3
        laneOffset = approach( laneOffset, desiredLaneOffset( for : car, in : session, lookahead : lookahead ), 2.8 * timeStep )
        let targetLateral = clamp( track.racingOffset( atDistance : aheadDistance ) + laneOffset, -limit, limit )
        let target = track.point( atDistance : aheadDistance, lateral : targetLateral )
        let toTarget = target - state.position
        let bearing = wrapAngle( toTarget.angle - state.heading )
        let wheelAngle = atan( 2 * car.model.spec.wheelbase * sin( bearing ) / max( toTarget.length, 1 ) )
        let speedSensitivity = max( 1 / ( 1 + speed / 26 ), 0.26 )
        let availableLock = car.model.spec.steeringLock * car.model.spec.steeringSensitivity * speedSensitivity
        input.steering = clamp( wheelAngle / max( availableLock, 0.01 ), -1, 1 )

        // Speed: follow the braking-aware profile a quarter second ahead.
        let profileIndex = track.index( forDistance : car.trackDistance + speed * 0.25 )
        var targetSpeed = car.speedProfile.isEmpty ? 30 : car.speedProfile[ profileIndex ]
        targetSpeed *= paceScale * mistakeFactor( targetSpeed : targetSpeed, timeStep : timeStep )
        targetSpeed = min( targetSpeed, trafficLimitedSpeed( for : car, in : session ) )

        // Facing the wrong way or far off the road: slow down and turn around.
        if track.tangent( atDistance : car.trackDistance ).dot( state.forward ) < 0 {
            targetSpeed = min( targetSpeed, 8 )
        }

        if abs( car.lateral ) > track.halfWidth + 1 {
            targetSpeed = min( targetSpeed, max( speed * 0.9, 12 ) )
        }

        if speed > targetSpeed + 0.8 {
            input.brake = clamp( ( speed - targetSpeed ) / 5, 0.25, 1 )
        } else if speed > targetSpeed - 1.5 {
            input.throttle = 0.45
        } else {
            input.throttle = 1
        }

        // Catch slides: lift off the throttle when the rear steps out.
        let slide = abs( state.slipAngle )

        if slide > 0.1 && speed > 8 {
            input.throttle *= clamp( 1 - ( slide - 0.1 ) * 5, 0.15, 1 )
        }

        lastTargetSpeed = targetSpeed
        return input
    }

    /// Manual shifting with skill-dependent precision (good drivers hit perfect shifts).
    func shifting( _ state : VehicleState, model : VehicleModel ) -> VehicleState {
        guard state.gear >= 1 && state.shiftTimeRemaining <= 0 else {
            return state
        }

        if state.gear < model.spec.gearCount
            && state.engineRPM >= model.idealUpshiftRPM( fromGear : state.gear ) * shiftPoint
            && state.throttle > 0.3 {
            return model.shiftingUp( state )
        }

        guard state.gear > 1 else {
            return state
        }

        let rpmInLowerGear = model.spec.wheelRPM( forSpeed : state.forwardSpeed, gear : state.gear - 1 )
        let isBoggedDown = state.engineRPM < model.spec.peakTorqueRPM * 0.75

        if rpmInLowerGear < model.spec.redlineRPM * 0.82 && ( state.brake > 0.2 || isBoggedDown ) {
            return model.shiftingDown( state )
        }

        return state
    }

    // MARK: - Drifting

    /// Front wheels aim down the road (counter-steer falls out of that); the throttle holds the angle.
    private func driftInput( _ car : RaceCar, in session : RaceSession, timeStep : Double ) -> VehicleInput {
        let track = session.track
        let state = car.state
        let spec = car.model.spec
        let speed = state.speed
        var input = VehicleInput()

        let lookahead = 7 + speed * 0.4
        let limit = track.halfWidth - 1.6
        let targetLateral = clamp( track.racingOffset( atDistance : car.trackDistance + lookahead ) * 0.5, -limit, limit )
        let target = track.point( atDistance : car.trackDistance + lookahead, lateral : targetLateral )
        let travel = speed > 3 ? state.velocity.angle : state.heading
        let courseError = wrapAngle( ( target - state.position ).angle - travel )
        let wheelAngle = wrapAngle( travel + courseError * 1.5 - state.heading )
        let speedSensitivity = max( 1 / ( 1 + speed / 26 ), 0.26 )
        let availableLock = spec.steeringLock * spec.steeringSensitivity * speedSensitivity
        input.steering = clamp( wheelAngle / max( availableLock, 0.01 ), -1, 1 )

        // Corner ahead: the sharpest bend in the next stretch sets which way the tail should hang out.
        // Once sliding, look further ahead so short straights are linked into one chain.
        let isSliding = abs( state.slipAngle ) > 0.15 || initiationCooldown > 0.2
        let reach = isSliding ? 1.2 + 0.8 * skill : 0.8
        let bend = stride( from : 0.0, through : 1, by : 0.25 )
            .map { track.curvature( atDistance : car.trackDistance + 4 + speed * reach * $0 ) }
            .max { abs( $0 ) < abs( $1 ) } ?? 0
        let isCorner = abs( bend ) > ( isSliding ? 1 / 220 : 1 / 110 )
        let turn : Double = bend >= 0 ? 1 : -1
        let targetAngle = isCorner ? 0.3 + 0.16 * skill : 0
        let slip = -state.slipAngle * turn
        let slipRate = clamp( ( slip - lastSlip ) / timeStep, -3, 3 )
        lastSlip = slip
        let profileIndex = track.index( forDistance : car.trackDistance + speed * 0.4 )
        let gripSpeed = car.speedProfile.isEmpty ? 20 : car.speedProfile[ profileIndex ]
        let targetSpeed = gripSpeed * paceScale

        // Spinning: lift and let the counter-steer catch it.
        if abs( state.slipAngle ) > 1.15 {
            initiationRemaining = 0
            input.brake = speed > 6 ? 0.3 : 0
            return input
        }

        initiationCooldown -= timeStep

        if initiationRemaining > 0 {
            initiationRemaining -= timeStep
            input.handbrake = true
            input.steering = turn * 0.7
            input.throttle = 0.6
            return input
        }

        if isSliding {
            // Hold the angle on the throttle; lift to straighten out of the corner.
            // Tail out the wrong way for this corner: lift so the car swings through (a transition).
            if !isCorner {
                input.throttle = clamp( 0.25 - slipRate * 0.3, 0, 0.6 )
            } else if slip < -0.1 {
                input.throttle = 0.1
            } else {
                input.throttle = clamp( 0.6 + ( targetAngle - slip ) * 2.5 - slipRate * 0.5, 0, 1 )
            }

            if speed > targetSpeed + 5 {
                input.throttle = min( input.throttle, 0.2 )
            }
        } else if isCorner && speed > 9 && speed < targetSpeed + 5 && initiationCooldown <= 0 {
            initiationRemaining = 0.22 + 0.08 * ( 1 - skill )
            initiationCooldown = 1.2
        } else if speed > targetSpeed + 1.5 {
            input.brake = clamp( ( speed - targetSpeed ) / 6, 0.2, 0.8 )
        } else {
            input.throttle = speed < targetSpeed ? 1 : 0.35
        }

        return input
    }

    // MARK: - Racecraft

    private func desiredLaneOffset( for car : RaceCar, in session : RaceSession, lookahead : Double ) -> Double {
        let track = session.track
        let myLine = track.racingOffset( atDistance : car.trackDistance + lookahead )
        let attackRange = 16 + 22 * profile.aggression
        var offset = 0.0

        for other in session.cars where other !== car && other.isActive {
            let gap = other.raceDistance - car.raceDistance
            let lateralGap = other.lateral - car.lateral

            // Attack: pull out of the slipstream towards the side with more room.
            if gap > 0 && gap < attackRange && abs( lateralGap ) < 2.8 && car.state.speed > other.state.speed - 1.5 {
                let roomLeft = track.halfWidth - other.lateral
                let roomRight = other.lateral + track.halfWidth
                let side : Double = roomLeft > roomRight ? 1 : -1
                let passingLateral = other.lateral + side * 3.1
                offset = passingLateral - myLine
            }

            // Defend: on straights, cover the inside when someone is close behind.
            let isStraight = abs( track.curvature( atDistance : car.trackDistance ) ) < 1 / 300
            if gap < 0 && gap > -15 && profile.defensiveness > 0.6 && isStraight && abs( lateralGap ) < 5 {
                offset = clamp( ( other.lateral - car.lateral ) * 0.5, -2, 2 )
            }

            // Side by side: give each other room.
            if abs( gap ) < 5 && abs( lateralGap ) < 2.4 {
                offset += lateralGap > 0 ? -1.6 : 1.6
            }
        }

        return offset
    }

    /// Lifts when boxed in behind a slower car with no room to pass.
    private func trafficLimitedSpeed( for car : RaceCar, in session : RaceSession ) -> Double {
        var limit = Double.infinity

        for other in session.cars where other !== car && other.isActive {
            let gap = other.raceDistance - car.raceDistance
            let lateralGap = abs( other.lateral - car.lateral )

            if gap > 0 && gap < 7 + car.state.speed * 0.15 && lateralGap < 1.9 {
                let cautious = profile.aggression < 0.6 ? 1.0 : 2.5
                limit = min( limit, other.state.speed + cautious )
            }
        }

        return limit
    }

    /// Occasional braking misjudgements for inconsistent drivers: a corner taken a little too fast.
    private func mistakeFactor( targetSpeed : Double, timeStep : Double ) -> Double {
        if mistakeRemaining > 0 {
            mistakeRemaining -= timeStep
            return mistakeScale
        }

        let isCornerApproach = lastTargetSpeed - targetSpeed > 0.5

        if isCornerApproach && generator.unit() < ( 1 - profile.consistency ) * 0.02 * ( 1.2 - skill ) {
            mistakeRemaining = 2.5
            mistakeScale = 1.04 + 0.05 * generator.unit()
            return mistakeScale
        }

        return 1
    }
}
