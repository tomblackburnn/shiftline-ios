import SwiftUI

@main
struct ShiftlineApp : App {
    @State private var store = ShiftlineApp.makeStore()

    var body : some Scene {
        WindowGroup {
            RootView()
                .environment( store )
                .preferredColorScheme( .dark )
                .tint( Theme.accent )
                .onAppear {
                    GameAudio.shared.start()
                    GameAudio.shared.playMusic( .menu, volume : store.settings.musicVolume * 0.5 )
                    Haptics.shared.isEnabled = store.settings.hapticsEnabled
                    if !ProcessInfo.processInfo.arguments.contains( "-uiTesting" ) {
                        GameCenterService.shared.authenticate()
                    }

                    #if DEBUG
                    DebugLaunch.apply( ProcessInfo.processInfo.arguments, to : store )
                    #endif
                }
        }
    }

    /// UI tests launch with a throwaway save directory and defaults so they never touch real progress.
    private static func makeStore() -> GameStore {
        guard ProcessInfo.processInfo.arguments.contains( "-uiTesting" ) else {
            return GameStore()
        }

        let directory = FileManager.default.temporaryDirectory.appendingPathComponent( "ShiftlineUITests-\( UUID().uuidString )" )
        let defaults = UserDefaults( suiteName : "ShiftlineUITests" ) ?? .standard
        defaults.removePersistentDomain( forName : "ShiftlineUITests" )
        return GameStore( store : SaveStore( root : directory ), defaults : defaults )
    }
}

#if DEBUG
/// Development launch arguments for automated checks:
/// `-debugProfile` creates a ready-made profile, `-debugRace <track> <mode>` starts a quick race,
/// `-debugEvent <id>` starts a career event, `-debugAutopilot` lets the AI drive the player's car.
enum DebugLaunch {
    static var isAutopilot = false

    static func apply( _ arguments : [String], to store : GameStore ) {
        isAutopilot = arguments.contains( "-debugAutopilot" )
        DebugOptions.shared.showsFPS = arguments.contains( "-debugFPS" )

        if arguments.contains( "-debugProfile" ) && !store.hasActiveProfile {
            store.createProfile( named : "Tester" )
            store.chooseStarter( arguments.value( after : "-debugCar" ) ?? Cars.starterIDs[ 0 ] )
            store.debugUnlockAllEvents()
            store.debugGiveCredits( 500_000 )
            store.debugSetLevel( 12 )
        }

        if let carID = arguments.value( after : "-debugCar" ), let car = store.save.garage.first( where : { $0.carID == carID } ) {
            store.select( car.id )
        }

        if let eventID = arguments.value( after : "-debugEvent" ), let event = Events.named( eventID ) {
            store.startEvent( event )
        }

        if let trackID = arguments.value( after : "-debugRace" ), let layout = Tracks.named( trackID ) {
            let mode = arguments.value( after : trackID ).flatMap { QuickMode( rawValue : $0 ) } ?? ( layout.isDragStrip ? .drag : .race )
            DebugOptions.shared.forcedTimeOfDay = arguments.value( after : "-debugTime" ).flatMap( TimeOfDay.init( rawValue : ) )
            DebugOptions.shared.forcedWeather = arguments.value( after : "-debugWeather" ).flatMap( Weather.init( rawValue : ) )
            store.startQuickRace(
                trackID : trackID,
                kind : mode.kind( for : layout ),
                laps : 2,
                opponents : mode == .race || mode == .elimination ? 5 : ( mode == .drag ? 1 : 0 ),
                weather : DebugOptions.shared.forcedWeather ?? .clear,
                timeOfDay : DebugOptions.shared.forcedTimeOfDay ?? .day
            )
        }
    }
}

extension Array where Element == String {
    func value( after flag : String ) -> String? {
        guard let index = firstIndex( of : flag ), index + 1 < count, !self[ index + 1 ].hasPrefix( "-" ) else {
            return nil
        }

        return self[ index + 1 ]
    }
}
#endif
