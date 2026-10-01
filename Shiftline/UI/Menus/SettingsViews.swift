import SwiftUI

/// Settings sections shared by the full settings screen and the in-race sheet.
struct SettingsForm : View {
    @Environment( GameStore.self ) private var store
    var showsProfileSection = true
    var onManageProfiles : ( () -> Void )?

    private func binding<Value>( _ keyPath : WritableKeyPath<GameSettings, Value> ) -> Binding<Value> {
        Binding(
            get : { store.settings[ keyPath : keyPath ] },
            set : { value in
                store.updateSettings { $0[ keyPath : keyPath ] = value }
                GameAudio.shared.engineVolume = store.settings.engineVolume
                GameAudio.shared.effectsVolume = store.settings.effectsVolume
                GameAudio.shared.music.volume = store.settings.musicVolume * 0.5
                Haptics.shared.isEnabled = store.settings.hapticsEnabled
            }
        )
    }

    var body : some View {
        Form {
            Section( "Controls" ) {
                Picker( "Steering", selection : binding( \.steeringMode ) ) {
                    ForEach( SteeringMode.allCases ) { mode in
                        Text( mode.title ).tag( mode )
                    }
                }

                if store.settings.steeringMode == .tilt {
                    LabeledContent( "Tilt sensitivity" ) {
                        Slider( value : binding( \.tiltSensitivity ), in : 0.5 ... 2 )
                    }
                }

                Toggle( "Left-handed pedals", isOn : binding( \.leftHandedControls ) )
            }

            Section( "Driving Assists" ) {
                Toggle( "Automatic gearbox", isOn : binding( \.assists.automaticTransmission ) )
                Toggle( "Traction control", isOn : binding( \.assists.tractionControl ) )
                Toggle( "Stability control", isOn : binding( \.assists.stabilityControl ) )
                Toggle( "Anti-lock brakes", isOn : binding( \.assists.antiLockBrakes ) )
                Toggle( "Steering assist", isOn : binding( \.assists.steeringAssist ) )
                Toggle( "Braking assist", isOn : binding( \.assists.brakingAssist ) )
                Toggle( "Racing line", isOn : binding( \.assists.racingLine ) )
            }

            Section {
                Picker( "AI difficulty", selection : binding( \.difficulty ) ) {
                    ForEach( Difficulty.allCases ) { difficulty in
                        Text( "\( difficulty.title ) · rewards ×\( String( format : "%.2f", difficulty.rewardMultiplier ) )" ).tag( difficulty )
                    }
                }

                Button( "Apply recommended assists for this difficulty" ) {
                    store.updateSettings { $0.assists = $0.difficulty.defaultAssists }
                }
            } header : {
                Text( "Difficulty" )
            } footer : {
                Text( "Difficulty changes AI skill and rewards. AI cars never get extra power." )
            }

            Section( "Display" ) {
                Picker( "Speed units", selection : binding( \.speedUnit ) ) {
                    ForEach( SpeedUnit.allCases ) { unit in
                        Text( unit.title ).tag( unit )
                    }
                }

                Toggle( "Minimap", isOn : binding( \.showMinimap ) )
                Toggle( "Camera shake", isOn : binding( \.cameraShake ) )
            }

            Section( "Audio & Haptics" ) {
                LabeledContent( "Engine" ) {
                    Slider( value : binding( \.engineVolume ), in : 0 ... 1 )
                }

                LabeledContent( "Effects" ) {
                    Slider( value : binding( \.effectsVolume ), in : 0 ... 1 )
                }

                LabeledContent( "Music" ) {
                    Slider( value : binding( \.musicVolume ), in : 0 ... 1 )
                }

                Toggle( "Haptics", isOn : binding( \.hapticsEnabled ) )
            }

            if showsProfileSection {
                Section( "Profile" ) {
                    LabeledContent( "Driver", value : store.save.profile.name )
                    LabeledContent( "Level", value : "\( store.save.profile.level )" )

                    if let onManageProfiles {
                        Button( "Switch or create profile", action : onManageProfiles )
                    }

                    Button( "Sign out to profile select" ) {
                        store.signOut()
                    }
                }

                Section {
                    LabeledContent( "Device leaderboards", value : "All local profiles" )
                    LabeledContent( "Game Center", value : GameCenterService.shared.status )
                    LabeledContent( "Asynchronous racing", value : "Time attack ghosts" )
                } header : {
                    Text( "Online" )
                } footer : {
                    Text( "Personal bests are ranked across every profile on this device. Best laps, sprint times, drag times and drift scores also go to the global Game Center leaderboards when you are signed in. Live multiplayer is not available in this version." )
                }
            }
        }
        .scrollContentBackground( .hidden )
    }
}

struct SettingsView : View {
    @Environment( GameStore.self ) private var store
    @State private var showsProfiles = false

    var body : some View {
        VStack( alignment : .leading, spacing : 10 ) {
            ScreenHeader( title : "Settings" )

            SettingsForm( onManageProfiles : { showsProfiles = true } )
        }
        .padding( .horizontal, 22 )
        .padding( .vertical, 12 )
        .gameBackground()
        .sheet( isPresented : $showsProfiles ) {
            ProfileSelectView( isManaging : true )
        }
    }
}

struct QuickSettingsSheet : View {
    @Environment( \.dismiss ) private var dismiss

    var body : some View {
        NavigationStack {
            SettingsForm( showsProfileSection : false )
                .background( Theme.background )
                .navigationTitle( "Settings" )
                .navigationBarTitleDisplayMode( .inline )
                .toolbar {
                    ToolbarItem( placement : .confirmationAction ) {
                        Button( "Done" ) {
                            dismiss()
                        }
                    }
                }
        }
    }
}

#if DEBUG
struct DebugMenuView : View {
    @Environment( GameStore.self ) private var store
    @State private var options = DebugOptions.shared
    @State private var refresh = false

    var body : some View {
        VStack( alignment : .leading, spacing : 10 ) {
            ScreenHeader( title : "Debug", subtitle : "Development builds only" )

            Form {
                Section( "Economy & Progress" ) {
                    Button( "Give 100,000 credits" ) {
                        store.debugGiveCredits( 100_000 )
                    }

                    Button( "Give 1,000,000 credits" ) {
                        store.debugGiveCredits( 1_000_000 )
                    }

                    Button( "Set level 10" ) {
                        store.debugSetLevel( 10 )
                    }

                    Button( "Set level 30" ) {
                        store.debugSetLevel( 30 )
                    }

                    Button( "Unlock all cars" ) {
                        store.debugUnlockAllCars()
                    }

                    Button( "Unlock all events" ) {
                        store.debugUnlockAllEvents()
                    }

                    Button( "Reset this profile", role : .destructive ) {
                        store.debugResetProfile()
                    }
                }

                Section( "Overlays" ) {
                    Toggle( "Full racing line", isOn : toggle( \.showsFullRacingLine ) )
                    Toggle( "Velocity / grip vectors", isOn : toggle( \.showsVectors ) )
                    Toggle( "AI targets", isOn : toggle( \.showsAITargets ) )
                    Toggle( "FPS and node count", isOn : toggle( \.showsFPS ) )
                    Toggle( "Telemetry panel", isOn : toggle( \.showsTelemetry ) )
                }

                Section( "Force conditions" ) {
                    Picker( "Weather", selection : Binding( get : { options.forcedWeather }, set : { options.forcedWeather = $0; refresh.toggle() } ) ) {
                        Text( "Event default" ).tag( Weather?.none )

                        ForEach( Weather.allCases ) { weather in
                            Text( weather.title ).tag( Weather?.some( weather ) )
                        }
                    }

                    Picker( "Time of day", selection : Binding( get : { options.forcedTimeOfDay }, set : { options.forcedTimeOfDay = $0; refresh.toggle() } ) ) {
                        Text( "Event default" ).tag( TimeOfDay?.none )

                        ForEach( TimeOfDay.allCases ) { time in
                            Text( time.title ).tag( TimeOfDay?.some( time ) )
                        }
                    }
                }

                Section( "Force race mode" ) {
                    ForEach( QuickMode.allCases ) { mode in
                        Button( "\( mode.title ) at Velocity Park / Kestrel" ) {
                            let layout = mode == .drag ? Tracks.kestrelQuarter : Tracks.velocityParkGP
                            store.startQuickRace(
                                trackID : layout.id,
                                kind : mode.kind( for : layout ),
                                laps : 2,
                                opponents : mode == .drag ? 1 : ( mode == .race || mode == .elimination ? 5 : 0 ),
                                weather : options.forcedWeather ?? .clear,
                                timeOfDay : options.forcedTimeOfDay ?? .day
                            )
                        }
                    }
                }
            }
            .scrollContentBackground( .hidden )
            .id( refresh )
        }
        .padding( .horizontal, 22 )
        .padding( .vertical, 12 )
        .gameBackground()
    }

    private func toggle( _ keyPath : ReferenceWritableKeyPath<DebugOptions, Bool> ) -> Binding<Bool> {
        Binding(
            get : { options[ keyPath : keyPath ] },
            set : { value in
                options[ keyPath : keyPath ] = value
                refresh.toggle()
            }
        )
    }
}
#endif
