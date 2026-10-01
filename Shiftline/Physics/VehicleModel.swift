import Foundation

nonisolated struct DrivingAssists : Codable, Equatable {
    var automaticTransmission = true
    var tractionControl = true
    var stabilityControl = true
    var antiLockBrakes = true
    var steeringAssist = true
    var brakingAssist = false
    var racingLine = true

    static let none = DrivingAssists(
        automaticTransmission : false,
        tractionControl : false,
        stabilityControl : false,
        antiLockBrakes : false,
        steeringAssist : false,
        brakingAssist : false,
        racingLine : false
    )
}

/// What the ground under the car is doing this step.
nonisolated struct SurfaceContact {
    var gripMultiplier = 1.0
    var rollingDragMultiplier = 1.0
    /// World-space uphill direction scaled by gradient (rise over run).
    var slope : Vec2 = .zero
    var tyreWearRate = 0.0
    /// Slipstream drag reduction 0...1.
    var slipstream = 0.0
}

/// Pure, SpriteKit-free vehicle dynamics: a bicycle model with a friction ellipse per axle,
/// load transfer, a torque curve, gearbox, forced induction and nitrous.
nonisolated struct VehicleModel {
    let spec : VehicleSpec
    let idealUpshiftRPMs : [Double]
    let idealLaunchRPM : Double

    static let timeStep = 1.0 / 120.0

    init( spec : VehicleSpec ) {
        self.spec = spec
        idealUpshiftRPMs = VehicleModel.computeIdealUpshifts( for : spec )
        idealLaunchRPM = VehicleModel.computeIdealLaunchRPM( for : spec )
    }

    // MARK: - Derived geometry

    var frontAxleDistance : Double {
        spec.wheelbase * ( 1 - spec.frontWeightFraction )
    }

    var rearAxleDistance : Double {
        spec.wheelbase * spec.frontWeightFraction
    }

    var yawInertia : Double {
        spec.massKilograms * frontAxleDistance * rearAxleDistance * ( 1.15 - 0.12 * spec.suspensionStiffness )
    }

    var launchWindow : ClosedRange<Double> {
        let halfWidth = spec.redlineRPM * 0.06
        return ( idealLaunchRPM - halfWidth ) ... ( idealLaunchRPM + halfWidth )
    }

    func idealUpshiftRPM( fromGear gear : Int ) -> Double {
        guard gear >= 1 && gear <= idealUpshiftRPMs.count else {
            return spec.redlineRPM * 0.97
        }

        return idealUpshiftRPMs[ gear - 1 ]
    }

    func initialState( at position : Vec2, heading : Double ) -> VehicleState {
        var state = VehicleState()
        state.position = position
        state.heading = heading
        state.engineRPM = spec.idleRPM
        state.nitrousRemaining = spec.nitrousCapacity
        return state
    }

    // MARK: - Transmission

    func shiftingUp( _ state : VehicleState, automatic : Bool = false ) -> VehicleState {
        guard state.gear < spec.gearCount && state.shiftTimeRemaining <= 0 else {
            return state
        }

        var updatedState = state

        if state.gear == -1 {
            updatedState.gear = 0
            return updatedState
        }

        if state.gear == 0 {
            updatedState.gear = 1
            return updatedState
        }

        let quality = automatic ? ShiftQuality.good : shiftQuality( for : state )
        let durationMultiplier = automatic ? 1.25 : quality.durationMultiplier
        updatedState.gear += 1
        updatedState.shiftTimeRemaining = spec.shiftDuration * durationMultiplier
        updatedState.lastShiftQuality = automatic ? nil : quality
        updatedState.perfectShiftBoostRemaining = quality == .perfect && !automatic ? 0.6 : 0
        updatedState.limiterTime = 0
        updatedState.events.insert( .upshift )

        if state.throttle > 0.6 && state.engineRPM > spec.redlineRPM * 0.8 {
            updatedState.events.insert( .backfire )
        }

        return updatedState
    }

    func shiftingDown( _ state : VehicleState ) -> VehicleState {
        guard state.shiftTimeRemaining <= 0 else {
            return state
        }

        var updatedState = state

        if state.gear <= 1 {
            updatedState.gear = state.speed < 1 ? -1 : state.gear
            return updatedState
        }

        let rpmAfterShift = spec.wheelRPM( forSpeed : state.forwardSpeed, gear : state.gear - 1 )

        guard rpmAfterShift < spec.redlineRPM * 1.02 else {
            return state
        }

        updatedState.gear -= 1
        updatedState.shiftTimeRemaining = spec.shiftDuration * 0.7
        updatedState.lastShiftQuality = nil
        updatedState.limiterTime = 0
        updatedState.events.insert( .downshift )
        return updatedState
    }

    func shiftQuality( for state : VehicleState ) -> ShiftQuality {
        if state.limiterTime > 0.25 {
            return .late
        }

        let ideal = idealUpshiftRPM( fromGear : state.gear )
        let difference = ( state.engineRPM - ideal ) / spec.redlineRPM

        if difference >= -0.045 {
            return difference <= 0.03 ? .perfect : .good
        }

        return difference >= -0.11 ? .good : .early
    }

    private func automaticShift( _ state : VehicleState ) -> VehicleState {
        guard state.gear >= 1 && state.shiftTimeRemaining <= 0 else {
            return state
        }

        // Shifts a little before the ideal point, so skilled manual shifting stays faster.
        let upshiftPoint = idealUpshiftRPM( fromGear : state.gear ) * 0.95

        if state.gear < spec.gearCount
            && state.engineRPM >= upshiftPoint
            && state.throttle > 0.1
            && state.wheelspin < 0.5 {
            return shiftingUp( state, automatic : true )
        }

        guard state.gear > 1 else {
            return state
        }

        let rpmInLowerGear = spec.wheelRPM( forSpeed : state.forwardSpeed, gear : state.gear - 1 )
        let wantsTorque = state.throttle > 0.5 && state.engineRPM < spec.peakTorqueRPM * 0.9
        let isSlowing = state.brake > 0.2 || state.engineRPM < spec.idleRPM * 1.6

        if rpmInLowerGear < spec.redlineRPM * 0.8 && ( wantsTorque || isSlowing ) {
            return shiftingDown( state )
        }

        return state
    }

    // MARK: - Simulation

    func advancing(
        _ state : VehicleState,
        with rawInput : VehicleInput,
        on contact : SurfaceContact = SurfaceContact(),
        assists : DrivingAssists = DrivingAssists(),
        by timeStep : Double = VehicleModel.timeStep
    ) -> VehicleState {
        var next = state
        next.events = []

        let input = resolvingReverse( rawInput, state : &next, timeStep : timeStep )
        next.throttle = input.throttle
        next.brake = input.brake

        let mass = spec.massKilograms
        let forward = Vec2( angle : state.heading )
        let left = forward.perpendicular
        let forwardSpeed = state.velocity.dot( forward )
        let lateralSpeed = state.velocity.dot( left )
        let speed = state.velocity.length
        let travelSign : Double = forwardSpeed >= 0 ? 1 : -1

        // Steering: speed-sensitive lock, smoothed, with optional counter-steer help.
        let speedSensitivity = max( 1 / ( 1 + speed / 26 ), 0.26 )
        var targetSteering = input.steering * spec.steeringLock * spec.steeringSensitivity * speedSensitivity

        if assists.steeringAssist && speed > 6 {
            targetSteering += clamp( state.slipAngle * 0.45, -0.25, 0.25 )
        }

        let steeringRate = 2.6 + 1.2 * spec.suspensionStiffness
        next.steeringAngle = approach( state.steeringAngle, targetSteering, steeringRate * timeStep )
        let steering = next.steeringAngle

        // Vertical loads with longitudinal weight transfer.
        let downforce = spec.downforceCoefficient * speed * speed
        let totalLoad = mass * Units.gravity + downforce
        let transferScale = 1 - 0.3 * spec.suspensionStiffness
        let transfer = mass * state.longitudinalAcceleration * spec.centreOfGravityHeight / spec.wheelbase * transferScale
        let frontLoad = max( totalLoad * spec.frontWeightFraction - transfer, totalLoad * 0.15 )
        let rearLoad = max( totalLoad * ( 1 - spec.frontWeightFraction ) + transfer, totalLoad * 0.15 )

        // Grip.
        let pressureGrip = 1 - 0.05 * spec.tyrePressure
        let baseGrip = spec.tyreGrip * contact.gripMultiplier * ( 1 - 0.22 * state.tyreWear ) * pressureGrip
        let frontLateralGrip = baseGrip * spec.tyre.lateralGrip * ( 1 + 0.07 * spec.suspensionBalance )
        let rearLateralGrip = baseGrip * spec.tyre.lateralGrip * ( spec.tyre.rearGripBias - 0.07 * spec.suspensionBalance )
        let longitudinalGrip = baseGrip * spec.tyre.longitudinalGrip

        // Engine and drive.
        let engine = engineOutput( state, input : input, next : &next, timeStep : timeStep )
        let overallRatio = spec.overallRatio( forGear : next.gear )
        let driveForce = engine.torque * overallRatio * spec.drivelineEfficiency / spec.wheelRadius

        let frontShare : Double
        switch spec.drivetrain {
        case .fwd:
            frontShare = 1
        case .rwd:
            frontShare = 0
        case .awd:
            frontShare = spec.frontTorqueSplit
        }

        let rearShare = input.handbrake && spec.drivetrain == .rwd ? 0 : 1 - frontShare
        let lateralUsage = min( abs( state.lateralAcceleration ) / ( baseGrip * Units.gravity ), 1 )
        let openDiffLoss = ( 1 - spec.differentialLock ) * 0.22 * lateralUsage
        let frontTraction = longitudinalGrip * frontLoad * ( 1 - openDiffLoss ) * ( 1 + 0.04 * spec.differentialLock )
        let rearTraction = longitudinalGrip * rearLoad * ( 1 - openDiffLoss ) * ( 1 + 0.06 * spec.differentialLock )

        var frontDrive = driveForce * frontShare
        var rearDrive = driveForce * rearShare
        var spinTarget = 0.0

        // Traction control works on combined grip: it leaves room for the cornering force in use.
        if assists.tractionControl {
            let cornering = min( lateralUsage, 0.95 )
            let allowance = 0.96 * max( ( 1 - cornering * cornering ).squareRoot(), 0.3 )
            frontDrive = clamp( frontDrive, -frontTraction * allowance, frontTraction * allowance )
            rearDrive = clamp( rearDrive, -rearTraction * allowance, rearTraction * allowance )
        }

        if abs( frontDrive ) > frontTraction {
            spinTarget = max( spinTarget, ( abs( frontDrive ) - frontTraction ) / frontTraction )
            frontDrive = frontDrive.sign == .minus ? -frontTraction : frontTraction
            frontDrive *= 1 - 0.18 * state.wheelspin
        }

        if abs( rearDrive ) > rearTraction {
            spinTarget = max( spinTarget, ( abs( rearDrive ) - rearTraction ) / rearTraction )
            rearDrive = rearDrive.sign == .minus ? -rearTraction : rearTraction
            rearDrive *= 1 - 0.18 * state.wheelspin
        }

        let spinRate = spinTarget > state.wheelspin ? 7.0 : 3.5
        next.wheelspin = approach( state.wheelspin, clamp( spinTarget, 0, 1 ), spinRate * timeStep )

        // Slip angles, and how much of its cornering grip each axle is being asked for (-1...1).
        let referenceSpeed = max( abs( forwardSpeed ), 2.5 )
        let frontSlipAngle = atan2( lateralSpeed + frontAxleDistance * state.yawRate, referenceSpeed ) - steering * travelSign
        let rearSlipAngle = atan2( lateralSpeed - rearAxleDistance * state.yawRate, referenceSpeed )
        let stiffness = spec.tyre.stiffness * ( 1 + 0.15 * spec.suspensionStiffness )
        let frontCurve = sin( spec.tyre.falloff * atan( stiffness * frontSlipAngle ) )
        let rearCurve = sin( spec.tyre.falloff * atan( stiffness * rearSlipAngle ) )

        // Brakes, with or without ABS, plus the handbrake locking the rear.
        let totalBrake = input.brake * spec.brakeDecelerationG * mass * Units.gravity
        var frontBrake = totalBrake * spec.brakeBias
        var rearBrake = totalBrake * ( 1 - spec.brakeBias )
        let frontBrakeLimit = longitudinalGrip * frontLoad
        let rearBrakeLimit = longitudinalGrip * rearLoad
        var frontLocked = false
        var rearLocked = input.handbrake && speed > 1

        if assists.antiLockBrakes {
            // ABS with brake-force distribution: a tyre that is cornering gives up braking to keep grip for the turn.
            // The rear backs off first and furthest, because braking unloads it and a light rear axle that is
            // also braking hard is what spins a car; the front keeps most of its braking. Straight-line stops are unchanged.
            let frontBraking = max( ( 1 - frontCurve * frontCurve ).squareRoot(), 0.85 )
            let rearDemand = min( abs( rearCurve ) * 1.25, 1 )
            let rearBraking = max( ( 1 - rearDemand * rearDemand ).squareRoot(), 0.25 )
            frontBrake = min( frontBrake, frontBrakeLimit * 0.97 * frontBraking )
            rearBrake = min( rearBrake, rearBrakeLimit * 0.97 * rearBraking )
        } else {
            if frontBrake > frontBrakeLimit {
                frontBrake = frontBrakeLimit * 0.8
                frontLocked = speed > 2
            }

            if rearBrake > rearBrakeLimit {
                rearBrake = rearBrakeLimit * 0.8
                rearLocked = rearLocked || speed > 2
            }
        }

        if input.handbrake && speed > 1 {
            rearBrake = max( rearBrake, rearBrakeLimit * 0.75 )
        }

        next.isLockingWheels = frontLocked || ( rearLocked && !input.handbrake )

        if next.isLockingWheels && !state.isLockingWheels {
            next.events.insert( .lockup )
        }

        let brakeScale : Double = abs( forwardSpeed ) < 0.3 ? 0 : travelSign
        let frontLongitudinal = frontDrive - frontBrake * brakeScale
        let rearLongitudinal = rearDrive - rearBrake * brakeScale

        // Lateral tyre forces from slip angles, limited by the friction ellipse.
        // Drive torque through an open differential mostly loads the inside wheel, so it costs less cornering grip
        // than braking does; a locked differential couples the two fully.
        let openCoupling = spec.tyre.openDifferentialCoupling
        let coupling = openCoupling + ( 1 - openCoupling ) * spec.differentialLock
        let frontCoupling = frontLongitudinal > 0 ? coupling : 1
        let rearCoupling = rearLongitudinal > 0 ? coupling : 1
        var frontCapacity = frontLateralGrip * frontLoad
            * ellipseRemainder( frontLongitudinal * frontCoupling, limit : longitudinalGrip * frontLoad )
        var rearCapacity = rearLateralGrip * rearLoad
            * ellipseRemainder( rearLongitudinal * rearCoupling, limit : longitudinalGrip * rearLoad )

        if frontShare > 0 {
            frontCapacity *= 1 - spec.tyre.wheelspinGripLoss * 0.8 * next.wheelspin * frontShare
        }

        if rearShare > 0 {
            rearCapacity *= 1 - spec.tyre.wheelspinGripLoss * next.wheelspin * rearShare
        }

        if frontLocked {
            frontCapacity *= 0.3
        }

        if rearLocked {
            rearCapacity *= input.handbrake ? 0.38 : 0.3
        }

        let frontLateral = -frontCapacity * frontCurve
        let rearLateral = -rearCapacity * rearCurve
        next.frontSlide = clamp( abs( frontSlipAngle ) * stiffness / 1.6, 0, 1 )
        next.rearSlide = clamp( abs( rearSlipAngle ) * stiffness / 1.6, 0, 1 )

        // Resolve forces into the body frame.
        let steeringCosine = cos( steering )
        let steeringSine = sin( steering )
        let bodyForward = frontLongitudinal * steeringCosine - frontLateral * steeringSine + rearLongitudinal
        let frontSideForce = frontLateral * steeringCosine + frontLongitudinal * steeringSine
        let bodyLateral = frontSideForce + rearLateral
        var yawMoment = frontAxleDistance * frontSideForce - rearAxleDistance * rearLateral

        if assists.stabilityControl && speed > 4 {
            let gripYawLimit = baseGrip * Units.gravity / max( speed, 1 )
            let desiredYaw = clamp( forwardSpeed * tan( steering ) / spec.wheelbase, -gripYawLimit, gripYawLimit )
            let excess = state.yawRate - desiredYaw

            if abs( excess ) > 0.12 || abs( state.slipAngle ) > 0.2 {
                yawMoment -= yawInertia * excess * 4.5
            }
        }

        // Resistive forces.
        let slipstreamScale = 1 - 0.35 * contact.slipstream
        let aeroDrag = -state.velocity * speed * spec.dragCoefficient * slipstreamScale
        let rollingScale = min( speed, 1 ) * ( 1 + 0.3 * spec.tyrePressure * -1 )
        let rollingResistance = -state.velocity.normalized
            * spec.rollingResistance * contact.rollingDragMultiplier * mass * Units.gravity * rollingScale
        let gradeForce = -contact.slope * mass * Units.gravity

        let totalForce = forward * bodyForward + left * bodyLateral + aeroDrag + rollingResistance + gradeForce
        let acceleration = totalForce / mass

        // Integrate.
        var velocity = state.velocity + acceleration * timeStep
        var yawRate = state.yawRate + yawMoment / yawInertia * timeStep

        // Blend to a kinematic model at walking pace, where slip angles are meaningless.
        let dynamicWeight = smoothstep( 1, 6, speed )
        let newForwardSpeed = velocity.dot( forward )
        let kinematicYaw = newForwardSpeed * tan( steering ) / spec.wheelbase
        yawRate = lerp( kinematicYaw, yawRate, dynamicWeight )
        let lateralKeep = lerp( 0.8, 1, dynamicWeight )
        velocity = forward * newForwardSpeed + left * ( velocity.dot( left ) * lateralKeep )

        // Brakes and rolling resistance must never push the car backwards.
        let isDriving = abs( engine.torque ) > 1 && next.gear != 0 && next.shiftTimeRemaining <= 0

        if !isDriving && forwardSpeed * velocity.dot( forward ) < 0 {
            velocity -= forward * velocity.dot( forward )
        }

        if input.throttle < 0.05 && velocity.length < 0.25 {
            velocity = .zero
            yawRate *= 0.5
        }

        next.velocity = velocity
        next.yawRate = clamp( yawRate, -6, 6 )
        next.heading = wrapAngle( state.heading + next.yawRate * timeStep )
        next.position = state.position + velocity * timeStep
        next.distanceTravelled += velocity.length * timeStep

        let smoothing = min( 12 * timeStep, 1 )
        next.longitudinalAcceleration = lerp( state.longitudinalAcceleration, acceleration.dot( forward ), smoothing )
        next.lateralAcceleration = lerp( state.lateralAcceleration, acceleration.dot( left ), smoothing )
        next.gripUsed = baseGrip

        let slideEnergy = next.wheelspin + max( next.rearSlide - 0.6, 0 ) + max( next.frontSlide - 0.6, 0 )
        next.tyreWear = min( state.tyreWear + contact.tyreWearRate * spec.tyre.wearRate * ( 0.002 + slideEnergy * 0.004 ) * speed * timeStep / 10, 1 )

        if assists.automaticTransmission {
            next = automaticShift( next )
        }

        return next
    }

    // MARK: - Helpers

    /// Remaining fraction of lateral grip once longitudinal force is spent.
    private func ellipseRemainder( _ longitudinal : Double, limit : Double ) -> Double {
        guard limit > 0 else {
            return 0
        }

        let used = min( abs( longitudinal ) / limit, 1 )
        return max( ( 1 - used * used ).squareRoot(), 0.2 )
    }

    /// Auto reverse: hold brake at a standstill to engage reverse, throttle to go forward again.
    private func resolvingReverse(
        _ input : VehicleInput,
        state : inout VehicleState,
        timeStep : Double
    ) -> VehicleInput {
        var resolved = input

        if state.gear == -1 {
            if input.throttle > 0.3 && state.speed < 1.5 {
                state.gear = 1
                state.reverseHoldTime = 0
                return input
            }

            resolved.throttle = input.brake
            resolved.brake = input.throttle
            return resolved
        }

        if state.gear >= 1 && input.brake > 0.5 && input.throttle < 0.1 && state.speed < 0.6 {
            state.reverseHoldTime += timeStep

            if state.reverseHoldTime > 0.4 {
                state.gear = -1
                state.reverseHoldTime = 0
            }
        } else {
            state.reverseHoldTime = 0
        }

        return resolved
    }

    private struct EngineOutput {
        var torque : Double
    }

    private func engineOutput(
        _ state : VehicleState,
        input : VehicleInput,
        next : inout VehicleState,
        timeStep : Double
    ) -> EngineOutput {
        let throttle = clamp( input.throttle, 0, 1 )
        next.launchRPM = max( state.launchRPM - 2_600 * timeStep, 0 )
        next.launchBogRemaining = max( state.launchBogRemaining - timeStep, 0 )
        next.perfectShiftBoostRemaining = max( state.perfectShiftBoostRemaining - timeStep, 0 )

        // Turbo spool and blow-off.
        let spoolTarget = throttle > 0.3
            ? smoothstep( spec.redlineRPM * 0.25, spec.redlineRPM * 0.55, state.engineRPM ) * throttle
            : 0
        let spoolRate = spoolTarget > state.turboSpool ? 1 / max( spec.turboLag, 0.1 ) : 4
        next.turboSpool = spec.turboBoost > 0
            ? approach( state.turboSpool, spoolTarget, spoolRate * timeStep )
            : 0

        if spec.turboBoost > 0 && state.turboSpool > 0.5 && throttle < 0.2 && state.throttle >= 0.2 {
            next.events.insert( .blowOff )
        }

        // Nitrous.
        let wantsNitrous = input.nitrous && state.nitrousRemaining > 0 && throttle > 0.1 && state.gear >= 1
        next.isNitrousActive = wantsNitrous

        if wantsNitrous {
            next.nitrousRemaining = max( state.nitrousRemaining - timeStep, 0 )

            if !state.isNitrousActive {
                next.events.insert( .nitrousStart )
            }
        }

        // Neutral: free revving (drag staging, shifting).
        if next.gear == 0 {
            let target = spec.idleRPM + throttle * ( spec.redlineRPM * 1.02 - spec.idleRPM )
            let rate = throttle > 0 ? 9_000.0 : 6_000.0
            next.engineRPM = approach( state.engineRPM, target, rate * timeStep )
            applyLimiter( &next, timeStep : timeStep )
            return EngineOutput( torque : 0 )
        }

        let wheelRPM = spec.wheelRPM( forSpeed : state.forwardSpeed, gear : next.gear )

        // Clutch disengaged mid-shift: RPM falls towards the new gear, no drive.
        if state.shiftTimeRemaining > 0 {
            next.shiftTimeRemaining = max( state.shiftTimeRemaining - timeStep, 0 )
            next.engineRPM = approach( state.engineRPM, max( wheelRPM, spec.idleRPM ), 14_000 * timeStep )
            return EngineOutput( torque : 0 )
        }

        // Slipping clutch in first/reverse keeps the engine in its power band from a standstill.
        var targetRPM = max( wheelRPM * ( 1 + next.wheelspin * 0.55 ), spec.idleRPM )

        if abs( next.gear ) == 1 {
            let clutchRPM = spec.idleRPM + throttle * ( spec.redlineRPM - spec.idleRPM ) * 0.42
            targetRPM = max( targetRPM, clutchRPM )
        }

        targetRPM = max( targetRPM, next.launchRPM )
        next.engineRPM = min( approach( state.engineRPM, targetRPM, 20_000 * timeStep ), spec.redlineRPM * 1.01 )
        let isOnLimiter = applyLimiter( &next, timeStep : timeStep )

        guard !isOnLimiter else {
            return EngineOutput( torque : 0 )
        }

        if throttle < 0.02 {
            let engineBraking = -spec.peakTorqueNewtonMetres * 0.14 * ( next.engineRPM / spec.redlineRPM )
            return EngineOutput( torque : next.gear > 0 ? engineBraking : 0 )
        }

        var torque = spec.torque( atRPM : next.engineRPM, boost : next.turboSpool ) * throttle

        if next.isNitrousActive {
            torque *= 1 + spec.nitrousBoost
        }

        if next.perfectShiftBoostRemaining > 0 {
            torque *= 1.05
        }

        if next.launchBogRemaining > 0 {
            torque *= 0.55
        }

        return EngineOutput( torque : torque )
    }

    @discardableResult
    private func applyLimiter( _ state : inout VehicleState, timeStep : Double ) -> Bool {
        guard state.engineRPM >= spec.redlineRPM else {
            state.limiterTime = 0
            return false
        }

        state.limiterTime += timeStep
        state.engineRPM = spec.redlineRPM * 0.985
        state.events.insert( .limiter )
        return true
    }

    // MARK: - Precomputation

    /// Upshift point that maximises wheel force: where the next gear starts pulling harder.
    private static func computeIdealUpshifts( for spec : VehicleSpec ) -> [Double] {
        ( 1 ..< max( spec.gearCount, 1 ) ).map { gear in
            let currentRatio = spec.overallRatio( forGear : gear )
            let nextRatio = spec.overallRatio( forGear : gear + 1 )
            let step = ( spec.redlineRPM - spec.peakTorqueRPM ) / 80

            for rpm in stride( from : spec.peakTorqueRPM, through : spec.redlineRPM, by : max( step, 1 ) ) {
                let currentForce = spec.torque( atRPM : rpm, boost : 1 ) * currentRatio
                let nextRPM = rpm * nextRatio / currentRatio
                let nextForce = spec.torque( atRPM : nextRPM, boost : 1 ) * nextRatio

                if nextForce >= currentForce {
                    return min( rpm, spec.redlineRPM * 0.985 )
                }
            }

            return spec.redlineRPM * 0.985
        }
    }

    /// Launch RPM at which first-gear drive force just meets the traction of the driven wheels.
    private static func computeIdealLaunchRPM( for spec : VehicleSpec ) -> Double {
        let weight = spec.massKilograms * Units.gravity
        let squat = 0.12
        let drivenLoad : Double

        switch spec.drivetrain {
        case .fwd:
            drivenLoad = weight * ( spec.frontWeightFraction - squat )
        case .rwd:
            drivenLoad = weight * ( 1 - spec.frontWeightFraction + squat )
        case .awd:
            drivenLoad = weight
        }

        let traction = drivenLoad * spec.tyreGrip * spec.tyre.longitudinalGrip * 1.05
        let ratio = spec.overallRatio( forGear : 1 ) * spec.drivelineEfficiency / spec.wheelRadius
        let lowest = spec.redlineRPM * 0.3
        let highest = spec.redlineRPM * 0.85

        for rpm in stride( from : lowest, through : highest, by : 50 ) {
            if spec.torque( atRPM : rpm, boost : 0.6 ) * ratio >= traction {
                return rpm
            }
        }

        return max( spec.peakTorqueRPM, lowest )
    }
}
