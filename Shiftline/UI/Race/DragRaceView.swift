import Observation
import SpriteKit
import SwiftUI

@Observable
final class DragViewModel {
    let pending : PendingRace
    @ObservationIgnored let race : DragRace
    @ObservationIgnored let scene : DragScene
    private( set ) var banners : [Banner] = []
    private( set ) var amberLit = 0
    private( set ) var isGreen = false
    private( set ) var isFoul = false
    private( set ) var hasLaunched = false
    private( set ) var speed = 0
    private( set ) var gear = "N"
    private( set ) var rpmFraction = 0.0
    private( set ) var shiftWindow : ClosedRange<Double> = 0.9 ... 0.97
    private( set ) var launchWindow : ClosedRange<Double> = 0.4 ... 0.5
    private( set ) var isLimiting = false
    private( set ) var playerProgress = 0.0
    private( set ) var opponentProgress = 0.0
    private( set ) var splits : [( String, Double )] = []
    private( set ) var nitrousFraction : Double?
    private( set ) var outcome : RaceOutcome?
    private( set ) var rewards : RaceRewards?
    var isPaused = false

    @ObservationIgnored var throttleHeld = false
    @ObservationIgnored var nitrousHeld = false
    @ObservationIgnored private var smoothedThrottle = 0.0
    @ObservationIgnored private var finishTimer = 0.0
    @ObservationIgnored private var hudTimer = 0.0
    @ObservationIgnored private weak var store : GameStore?
    @ObservationIgnored private let settings : GameSettings
    @ObservationIgnored private var fieldTask : Task<[( id : String, result : DragRunResult )], Never>?
    @ObservationIgnored private var isResolvingOutcome = false
    @ObservationIgnored private var isTornDown = false

    init( pending : PendingRace, store : GameStore ) {
        self.pending = pending
        self.store = store
        settings = store.settings
        let config = pending.config
        let layout = Tracks.named( config.trackID ) ?? Tracks.kestrelQuarter
        let length = TrackGeometry.dragLength( of : layout )
        let opponent = RaceFactory( save : store.save ).dragOpponent( for : config )
        let player = config.player ?? RaceFactory( save : store.save ).playerEntrant( for : store.selectedCar ?? OwnedCar( carID : Cars.starterIDs[ 0 ] ) )
        race = DragRace( length : length, player : player, opponent : opponent.entrant, opponentSkill : opponent.skill, seed : config.title + "\( Date().timeIntervalSince1970 )" )
        scene = DragScene( race : race, environment : layout.environment, timeOfDay : config.timeOfDay, size : CGSize( width : 844, height : 390 ) )
        scene.cameraShakeEnabled = settings.cameraShake && !UIAccessibility.isReduceMotionEnabled
        Haptics.shared.isEnabled = settings.hapticsEnabled

        let redline = race.player.model.spec.redlineRPM
        let window = race.player.model.launchWindow
        launchWindow = ( window.lowerBound / redline ) ... ( window.upperBound / redline )

        let audio = GameAudio.shared
        audio.playerEngine.parameters.cylinders = Double( Cars.named( player.carID )?.cylinders ?? 4 )
        audio.opponentEngine.parameters.cylinders = Double( Cars.named( opponent.entrant.carID )?.cylinders ?? 4 )
        audio.engineVolume = settings.engineVolume
        audio.effectsVolume = settings.effectsVolume
        audio.playMusic( pending.context.rivalID != nil ? .rival : .silent, volume : settings.musicVolume * 0.3 )

        scene.onFrame = { [weak self] delta in
            self?.frame( delta )
        }

        startField()
    }

    var tutorialPrompt : String? {
        guard pending.context.tutorial == .dragLaunch else {
            return nil
        }

        if !hasLaunched {
            return isGreen ? "GREEN! TAP LAUNCH NOW" : "HOLD GAS: KEEP THE NEEDLE IN THE BLUE WINDOW"
        }

        return race.isComplete ? nil : "TAP SHIFT WHEN THE BAR REACHES THE GREEN ZONE"
    }

    func tearDown() {
        guard !isTornDown else {
            return
        }

        isTornDown = true
        scene.onFrame = nil
        scene.isPaused = true
        fieldTask?.cancel()
        GameAudio.shared.silenceRaceVoices()
        GameAudio.shared.playMusic( .menu, volume : settings.musicVolume * 0.5 )
    }

    /// Championship drag rounds: every other competitor makes a real simulated pass.
    private func startField() {
        guard let championshipID = pending.context.championshipID,
              let championship = Championships.named( championshipID ),
              let progress = store?.save.championships[ championshipID ] else {
            return
        }

        let headsUpID = race.opponent.entrant.profile?.id
        let buildLevel = RaceFactory.aiBuildLevel( for : championship.tier )
        let profiles = ChampionshipRules().field( for : championship )
        let length = race.length
        let skill = championship.tier.opponentSkill + pending.config.difficulty.skillOffset
        let others = progress.standings.filter { !$0.isPlayer && $0.id != headsUpID }.compactMap { standing -> ( String, RaceEntrant, Double )? in
            guard let profile = profiles.first( where : { $0.id == standing.id } ) else {
                return nil
            }

            let entrant = RaceFactory.aiEntrant( profile : profile, car : RaceFactory.aiCar( standing.carID, buildLevel : buildLevel ), seed : championshipID )
            return ( standing.id, entrant, clamp( skill + profile.skill, 0, 1 ) )
        }

        fieldTask = Task.detached( priority : .utility ) {
            others.map { item in
                ( item.0, DragRace.simulatedPass( entrant : item.1, length : length, skill : item.2, seed : item.0 ) )
            }
        }
    }

    func launchOrShift() {
        if race.player.launchTime == nil {
            race.launchPlayer()
        } else {
            race.shiftUpPlayer()
        }
    }

    func shiftDown() {
        race.shiftDownPlayer()
    }

    private func frame( _ delta : Double ) {
        guard !isPaused else {
            GameAudio.shared.playerEngine.parameters.volume = 0
            GameAudio.shared.opponentEngine.parameters.volume = 0
            return
        }

        smoothedThrottle = approach( smoothedThrottle, throttleHeld ? 1 : 0, delta * ( throttleHeld ? 6 : 10 ) )
        #if DEBUG
        if DebugLaunch.isAutopilot {
            race.player.driveAI( phase : race.phase, time : race.clock, greenTime : race.greenTime )
        } else {
            race.player.throttle = race.isComplete ? 0 : smoothedThrottle
            race.player.nitrous = nitrousHeld
        }
        #else
        race.player.throttle = race.isComplete ? 0 : smoothedThrottle
        race.player.nitrous = nitrousHeld
        #endif

        // Automatic gearbox assist still shifts a little early.
        if settings.assists.automaticTransmission, race.player.launchTime != nil, race.player.state.gear >= 1 {
            let ideal = race.player.model.idealUpshiftRPM( fromGear : race.player.state.gear )

            if race.player.state.engineRPM >= ideal * 0.95 {
                race.shiftUpPlayer()
            }
        }

        race.advance( by : delta )
        handleEvents()
        updateAudio()

        hudTimer += delta

        if hudTimer > 1.0 / 30 {
            hudTimer = 0
            refreshHUD()
        }

        if race.isComplete && outcome == nil {
            finishTimer += delta

            if finishTimer > 1.6 {
                finish()
            }
        }
    }

    private func handleEvents() {
        let audio = GameAudio.shared
        let events = race.player.events
        race.player.events = []
        race.opponent.events = []

        if events.contains( .upshift ) {
            audio.play( .shift, volume : 0.8 )
        }

        if events.contains( .backfire ) {
            audio.play( .backfire )
        }

        if events.contains( .nitrousStart ) {
            audio.play( .nitrous )
            scene.kick( 0.3 )
        }

        for event in race.events {
            switch event {
            case .amber( let count ):
                amberLit = count
                audio.play( .countdown, volume : 0.6 )
                Haptics.shared.play( .countdown )
            case .green:
                isGreen = true
                audio.play( .go )
            case .launched( let rating, let reaction ):
                hasLaunched = true
                Haptics.shared.play( .launch )
                scene.kick( rating == .wheelspin ? 0.6 : 0.4 )
                let tone : Banner.Tone = rating.isClean ? .great : ( rating == .ok ? .good : .bad )
                addBanner( rating.title + " LAUNCH", detail : race.player.isFoul ? "RED LIGHT" : String( format : "REACTION %.3f", reaction ), tone : race.player.isFoul ? .bad : tone )
            case .foul:
                isFoul = true
                audio.play( .eliminated )
            case .shift( let quality ):
                Haptics.shared.play( .shift( perfect : quality == .perfect ) )

                if quality == .perfect {
                    scene.kick( 0.2 )
                }

                addBanner( quality.title + " SHIFT", tone : quality == .perfect ? .great : ( quality == .good ? .good : .bad ), duration : 0.9 )
            case .split( let label, let time ):
                splits.append( ( label, time ) )
            case .finished( let won ):
                audio.play( won ? .reward : .eliminated )
                Haptics.shared.play( .finish )
                addBanner( won ? "YOU WIN" : "YOU LOSE", tone : won ? .great : .bad, duration : 2 )
            }
        }

        race.events.removeAll()
    }

    private func addBanner( _ text : String, detail : String? = nil, tone : Banner.Tone, duration : Double = 1.6 ) {
        banners.removeAll { $0.expires < Date() }
        banners.append( Banner( text : text, detail : detail, tone : tone, expires : Date().addingTimeInterval( duration ) ) )
    }

    private func updateAudio() {
        let audio = GameAudio.shared

        for ( voice, racer, volume ) in [ ( audio.playerEngine, race.player, 0.6 ), ( audio.opponentEngine, race.opponent, 0.35 ) ] {
            let state = racer.state
            voice.parameters.rpm = state.engineRPM
            voice.parameters.load = state.shiftTimeRemaining > 0 ? 0.1 : max( racer.throttle, 0.08 )
            voice.parameters.volume = volume * audio.engineVolume
            voice.parameters.boost = state.turboSpool * ( racer.model.spec.turboBoost > 0 ? 1 : 0 )
            voice.parameters.isLimiting = state.limiterTime > 0
        }

        audio.tyres.parameters.squeal = clamp( race.player.state.wheelspin, 0, 1 ) * 0.6 * audio.effectsVolume
        audio.tyres.parameters.wind = clamp( race.player.state.speed / 90, 0, 1 ) * 0.35 * audio.effectsVolume

        if race.player.state.wheelspin > 0.3 {
            Haptics.shared.play( .wheelspin( race.player.state.wheelspin ) )
        }
    }

    private func refreshHUD() {
        let state = race.player.state
        let spec = race.player.model.spec
        hasLaunched = race.player.launchTime != nil
        speed = Int( settings.speedUnit.value( fromMetresPerSecond : state.speed ) )
        gear = state.gear == 0 ? "N" : ( state.gear < 0 ? "R" : "\( state.gear )" )
        rpmFraction = state.engineRPM / spec.redlineRPM
        let ideal = race.player.model.idealUpshiftRPM( fromGear : max( state.gear, 1 ) ) / spec.redlineRPM
        shiftWindow = ( ideal - 0.045 ) ... min( ideal + 0.03, 1 )
        isLimiting = state.limiterTime > 0
        playerProgress = clamp( race.player.distance / race.length, 0, 1 )
        opponentProgress = clamp( race.opponent.distance / race.length, 0, 1 )
        nitrousFraction = spec.nitrousCapacity > 0 ? state.nitrousRemaining / spec.nitrousCapacity : nil
        banners.removeAll { $0.expires < Date() }
    }

    private func finish() {
        guard outcome == nil, !isResolvingOutcome, let store else {
            return
        }

        isResolvingOutcome = true
        let task = fieldTask

        Task { @MainActor in
            let field = await task?.value ?? []
            var built = OutcomeBuilder.outcome( from : race, config : pending.config, context : pending.context, fieldResults : field )

            if pending.context.tutorial != nil {
                let result = race.player.result( greenTime : race.greenTime ?? 0 )
                built.didFinish = !result.isFoul && result.launch != .bogged
            }

            outcome = built
            rewards = store.complete( built, race : pending )
        }
    }

    func quit() {
        tearDown()
        store?.activeRace = nil
    }

    func restart() {
        tearDown()
        store?.restart( pending )
    }
}

struct DragRaceView : View {
    @State private var model : DragViewModel
    @State private var showsSettings = false
    @Environment( GameStore.self ) private var store

    init( race : PendingRace, store : GameStore ) {
        _model = State( initialValue : DragViewModel( pending : race, store : store ) )
    }

    var body : some View {
        ZStack {
            SpriteView( scene : model.scene, preferredFramesPerSecond : 60, options : [ .ignoresSiblingOrder ] )
                .ignoresSafeArea()

            if model.outcome == nil {
                hud
                controls
            }

            if model.isPaused && model.outcome == nil {
                PauseMenu(
                    title : model.pending.config.title,
                    onResume : { model.isPaused = false },
                    onRestart : { model.restart() },
                    onSettings : { showsSettings = true },
                    onQuit : { model.quit() }
                )
            }

            if let outcome = model.outcome {
                RaceResultsView(
                    outcome : outcome,
                    rewards : model.rewards,
                    race : model.pending,
                    dragRace : model.race,
                    onContinue : { model.quit() },
                    onRestart : { model.restart() }
                )
            }
        }
        .background( Color.black )
        .sheet( isPresented : $showsSettings ) {
            QuickSettingsSheet()
        }
        .onDisappear {
            model.tearDown()
        }
    }

    private var hud : some View {
        VStack {
            HStack( alignment : .top ) {
                ChristmasTree( amberLit : model.amberLit, isGreen : model.isGreen, isFoul : model.isFoul )

                VStack( alignment : .leading, spacing : 6 ) {
                    DistanceBar( player : model.playerProgress, opponent : model.opponentProgress )
                        .frame( width : 260, height : 24 )

                    ForEach( model.splits, id : \.0 ) { split in
                        HStack {
                            Text( split.0 )
                                .font( .label( 11, weight : .heavy ) )
                                .foregroundStyle( Theme.secondaryText )
                            Text( String( format : "%.3f", split.1 ) )
                                .font( .numeric( 14 ) )
                                .foregroundStyle( .white )
                        }
                    }
                }
                .padding( 10 )
                .background( Color.black.opacity( 0.45 ), in : RoundedRectangle( cornerRadius : 10 ) )

                Spacer()

                Button {
                    model.isPaused = true
                } label : {
                    Image( systemName : "pause.fill" )
                        .font( .system( size : 18, weight : .bold ) )
                        .foregroundStyle( .white )
                        .frame( width : 46, height : 40 )
                        .background( SlantedShape( slant : 6 ).fill( Color.black.opacity( 0.55 ) ) )
                }
                .accessibilityLabel( "Pause" )
            }
            .padding( .horizontal, 18 )
            .padding( .top, 10 )

            if let prompt = model.tutorialPrompt {
                Text( prompt )
                    .font( .display( 20 ) )
                    .foregroundStyle( Theme.accent )
                    .padding( .horizontal, 16 )
                    .padding( .vertical, 6 )
                    .background( Color.black.opacity( 0.6 ), in : RoundedRectangle( cornerRadius : 10 ) )
            }

            ForEach( model.banners ) { banner in
                BannerView( banner : banner )
            }

            Spacer()

            HStack( alignment : .bottom, spacing : 14 ) {
                VStack( alignment : .trailing, spacing : -6 ) {
                    Text( "\( model.speed )" )
                        .font( .display( 54 ) )
                        .foregroundStyle( .white )
                        .monospacedDigit()
                        .frame( minWidth : 110, alignment : .trailing )
                    Text( store.settings.speedUnit.title.uppercased() )
                        .font( .label( 12, weight : .heavy ) )
                        .foregroundStyle( Theme.secondaryText )
                }

                VStack( alignment : .leading, spacing : 4 ) {
                    Text( model.hasLaunched ? "SHIFT ZONE" : "LAUNCH WINDOW" )
                        .font( .label( 10, weight : .heavy ) )
                        .foregroundStyle( model.hasLaunched ? Theme.success : Theme.cool )

                    RPMBar(
                        fraction : model.rpmFraction,
                        window : model.shiftWindow,
                        isLimiting : model.isLimiting,
                        isManual : model.hasLaunched,
                        launchWindow : model.hasLaunched ? nil : model.launchWindow
                    )
                    .frame( width : 240, height : 18 )
                }

                Text( model.gear )
                    .font( .display( 44 ) )
                    .foregroundStyle( .white )
                    .frame( width : 50, height : 56 )
                    .background( SlantedShape( slant : 6 ).fill( Color.black.opacity( 0.55 ) ) )
            }
            .padding( .horizontal, 16 )
            .padding( .vertical, 6 )
            .background( Color.black.opacity( 0.45 ), in : RoundedRectangle( cornerRadius : 14 ) )
            .padding( .bottom, 8 )
            .padding( .leading, 130 )
            .padding( .trailing, 270 )
        }
    }

    private var controls : some View {
        HStack( alignment : .bottom ) {
            VStack( spacing : 10 ) {
                if model.nitrousFraction != nil {
                    HoldButton( name : "Nitrous", onChange : { model.nitrousHeld = $0 } ) { pressed in
                        PedalLabel( title : "N2O", symbol : "bolt.fill", colour : Theme.cool, isPressed : pressed, width : 90, height : 60 )
                    }
                }

                Button {
                    model.shiftDown()
                } label : {
                    PedalLabel( title : "DOWN", symbol : "arrowtriangle.down.fill", colour : Theme.secondaryText, isPressed : false, width : 90, height : 60 )
                }
                .buttonStyle( .plain )
            }

            Spacer()

            HStack( alignment : .bottom, spacing : 12 ) {
                Button {
                    model.launchOrShift()
                } label : {
                    PedalLabel(
                        title : model.hasLaunched ? "SHIFT" : "LAUNCH",
                        symbol : model.hasLaunched ? "arrowtriangle.up.fill" : "flag.checkered",
                        colour : model.hasLaunched ? Theme.success : Theme.accent,
                        isPressed : false,
                        width : 120,
                        height : 110
                    )
                }
                .buttonStyle( .plain )

                HoldButton( name : "Gas", onChange : { model.throttleHeld = $0 } ) { pressed in
                    PedalLabel( title : "GAS", symbol : "chevron.up.2", colour : Theme.success, isPressed : pressed, width : 100, height : 150 )
                }
            }
        }
        .environment( \.layoutDirection, store.settings.leftHandedControls ? .rightToLeft : .leftToRight )
        .padding( .horizontal, 18 )
        .padding( .bottom, 12 )
        .frame( maxHeight : .infinity, alignment : .bottom )
    }
}

struct ChristmasTree : View {
    let amberLit : Int
    let isGreen : Bool
    let isFoul : Bool

    var body : some View {
        VStack( spacing : 6 ) {
            ForEach( 0 ..< 3, id : \.self ) { index in
                light( Theme.accent, isOn : index < amberLit )
            }

            light( Theme.success, isOn : isGreen && !isFoul )
            light( Theme.hot, isOn : isFoul )
        }
        .padding( 8 )
        .background( Color.black.opacity( 0.7 ), in : RoundedRectangle( cornerRadius : 10 ) )
        .accessibilityLabel( isFoul ? "Red light" : ( isGreen ? "Green light" : "\( amberLit ) amber lights" ) )
    }

    private func light( _ colour : Color, isOn : Bool ) -> some View {
        Circle()
            .fill( isOn ? colour : colour.opacity( 0.15 ) )
            .frame( width : 22, height : 22 )
            .shadow( color : colour, radius : isOn ? 8 : 0 )
    }
}

struct DistanceBar : View {
    let player : Double
    let opponent : Double

    var body : some View {
        GeometryReader { proxy in
            ZStack( alignment : .leading ) {
                Capsule().fill( Color.white.opacity( 0.12 ) ).frame( height : 4 ).offset( y : 0 )

                Circle()
                    .fill( Theme.hot )
                    .frame( width : 10, height : 10 )
                    .offset( x : ( proxy.size.width - 10 ) * opponent, y : -6 )

                Circle()
                    .fill( Theme.accent )
                    .frame( width : 12, height : 12 )
                    .offset( x : ( proxy.size.width - 12 ) * player, y : 6 )

                Image( systemName : "flag.checkered" )
                    .font( .system( size : 12 ) )
                    .foregroundStyle( .white )
                    .offset( x : proxy.size.width - 6, y : -12 )
            }
            .frame( maxHeight : .infinity )
        }
        .accessibilityLabel( "Distance: you \( Int( player * 100 ) ) percent, opponent \( Int( opponent * 100 ) ) percent" )
    }
}
