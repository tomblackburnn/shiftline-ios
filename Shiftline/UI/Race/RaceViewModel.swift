import CoreMotion
import Foundation
import Observation
import SpriteKit
import UIKit

struct Banner : Identifiable, Equatable {
    enum Tone {
        case neutral
        case good
        case great
        case bad
    }

    let id = UUID()
    let text : String
    var detail : String?
    var tone : Tone = .neutral
    var expires : Date
}

struct DriftHUD : Equatable {
    var total : Int
    var pending : Int
    var multiplier : Double
    var angle : Double
    var isDrifting : Bool
    var isInZone : Bool
}

struct RaceHUD : Equatable {
    var speed = 0
    var gear = "N"
    var rpmFraction = 0.0
    var shiftWindow : ClosedRange<Double> = 0.9 ... 0.97
    var isOnLimiter = false
    var boost = 0.0
    var nitrousFraction : Double?
    /// Slipstream charge 0...1 while drafting.
    var slipstreamCharge = 0.0
    var isBoosting = false
    var items : [HUDItem] = []
    var countdown : Int?
    var wrongWay = false
    var drift : DriftHUD?
    var tutorialInstruction : String?
    var tutorialHint : String?
    var isManual = false
}

/// Couples a RaceSession to its scene, controls, HUD, audio and haptics.
@Observable
final class RaceViewModel {
    let race : PendingRace
    let session : RaceSession
    @ObservationIgnored let scene : RaceScene
    private( set ) var hud = RaceHUD()
    private( set ) var banners : [Banner] = []
    private( set ) var carDots : [( position : CGPoint, isPlayer : Bool, isEliminated : Bool )] = []
    var isPaused = false
    private( set ) var isFinishing = false
    private( set ) var outcome : RaceOutcome?
    private( set ) var rewards : RaceRewards?

    // Controls written by the control overlay.
    @ObservationIgnored var throttleHeld = false
    @ObservationIgnored var brakeHeld = false
    @ObservationIgnored var steerInput = 0.0
    @ObservationIgnored var handbrakeHeld = false
    @ObservationIgnored var nitrousHeld = false

    @ObservationIgnored private var hudTimer = 0.0
    @ObservationIgnored private var finishTimer = 0.0
    @ObservationIgnored private var smoothedThrottle = 0.0
    @ObservationIgnored private var smoothedBrake = 0.0
    @ObservationIgnored private var smoothedSteer = 0.0
    /// One manager for the whole app: Core Motion delivers unreliably when several exist.
    private static let motion = CMMotionManager()
    @ObservationIgnored private let settings : GameSettings
    @ObservationIgnored private weak var store : GameStore?
    @ObservationIgnored private var offTrackFieldTask : Task<[( String, Double )], Never>?
    @ObservationIgnored private var lastKerbHaptic = 0.0
    @ObservationIgnored private var isResolvingOutcome = false
    @ObservationIgnored private var isTornDown = false

    init( race : PendingRace, store : GameStore ) {
        self.race = race
        self.store = store
        settings = store.settings
        session = RaceSession( config : OffscreenField.onTrackConfig( for : race.config, context : race.context ) )
        scene = RaceScene( session : session, size : CGSize( width : 844, height : 390 ) )
        scene.cameraShakeEnabled = settings.cameraShake && !UIAccessibility.isReduceMotionEnabled
        Haptics.shared.isEnabled = settings.hapticsEnabled

        let player = race.config.player
        let definition = player.flatMap { Cars.named( $0.carID ) }
        let exhaustLevel = store.selectedCar.map { Double( $0.level( of : .exhaust ) ) / 4 } ?? 0
        GameAudio.shared.playerEngine.parameters.cylinders = Double( definition?.cylinders ?? 4 )
        GameAudio.shared.playerEngine.parameters.exhaust = exhaustLevel
        GameAudio.shared.engineVolume = settings.engineVolume
        GameAudio.shared.effectsVolume = settings.effectsVolume
        GameAudio.shared.playMusic( race.context.rivalID != nil ? .rival : ( race.context.championshipID != nil ? .championship : .race ), volume : settings.musicVolume * 0.35 )

        scene.onFrame = { [weak self] delta in
            self?.frame( delta )
        }

        startOffscreenField()

        #if DEBUG
        if DebugLaunch.isAutopilot {
            session.player.ai = AIDriver( profile : Opponents.pool[ 3 ], skill : 0.8, seed : "autopilot" )
            session.player.assists.automaticTransmission = true
        }
        #endif
    }

    func tearDown() {
        guard !isTornDown else {
            return
        }

        isTornDown = true
        RaceViewModel.motion.stopDeviceMotionUpdates()
        scene.onFrame = nil
        scene.isPaused = true
        offTrackFieldTask?.cancel()
        GameAudio.shared.silenceRaceVoices()
        GameAudio.shared.playMusic( .menu, volume : settings.musicVolume * 0.5 )
    }

    var isTutorial : Bool {
        race.context.tutorial != nil
    }

    // MARK: - Frame loop

    private func frame( _ delta : Double ) {
        guard !isPaused else {
            GameAudio.shared.playerEngine.parameters.volume = 0
            GameAudio.shared.opponentEngine.parameters.volume = 0
            return
        }

        applyControls( delta )
        session.advance( by : delta )
        handleEvents()
        updateAudio()
        updateContinuousHaptics( delta )

        hudTimer += delta

        if hudTimer >= 1.0 / 30 {
            hudTimer = 0
            refreshHUD()
        }

        if session.phase == .finished && outcome == nil {
            isFinishing = true
            finishTimer += delta

            if finishTimer > 2.2 {
                finish()
            }
        }
    }

    private func applyControls( _ delta : Double ) {
        let throttleTarget = throttleHeld ? 1.0 : 0
        let brakeTarget = brakeHeld ? 1.0 : 0
        smoothedThrottle = approach( smoothedThrottle, throttleTarget, delta * ( throttleTarget > smoothedThrottle ? 7 : 12 ) )
        smoothedBrake = approach( smoothedBrake, brakeTarget, delta * 10 )

        // Read live so a steering mode chosen from the pause menu takes effect straight away.
        let controls = store?.settings ?? settings
        let motion = RaceViewModel.motion
        var steer = steerInput

        if controls.steeringMode == .tilt {
            if !motion.isDeviceMotionActive && motion.isDeviceMotionAvailable {
                motion.deviceMotionUpdateInterval = 1.0 / 60
                motion.startDeviceMotionUpdates()
            }

            // Held like a wheel in landscape, turning the phone moves gravity along its long (y) axis.
            if let gravity = motion.deviceMotion?.gravity {
                let orientation = scene.view?.window?.windowScene?.interfaceOrientation ?? .landscapeRight
                let sign : Double = orientation == .landscapeLeft ? -1 : 1
                steer = clamp( gravity.y * sign * 2.6 * controls.tiltSensitivity, -1, 1 )
            }
        } else if motion.isDeviceMotionActive {
            motion.stopDeviceMotionUpdates()
        }

        smoothedSteer = controls.steeringMode == .buttons ? approach( smoothedSteer, steer, delta * 6 ) : steer
        session.controls = PlayerControls(
            throttle : smoothedThrottle,
            brake : smoothedBrake,
            steering : smoothedSteer,
            handbrake : handbrakeHeld,
            nitrous : nitrousHeld
        )
    }

    func shiftUp() {
        session.shiftUp()
    }

    func shiftDown() {
        session.shiftDown()
    }

    func resetCar() {
        session.resetToTrack( session.player )
        session.player.penaltySeconds += session.config.kind == .practice ? 0 : 2
        addBanner( "RESET", detail : session.config.kind == .practice ? nil : "+2.0s", tone : .bad )
    }

    // MARK: - Events

    private func handleEvents() {
        let audio = GameAudio.shared
        let player = session.player

        if player.pendingEvents.contains( .blowOff ) {
            audio.play( .blowOff, volume : 0.6 )
        }

        if player.pendingEvents.contains( .backfire ) {
            audio.play( .backfire, volume : 0.8 )
        }

        if player.pendingEvents.contains( .nitrousStart ) {
            audio.play( .nitrous )
            scene.kick( 0.25 )
        }

        if player.pendingEvents.contains( .lockup ) {
            audio.play( .brakeLock, volume : 0.5 )
        }

        if player.pendingEvents.contains( .upshift ) || player.pendingEvents.contains( .downshift ) {
            audio.play( .shift, volume : 0.7 )
        }

        for car in session.cars {
            car.pendingEvents = []
        }

        for event in session.drainEvents() {
            switch event {
            case .countdown( let number ):
                audio.play( .countdown, volume : number == 1 ? 1 : 0.7 )
                Haptics.shared.play( .countdown )
            case .go:
                audio.play( .go )
                Haptics.shared.play( .go )
                scene.kick( 0.3 )
                addBanner( "GO!", tone : .great, duration : 1 )
            case .start( let quality ):
                if quality == .tooEarly {
                    addBanner( quality.title, detail : "TOO EARLY", tone : .bad )
                } else {
                    audio.play( .nitrous )
                    Haptics.shared.play( .launch )
                    scene.kick( quality == .perfect ? 0.5 : 0.3 )
                    addBanner( quality.title, detail : "BOOST", tone : quality == .perfect ? .great : .good )
                }
            case .slingshot:
                audio.play( .nitrous )
                Haptics.shared.play( .launch )
                scene.kick( 0.3 )
                addBanner( "SLINGSHOT", detail : "SLIPSTREAM BOOST", tone : .great, duration : 1.2 )
            case .shift( let quality ):
                Haptics.shared.play( .shift( perfect : quality == .perfect ) )

                if quality == .perfect {
                    scene.kick( 0.15 )
                }

                addBanner( quality.title + " SHIFT", tone : quality == .perfect ? .great : ( quality == .good ? .good : .bad ), duration : 0.9 )
            case .lap( _, let time, let isBest, let isValid ):
                audio.play( .lap )
                let label = isValid ? ( isBest ? "BEST LAP" : "LAP" ) : "LAP INVALID"
                addBanner( label, detail : RaceFormat.time( time ), tone : isValid ? ( isBest ? .great : .good ) : .bad )
            case .finalLap:
                addBanner( "FINAL LAP", tone : .great )
            case .checkpoint( _, let bonus ):
                audio.play( .checkpoint )
                addBanner( "CHECKPOINT", detail : String( format : "+%.1fs", bonus ), tone : .good )
            case .sector( let index, _, let delta ):
                if let delta {
                    addBanner( "SECTOR \( index + 1 )", detail : RaceFormat.delta( delta ), tone : delta <= 0 ? .great : .bad, duration : 1.2 )
                }
            case .collision( _, let intensity, let withWall, let point ):
                audio.play( intensity > 8 ? .crashHeavy : .crashLight, volume : clamp( intensity / 10, 0.3, 1 ) )
                Haptics.shared.play( .collision( intensity ) )
                scene.impact( at : point, intensity : intensity )

                if withWall && intensity > 10 {
                    addBanner( "HEAVY IMPACT", tone : .bad, duration : 1 )
                }
            case .overtake:
                if session.phase == .racing {
                    addBanner( "P\( session.player.position )", detail : "OVERTAKE", tone : .good, duration : 1.2 )
                }
            case .positionLost:
                break
            case .eliminated( let car, let name ):
                audio.play( .eliminated )
                addBanner( car == session.player.id ? "ELIMINATED" : "OUT", detail : car == session.player.id ? nil : name, tone : .bad, duration : 2 )
            case .trackLimits( let car, let penalty, let invalidated ):
                if car == session.player.id {
                    addBanner( "TRACK LIMITS", detail : invalidated ? "LAP INVALIDATED" : String( format : "+%.1fs", penalty ), tone : .bad )
                }
            case .wrongWay:
                addBanner( "WRONG WAY", tone : .bad, duration : 1.5 )
            case .drift( let driftEvent ):
                handleDrift( driftEvent )
            case .speedTrap( _, let speed ):
                audio.play( .checkpoint )
                let unit = settings.speedUnit
                addBanner( "SPEED TRAP", detail : "\( Int( unit.value( fromKPH : speed ) ) ) \( unit.title )", tone : .great )
            case .finished( let position ):
                audio.play( .reward )
                Haptics.shared.play( .finish )
                let text = session.config.kind.isScored || isTutorial ? "FINISHED" : "P\( position )"
                addBanner( text, detail : "FINISH", tone : position == 1 ? .great : .good, duration : 2.5 )
            case .timeUp:
                audio.play( .eliminated )
                addBanner( "TIME UP", tone : .bad, duration : 2.5 )
            case .message( let text ):
                audio.play( .checkpoint, volume : 0.6 )
                addBanner( text, tone : .great, duration : 1.4 )
            }
        }
    }

    private func handleDrift( _ event : DriftEvent ) {
        switch event {
        case .started:
            break
        case .transition( let bonus ):
            Haptics.shared.play( .driftTransition )
            addBanner( "TRANSITION", detail : "+\( bonus )", tone : .good, duration : 1 )
        case .clip( let bonus ):
            addBanner( "CLIPPING POINT", detail : "+\( bonus )", tone : .great, duration : 1 )
        case .banked( let points, let multiplier ):
            GameAudio.shared.play( .driftBank, volume : 0.7 )
            addBanner( "+\( RaceFormat.points( points ) )", detail : String( format : "×%.1f BANKED", multiplier ), tone : .great, duration : 1.4 )
        case .failed( let reason ):
            addBanner( reason, detail : "COMBO LOST", tone : .bad, duration : 1.4 )
        case .multiplierUp( let multiplier ):
            addBanner( String( format : "×%.1f", multiplier ), tone : .good, duration : 0.8 )
        }
    }

    private func addBanner( _ text : String, detail : String? = nil, tone : Banner.Tone, duration : Double = 1.6 ) {
        banners.removeAll { $0.expires < Date() }

        if banners.count >= 3 {
            banners.removeFirst()
        }

        banners.append( Banner( text : text, detail : detail, tone : tone, expires : Date().addingTimeInterval( duration ) ) )
    }

    // MARK: - Audio and haptics

    private func updateAudio() {
        let audio = GameAudio.shared
        let player = session.player
        let state = player.state
        let engine = audio.playerEngine.parameters
        engine.rpm = state.engineRPM
        engine.load = state.shiftTimeRemaining > 0 ? 0.1 : max( state.throttle, 0.08 )
        engine.volume = 0.55 * audio.engineVolume
        engine.boost = state.turboSpool * ( player.model.spec.turboBoost > 0 ? 1 : 0 )
        engine.isLimiting = state.limiterTime > 0

        // Nearest opponent is audible too.
        let nearest = session.cars
            .filter { !$0.isPlayer && !$0.isEliminated }
            .min { ( $0.state.position - state.position ).lengthSquared < ( $1.state.position - state.position ).lengthSquared }

        if let nearest {
            let distance = ( nearest.state.position - state.position ).length
            let opponent = audio.opponentEngine.parameters
            opponent.rpm = nearest.state.engineRPM
            opponent.load = nearest.state.throttle
            opponent.cylinders = Double( Cars.named( nearest.entrant.carID )?.cylinders ?? 4 )
            opponent.volume = audio.engineVolume * 0.35 * clamp( 1 - distance / 60, 0, 1 )
        } else {
            audio.opponentEngine.parameters.volume = 0
        }

        let tyres = audio.tyres.parameters
        let slide = max( state.rearSlide - 0.55, 0 ) + max( state.frontSlide - 0.6, 0 ) * 0.7 + state.wheelspin * 0.8
        tyres.squeal = clamp( slide * ( state.speed > 3 ? 1 : 0.3 ), 0, 1 ) * 0.5 * audio.effectsVolume
        tyres.skid = state.isLockingWheels ? 0.4 * audio.effectsVolume : 0
        tyres.rumble = player.surface == .kerb && state.speed > 5 ? 0.5 : ( player.surface == .runoff && state.speed > 5 ? 0.3 : 0 )
        tyres.wind = clamp( state.speed / 90, 0, 1 ) * 0.35 * audio.effectsVolume
    }

    private func updateContinuousHaptics( _ delta : Double ) {
        let state = session.player.state
        lastKerbHaptic += delta

        guard lastKerbHaptic > 0.1 else {
            return
        }

        lastKerbHaptic = 0

        if session.player.surface == .kerb && state.speed > 8 {
            Haptics.shared.play( .kerb )
        } else if state.wheelspin > 0.35 {
            Haptics.shared.play( .wheelspin( state.wheelspin ) )
        }
    }

    // MARK: - HUD

    private func refreshHUD() {
        let player = session.player
        let state = player.state
        let spec = player.model.spec
        var updated = RaceHUD()
        updated.speed = Int( settings.speedUnit.value( fromMetresPerSecond : state.speed ) )

        switch state.gear {
        case -1:
            updated.gear = "R"
        case 0:
            updated.gear = "N"
        default:
            updated.gear = "\( state.gear )"
        }

        updated.rpmFraction = state.engineRPM / spec.redlineRPM
        let ideal = player.model.idealUpshiftRPM( fromGear : max( state.gear, 1 ) ) / spec.redlineRPM
        updated.shiftWindow = ( ideal - 0.045 ) ... min( ideal + 0.03, 1 )
        updated.isOnLimiter = state.limiterTime > 0
        updated.boost = state.turboSpool
        updated.nitrousFraction = spec.nitrousCapacity > 0 ? state.nitrousRemaining / spec.nitrousCapacity : nil
        updated.slipstreamCharge = player.slipstreamCharge.level
        updated.isBoosting = player.boostRemaining > 0
        updated.items = session.mode.hudItems( session )
        updated.countdown = session.phase == .countdown ? Int( session.countdownRemaining.rounded( .up ) ) : nil
        updated.wrongWay = player.wrongWayTime > 1
        updated.isManual = !player.assists.automaticTransmission

        if case .drift( let format, _ ) = session.config.kind {
            let drift = session.drift
            updated.drift = DriftHUD(
                total : format == .chain ? drift.bestChain : drift.bankedScore,
                pending : Int( drift.pendingScore * drift.multiplier ),
                multiplier : drift.multiplier,
                angle : state.slipAngle * 180 / .pi,
                isDrifting : drift.isDrifting,
                isInZone : format != .sections || session.driftZones.contains { $0.contains( player.trackDistance ) }
            )
        } else if isTutorial, case .tutorial( .drifting ) = session.config.kind {
            updated.drift = DriftHUD(
                total : session.drift.bankedScore,
                pending : Int( session.drift.pendingScore * session.drift.multiplier ),
                multiplier : session.drift.multiplier,
                angle : state.slipAngle * 180 / .pi,
                isDrifting : session.drift.isDrifting,
                isInZone : true
            )
        }

        if let tutorial = session.mode as? TutorialMode, let step = tutorial.currentStep {
            updated.tutorialInstruction = step.instruction
            updated.tutorialHint = step.hint
        }

        hud = updated
        banners.removeAll { $0.expires < Date() }
        carDots = session.cars.map { car in
            ( car.state.position.cgPoint, car.isPlayer, car.isEliminated )
        }
    }

    // MARK: - Finish

    /// Championship time-attack rounds: the rest of the field sets real laps in a headless simulation meanwhile.
    private func startOffscreenField() {
        guard OffscreenField.runsFieldOffscreen( race.config, context : race.context ) else {
            return
        }

        let config = race.config
        offTrackFieldTask = Task.detached( priority : .utility ) {
            OffscreenField.scores( for : config )
        }
    }

    private func finish() {
        guard outcome == nil, !isResolvingOutcome, let store else {
            return
        }

        isResolvingOutcome = true
        var built = OutcomeBuilder.outcome( from : session, context : race.context )
        let offscreenTask = offTrackFieldTask

        Task { @MainActor in
            // Merge the off-screen field's times or scores into the championship order.
            if let offscreenTask {
                var results = await offscreenTask.value

                if let score = session.mode.playerScore( session ) {
                    results.append( ( "player", score ) )
                }

                let lowerIsBetter = OffscreenField.lowerIsBetter( race.config.kind )
                built.finishingOrder = results.sorted { lowerIsBetter ? $0.1 < $1.1 : $0.1 > $1.1 }.map { $0.0 }

                if !built.finishingOrder.contains( "player" ) {
                    built.finishingOrder.append( "player" )
                }

                built.placement = ( built.finishingOrder.firstIndex( of : "player" ) ?? 0 ) + 1
                built.fieldSize = built.finishingOrder.count
            }

            outcome = built
            rewards = store.complete( built, race : race )

            if let rewards, !rewards.unlockedAchievements.isEmpty {
                Haptics.shared.play( .achievement )
            }
        }
    }

    func quit() {
        tearDown()
        store?.activeRace = nil
    }

    func restart() {
        tearDown()
        store?.restart( race )
    }
}
