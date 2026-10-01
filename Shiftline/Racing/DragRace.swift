import Foundation

nonisolated enum LaunchRating : String, Codable {
    case perfect
    case good
    case ok
    case bogged
    case wheelspin

    var title : String {
        switch self {
        case .ok:
            return "OK"
        default:
            return rawValue.uppercased()
        }
    }

    var isClean : Bool {
        self == .perfect || self == .good
    }
}

nonisolated enum DragPhase : Equatable {
    case staging
    case tree
    case racing
    case finished
}

nonisolated enum DragEvent {
    case amber( Int )
    case green
    case launched( LaunchRating, reaction : Double )
    case foul
    case shift( ShiftQuality )
    case split( String, Double )
    case finished( won : Bool )
}

nonisolated struct DragRunResult : Equatable {
    var reactionTime : Double
    var sixtyFoot : Double?
    var eighthMile : Double?
    var elapsedTime : Double
    var trapSpeedKPH : Double
    var launch : LaunchRating
    var perfectShifts : Int
    var shifts : Int
    var isFoul : Bool

    /// Heads-up result: reaction plus elapsed time.
    var totalTime : Double {
        reactionTime + elapsedTime
    }
}

/// One car's pass down the strip, driven by the player or by a drag AI.
nonisolated final class DragRacer {
    let name : String
    let entrant : RaceEntrant
    let model : VehicleModel
    var state : VehicleState
    var previousState : VehicleState
    var throttle = 0.0
    var nitrous = false
    var launchTime : Double?
    var launchRating : LaunchRating?
    var finishTime : Double?
    var sixtyFoot : Double?
    var eighthMile : Double?
    var trapStartTime : Double?
    var trapSpeed = 0.0
    var shifts = 0
    var perfectShifts = 0
    var isFoul = false
    var events : VehicleEvents = []

    // AI behaviour.
    let skill : Double
    let isAI : Bool
    private var generator : SeededGenerator
    private( set ) var plannedReaction : Double
    private( set ) var plannedLaunchRPM : Double
    private let shiftAccuracy : Double

    init( entrant : RaceEntrant, lane : Double, skill : Double, seed : String ) {
        name = entrant.name
        self.entrant = entrant
        model = VehicleModel( spec : entrant.spec )
        state = model.initialState( at : Vec2( 0, lane ), heading : 0 )
        state.gear = 0
        previousState = state
        self.skill = clamp( skill, 0, 1 )
        isAI = !entrant.isPlayer
        generator = SeededGenerator( text : seed + entrant.name )
        plannedReaction = 0.16 + ( 1 - self.skill ) * 0.22 + generator.unit() * 0.06
        let launchError = ( generator.unit() * 2 - 1 ) * ( 1 - self.skill ) * 0.16 * model.spec.redlineRPM
        plannedLaunchRPM = model.idealLaunchRPM + launchError
        shiftAccuracy = 0.93 + 0.06 * self.skill + ( generator.unit() - 0.5 ) * 0.02
    }

    var distance : Double {
        state.position.x
    }

    func result( greenTime : Double ) -> DragRunResult {
        let launch = launchTime ?? greenTime
        return DragRunResult(
            reactionTime : launch - greenTime,
            sixtyFoot : sixtyFoot.map { $0 - launch },
            eighthMile : eighthMile.map { $0 - launch },
            elapsedTime : ( finishTime ?? launch + 99 ) - launch,
            trapSpeedKPH : trapSpeed * Units.metresPerSecondToKPH,
            launch : launchRating ?? .ok,
            perfectShifts : perfectShifts,
            shifts : shifts,
            isFoul : isFoul
        )
    }

    /// Clutch dump: rates the launch from RPM against the car's traction-limited ideal.
    func launch( at time : Double ) -> LaunchRating {
        let ideal = model.idealLaunchRPM
        let redline = model.spec.redlineRPM
        let error = ( state.engineRPM - ideal ) / redline
        let rating : LaunchRating

        if error < -0.12 {
            rating = .bogged
            state.launchBogRemaining = 0.6
        } else if error > 0.12 {
            rating = .wheelspin
            state.wheelspin = min( ( error - 0.12 ) * 5 + 0.5, 1 )
        } else if abs( error ) <= 0.035 {
            rating = .perfect
        } else if abs( error ) <= 0.07 {
            rating = .good
        } else {
            rating = .ok
        }

        state.gear = 1
        state.launchRPM = state.engineRPM
        launchTime = time
        launchRating = rating
        return rating
    }

    func shiftUp() -> ShiftQuality? {
        let before = state
        state = model.shiftingUp( state )

        guard state.gear != before.gear else {
            return nil
        }

        shifts += 1
        events.formUnion( state.events )

        if state.lastShiftQuality == .perfect {
            perfectShifts += 1
        }

        return state.lastShiftQuality
    }

    func shiftDown() {
        state = model.shiftingDown( state )
        events.formUnion( state.events )
    }

    /// AI throttle, launch and shift decisions.
    func driveAI( phase : DragPhase, time : Double, greenTime : Double? ) {
        switch phase {
        case .staging, .tree:
            let error = ( plannedLaunchRPM - state.engineRPM ) / model.spec.redlineRPM
            throttle = clamp( throttle + error * 0.4, 0, 1 )
        case .racing:
            guard let greenTime else {
                return
            }

            if launchTime == nil && time >= greenTime + plannedReaction {
                _ = launch( at : time )
            }

            if launchTime != nil {
                throttle = 1
                nitrous = state.gear >= 3 && skill > 0.3

                if state.gear >= 1 && state.engineRPM >= model.idealUpshiftRPM( fromGear : state.gear ) * shiftAccuracy {
                    _ = shiftUp()
                }
            }
        case .finished:
            throttle = 0
        }
    }
}

/// Heads-up drag race with a christmas tree, launch control by the player and manual shifting.
nonisolated final class DragRace {
    let length : Double
    let player : DragRacer
    let opponent : DragRacer
    private( set ) var phase = DragPhase.staging
    private( set ) var clock = 0.0
    private( set ) var greenTime : Double?
    private( set ) var amberLit = 0
    private( set ) var renderAlpha = 1.0
    private var accumulator = 0.0
    private let treeStart : Double
    private let greenDelay : Double
    var events : [DragEvent] = []

    static let stagingTime = 1.6
    static let timeStep = VehicleModel.timeStep

    init( length : Double, player : RaceEntrant, opponent : RaceEntrant, opponentSkill : Double, seed : String ) {
        self.length = length
        self.player = DragRacer( entrant : player, lane : -2.2, skill : 1, seed : seed )
        self.opponent = DragRacer( entrant : opponent, lane : 2.2, skill : opponentSkill, seed : seed )
        var generator = SeededGenerator( text : seed + "tree" )
        treeStart = DragRace.stagingTime
        greenDelay = 1.5 + generator.unit() * 0.5
    }

    var racers : [DragRacer] {
        [ player, opponent ]
    }

    var isComplete : Bool {
        phase == .finished
    }

    var playerWon : Bool {
        let mine = player.result( greenTime : greenTime ?? 0 )
        let theirs = opponent.result( greenTime : greenTime ?? 0 )

        if mine.isFoul != theirs.isFoul {
            return !mine.isFoul
        }

        return mine.totalTime <= theirs.totalTime
    }

    /// Player taps launch. Before green is a foul (red light).
    func launchPlayer() {
        guard player.launchTime == nil, phase != .finished else {
            return
        }

        // Leaving before green is a red light: the pass still runs, but it cannot win.
        guard let greenTime, clock >= greenTime else {
            player.isFoul = true
            events.append( .foul )
            let rating = player.launch( at : clock )
            events.append( .launched( rating, reaction : 0 ) )
            return
        }

        let rating = player.launch( at : clock )
        events.append( .launched( rating, reaction : clock - greenTime ) )
    }

    func shiftUpPlayer() {
        guard player.launchTime != nil, let quality = player.shiftUp() else {
            return
        }

        events.append( .shift( quality ) )
    }

    func shiftDownPlayer() {
        guard player.launchTime != nil else {
            return
        }

        player.shiftDown()
    }

    func advance( by frameTime : Double ) {
        accumulator += min( max( frameTime, 0 ), 0.1 )
        var steps = 0

        while accumulator >= DragRace.timeStep && steps < 12 {
            step()
            accumulator -= DragRace.timeStep
            steps += 1
        }

        renderAlpha = accumulator / DragRace.timeStep
    }

    func step() {
        let timeStep = DragRace.timeStep
        clock += timeStep

        for racer in racers {
            racer.previousState = racer.state
        }

        updateTree()
        opponent.driveAI( phase : phase, time : clock, greenTime : greenTime )

        var assists = DrivingAssists.none
        assists.antiLockBrakes = true

        for racer in racers {
            var input = VehicleInput( throttle : racer.throttle, brake : 0, steering : 0, handbrake : false, nitrous : racer.nitrous )

            if racer.launchTime == nil {
                // Staged: in neutral, free revving, held on the brakes.
                racer.state.gear = 0
                input.brake = 1
            }

            racer.state = racer.model.advancing( racer.state, with : input, assists : assists, by : timeStep )
            racer.state.position.y = racer.previousState.position.y
            racer.state.velocity.y = 0
            racer.state.heading = 0
            racer.state.yawRate = 0
            racer.events.formUnion( racer.state.events )
            recordSplits( racer )
        }

        if phase == .racing && racers.allSatisfy( { $0.finishTime != nil } ) {
            phase = .finished
            events.append( .finished( won : playerWon ) )
        }
    }

    private func updateTree() {
        guard phase == .staging || phase == .tree else {
            return
        }

        if clock >= treeStart && phase == .staging {
            phase = .tree
        }

        guard phase == .tree else {
            return
        }

        let sinceTree = clock - treeStart
        let lit = min( Int( sinceTree / 0.5 ) + 1, 3 )

        if lit > amberLit {
            amberLit = lit
            events.append( .amber( lit ) )
        }

        if sinceTree >= greenDelay {
            greenTime = clock
            phase = .racing
            events.append( .green )
        }
    }

    private func recordSplits( _ racer : DragRacer ) {
        guard let launch = racer.launchTime, racer.finishTime == nil else {
            return
        }

        let distance = racer.distance

        if racer.sixtyFoot == nil && distance >= Units.sixtyFeet {
            racer.sixtyFoot = clock

            if racer === player {
                events.append( .split( "60 FT", clock - launch ) )
            }
        }

        if racer.eighthMile == nil && distance >= Units.eighthMile && length > Units.eighthMile + 1 {
            racer.eighthMile = clock

            if racer === player {
                events.append( .split( "1/8 MILE", clock - launch ) )
            }
        }

        if racer.trapStartTime == nil && distance >= length - 20.1 {
            racer.trapStartTime = clock
        }

        if distance >= length {
            racer.finishTime = clock
            let trapDuration = clock - ( racer.trapStartTime ?? clock - 0.1 )
            racer.trapSpeed = 20.1 / max( trapDuration, 0.01 )
        }

        // A pass that never finishes (e.g. stalled) is cut off.
        if clock - launch > 60 {
            racer.finishTime = clock
        }
    }

    /// Runs an AI-only pass to completion (used for championship drag rounds).
    static func simulatedPass( entrant : RaceEntrant, length : Double, skill : Double, seed : String ) -> DragRunResult {
        var ghostEntrant = entrant
        ghostEntrant.isPlayer = false
        let race = DragRace( length : length, player : ghostEntrant, opponent : ghostEntrant, opponentSkill : skill, seed : seed )
        var guardSteps = 0

        while race.opponent.finishTime == nil && guardSteps < 120 * 90 {
            race.step()
            guardSteps += 1

            if race.player.launchTime == nil && race.phase == .racing {
                race.player.finishTime = race.clock
            }
        }

        return race.opponent.result( greenTime : race.greenTime ?? 0 )
    }
}
