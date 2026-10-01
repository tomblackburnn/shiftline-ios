import SwiftUI

struct StatisticsView : View {
    @Environment( GameStore.self ) private var store
    @State private var section = 0

    var body : some View {
        VStack( alignment : .leading, spacing : 10 ) {
            ScreenHeader( title : "Records", subtitle : "Statistics and personal bests" ) {
                Picker( "Section", selection : $section ) {
                    Text( "Statistics" ).tag( 0 )
                    Text( "Personal Bests" ).tag( 1 )
                    Text( "Leaderboards" ).tag( 2 )
                }
                .pickerStyle( .segmented )
                .frame( width : 380 )
            }

            switch section {
            case 0:
                statistics
            case 1:
                personalBests
            default:
                DeviceLeaderboardView()
            }
        }
        .padding( .horizontal, 22 )
        .padding( .vertical, 12 )
        .gameBackground()
    }

    private var statistics : some View {
        let stats = store.save.statistics
        let unit = store.settings.speedUnit

        return ScrollView {
            HStack( spacing : 10 ) {
                headline( "WIN RATE", String( format : "%.0f%%", stats.winPercentage ) )
                headline( "WINS", "\( Int( stats[ .wins ] ) )" )
                headline( "PODIUMS", "\( Int( stats[ .podiums ] ) )" )
                headline( "EVENTS", "\( Int( stats[ .racesEntered ] ) )" )
                headline( "DISTANCE", RaceFormat.distance( stats[ .distanceDriven ] ) )
            }

            LazyVGrid( columns : [ GridItem( .flexible() ), GridItem( .flexible() ), GridItem( .flexible() ) ], spacing : 6 ) {
                ForEach( StatisticKey.allCases, id : \.self ) { key in
                    HStack {
                        Text( key.title )
                            .font( .label( 12 ) )
                            .foregroundStyle( Theme.secondaryText )
                        Spacer()
                        Text( format( key, value : stats[ key ], unit : unit ) )
                            .font( .numeric( 12 ) )
                            .foregroundStyle( .white )
                    }
                    .padding( .horizontal, 10 )
                    .padding( .vertical, 6 )
                    .background( Theme.panel, in : RoundedRectangle( cornerRadius : 8 ) )
                }
            }
        }
    }

    private func format( _ key : StatisticKey, value : Double, unit : SpeedUnit ) -> String {
        switch key {
        case .bestReactionTime, .fastestQuarterMile:
            return value > 0 ? String( format : "%.3f s", value ) : "-"
        case .topSpeedKPH:
            return "\( Int( unit.value( fromKPH : value ) ) ) \( unit.title )"
        case .distanceDriven:
            return RaceFormat.distance( value )
        case .creditsEarned, .creditsSpent, .driftTotalScore, .highestDriftChain:
            return Int( value ).formatted( .number )
        default:
            return "\( Int( value ) )"
        }
    }

    private func headline( _ title : String, _ value : String ) -> some View {
        VStack( alignment : .leading, spacing : 0 ) {
            Text( title )
                .font( .label( 11, weight : .heavy ) )
                .foregroundStyle( Theme.secondaryText )
            Text( value )
                .font( .display( 28 ) )
                .foregroundStyle( .white )
        }
        .frame( maxWidth : .infinity, alignment : .leading )
        .panel( padding : 10 )
    }

    private var personalBests : some View {
        let bests = store.save.personalBests
            .filter { $0.key.split( separator : "|" ).count == 2 }
            .sorted { $0.key < $1.key }

        return ScrollView {
            if bests.isEmpty {
                Text( "Finish events to set personal bests." )
                    .font( .label( 14 ) )
                    .foregroundStyle( Theme.secondaryText )
                    .padding()
            }

            VStack( spacing : 5 ) {
                ForEach( bests, id : \.key ) { key, best in
                    let parts = key.split( separator : "|" ).map( String.init )

                    HStack {
                        Text( Tracks.named( parts[ 0 ] )?.fullName ?? parts[ 0 ] )
                            .font( .label( 14, weight : .bold ) )
                            .foregroundStyle( .white )
                        Text( parts[ 1 ].uppercased() )
                            .font( .label( 11, weight : .heavy ) )
                            .foregroundStyle( Theme.accent )
                        Spacer()
                        Text( Cars.named( best.carID )?.fullName ?? "" )
                            .font( .label( 12 ) )
                            .foregroundStyle( Theme.secondaryText )
                        Text( best.lowerIsBetter ? RaceFormat.time( best.value ) : Int( best.value ).formatted( .number ) )
                            .font( .numeric( 14 ) )
                            .foregroundStyle( .white )
                            .frame( width : 100, alignment : .trailing )
                        Text( best.date.formatted( date : .abbreviated, time : .omitted ) )
                            .font( .label( 11 ) )
                            .foregroundStyle( Theme.secondaryText )
                            .frame( width : 90, alignment : .trailing )
                    }
                    .padding( .horizontal, 10 )
                    .padding( .vertical, 6 )
                    .background( Theme.panel, in : RoundedRectangle( cornerRadius : 8 ) )
                }
            }
        }
    }
}

struct AchievementsView : View {
    @Environment( GameStore.self ) private var store

    var body : some View {
        let unlocked = store.save.achievements

        VStack( alignment : .leading, spacing : 10 ) {
            ScreenHeader( title : "Achievements", subtitle : "\( unlocked.count ) of \( Achievements.all.count ) unlocked" )

            ScrollView {
                LazyVGrid( columns : [ GridItem( .adaptive( minimum : 250 ), spacing : 8 ) ], spacing : 8 ) {
                    ForEach( Achievements.all ) { achievement in
                        let date = unlocked[ achievement.id ]
                        let progress = date == nil ? achievement.progress( store.save ) : 1

                        HStack( spacing : 10 ) {
                            Image( systemName : achievement.symbol )
                                .font( .system( size : 22, weight : .bold ) )
                                .foregroundStyle( date == nil ? Theme.secondaryText : Theme.gold )
                                .frame( width : 36 )

                            VStack( alignment : .leading, spacing : 3 ) {
                                Text( achievement.title.uppercased() )
                                    .font( .display( 15 ) )
                                    .foregroundStyle( date == nil ? .white.opacity( 0.7 ) : .white )
                                Text( achievement.summary )
                                    .font( .label( 11 ) )
                                    .foregroundStyle( Theme.secondaryText )

                                if let date {
                                    Text( date.formatted( date : .abbreviated, time : .omitted ) )
                                        .font( .label( 10, weight : .bold ) )
                                        .foregroundStyle( Theme.gold )
                                } else {
                                    ProgressView( value : progress )
                                        .tint( Theme.accent )
                                }
                            }
                        }
                        .panel( padding : 10, highlighted : date != nil )
                    }
                }
            }
        }
        .padding( .horizontal, 22 )
        .padding( .vertical, 12 )
        .gameBackground()
    }
}

struct TutorialsView : View {
    @Environment( GameStore.self ) private var store
    @Environment( \.dismiss ) private var dismiss

    var body : some View {
        VStack( alignment : .leading, spacing : 10 ) {
            ScreenHeader( title : "Driving School", subtitle : "Short interactive lessons. Each one pays out once." )

            LazyVGrid( columns : [ GridItem( .adaptive( minimum : 240 ), spacing : 10 ) ], spacing : 10 ) {
                ForEach( TutorialKind.allCases ) { kind in
                    let isDone = store.save.profile.completedTutorials.contains( kind )

                    Button {
                        if kind == .tuning, let car = store.selectedCar {
                            store.message = "Open Garage → Tuning on your \( car.definition.model ) to start this lesson."
                        } else {
                            store.startTutorial( kind )
                        }
                    } label : {
                        HStack( spacing : 12 ) {
                            Image( systemName : isDone ? "checkmark.seal.fill" : "graduationcap.fill" )
                                .font( .system( size : 26 ) )
                                .foregroundStyle( isDone ? Theme.success : Theme.accent )

                            VStack( alignment : .leading, spacing : 2 ) {
                                Text( kind.title.uppercased() )
                                    .font( .display( 17 ) )
                                    .foregroundStyle( .white )
                                Text( kind.summary )
                                    .font( .label( 12 ) )
                                    .foregroundStyle( Theme.secondaryText )
                                    .lineLimit( 2 )
                            }

                            Spacer()
                        }
                        .panel( highlighted : !isDone )
                    }
                    .buttonStyle( .plain )
                    .accessibilityIdentifier( "tutorial-\( kind.rawValue )" )
                }
            }

            Spacer()
        }
        .padding( .horizontal, 22 )
        .padding( .vertical, 12 )
        .gameBackground()
    }
}

struct RivalsView : View {
    @Environment( GameStore.self ) private var store

    var body : some View {
        VStack( alignment : .leading, spacing : 10 ) {
            ScreenHeader( title : "Rivals", subtitle : "Six drivers who won't let you forget a loss" )

            ScrollView {
                LazyVGrid( columns : [ GridItem( .flexible(), spacing : 10 ), GridItem( .flexible(), spacing : 10 ) ], spacing : 10 ) {
                    ForEach( Opponents.rivals ) { rival in
                        VStack( alignment : .leading, spacing : 8 ) {
                            RivalCard( rival : rival )

                            ForEach( Array( rival.encounters.enumerated() ), id : \.offset ) { _, encounter in
                                let event = Events.all.first { $0.rivalID == rival.id && $0.tier == encounter.tier }
                                let isBeaten = event.map { ( store.save.events[ $0.id ]?.wins ?? 0 ) > 0 } ?? false

                                HStack {
                                    Image( systemName : isBeaten ? "checkmark.circle.fill" : "circle" )
                                        .foregroundStyle( isBeaten ? Theme.success : Theme.secondaryText )

                                    VStack( alignment : .leading, spacing : 0 ) {
                                        Text( "\( encounter.tier.title ) · \( event?.name ?? "" )" )
                                            .font( .label( 12, weight : .bold ) )
                                            .foregroundStyle( .white )
                                        Text( "\"\( encounter.taunt )\" — \( Cars.named( encounter.carID )?.fullName ?? "" )" )
                                            .font( .label( 11 ) )
                                            .italic()
                                            .foregroundStyle( Theme.secondaryText )
                                    }
                                }
                            }

                            if ( store.save.rivalWins[ rival.id ] ?? 0 ) >= rival.encounters.count {
                                Text( "\"\( rival.defeatLine )\"" )
                                    .font( .label( 12 ) )
                                    .italic()
                                    .foregroundStyle( Theme.accent )
                            }
                        }
                    }
                }
            }
        }
        .padding( .horizontal, 22 )
        .padding( .vertical, 12 )
        .gameBackground()
    }
}

/// Ranks every local profile's best on a chosen track and discipline.
struct DeviceLeaderboardView : View {
    @Environment( GameStore.self ) private var store
    @State private var keys : [String] = []
    @State private var selectedKey : String?
    @State private var entries : [LeaderboardEntry] = []

    private var leaderboard : LocalLeaderboard {
        LocalLeaderboard( store : store.store, currentProfileID : store.profileID )
    }

    private func title( for key : String ) -> String {
        let parts = key.split( separator : "|" ).map( String.init )
        return "\( Tracks.named( parts[ 0 ] )?.fullName ?? parts[ 0 ] ) · \( parts.count > 1 ? parts[ 1 ] : "" )"
    }

    var body : some View {
        HStack( alignment : .top, spacing : 12 ) {
            ScrollView {
                VStack( spacing : 4 ) {
                    if keys.isEmpty {
                        Text( "Set personal bests to fill the leaderboards." )
                            .font( .label( 13 ) )
                            .foregroundStyle( Theme.secondaryText )
                    }

                    ForEach( keys, id : \.self ) { key in
                        Button {
                            select( key )
                        } label : {
                            Text( title( for : key ) )
                                .font( .label( 12, weight : .bold ) )
                                .foregroundStyle( .white )
                                .lineLimit( 1 )
                                .frame( maxWidth : .infinity, alignment : .leading )
                                .panel( padding : 8, highlighted : key == selectedKey )
                        }
                        .buttonStyle( .plain )
                    }
                }
            }
            .frame( width : 300 )

            VStack( alignment : .leading, spacing : 4 ) {
                ForEach( Array( entries.enumerated() ), id : \.element.id ) { index, entry in
                    HStack {
                        Text( "\( index + 1 )" )
                            .font( .display( 18 ) )
                            .foregroundStyle( index < 3 ? Theme.medalColour( index + 1 ) : .white )
                            .frame( width : 28 )
                        Text( entry.profileName )
                            .font( .label( 14, weight : entry.isCurrentProfile ? .heavy : .semibold ) )
                            .foregroundStyle( entry.isCurrentProfile ? Theme.accent : .white )
                        Text( Cars.named( entry.carID )?.fullName ?? "" )
                            .font( .label( 11 ) )
                            .foregroundStyle( Theme.secondaryText )
                        Spacer()
                        Text( isTime( selectedKey ) ? RaceFormat.time( entry.value ) : Int( entry.value ).formatted( .number ) )
                            .font( .numeric( 14 ) )
                            .foregroundStyle( .white )
                    }
                    .padding( .horizontal, 8 )
                    .padding( .vertical, 4 )
                    .background( entry.isCurrentProfile ? Theme.accent.opacity( 0.12 ) : Color.clear, in : RoundedRectangle( cornerRadius : 6 ) )
                }

                Spacer()

                HStack {
                    Text( GameCenterService.shared.status )
                        .font( .label( 11 ) )
                        .foregroundStyle( Theme.secondaryText )
                        .lineLimit( 1 )
                    Spacer()

                    Button( "GLOBAL LEADERBOARDS" ) {
                        GameCenterService.shared.showLeaderboards()
                    }
                    .buttonStyle( .shift( .secondary, compact : true ) )
                    .disabled( !GameCenterService.shared.isAuthenticated )
                    .opacity( GameCenterService.shared.isAuthenticated ? 1 : 0.4 )
                    .accessibilityIdentifier( "globalLeaderboardsButton" )
                }
            }
            .frame( maxWidth : .infinity )
            .panel()
        }
        .task {
            keys = leaderboard.keys()

            if let first = keys.first {
                select( first )
            }
        }
    }

    private func isTime( _ key : String? ) -> Bool {
        let key = key ?? ""
        let scoredModes = [ "drift", "speedTrap", "checkpoint" ]
        return store.save.personalBests[ key ]?.lowerIsBetter ?? !scoredModes.contains { key.hasSuffix( "|" + $0 ) }
    }

    private func select( _ key : String ) {
        selectedKey = key
        entries = leaderboard.entries( for : key, lowerIsBetter : isTime( key ) )
    }
}
