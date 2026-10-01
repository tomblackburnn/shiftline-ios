import SpriteKit
import SwiftUI

/// Presents whatever race the store has queued: track racing or drag.
struct RaceContainerView : View {
    let race : PendingRace
    @Environment( GameStore.self ) private var store

    var body : some View {
        Group {
            if case .drag = race.config.kind {
                DragRaceView( race : race, store : store )
            } else {
                TrackRaceView( race : race, store : store )
            }
        }
        .id( race.id )
        .statusBarHidden()
        .persistentSystemOverlays( .hidden )
    }
}

struct TrackRaceView : View {
    @State private var model : RaceViewModel
    @State private var showsSettings = false
    @Environment( GameStore.self ) private var store

    init( race : PendingRace, store : GameStore ) {
        _model = State( initialValue : RaceViewModel( race : race, store : store ) )
    }

    var body : some View {
        ZStack {
            SpriteView( scene : model.scene, preferredFramesPerSecond : 60, options : [ .ignoresSiblingOrder ] )
                .ignoresSafeArea()

            if model.outcome == nil {
                RaceControlsView( model : model, settings : store.settings )
                    .frame( maxWidth : .infinity, maxHeight : .infinity, alignment : .bottom )
                    .opacity( model.isPaused ? 0 : 1 )

                RaceHUDView( model : model, settings : store.settings ) {
                    model.isPaused = true
                }
                .allowsHitTesting( !model.isPaused )

                #if DEBUG
                if DebugOptions.shared.showsTelemetry {
                    TelemetryView( session : model.session )
                        .frame( maxWidth : .infinity, maxHeight : .infinity, alignment : .leading )
                        .padding( .top, 140 )
                        .padding( .leading, 18 )
                        .allowsHitTesting( false )
                }
                #endif
            }

            if model.isPaused && model.outcome == nil {
                PauseMenu(
                    title : model.race.config.title,
                    onResume : { model.isPaused = false },
                    onRestart : { model.restart() },
                    onReset : {
                        model.resetCar()
                        model.isPaused = false
                    },
                    onSettings : { showsSettings = true },
                    onQuit : { model.quit() }
                )
            }

            if let outcome = model.outcome {
                RaceResultsView(
                    outcome : outcome,
                    rewards : model.rewards,
                    race : model.race,
                    session : model.session,
                    onContinue : { model.quit() },
                    onRestart : { model.restart() }
                )
                .transition( .opacity )
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
}

struct PauseMenu : View {
    let title : String
    let onResume : () -> Void
    let onRestart : () -> Void
    var onReset : ( () -> Void )?
    let onSettings : () -> Void
    let onQuit : () -> Void

    var body : some View {
        ZStack {
            Color.black.opacity( 0.7 ).ignoresSafeArea()

            VStack( spacing : 14 ) {
                Text( "PAUSED" )
                    .font( .display( 44 ) )
                    .foregroundStyle( .white )

                Text( title )
                    .font( .label( 15 ) )
                    .foregroundStyle( Theme.secondaryText )

                Button( "RESUME", action : onResume )
                    .buttonStyle( .shift )

                HStack( spacing : 12 ) {
                    Button( "RESTART", action : onRestart )
                        .buttonStyle( .shift( .secondary, compact : true ) )

                    if let onReset {
                        Button( "RESET CAR", action : onReset )
                            .buttonStyle( .shift( .secondary, compact : true ) )
                    }

                    Button( "SETTINGS", action : onSettings )
                        .buttonStyle( .shift( .secondary, compact : true ) )
                }

                Button( "QUIT EVENT", action : onQuit )
                    .buttonStyle( .shift( .destructive, compact : true ) )
            }
        }
    }
}

#if DEBUG
struct TelemetryView : View {
    let session : RaceSession

    var body : some View {
        TimelineView( .periodic( from : .now, by : 0.1 ) ) { _ in
            let car = session.player
            let state = car.state
            let lines = [
                String( format : "SPD %.1f m/s", state.speed ),
                String( format : "RPM %.0f  G%d", state.engineRPM, state.gear ),
                String( format : "THR %.2f  BRK %.2f", state.throttle, state.brake ),
                String( format : "STR %.3f rad", state.steeringAngle ),
                String( format : "LAT %.2f m/s", state.lateralSpeed ),
                String( format : "DRIFT %.1f°", state.driftAngleDegrees ),
                String( format : "GRIP %.2f  SPIN %.2f", state.gripUsed, state.wheelspin ),
                String( format : "SLIDE F%.2f R%.2f", state.frontSlide, state.rearSlide ),
                "CP \( car.nextCheckpoint )  LAP \( car.lapsCompleted )",
                String( format : "S %.0f  LATERAL %.1f", car.trackDistance, car.lateral )
            ]

            VStack( alignment : .leading, spacing : 1 ) {
                ForEach( lines, id : \.self ) { line in
                    Text( line )
                }
            }
            .font( .system( size : 10, design : .monospaced ) )
            .foregroundStyle( .green )
            .padding( 6 )
            .background( Color.black.opacity( 0.6 ) )
        }
    }
}
#endif
