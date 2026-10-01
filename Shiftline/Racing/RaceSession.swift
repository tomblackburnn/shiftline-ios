import Foundation

nonisolated struct PlayerControls {
    var throttle = 0.0
    var brake = 0.0
    var steering = 0.0
    var handbrake = false
    var nitrous = false
}

/// Owns a race: cars, fixed-timestep simulation, progress, collisions and rules.
/// Independent of SpriteKit so it can be driven headlessly in tests.
nonisolated final class RaceSession {
    let config : RaceConfig
    let track : TrackGeometry
    let mode : RaceMode
    private( set ) var cars : [RaceCar] = []
    let playerIndex : Int

    var phase = RacePhase.countdown
    var countdownRemaining = 3.6
    var elapsed = 0.0
    var controls = PlayerControls()
    var events : [RaceEvent] = []
    var drift = DriftScorer()
    var ghostRecorder = GhostRecorder()
    var bestGhost : GhostRecording?
    var driftZones : [ClosedRange<Double>] = []
    var speedTraps : [Double] = []
    var clippingPoints : [( distance : Double, lateral : Double )] = []
    var tyreWearRate = 0.0
    var eliminationsSoFar = 0

    /// 0...1 interpolation factor between the previous and current physics step, for rendering.
    private( set ) var renderAlpha = 1.0
    private var accumulator = 0.0
    private var lastCountdownSecond = 4
    private var playerPositionLastStep = 0

    static let timeStep = VehicleModel.timeStep
    static let maximumStepsPerFrame = 12

    var player : RaceCar {
        cars[ playerIndex ]
    }

    var weatherGrip : Double {
        config.weather.gripMultiplier
    }

    var laps : Int {
        max( config.laps, 1 )
    }

    init( config : RaceConfig ) {
        self.config = config
        let layout = Tracks.named( config.trackID ) ?? Tracks.velocityParkGP
        track = TrackGeometry( layout : layout )
        mode = RaceModes.make( for : config )
        playerIndex = max( config.entrants.firstIndex { $0.isPlayer } ?? 0, 0 )

        let surfaceGrip = layout.surface.grip * config.weather.gripMultiplier

        for ( index, configured ) in config.entrants.enumerated() {
            var entrant = configured

            if config.kind.usesDriftTyres {
                entrant.spec.tyre = .drift
            }

            let slot = gridSlotIndex( for : index )
            let grid = track.gridSlot( slot )
            var assists = entrant.isPlayer ? config.assists : DrivingAssists()

            if !entrant.isPlayer {
                assists.automaticTransmission = false
            }

            let car = RaceCar( id : index, entrant : entrant, assists : assists, position : grid.position, heading : grid.heading )
            let projection = track.project( grid.position )
            car.trackIndex = projection.index
            car.trackDistance = projection.distance
            car.lateral = projection.lateral
            car.raceDistance = initialRaceDistance( for : projection.distance )

            if let profile = entrant.profile {
                let skill = clamp( config.opponentSkill + profile.skill + config.difficulty.skillOffset, 0, 1 )
                car.ai = AIDriver( profile : profile, skill : skill, seed : config.title )
                car.speedProfile = AIDriver.speedProfile(
                    for : entrant.spec,
                    on : track,
                    surfaceGrip : surfaceGrip,
                    skill : skill,
                    brakingLateness : profile.brakingLateness
                )
            } else {
                car.speedProfile = AIDriver.speedProfile(
                    for : entrant.spec,
                    on : track,
                    surfaceGrip : surfaceGrip,
                    skill : 0.92,
                    brakingLateness : 0.5
                )
            }

            cars.append( car )
        }

        configureZones()
        mode.prepare( self )
    }

    private func gridSlotIndex( for entrantIndex : Int ) -> Int {
        // The player starts at the back of the grid in races, alone in solo modes.
        guard config.entrants.count > 1 else {
            return 0
        }

        if config.entrants[ entrantIndex ].isPlayer {
            return config.entrants.count - 1
        }

        let aiIndex = config.entrants[ 0 ..< entrantIndex ].filter { !$0.isPlayer }.count
        return aiIndex
    }

    private func initialRaceDistance( for distance : Double ) -> Double {
        if track.isClosed {
            return distance > track.length / 2 ? distance - track.length : distance
        }

        return distance - track.startDistance
    }

    private func configureZones() {
        let layout = track.layout
        let routeLength = track.isClosed ? track.length : track.finishDistance - track.startDistance
        let origin = track.isClosed ? 0 : track.startDistance

        if layout.driftZones.isEmpty {
            driftZones = automaticDriftZones()
        } else {
            driftZones = layout.driftZones.map { ( origin + $0.lowerBound * routeLength ) ... ( origin + $0.upperBound * routeLength ) }
        }

        speedTraps = RaceSession.previewTraps( track : track )

        // Apex clipping points: the tightest spot of each drift zone, on the inside kerb.
        clippingPoints = driftZones.compactMap { zone in
            let lower = track.index( forDistance : zone.lowerBound )
            let upper = track.index( forDistance : zone.upperBound )

            guard upper > lower else {
                return nil
            }

            let apex = ( lower ... upper ).max { abs( track.racingCurvatures[ $0 ] ) < abs( track.racingCurvatures[ $1 ] ) } ?? lower
            let side : Double = track.racingCurvatures[ apex ] > 0 ? 1 : -1
            return ( Double( apex ) * track.spacing, side * ( track.halfWidth - 1.2 ) )
        }
    }

    /// Corners tight enough to slide through become drift zones.
    private func automaticDriftZones() -> [ClosedRange<Double>] {
        var zones : [ClosedRange<Double>] = []
        var start : Int?

        for index in 0 ..< track.sampleCount {
            let isCorner = abs( track.curvatures[ index ] ) > 1 / 140

            if isCorner && start == nil {
                start = index
            } else if !isCorner, let zoneStart = start {
                let lower = Double( max( zoneStart - 8, 0 ) ) * track.spacing
                let upper = Double( index + 6 ) * track.spacing

                if upper - lower > 30 {
                    zones.append( lower ... upper )
                }

                start = nil
            }
        }

        return zones
    }

    /// Speed trap positions: authored ones, or the end of the longest straights.
    static func previewTraps( track : TrackGeometry ) -> [Double] {
        let layout = track.layout

        if !layout.speedTraps.isEmpty {
            let origin = track.isClosed ? 0 : track.startDistance
            let routeLength = track.isClosed ? track.length : track.finishDistance - track.startDistance
            return layout.speedTraps.map { origin + $0 * routeLength }
        }

        var straights : [( start : Int, end : Int )] = []
        var start : Int?

        for index in 0 ..< track.sampleCount {
            let isStraight = abs( track.racingCurvatures[ index ] ) < 1 / 450

            if isStraight && start == nil {
                start = index
            } else if !isStraight, let straightStart = start {
                straights.append( ( straightStart, index ) )
                start = nil
            }
        }

        if let straightStart = start {
            straights.append( ( straightStart, track.sampleCount - 1 ) )
        }

        let lower = track.isClosed ? 0 : track.startDistance + 100
        let upper = track.isClosed ? track.length : track.finishDistance - 10

        return straights
            .filter { $0.end - $0.start > 60 }
            .sorted { $0.end - $0.start > $1.end - $1.start }
            .prefix( 3 )
            .map { Double( $0.start ) * track.spacing + Double( $0.end - $0.start ) * track.spacing * 0.85 }
            .filter { $0 > lower && $0 < upper }
            .sorted()
    }

    // MARK: - Loop

    /// Advances real time by running as many fixed physics steps as fit.
    func advance( by frameTime : Double ) {
        accumulator += min( max( frameTime, 0 ), 0.1 )
        var steps = 0

        while accumulator >= RaceSession.timeStep && steps < RaceSession.maximumStepsPerFrame {
            step()
            accumulator -= RaceSession.timeStep
            steps += 1
        }

        if steps == RaceSession.maximumStepsPerFrame {
            accumulator = 0
        }

        renderAlpha = accumulator / RaceSession.timeStep
    }

    func shiftUp() {
        guard phase != .finished else {
            return
        }

        player.state = player.model.shiftingUp( player.state )

        if let event = player.recordShift() {
            events.append( event )
        }

        player.pendingEvents.formUnion( player.state.events )
    }

    func shiftDown() {
        guard phase != .finished else {
            return
        }

        player.state = player.model.shiftingDown( player.state )
        player.pendingEvents.formUnion( player.state.events )
    }

    /// Puts a car back on the racing line at its current progress, at rest.
    func resetToTrack( _ car : RaceCar ) {
        let distance = track.isClosed ? car.trackDistance : max( car.trackDistance, track.startDistance )
        let lateral = track.racingOffset( atDistance : distance )
        var state = car.model.initialState(
            at : track.point( atDistance : distance, lateral : lateral ),
            heading : track.tangent( atDistance : distance ).angle
        )
        state.gear = 1
        state.nitrousRemaining = car.state.nitrousRemaining
        state.tyreWear = car.state.tyreWear
        state.distanceTravelled = car.state.distanceTravelled
        car.state = state
        car.previousState = state
        car.stuckTime = 0
    }

    func step() {
        let timeStep = RaceSession.timeStep

        for car in cars {
            car.previousState = car.state
        }

        switch phase {
        case .countdown:
            stepCountdown( timeStep )
        case .racing:
            stepRacing( timeStep )
        case .finished:
            stepCoolDown( timeStep )
        }
    }

    private func stepCountdown( _ timeStep : Double ) {
        countdownRemaining -= timeStep
        let second = Int( countdownRemaining.rounded( .up ) )

        if second < lastCountdownSecond && second >= 1 && second <= 3 {
            events.append( .countdown( second ) )
        }

        lastCountdownSecond = second

        // Engines idle or rev on the grid; cars are held on the brakes.
        for car in cars {
            var input = VehicleInput()
            input.brake = 1
            input.throttle = car.isPlayer ? controls.throttle : 0.8
            var held = car.state
            held.gear = 0
            held = car.model.advancing( held, with : input, assists : car.assists, by : timeStep )
            held.gear = 1
            held.velocity = .zero
            held.yawRate = 0
            held.position = car.state.position
            held.heading = car.state.heading
            car.state = held

            // Remember when the throttle went down: timing it to the "2" earns a start boost.
            if car.isPlayer && car.ai == nil {
                if controls.throttle > 0.5 {
                    car.startHoldBegan = car.startHoldBegan ?? countdownRemaining
                } else {
                    car.startHoldBegan = nil
                }
            }
        }

        if countdownRemaining <= 0 {
            phase = .racing
            events.append( .go )

            for car in cars {
                car.lapStartTime = 0
                car.sectorStartTime = 0
                applyStart( to : car )
            }
        }
    }

    private func applyStart( to car : RaceCar ) {
        // Revs built on the line carry into the launch. They are held just under the shift point:
        // sitting on the limiter would cut the engine and make an automatic gearbox grab second at a standstill.
        car.state.limiterTime = 0
        car.state.engineRPM = min( car.state.engineRPM, car.model.idealUpshiftRPM( fromGear : 1 ) * 0.88 )
        car.state.launchRPM = car.state.engineRPM

        let quality : StartQuality

        if let ai = car.ai {
            var generator = SeededGenerator( text : config.title + "start\( car.id )" )
            quality = StartQuality( skill : ai.skill, roll : generator.unit() )
        } else {
            quality = StartQuality( holdBegan : car.startHoldBegan )
        }

        if let boost = quality.boost {
            car.boost = boost
            car.boostRemaining = boost.duration
        }

        if quality == .tooEarly {
            car.wheelspinPenaltyRemaining = Boost.earlyStartPenalty
        }

        if car.isPlayer && quality != .normal {
            events.append( .start( quality ) )
        }
    }

    /// Start and slingshot boosts push the car along its nose; an early start just spins the wheels.
    private func applyBoosts( to car : RaceCar, timeStep : Double ) {
        if car.wheelspinPenaltyRemaining > 0 {
            car.wheelspinPenaltyRemaining -= timeStep
            car.state.wheelspin = max( car.state.wheelspin, 0.9 )
        }

        guard car.boostRemaining > 0, let boost = car.boost else {
            return
        }

        car.boostRemaining -= timeStep

        if car.input.throttle > 0.2 && car.state.forwardSpeed >= 0 {
            car.state.velocity += car.state.forward * boost.acceleration * timeStep
        }
    }

    private func stepRacing( _ timeStep : Double ) {
        elapsed += timeStep

        for car in cars where car.isActive {
            car.input = input( for : car, timeStep : timeStep )

            if car.wheelspinPenaltyRemaining > 0 {
                car.input.throttle *= 0.2
            }

            if let ai = car.ai {
                car.state = ai.shifting( car.state, model : car.model )
            }

            let contact = surfaceContact( for : car )
            car.state = car.model.advancing( car.state, with : car.input, on : contact, assists : car.assists, by : timeStep )
            applyBoosts( to : car, timeStep : timeStep )
            car.pendingEvents.formUnion( car.state.events )
            car.topSpeed = max( car.topSpeed, car.state.speed )

            if car.isPlayer, car.assists.automaticTransmission, car.state.events.contains( .upshift ) {
                car.shifts += 1
            }
        }

        resolveWallCollisions()
        resolveCarCollisions()

        for car in cars where car.isActive {
            updateProgress( car, timeStep : timeStep )
        }

        updateSlipstream( timeStep )
        updateStandings()
        updatePlayerExtras( timeStep )
        mode.update( self, timeStep : timeStep )

        if mode.isComplete( self ) {
            finishRace()
        }
    }

    /// After the flag everyone keeps driving under AI control so the scene stays alive.
    private func stepCoolDown( _ timeStep : Double ) {
        for car in cars where car.isActive {
            var input = car.ai?.control( car, in : self, timeStep : timeStep ) ?? VehicleInput()

            if car.isPlayer {
                input = VehicleInput( throttle : 0, brake : 0.4, steering : 0 )
            }

            input.throttle *= 0.6
            car.state = car.model.advancing( car.state, with : input, on : surfaceContact( for : car ), assists : DrivingAssists(), by : timeStep )
            updateProgress( car, timeStep : timeStep )
        }

        resolveWallCollisions()
        resolveCarCollisions()
    }

    // MARK: - Inputs and surfaces

    private func input( for car : RaceCar, timeStep : Double ) -> VehicleInput {
        if let ai = car.ai {
            return ai.control( car, in : self, timeStep : timeStep )
        }

        if !car.isPlayer {
            return VehicleInput()
        }

        var input = VehicleInput(
            throttle : clamp( controls.throttle, 0, 1 ),
            brake : clamp( controls.brake, 0, 1 ),
            steering : clamp( controls.steering, -1, 1 ),
            handbrake : controls.handbrake,
            nitrous : controls.nitrous
        )

        // Braking assist: gently brakes towards the target speed for the next corner.
        if car.assists.brakingAssist && !car.speedProfile.isEmpty {
            let index = track.index( forDistance : car.trackDistance + car.state.speed * 0.3 )
            let target = car.speedProfile[ index ] * 1.03

            if car.state.speed > target + 1 {
                input.brake = max( input.brake, clamp( ( car.state.speed - target ) / 6, 0, 0.9 ) )
                input.throttle = min( input.throttle, 0.2 )
            }
        }

        return input
    }

    func surfaceContact( for car : RaceCar ) -> SurfaceContact {
        let layout = track.layout
        let offset = abs( car.lateral )
        let curvature = abs( track.curvatures[ car.trackIndex ] )
        var contact = SurfaceContact()

        if offset <= track.halfWidth {
            car.surface = .road
            contact.gripMultiplier = layout.surface.grip * weatherGrip
        } else if offset <= track.halfWidth + 1.2 && curvature > 1 / 160 {
            car.surface = .kerb
            contact.gripMultiplier = 0.95 * weatherGrip
        } else {
            car.surface = .runoff
            contact.gripMultiplier = layout.runoff.grip * ( config.weather == .rain ? 0.85 : 1 )
            contact.rollingDragMultiplier = layout.runoff.rollingDrag
        }

        contact.slope = track.tangents[ car.trackIndex ] * layout.grade
        contact.tyreWearRate = tyreWearRate
        contact.slipstream = car.slipstream
        return contact
    }

    // MARK: - Progress

    private func updateProgress( _ car : RaceCar, timeStep : Double ) {
        let projection = track.project( car.state.position, near : car.trackIndex )
        var delta = projection.distance - car.trackDistance

        if track.isClosed {
            if delta > track.length / 2 {
                delta -= track.length
            } else if delta < -track.length / 2 {
                delta += track.length
            }
        }

        car.trackIndex = projection.index
        car.trackDistance = projection.distance
        car.lateral = projection.lateral
        car.raceDistance += clamp( delta, -30, 30 )

        guard phase == .racing, !car.isFinished else {
            return
        }

        updateCheckpoints( car )
        updateTrackLimits( car, timeStep : timeStep )

        let isWrongWay = projection.tangent.dot( car.state.forward ) < -0.3 && car.state.speed > 2

        if isWrongWay {
            car.wrongWayTime += timeStep

            if car.isPlayer && car.wrongWayTime - timeStep < 1 && car.wrongWayTime >= 1 {
                events.append( .wrongWay )
            }
        } else {
            car.wrongWayTime = 0
        }

        // Cars that get truly stuck are recovered to the track after a while.
        if car.state.speed < 1 {
            car.stuckTime += timeStep

            if car.stuckTime > ( car.isPlayer ? 8 : 6 ) {
                resetToTrack( car )
            }
        } else {
            car.stuckTime = 0
        }

        if mode.isFinished( car, in : self ) {
            car.finishTime = elapsed

            if car.isPlayer {
                events.append( .finished( position : car.position ) )
            }
        }
    }

    /// Absolute race distance of a global checkpoint index.
    func checkpointRaceDistance( _ index : Int ) -> Double {
        let perLap = track.checkpoints.count
        let lap = index / perLap
        let checkpoint = track.checkpoints[ index % perLap ]

        if track.isClosed {
            return Double( lap ) * track.length + checkpoint
        }

        return checkpoint - track.startDistance
    }

    private func updateCheckpoints( _ car : RaceCar ) {
        let perLap = track.checkpoints.count

        while car.raceDistance >= checkpointRaceDistance( car.nextCheckpoint ) {
            let index = car.nextCheckpoint
            let sectorTime = elapsed - car.sectorStartTime
            car.sectorStartTime = elapsed
            car.currentSectors.append( sectorTime )
            let sectorIndex = index % perLap

            if car.isPlayer {
                let best = sectorIndex < car.bestSectors.count ? car.bestSectors[ sectorIndex ] : nil
                events.append( .sector( index : sectorIndex, time : sectorTime, delta : best.map { sectorTime - $0 } ) )
            }

            car.nextCheckpoint += 1
            mode.checkpointPassed( by : car, index : index, in : self )

            if !track.isClosed && car.nextCheckpoint >= perLap {
                break
            }

            if track.isClosed && sectorIndex == perLap - 1 {
                completeLap( car )
            }
        }
    }

    private func completeLap( _ car : RaceCar ) {
        let lapTime = elapsed - car.lapStartTime
        car.lapStartTime = elapsed
        car.lapsCompleted += 1
        car.lapTimes.append( lapTime )
        let isValid = car.isLapValid
        let isBest = isValid && lapTime < ( car.bestLap ?? .infinity )

        if isBest {
            car.bestLap = lapTime
        }

        if isValid {
            for ( index, sector ) in car.currentSectors.enumerated() {
                if index < car.bestSectors.count {
                    car.bestSectors[ index ] = min( car.bestSectors[ index ], sector )
                } else {
                    car.bestSectors.append( sector )
                }
            }
        }

        car.currentSectors = []

        if car.isPlayer {
            events.append( .lap( car : car.id, time : lapTime, isBest : isBest, isValid : isValid ) )

            if isBest {
                bestGhost = GhostRecording(
                    trackID : config.trackID,
                    carID : car.entrant.carID,
                    driverName : car.name,
                    lapTime : lapTime,
                    paintHex : car.entrant.appearance.paintHex,
                    samples : ghostRecorder.samples
                )
            }

            ghostRecorder.reset()

            if mode.totalLaps > 1 && car.lapsCompleted == mode.totalLaps - 1 {
                events.append( .finalLap )
            }
        }

        car.isLapValid = true
        mode.lapCompleted( by : car, lapTime : lapTime, in : self )
    }

    private func updateTrackLimits( _ car : RaceCar, timeStep : Double ) {
        let isOffTrack = abs( car.lateral ) > track.halfWidth + 1.2

        if isOffTrack {
            car.offTrackTime += timeStep
            return
        }

        if car.offTrackTime > 0.45 && car.state.speed > 12 {
            car.trackLimitCount += 1
            mode.trackLimitsBroken( by : car, in : self )
        }

        car.offTrackTime = 0
    }

    // MARK: - Standings

    /// Current order: finishers by time, then by distance covered, then eliminated cars.
    var standings : [RaceCar] {
        cars.sorted { lhs, rhs in
            if lhs.isEliminated != rhs.isEliminated {
                return !lhs.isEliminated
            }

            if lhs.isEliminated {
                return lhs.eliminationOrder > rhs.eliminationOrder
            }

            switch ( lhs.totalTime, rhs.totalTime ) {
            case let ( left?, right? ):
                return left < right
            case ( .some, .none ):
                return true
            case ( .none, .some ):
                return false
            default:
                return lhs.raceDistance > rhs.raceDistance
            }
        }
    }

    private func updateStandings() {
        for ( index, car ) in standings.enumerated() {
            car.position = index + 1
        }

        let position = player.position

        if playerPositionLastStep != 0 && position != playerPositionLastStep && cars.count > 1 {
            if position < playerPositionLastStep {
                if elapsed - player.lastCollisionTime > 2 {
                    player.cleanOvertakes += 1
                }

                events.append( .overtake )
            } else {
                events.append( .positionLost )
            }
        }

        playerPositionLastStep = position
    }

    private func updateSlipstream( _ timeStep : Double ) {
        for car in cars {
            var best = 0.0

            for other in cars where other !== car && other.isActive {
                let relative = other.state.position - car.state.position
                let along = relative.dot( car.state.forward )
                let across = abs( relative.dot( car.state.forward.perpendicular ) )

                if along > 3 && along < 30 && across < 2.2 && car.state.speed > 20 {
                    best = max( best, 1 - along / 30 )
                }
            }

            car.slipstream = best

            // Sitting in the tow charges a slingshot; a full charge fires it.
            if car.slipstreamCharge.update( tow : best, isBoosting : car.boostRemaining > 0, timeStep : timeStep ) {
                car.boost = .slingshot
                car.boostRemaining = Boost.slingshot.duration

                if car.isPlayer {
                    events.append( .slingshot )
                }
            }
        }
    }

    private func updatePlayerExtras( _ timeStep : Double ) {
        ghostRecorder.record( player.state, lapTime : elapsed - player.lapStartTime )
    }

    // MARK: - Collisions

    private func resolveWallCollisions() {
        for car in cars where car.isActive {
            for circle in car.collisionCircles {
                let projection = track.project( circle.centre, near : car.trackIndex )
                let reach = abs( projection.lateral ) + circle.radius
                let barrier = track.barrierOffset

                guard reach > barrier else {
                    continue
                }

                let normal = projection.tangent.perpendicular * ( projection.lateral > 0 ? -1 : 1 )
                let penetration = reach - barrier
                car.state.position += normal * penetration
                let contact = circle.centre - normal * circle.radius - car.state.position
                let intensity = applyImpulse( to : car, at : contact, normal : normal, restitution : 0.25, friction : 0.35 )

                if intensity > 1.2 {
                    registerCollision( car, intensity : intensity, withWall : true, point : car.state.position + contact )
                }
            }
        }
    }

    private func resolveCarCollisions() {
        let active = cars.filter { $0.isActive }

        guard active.count > 1 else {
            return
        }

        for first in 0 ..< active.count - 1 {
            for second in first + 1 ..< active.count {
                let a = active[ first ]
                let b = active[ second ]

                guard ( a.state.position - b.state.position ).lengthSquared < 64 else {
                    continue
                }

                for circleA in a.collisionCircles {
                    for circleB in b.collisionCircles {
                        let separation = circleA.centre - circleB.centre
                        let distance = separation.length
                        let minimum = circleA.radius + circleB.radius

                        guard distance < minimum && distance > 1e-4 else {
                            continue
                        }

                        let normal = separation / distance
                        let penetration = minimum - distance
                        let massA = a.model.spec.massKilograms
                        let massB = b.model.spec.massKilograms
                        let shareA = massB / ( massA + massB )
                        a.state.position += normal * penetration * shareA
                        b.state.position -= normal * penetration * ( 1 - shareA )

                        let contactA = circleA.centre - normal * circleA.radius - a.state.position
                        let contactB = circleB.centre + normal * circleB.radius - b.state.position
                        let intensity = applyPairImpulse( a, b, contactA : contactA, contactB : contactB, normal : normal )

                        if intensity > 1 {
                            let point = a.state.position + contactA
                            registerCollision( a, intensity : intensity, withWall : false, point : point )
                            registerCollision( b, intensity : intensity, withWall : false, point : point )
                        }
                    }
                }
            }
        }
    }

    private func registerCollision( _ car : RaceCar, intensity : Double, withWall : Bool, point : Vec2 ) {
        guard elapsed - car.lastCollisionTime > 0.3 else {
            car.lastCollisionTime = elapsed
            return
        }

        car.lastCollisionTime = elapsed
        car.collisions += 1

        if withWall {
            car.wallHits += 1
        }

        if car.isPlayer {
            events.append( .collision( car : car.id, intensity : intensity, withWall : withWall, point : point ) )

            if let driftEvent = drift.registerCollision( intensity : intensity ) {
                events.append( .drift( driftEvent ) )
            }
        }
    }

    /// Rigid-body impulse against a static wall. Returns the closing speed.
    private func applyImpulse(
        to car : RaceCar,
        at contact : Vec2,
        normal : Vec2,
        restitution : Double,
        friction : Double
    ) -> Double {
        let mass = car.model.spec.massKilograms
        let inertia = car.model.yawInertia
        let pointVelocity = car.state.velocity + Vec2( -car.state.yawRate * contact.y, car.state.yawRate * contact.x )
        let closing = pointVelocity.dot( normal )

        guard closing < 0 else {
            return 0
        }

        let armNormal = contact.cross( normal )
        let impulse = -( 1 + restitution ) * closing / ( 1 / mass + armNormal * armNormal / inertia )
        car.state.velocity += normal * ( impulse / mass )
        car.state.yawRate += armNormal * impulse / inertia

        let tangent = normal.perpendicular
        let sliding = pointVelocity.dot( tangent )
        let armTangent = contact.cross( tangent )
        let frictionImpulse = clamp(
            -sliding / ( 1 / mass + armTangent * armTangent / inertia ),
            -friction * impulse,
            friction * impulse
        )
        car.state.velocity += tangent * ( frictionImpulse / mass )
        car.state.yawRate = clamp( car.state.yawRate + armTangent * frictionImpulse / inertia, -4, 4 )
        return -closing
    }

    private func applyPairImpulse( _ a : RaceCar, _ b : RaceCar, contactA : Vec2, contactB : Vec2, normal : Vec2 ) -> Double {
        let massA = a.model.spec.massKilograms
        let massB = b.model.spec.massKilograms
        let inertiaA = a.model.yawInertia
        let inertiaB = b.model.yawInertia
        let velocityA = a.state.velocity + Vec2( -a.state.yawRate * contactA.y, a.state.yawRate * contactA.x )
        let velocityB = b.state.velocity + Vec2( -b.state.yawRate * contactB.y, b.state.yawRate * contactB.x )
        let closing = ( velocityA - velocityB ).dot( normal )

        guard closing < 0 else {
            return 0
        }

        let armA = contactA.cross( normal )
        let armB = contactB.cross( normal )
        let denominator = 1 / massA + 1 / massB + armA * armA / inertiaA + armB * armB / inertiaB
        let impulse = -( 1 + 0.3 ) * closing / denominator
        a.state.velocity += normal * ( impulse / massA )
        b.state.velocity -= normal * ( impulse / massB )
        a.state.yawRate = clamp( a.state.yawRate + armA * impulse / inertiaA, -4, 4 )
        b.state.yawRate = clamp( b.state.yawRate - armB * impulse / inertiaB, -4, 4 )
        return -closing
    }

    // MARK: - Finishing

    private func finishRace() {
        guard phase == .racing else {
            return
        }

        if let driftEvent = drift.finish() {
            events.append( .drift( driftEvent ) )
        }

        phase = .finished

        // Unfinished AI get an honest estimate from their remaining distance and average pace.
        for car in cars where !car.isFinished && !car.isEliminated && !car.isPlayer {
            let covered = max( car.raceDistance, 1 )
            let remaining = max( mode.raceDistance( self ) - covered, 0 )
            let averageSpeed = max( covered / max( elapsed, 1 ), 5 )
            car.finishTime = elapsed + remaining / averageSpeed
        }

        updateStandings()

        for car in cars where car.ai == nil && car.isPlayer {
            car.ai = AIDriver( profile : Opponents.pool[ 0 ], skill : 0.5, seed : "cooldown" )
        }
    }

    func drainEvents() -> [RaceEvent] {
        defer {
            events.removeAll( keepingCapacity : true )
        }

        return events
    }

    func eliminate( _ car : RaceCar ) {
        guard !car.isEliminated else {
            return
        }

        eliminationsSoFar += 1
        car.isEliminated = true
        car.eliminationOrder = eliminationsSoFar
        events.append( .eliminated( car : car.id, name : car.name ) )
    }
}
