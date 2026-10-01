import SwiftUI

enum Screen : Hashable {
    case career
    case event( String )
    case quickRace
    case garage
    case dealership
    case upgrades( UUID )
    case tuning( UUID )
    case customise( UUID )
    case championships
    case championship( String )
    case statistics
    case achievements
    case settings
    case tutorials
    case rivals
    case profiles
    case debug
}

struct RootView : View {
    @Environment( GameStore.self ) private var store
    @State private var path : [Screen] = []

    var body : some View {
        ZStack {
            if !store.hasActiveProfile {
                ProfileSelectView()
            } else if !store.save.profile.hasChosenStarter {
                StarterSelectView()
            } else {
                NavigationStack( path : $path ) {
                    MainMenuView( path : $path )
                        .navigationDestination( for : Screen.self ) { screen in
                            destination( for : screen )
                                .toolbar( .hidden, for : .navigationBar )
                        }
                        .toolbar( .hidden, for : .navigationBar )
                }
            }

            if let message = store.message {
                VStack {
                    ToastView( message : message )
                        .padding( .top, 12 )
                        .onTapGesture {
                            store.message = nil
                        }
                    Spacer()
                }
                .transition( .move( edge : .top ).combined( with : .opacity ) )
                .task( id : message ) {
                    try? await Task.sleep( for : .seconds( 3 ) )
                    store.message = nil
                }
            }
        }
        .animation( .spring( response : 0.35 ), value : store.message )
        // Presented by flag, not by item: a restart swaps the race inside the cover
        // instead of dismissing it, which would tear down the new race's view model.
        .fullScreenCover( isPresented : Binding( get : { store.activeRace != nil }, set : { if !$0 { store.activeRace = nil } } ) ) {
            if let race = store.activeRace {
                RaceContainerView( race : race )
            }
        }
    }

    @ViewBuilder
    private func destination( for screen : Screen ) -> some View {
        switch screen {
        case .career:
            CareerView( path : $path )
        case .event( let id ):
            EventDetailView( eventID : id )
        case .quickRace:
            QuickRaceView()
        case .garage:
            GarageView( path : $path )
        case .dealership:
            DealershipView()
        case .upgrades( let id ):
            UpgradeShopView( ownedID : id )
        case .tuning( let id ):
            TuningView( ownedID : id )
        case .customise( let id ):
            CustomiseView( ownedID : id )
        case .championships:
            ChampionshipsView( path : $path )
        case .championship( let id ):
            ChampionshipDetailView( championshipID : id )
        case .statistics:
            StatisticsView()
        case .achievements:
            AchievementsView()
        case .settings:
            SettingsView()
        case .tutorials:
            TutorialsView()
        case .rivals:
            RivalsView()
        case .profiles:
            ProfileSelectView( isManaging : true )
        case .debug:
            #if DEBUG
            DebugMenuView()
            #else
            EmptyView()
            #endif
        }
    }
}
