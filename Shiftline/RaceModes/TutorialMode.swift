import Foundation

nonisolated struct TutorialStep {
    let instruction : String
    let hint : String
    let isComplete : ( RaceSession ) -> Bool
}

/// Interactive lessons on real tracks: each step waits for the player to actually do the thing.
nonisolated final class TutorialMode : RaceMode {
    let kind : TutorialKind
    let totalLaps : Int
    private( set ) var steps : [TutorialStep] = []
    private( set ) var stepIndex = 0
    private var stepTimer = 0.0
    private var hasBeenFast = false

    init( kind : TutorialKind ) {
        self.kind = kind
        totalLaps = kind == .circuitRacing ? 2 : 1
        steps = makeSteps()
    }

    var currentStep : TutorialStep? {
        stepIndex < steps.count ? steps[ stepIndex ] : nil
    }

    var isLessonComplete : Bool {
        stepIndex >= steps.count
    }

    func update( _ session : RaceSession, timeStep : Double ) {
        stepTimer += timeStep

        if kind == .drifting {
            for event in session.drift.update( session.player.state, context : DriftContext(), timeStep : timeStep ) {
                session.events.append( .drift( event ) )
            }
        }

        guard let step = currentStep, stepTimer > 0.6, step.isComplete( session ) else {
            return
        }

        stepIndex += 1
        stepTimer = 0
        session.events.append( .message( stepIndex < steps.count ? "NICE!" : "LESSON COMPLETE" ) )
    }

    func isFinished( _ car : RaceCar, in session : RaceSession ) -> Bool {
        guard car.isPlayer else {
            return false
        }

        return isLessonComplete
    }

    func isComplete( _ session : RaceSession ) -> Bool {
        isLessonComplete
    }

    func trackLimitsBroken( by car : RaceCar, in session : RaceSession ) {}

    func hudItems( _ session : RaceSession ) -> [HUDItem] {
        [ HUDItem( label : "STEP", value : "\( min( stepIndex + 1, steps.count ) )/\( steps.count )" ) ]
    }

    private func makeSteps() -> [TutorialStep] {
        switch kind {
        case .basics:
            return [
                TutorialStep(
                    instruction : "Hold the accelerator on the right",
                    hint : "Reach 80 km/h.",
                    isComplete : { [weak self] session in
                        let isFast = session.player.state.speed * Units.metresPerSecondToKPH > 80
                        self?.hasBeenFast = self?.hasBeenFast == true || isFast
                        return isFast
                    }
                ),
                TutorialStep(
                    instruction : "Press BRAKE, beside the accelerator",
                    hint : "Come to a complete stop.",
                    isComplete : { session in session.player.state.speed < 1 }
                ),
                TutorialStep(
                    instruction : "Keep holding the brake to reverse",
                    hint : "Hold brake while stopped to engage reverse.",
                    isComplete : { session in session.player.state.gear == -1 && session.player.state.speed > 1 }
                ),
                TutorialStep(
                    instruction : "Accelerate away again",
                    hint : "Press the accelerator to select first gear and go.",
                    isComplete : { session in session.player.state.gear >= 1 && session.player.state.speed * Units.metresPerSecondToKPH > 50 }
                )
            ]
        case .steering:
            return [
                TutorialStep(
                    instruction : "Steer with LEFT and RIGHT",
                    hint : "Follow the road through the first corners.",
                    isComplete : { session in session.player.nextCheckpoint >= 1 }
                ),
                TutorialStep(
                    instruction : "Follow the racing line",
                    hint : "Green: accelerate. Yellow: lift. Red: brake.",
                    isComplete : { session in session.player.nextCheckpoint >= 2 }
                ),
                TutorialStep(
                    instruction : "Brake before corners, not in them",
                    hint : "Reach the finish of the route.",
                    isComplete : { session in session.player.raceDistance >= session.track.raceLength - 5 }
                )
            ]
        case .shifting:
            return [
                TutorialStep(
                    instruction : "Tap ▲ to shift up in the green zone",
                    hint : "Watch the rev bar. Get a GOOD or PERFECT shift.",
                    isComplete : { session in
                        let quality = session.player.state.lastShiftQuality
                        return quality == .perfect || quality == .good
                    }
                ),
                TutorialStep(
                    instruction : "Nail three perfect shifts",
                    hint : "Shifting early bogs the engine; hitting the limiter wastes time.",
                    isComplete : { session in session.player.perfectShifts >= 3 }
                ),
                TutorialStep(
                    instruction : "Tap ▼ to shift down before a corner",
                    hint : "Downshift under braking to keep the engine in its power band.",
                    isComplete : { session in session.player.pendingEvents.contains( .downshift ) || session.player.state.events.contains( .downshift ) }
                )
            ]
        case .drifting:
            return [
                TutorialStep(
                    instruction : "Build some speed",
                    hint : "Get above 60 km/h.",
                    isComplete : { session in session.player.state.speed * Units.metresPerSecondToKPH > 60 }
                ),
                TutorialStep(
                    instruction : "Steer in, pull the handbrake, then throttle",
                    hint : "Get the car sideways — over 20° of angle.",
                    isComplete : { session in session.player.state.driftAngleDegrees > 20 && session.player.state.speed > 8 }
                ),
                TutorialStep(
                    instruction : "Counter-steer and hold the slide",
                    hint : "Keep a drift going for two seconds.",
                    isComplete : { session in session.drift.isDrifting && session.drift.chainTime > 2 }
                ),
                TutorialStep(
                    instruction : "Flick into the next corner",
                    hint : "Switch direction mid-drift for a transition bonus.",
                    isComplete : { session in session.drift.transitions >= 1 }
                ),
                TutorialStep(
                    instruction : "Bank 3,000 points",
                    hint : "Longer, faster, higher-angle drifts score more.",
                    isComplete : { session in session.drift.bankedScore >= 3_000 }
                )
            ]
        case .circuitRacing:
            return [
                TutorialStep(
                    instruction : "Overtake the pace car",
                    hint : "Pull out of its slipstream and brake later into a corner.",
                    isComplete : { session in session.player.position == 1 }
                ),
                TutorialStep(
                    instruction : "Complete the lap cleanly",
                    hint : "Stay inside the white lines — cutting costs time.",
                    isComplete : { session in session.player.lapsCompleted >= 1 }
                ),
                TutorialStep(
                    instruction : "Finish in first place",
                    hint : "Hold your lead to the flag.",
                    isComplete : { session in session.player.lapsCompleted >= 2 && session.player.position == 1 }
                )
            ]
        case .dragLaunch, .tuning:
            return []
        }
    }
}
