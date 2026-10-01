import Foundation
import Testing
@testable import Shiftline

struct VehiclePhysicsTests {
    @Test func hatchbackReachesHundredInBelievableTime() {
        let time = TestSupport.timeToSpeed( TestSupport.spec( "hayase-pip" ), speed : 100 / 3.6 )
        #expect( time > 7 && time < 12 )
    }

    @Test func morePowerfulCarsAccelerateFaster() {
        let hatch = TestSupport.timeToSpeed( TestSupport.spec( "hayase-pip" ), speed : 100 / 3.6 )
        let supercar = TestSupport.timeToSpeed( TestSupport.spec( "veltra-vortex" ), speed : 100 / 3.6 )
        let hypercar = TestSupport.timeToSpeed( TestSupport.spec( "aurex-fulmine" ), speed : 100 / 3.6 )
        #expect( supercar < hatch )
        #expect( hypercar < supercar )
    }

    @Test func topSpeedIsLimitedByDragAndGearing() {
        let spec = TestSupport.spec( "hayase-pip" )
        let model = VehicleModel( spec : spec )
        var state = model.initialState( at : .zero, heading : 0 )
        var input = VehicleInput()
        input.throttle = 1

        for _ in 0 ..< 120 * 90 {
            state = model.advancing( state, with : input )
        }

        let kph = state.speed * 3.6
        #expect( kph > 150 && kph < 200 )
    }

    @Test func brakingStopsTheCarWithoutReversing() {
        let model = VehicleModel( spec : TestSupport.spec( "veltra-aria" ) )
        var state = model.initialState( at : .zero, heading : 0 )
        state.velocity = Vec2( 30, 0 )
        state.gear = 4
        var input = VehicleInput()
        input.brake = 1
        var time = 0.0

        while state.speed > 0.01 && time < 10 {
            state = model.advancing( state, with : input )
            time += VehicleModel.timeStep
        }

        #expect( state.speed < 0.05 )
        #expect( time < 4.5 )
        #expect( state.forwardSpeed >= -0.01 )
    }

    @Test func positiveSteeringTurnsLeft() {
        let model = VehicleModel( spec : TestSupport.spec( "hayase-pip" ) )
        var state = model.initialState( at : .zero, heading : 0 )
        state.velocity = Vec2( 15, 0 )
        state.gear = 2
        var input = VehicleInput()
        input.throttle = 0.4
        input.steering = 1

        for _ in 0 ..< 120 {
            state = model.advancing( state, with : input )
        }

        #expect( state.heading > 0.2 )
        #expect( state.position.y > 0 )
    }

    @Test func corneringAtFullThrottleAndHighSpeedLosesGrip() {
        let model = VehicleModel( spec : TestSupport.spec( "brannock-outlaw" ) )
        var state = model.initialState( at : .zero, heading : 0 )
        state.velocity = Vec2( 45, 0 )
        state.gear = 4
        var input = VehicleInput()
        input.throttle = 1
        input.steering = 1

        for _ in 0 ..< 240 {
            state = model.advancing( state, with : input, assists : .none )
        }

        // Tyres saturate: the car slides instead of following the steered path.
        #expect( state.rearSlide > 0.5 || state.frontSlide > 0.5 )
    }

    @Test func perfectShiftIsRatedAndFasterThanEarlyShift() {
        let model = VehicleModel( spec : TestSupport.spec( "veltra-aria" ) )
        var state = model.initialState( at : .zero, heading : 0 )
        state.gear = 2
        state.engineRPM = model.idealUpshiftRPM( fromGear : 2 )
        let perfect = model.shiftingUp( state )
        #expect( perfect.lastShiftQuality == .perfect )
        #expect( perfect.gear == 3 )

        state.engineRPM = model.spec.peakTorqueRPM * 0.8
        let early = model.shiftingUp( state )
        #expect( early.lastShiftQuality == .early )
        #expect( early.shiftTimeRemaining > perfect.shiftTimeRemaining )
    }

    @Test func downshiftIsRefusedWhenItWouldOverRev() {
        let model = VehicleModel( spec : TestSupport.spec( "hayase-pip" ) )
        var state = model.initialState( at : .zero, heading : 0 )
        state.gear = 4
        state.velocity = Vec2( 45, 0 )
        let result = model.shiftingDown( state )
        #expect( result.gear == 4 )
    }

    @Test func revLimiterCutsPower() {
        let model = VehicleModel( spec : TestSupport.spec( "hayase-pip" ) )
        var state = model.initialState( at : .zero, heading : 0 )
        var input = VehicleInput()
        input.throttle = 1
        var assists = DrivingAssists()
        assists.automaticTransmission = false
        var hitLimiter = false

        for _ in 0 ..< 120 * 8 {
            state = model.advancing( state, with : input, assists : assists )
            hitLimiter = hitLimiter || state.events.contains( .limiter )
        }

        #expect( hitLimiter )
        #expect( state.gear == 1 )
        #expect( state.engineRPM <= model.spec.redlineRPM * 1.01 )
    }

    @Test func skilledManualShiftingBeatsAutomatic() {
        let spec = TestSupport.spec( "veltra-aria" )
        var manual = DrivingAssists()
        manual.automaticTransmission = false
        let automaticTime = TestSupport.timeToSpeed( spec, speed : 160 / 3.6 )
        let manualTime = TestSupport.timeToSpeed( spec, speed : 160 / 3.6, assists : manual )
        #expect( manualTime < automaticTime )
        #expect( automaticTime - manualTime < 2.5 )
    }

    @Test func allWheelDriveLaunchesHarderThanRearWheelDrive() {
        var rear = TestSupport.spec( "hayase-zenith-r" )
        rear.drivetrain = .rwd
        var all = rear
        all.drivetrain = .awd
        let rearTime = TestSupport.timeToSpeed( rear, speed : 60 / 3.6, assists : .none )
        let allTime = TestSupport.timeToSpeed( all, speed : 60 / 3.6, assists : .none )
        #expect( allTime < rearTime )
    }

    @Test func tractionControlLimitsWheelspin() {
        let spec = TestSupport.spec( "brannock-goliath" )
        let model = VehicleModel( spec : spec )
        var input = VehicleInput()
        input.throttle = 1
        var withoutTC = model.initialState( at : .zero, heading : 0 )
        var withTC = withoutTC
        var assists = DrivingAssists.none
        assists.automaticTransmission = true

        for _ in 0 ..< 60 {
            withoutTC = model.advancing( withoutTC, with : input, assists : assists )
        }

        assists.tractionControl = true

        for _ in 0 ..< 60 {
            withTC = model.advancing( withTC, with : input, assists : assists )
        }

        #expect( withoutTC.wheelspin > 0.3 )
        #expect( withTC.wheelspin < withoutTC.wheelspin )
    }

    @Test func handbrakeProvokesRearSlideOnRearDrive() {
        let model = VehicleModel( spec : TestSupport.spec( "hayase-kite-s" ) )
        var state = model.initialState( at : .zero, heading : 0 )
        state.velocity = Vec2( 20, 0 )
        state.gear = 3
        var input = VehicleInput()
        input.steering = 0.8
        input.handbrake = true
        input.throttle = 0.5

        for _ in 0 ..< 90 {
            state = model.advancing( state, with : input, assists : .none )
        }

        #expect( state.driftAngleDegrees > 12 )
    }

    @Test func nitrousIncreasesAcceleration() {
        var spec = TestSupport.spec( "hayase-tempo-z" )
        spec.nitrousCapacity = 10
        let model = VehicleModel( spec : spec )
        var input = VehicleInput()
        input.throttle = 1
        var plain = model.initialState( at : .zero, heading : 0 )
        var boosted = plain

        for _ in 0 ..< 240 {
            plain = model.advancing( plain, with : input )
        }

        input.nitrous = true

        for _ in 0 ..< 240 {
            boosted = model.advancing( boosted, with : input )
        }

        #expect( boosted.speed > plain.speed )
        #expect( boosted.nitrousRemaining < spec.nitrousCapacity )
    }

    @Test func turboNeedsTimeToSpool() {
        let model = VehicleModel( spec : TestSupport.spec( "hayase-arc-s" ) )
        var state = model.initialState( at : .zero, heading : 0 )
        state.gear = 3
        state.velocity = Vec2( 22, 0 )
        var input = VehicleInput()
        input.throttle = 1
        state = model.advancing( state, with : input )
        let early = state.turboSpool

        for _ in 0 ..< 180 {
            state = model.advancing( state, with : input )
        }

        #expect( early < 0.1 )
        #expect( state.turboSpool > early )
    }

    @Test func uphillGradeSlowsAcceleration() {
        let spec = TestSupport.spec( "norrvik-fjell" )
        let model = VehicleModel( spec : spec )
        var input = VehicleInput()
        input.throttle = 1
        var flat = model.initialState( at : .zero, heading : 0 )
        var climbing = flat
        var hill = SurfaceContact()
        hill.slope = Vec2( 0.1, 0 )

        for _ in 0 ..< 600 {
            flat = model.advancing( flat, with : input )
            climbing = model.advancing( climbing, with : input, on : hill )
        }

        #expect( climbing.speed < flat.speed )
    }

    @Test func rainReducesCorneringGrip() {
        let model = VehicleModel( spec : TestSupport.spec( "veltra-aria" ) )
        var dry = model.initialState( at : .zero, heading : 0 )
        dry.velocity = Vec2( 30, 0 )
        dry.gear = 3
        var wet = dry
        var rain = SurfaceContact()
        rain.gripMultiplier = Weather.rain.gripMultiplier
        var input = VehicleInput()
        input.steering = 1
        input.throttle = 0.3
        var peakDry = 0.0
        var peakWet = 0.0

        for _ in 0 ..< 180 {
            dry = model.advancing( dry, with : input, assists : .none )
            wet = model.advancing( wet, with : input, on : rain, assists : .none )
            peakDry = max( peakDry, abs( dry.lateralAcceleration ) )
            peakWet = max( peakWet, abs( wet.lateralAcceleration ) )
        }

        #expect( peakWet < peakDry )
    }

    @Test func autoReverseEngagesAfterHoldingBrake() {
        let model = VehicleModel( spec : TestSupport.spec( "hayase-pip" ) )
        var state = model.initialState( at : .zero, heading : 0 )
        var input = VehicleInput()
        input.brake = 1

        for _ in 0 ..< 120 {
            state = model.advancing( state, with : input )
        }

        #expect( state.gear == -1 )
        #expect( state.forwardSpeed < -0.1 )
    }

    @Test func generatedGearsAreDescending() {
        for car in Cars.all {
            let ratios = car.baseSpec.gearRatios
            #expect( zip( ratios, ratios.dropFirst() ).allSatisfy { $0 > $1 }, "\( car.id )" )
        }
    }

    /// Runs full brake with the given steering from 45 m/s on a wet road; returns sideways movement and stopping distance.
    private func wetBraking( _ carID : CarID, steering : Double ) -> ( sideways : Double, distance : Double ) {
        let model = VehicleModel( spec : TestSupport.spec( carID ) )
        var state = model.initialState( at : .zero, heading : 0 )
        state.velocity = Vec2( 45, 0 )
        state.gear = 4
        var contact = SurfaceContact()
        contact.gripMultiplier = Weather.rain.gripMultiplier
        var input = VehicleInput()
        input.brake = 1
        input.steering = steering
        var steps = 0

        while state.speed > 5 && steps < 120 * 10 {
            state = model.advancing( state, with : input, on : contact, assists : DrivingAssists(), by : VehicleModel.timeStep )
            steps += 1
        }

        return ( state.position.y, state.position.x )
    }

    @Test func antiLockBrakesLeaveGripToSteerInTheWet() {
        for carID in [ "hayase-pip", "kazeru-hikari", "aurex-fulmine" ] {
            let straight = wetBraking( carID, steering : 0 )
            let turning = wetBraking( carID, steering : 1 )

            // Steering left while braking must move the car left, a long way; it used to slide straight on.
            #expect( turning.sideways > 8, "\( carID ) moved \( turning.sideways ) m" )
            #expect( abs( straight.sideways ) < 0.5 )
            // Giving up some braking for the turn must not cost much distance.
            #expect( turning.distance < straight.distance * 1.5 )
        }
    }

    /// Wet road, traction and stability control off: hold the throttle flat and half lock from 108 km/h for three seconds.
    private func wetPowerSlide( _ carID : CarID, tyre : TyreCompound ) -> Double {
        var spec = TestSupport.spec( carID )
        spec.tyre = tyre
        let model = VehicleModel( spec : spec )
        var state = model.initialState( at : .zero, heading : 0 )
        state.velocity = Vec2( 30, 0 )
        state.gear = 3
        var contact = SurfaceContact()
        contact.gripMultiplier = Weather.rain.gripMultiplier
        var assists = DrivingAssists.none
        assists.antiLockBrakes = true
        var input = VehicleInput()
        input.throttle = 1
        input.steering = 0.5
        var worstSlide = 0.0

        for _ in 0 ..< 360 {
            state = model.advancing( state, with : input, on : contact, assists : assists, by : VehicleModel.timeStep )
            worstSlide = max( worstSlide, state.driftAngleDegrees )
        }

        return worstSlide
    }

    @Test func roadTyresStayPlantedUnderPowerWithoutAidsButDriftTyresLetGo() {
        for carID in [ "hayase-kite-s", "kazeru-hikari", "wrenfield-peregrine" ] {
            let street = wetPowerSlide( carID, tyre : .street )
            let drift = wetPowerSlide( carID, tyre : .drift )
            #expect( street < 25, "\( carID ) slid to \( street )° on street tyres" )
            #expect( drift > street, "\( carID ) street \( street )° drift \( drift )°" )
        }
    }
}
