import SwiftUI

struct ChampionshipsView : View {
    @Binding var path : [Screen]
    @Environment( GameStore.self ) private var store
    private let rules = ProgressionRules()

    var body : some View {
        VStack( alignment : .leading, spacing : 10 ) {
            ScreenHeader( title : "Championships", subtitle : "Multi-round series scored 25-18-15-12-10-8-6-4" )

            ScrollView {
                LazyVGrid( columns : [ GridItem( .adaptive( minimum : 260 ), spacing : 10 ) ], spacing : 10 ) {
                    ForEach( Championships.all ) { championship in
                        let locks = rules.lockReasons( for : championship.requirements, tier : championship.tier, in : store.save )
                        let progress = store.save.championships[ championship.id ]

                        Button {
                            path.append( .championship( championship.id ) )
                        } label : {
                            VStack( alignment : .leading, spacing : 6 ) {
                                HStack {
                                    Text( championship.tier.title.uppercased() )
                                        .font( .label( 11, weight : .heavy ) )
                                        .foregroundStyle( Theme.accent )
                                    Spacer()

                                    if ( progress?.timesWon ?? 0 ) > 0 {
                                        Image( systemName : "trophy.fill" )
                                            .foregroundStyle( Theme.gold )
                                    } else if !locks.isEmpty {
                                        Image( systemName : "lock.fill" )
                                            .foregroundStyle( Theme.secondaryText )
                                    }
                                }

                                Text( championship.name.uppercased() )
                                    .font( .display( 20 ) )
                                    .foregroundStyle( .white )

                                Text( championship.summary )
                                    .font( .label( 12 ) )
                                    .foregroundStyle( Theme.secondaryText )
                                    .lineLimit( 2, reservesSpace : true )

                                HStack( spacing : 6 ) {
                                    ForEach( championship.rounds ) { round in
                                        Image( systemName : round.kind.symbol )
                                            .font( .system( size : 12 ) )
                                            .foregroundStyle( .white.opacity( 0.8 ) )
                                    }

                                    Spacer()
                                    CreditsLabel( amount : championship.prize, size : 13 )
                                }

                                if let progress, !progress.isComplete {
                                    Text( "IN PROGRESS · ROUND \( progress.nextRound + 1 )/\( championship.rounds.count )" )
                                        .font( .label( 11, weight : .heavy ) )
                                        .foregroundStyle( Theme.success )
                                } else if let first = locks.first {
                                    Text( first )
                                        .font( .label( 11 ) )
                                        .foregroundStyle( Theme.hot )
                                        .lineLimit( 1 )
                                }
                            }
                            .panel( highlighted : progress.map { !$0.isComplete } ?? false )
                        }
                        .buttonStyle( .plain )
                        .accessibilityIdentifier( "championship-\( championship.id )" )
                    }
                }
            }
        }
        .padding( .horizontal, 22 )
        .padding( .vertical, 12 )
        .gameBackground()
    }
}

struct ChampionshipDetailView : View {
    let championshipID : String
    @Environment( GameStore.self ) private var store
    @State private var showsCarPicker = false
    private let rules = ProgressionRules()

    var body : some View {
        if let championship = Championships.named( championshipID ) {
            content( championship )
        }
    }

    private func content( _ championship : ChampionshipDefinition ) -> some View {
        let progress = store.save.championships[ championship.id ]
        let locks = rules.lockReasons( for : championship.requirements, tier : championship.tier, in : store.save )
        let carIssues = store.selectedCar.map { rules.carIssues( for : championship.requirements, tier : championship.tier, car : $0 ) } ?? [ "Select a car" ]

        return VStack( alignment : .leading, spacing : 10 ) {
            ScreenHeader( title : championship.name, subtitle : championship.summary )

            HStack( alignment : .top, spacing : 14 ) {
                VStack( alignment : .leading, spacing : 6 ) {
                    Text( "ROUNDS" )
                        .font( .label( 12, weight : .heavy ) )
                        .foregroundStyle( Theme.secondaryText )

                    ScrollView {
                    ForEach( Array( championship.rounds.enumerated() ), id : \.element.id ) { index, round in
                        let isDone = ( progress?.nextRound ?? 0 ) > index || ( progress?.isComplete ?? false )
                        let isNext = progress.map { !$0.isComplete && $0.nextRound == index } ?? false

                        HStack( spacing : 10 ) {
                            Text( "\( index + 1 )" )
                                .font( .display( 18 ) )
                                .foregroundStyle( isNext ? Color.black : .white )
                                .frame( width : 28, height : 28 )
                                .background( SlantedShape( slant : 4 ).fill( isNext ? Theme.accent : Theme.panelRaised ) )

                            VStack( alignment : .leading, spacing : 0 ) {
                                Text( round.name.uppercased() )
                                    .font( .display( 15 ) )
                                    .foregroundStyle( .white )
                                Text( "\( round.kind.title ) · \( Tracks.named( round.trackID )?.fullName ?? "" )" )
                                    .font( .label( 11 ) )
                                    .foregroundStyle( Theme.secondaryText )
                            }

                            Spacer()

                            Image( systemName : round.timeOfDay.symbol )
                            Image( systemName : round.weather.symbol )

                            if isDone {
                                Image( systemName : "checkmark.circle.fill" )
                                    .foregroundStyle( Theme.success )
                            }
                        }
                        .font( .system( size : 12 ) )
                        .foregroundStyle( .white.opacity( 0.8 ) )
                        .panel( padding : 8, highlighted : isNext )
                    }
                    }
                }
                .frame( width : 340 )

                VStack( alignment : .leading, spacing : 8 ) {
                    if let progress {
                        ScrollView {
                            StandingsView( standings : progress.standings, remainingRounds : championship.rounds.count - progress.nextRound )
                        }
                    } else {
                        VStack( alignment : .leading, spacing : 6 ) {
                            Text( "ENTRY" )
                                .font( .label( 12, weight : .heavy ) )
                                .foregroundStyle( Theme.secondaryText )

                            ForEach( rules.requirementChecks( for : championship.requirements, tier : championship.tier, car : store.selectedCar, in : store.save ), id : \.text ) { check in
                                Label( check.text, systemImage : check.isMet ? "checkmark.circle.fill" : "xmark.circle.fill" )
                                    .font( .label( 13 ) )
                                    .foregroundStyle( check.isMet ? Theme.success : Theme.hot )
                            }

                            HStack {
                                Text( "Champion's prize" )
                                    .font( .label( 13 ) )
                                    .foregroundStyle( .white )
                                Spacer()
                                CreditsLabel( amount : championship.prize )
                            }
                        }
                        .panel()
                    }

                    Spacer( minLength : 0 )

                    HStack {
                        if let car = store.selectedCar {
                            CompactCarRow( car : car ) {
                                showsCarPicker = true
                            }
                        }

                        Spacer()

                        if progress == nil || progress?.isComplete == true {
                            Button( progress?.isComplete == true ? "ENTER AGAIN" : "ENTER CHAMPIONSHIP" ) {
                                store.enterChampionship( championship )
                            }
                            .buttonStyle( .shift )
                            .disabled( !locks.isEmpty || !carIssues.isEmpty )
                            .opacity( locks.isEmpty && carIssues.isEmpty ? 1 : 0.4 )
                            .accessibilityIdentifier( "enterChampionshipButton" )
                        } else if let progress {
                            Button( "START ROUND \( progress.nextRound + 1 )" ) {
                                store.startNextRound( of : championship )
                            }
                            .buttonStyle( .shift )
                            .disabled( !carIssues.isEmpty )
                            .opacity( carIssues.isEmpty ? 1 : 0.4 )
                            .accessibilityIdentifier( "startRoundButton" )
                        }
                    }

                    if let issue = carIssues.first {
                        Text( issue )
                            .font( .label( 12 ) )
                            .foregroundStyle( Theme.hot )
                    }
                }
            }
        }
        .padding( .horizontal, 22 )
        .padding( .vertical, 12 )
        .gameBackground()
        .sheet( isPresented : $showsCarPicker ) {
            CarPickerSheet( requirements : championship.requirements, tier : championship.tier )
        }
    }
}

struct StandingsView : View {
    let standings : [ChampionshipStanding]
    let remainingRounds : Int

    var body : some View {
        VStack( alignment : .leading, spacing : 4 ) {
            HStack {
                Text( "STANDINGS" )
                    .font( .label( 12, weight : .heavy ) )
                    .foregroundStyle( Theme.secondaryText )
                Spacer()
                Text( remainingRounds > 0 ? "\( remainingRounds ) ROUNDS LEFT" : "FINAL" )
                    .font( .label( 12, weight : .heavy ) )
                    .foregroundStyle( Theme.accent )
            }

            HStack {
                Text( "" ).frame( width : 24 )
                Text( "DRIVER" )
                Spacer()
                Text( "W" ).frame( width : 24 )
                Text( "POD" ).frame( width : 34 )
                Text( "PTS" ).frame( width : 40, alignment : .trailing )
            }
            .font( .label( 10, weight : .heavy ) )
            .foregroundStyle( Theme.secondaryText )

            ForEach( Array( standings.enumerated() ), id : \.element.id ) { index, standing in
                HStack {
                    Text( "\( index + 1 )" )
                        .font( .display( 16 ) )
                        .foregroundStyle( index < 3 ? Theme.medalColour( index + 1 ) : .white )
                        .frame( width : 24 )

                    VStack( alignment : .leading, spacing : 0 ) {
                        Text( standing.name )
                            .font( .label( 14, weight : standing.isPlayer ? .heavy : .semibold ) )
                            .foregroundStyle( standing.isPlayer ? Theme.accent : .white )
                        Text( Cars.named( standing.carID )?.fullName ?? "" )
                            .font( .label( 10 ) )
                            .foregroundStyle( Theme.secondaryText )
                    }

                    Spacer()

                    Text( "\( standing.wins )" ).frame( width : 24 )
                    Text( "\( standing.podiums )" ).frame( width : 34 )
                    Text( "\( standing.points )" )
                        .font( .numeric( 14 ) )
                        .frame( width : 40, alignment : .trailing )
                }
                .font( .numeric( 12 ) )
                .foregroundStyle( .white )
                .padding( .vertical, 2 )
                .padding( .horizontal, 6 )
                .background( standing.isPlayer ? Theme.accent.opacity( 0.12 ) : Color.clear, in : RoundedRectangle( cornerRadius : 6 ) )
            }

            Text( "Ties are broken by wins, then by best finishing positions." )
                .font( .label( 10 ) )
                .foregroundStyle( Theme.secondaryText )
        }
        .panel()
    }
}
