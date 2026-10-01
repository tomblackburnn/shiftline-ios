import SwiftUI

enum QuickMode : String, CaseIterable, Identifiable {
    case race
    case freeDrive
    case timeAttack
    case elimination
    case drift
    case speedTrap
    case checkpoint
    case drag
    case endurance

    var id : String {
        rawValue
    }

    var title : String {
        switch self {
        case .race:
            return "Race"
        case .freeDrive:
            return "Free Drive"
        case .timeAttack:
            return "Time Attack"
        case .elimination:
            return "Elimination"
        case .drift:
            return "Drift"
        case .speedTrap:
            return "Speed Trap"
        case .checkpoint:
            return "Checkpoint"
        case .drag:
            return "Drag"
        case .endurance:
            return "Endurance"
        }
    }

    func isAvailable( on layout : TrackLayout ) -> Bool {
        switch self {
        case .drag:
            return layout.isDragStrip
        case .race, .drift, .speedTrap, .checkpoint, .freeDrive:
            return !layout.isDragStrip
        case .timeAttack, .elimination, .endurance:
            return layout.isClosed
        }
    }

    func kind( for layout : TrackLayout ) -> RaceKind {
        switch self {
        case .race:
            return layout.isClosed ? .circuit : .sprint
        case .freeDrive:
            return .practice
        case .timeAttack:
            return .timeAttack
        case .elimination:
            return .elimination
        case .drift:
            return .drift( layout.isClosed ? .scoreAttack : .sections, duration : 90 )
        case .speedTrap:
            return .speedTrap
        case .checkpoint:
            return .checkpoint( startTime : 0, bonusPerCheckpoint : 0 )
        case .drag:
            return .drag
        case .endurance:
            return .endurance
        }
    }
}

struct QuickRaceView : View {
    @Environment( GameStore.self ) private var store
    @State private var environment = TrackEnvironment.velocityPark
    @State private var trackID : TrackID = Tracks.velocityParkGP.id
    @State private var mode = QuickMode.race
    @State private var laps = 3
    @State private var opponents = 5
    @State private var weather = Weather.clear
    @State private var timeOfDay = TimeOfDay.day

    private var layout : TrackLayout {
        Tracks.named( trackID ) ?? Tracks.velocityParkGP
    }

    var body : some View {
        VStack( alignment : .leading, spacing : 10 ) {
            ScreenHeader( title : "Quick Race", subtitle : "Any track, any mode, your rules" )

            HStack( alignment : .top, spacing : 14 ) {
                VStack( alignment : .leading, spacing : 8 ) {
                    ScrollView( .horizontal, showsIndicators : false ) {
                        HStack( spacing : 5 ) {
                            ForEach( TrackEnvironment.allCases ) { item in
                                Button {
                                    environment = item
                                    trackID = Tracks.layouts( in : item ).first?.id ?? trackID
                                    fixMode()
                                } label : {
                                    Chip( text : item.title, isSelected : environment == item )
                                }
                            }
                        }
                        .buttonStyle( .plain )
                    }

                    ScrollView {
                        VStack( spacing : 6 ) {
                            ForEach( Tracks.layouts( in : environment ) ) { item in
                                Button {
                                    trackID = item.id
                                    fixMode()
                                } label : {
                                    HStack {
                                        TrackMapView( layout : item, lineWidth : 2 )
                                            .frame( width : 60, height : 40 )

                                        VStack( alignment : .leading ) {
                                            Text( item.variant.uppercased() )
                                                .font( .display( 16 ) )
                                                .foregroundStyle( .white )
                                            Text( item.isDragStrip ? "Drag strip" : ( item.isClosed ? "Circuit" : "Point to point" ) )
                                                .font( .label( 11 ) )
                                                .foregroundStyle( Theme.secondaryText )
                                        }

                                        Spacer()
                                    }
                                    .panel( padding : 8, highlighted : trackID == item.id )
                                }
                                .buttonStyle( .plain )
                            }
                        }
                    }
                }
                .frame( width : 300 )

                VStack( alignment : .leading, spacing : 10 ) {
                    ScrollView {
                    VStack( alignment : .leading, spacing : 10 ) {
                    Text( layout.fullName.uppercased() )
                        .font( .display( 22 ) )
                        .foregroundStyle( .white )

                    Text( layout.summary.isEmpty ? environment.summary : layout.summary )
                        .font( .label( 12 ) )
                        .foregroundStyle( Theme.secondaryText )

                    LazyVGrid( columns : [ GridItem( .adaptive( minimum : 110 ) ) ], spacing : 6 ) {
                        ForEach( QuickMode.allCases.filter { $0.isAvailable( on : layout ) } ) { item in
                            Button {
                                mode = item
                            } label : {
                                Chip( text : item.title, symbol : item.kind( for : layout ).symbol, isSelected : mode == item )
                            }
                            .buttonStyle( .plain )
                        }
                    }

                    HStack( spacing : 16 ) {
                        if layout.isClosed && ( mode == .race || mode == .timeAttack || mode == .endurance ) {
                            Stepper( "LAPS  \( laps )", value : $laps, in : 1 ... ( mode == .endurance ? 20 : 10 ) )
                        }

                        if mode == .race || mode == .elimination || mode == .endurance {
                            Stepper( "RIVALS  \( opponents )", value : $opponents, in : ( mode == .elimination ? 2 : 1 ) ... 7 )
                        }
                    }
                    .font( .label( 14, weight : .bold ) )
                    .foregroundStyle( .white )

                    HStack {
                        Picker( "Time", selection : $timeOfDay ) {
                            ForEach( TimeOfDay.allCases ) { item in
                                Image( systemName : item.symbol ).tag( item )
                            }
                        }
                        .pickerStyle( .segmented )

                        if !layout.isDragStrip {
                            Picker( "Weather", selection : $weather ) {
                                ForEach( Weather.allCases ) { item in
                                    Image( systemName : item.symbol ).tag( item )
                                }
                            }
                            .pickerStyle( .segmented )
                        }
                    }

                    Text( mode.kind( for : layout ).rulesSummary )
                        .font( .label( 12 ) )
                        .foregroundStyle( Theme.secondaryText )
                    }
                    }

                    HStack {
                        if let car = store.selectedCar {
                            Text( car.definition.fullName.uppercased() )
                                .font( .display( 15 ) )
                                .foregroundStyle( .white )
                            ClassBadge( performance : PerformanceProfile.measure( CarBuild( owned : car ).spec ) )
                        }

                        Spacer()

                        Button( "GO" ) {
                            start()
                        }
                        .buttonStyle( .shift )
                        .accessibilityIdentifier( "quickRaceGoButton" )
                    }
                }
                .panel()
            }
        }
        .padding( .horizontal, 22 )
        .padding( .vertical, 12 )
        .gameBackground()
    }

    private func fixMode() {
        if !mode.isAvailable( on : layout ) {
            mode = QuickMode.allCases.first { $0.isAvailable( on : layout ) } ?? .race
        }
    }

    private func start() {
        let kind = mode.kind( for : layout )
        let opponentCount : Int

        switch mode {
        case .race, .endurance:
            opponentCount = opponents
        case .elimination:
            opponentCount = max( opponents, 2 )
        case .drag:
            opponentCount = 1
        default:
            opponentCount = 0
        }

        store.startQuickRace(
            trackID : trackID,
            kind : kind,
            laps : layout.isClosed ? ( mode == .drift ? 2 : laps ) : 1,
            opponents : opponentCount,
            weather : layout.isDragStrip ? .clear : weather,
            timeOfDay : timeOfDay
        )
    }
}
