import SwiftUI

struct MainMenuView : View {
    @Binding var path : [Screen]
    @Environment( GameStore.self ) private var store

    var body : some View {
        HStack( spacing : 18 ) {
            heroPanel
                .frame( maxWidth : .infinity )

            VStack( spacing : 8 ) {
                HStack {
                    Spacer()
                    ProfileStrip()
                }

                nextStepCard

                Grid( horizontalSpacing : 8, verticalSpacing : 8 ) {
                    GridRow {
                        tile( "Career", symbol : "flag.checkered.2.crossed", screen : .career, isPrimary : true )
                            .gridCellColumns( 2 )
                        tile( "Quick Race", symbol : "bolt.car.fill", screen : .quickRace )
                    }

                    GridRow {
                        tile( "Championships", symbol : "trophy.fill", screen : .championships )
                        tile( "Garage", symbol : "car.2.fill", screen : .garage )
                        tile( "Dealership", symbol : "cart.fill", screen : .dealership )
                    }

                    GridRow {
                        tile( "Rivals", symbol : "person.2.fill", screen : .rivals )
                        tile( "Tutorials", symbol : "graduationcap.fill", screen : .tutorials )
                        tile( "Records", symbol : "chart.bar.fill", screen : .statistics )
                    }

                    GridRow {
                        tile( "Achievements", symbol : "medal.fill", screen : .achievements )
                        tile( "Settings", symbol : "gearshape.fill", screen : .settings )
                        #if DEBUG
                        tile( "Debug", symbol : "ladybug.fill", screen : .debug )
                        #else
                        tile( "Profiles", symbol : "person.crop.circle", screen : .profiles )
                        #endif
                    }
                }
            }
            .frame( width : 420 )
        }
        .padding( .horizontal, 22 )
        .padding( .vertical, 10 )
        .gameBackground()
    }

    private var heroPanel : some View {
        VStack( alignment : .leading, spacing : 10 ) {
            ShiftlineLogo( size : 26 )

            Spacer( minLength : 0 )

            if let car = store.selectedCar {
                let performance = PerformanceProfile.measure( CarBuild( owned : car ).spec )

                VStack( alignment : .leading, spacing : 4 ) {
                    Text( store.save.profile.name.uppercased() )
                        .font( .label( 13, weight : .heavy ) )
                        .foregroundStyle( Theme.secondaryText )

                    HStack( alignment : .center ) {
                        Text( car.definition.fullName.uppercased() )
                            .font( .display( 24 ) )
                            .foregroundStyle( .white )
                            .lineLimit( 1 )
                            .minimumScaleFactor( 0.6 )
                        ClassBadge( performance : performance )
                    }
                }

                CarSideView( definition : car.definition, appearance : car.appearance )
                    .frame( maxHeight : 110 )
                    .onTapGesture {
                        path.append( .garage )
                    }
            }

            Spacer( minLength : 0 )
            DailyChallengesStrip()
        }
    }

    /// Guides new players through the first-time flow: tutorial → garage → first event → more disciplines.
    @ViewBuilder
    private var nextStepCard : some View {
        let save = store.save
        let completed = save.profile.completedTutorials

        if !completed.contains( .basics ) {
            guidance( "Learn the basics", detail : "Throttle, brakes and reverse in two minutes." ) {
                store.startTutorial( .basics )
            }
        } else if save.events[ Events.firstEventID ] == nil, let first = Events.named( Events.firstEventID ) {
            guidance( "Your first race: \( first.name )", detail : first.summary ) {
                path.append( .event( first.id ) )
            }
        } else if !completed.contains( .steering ) {
            guidance( "Next lesson: steering & lines", detail : "Follow the racing line through the forest." ) {
                store.startTutorial( .steering )
            }
        }
    }

    private func guidance( _ title : String, detail : String, action : @escaping () -> Void ) -> some View {
        Button( action : action ) {
            HStack {
                Image( systemName : "arrow.right.circle.fill" )
                    .font( .system( size : 26 ) )
                    .foregroundStyle( Theme.accent )

                VStack( alignment : .leading, spacing : 1 ) {
                    Text( title.uppercased() )
                        .font( .display( 17 ) )
                        .foregroundStyle( .white )
                    Text( detail )
                        .font( .label( 12 ) )
                        .foregroundStyle( Theme.secondaryText )
                        .lineLimit( 1 )
                }

                Spacer()
            }
            .panel( padding : 10, highlighted : true )
        }
        .buttonStyle( .plain )
        .accessibilityIdentifier( "nextStepCard" )
    }

    private func tile( _ title : String, symbol : String, screen : Screen, isPrimary : Bool = false ) -> some View {
        Button {
            GameAudio.shared.play( .tap )
            path.append( screen )
        } label : {
            HStack( spacing : 8 ) {
                Image( systemName : symbol )
                    .font( .system( size : isPrimary ? 22 : 16, weight : .bold ) )
                    .foregroundStyle( isPrimary ? Color.black : Theme.accent )
                    .frame( width : 26 )

                Text( title.uppercased() )
                    .font( .display( isPrimary ? 22 : 14 ) )
                    .foregroundStyle( isPrimary ? Color.black : .white )
                    .lineLimit( 1 )
                    .minimumScaleFactor( 0.6 )

                Spacer( minLength : 0 )
            }
            .frame( maxWidth : .infinity, minHeight : isPrimary ? 44 : 36, alignment : .leading )
            .padding( .horizontal, 10 )
            .padding( .vertical, 6 )
            .background {
                if isPrimary {
                    RoundedRectangle( cornerRadius : 12 ).fill( Theme.stripe )
                } else {
                    RoundedRectangle( cornerRadius : 12 ).fill( Theme.panel )
                        .overlay( RoundedRectangle( cornerRadius : 12 ).stroke( Theme.stroke, lineWidth : 1 ) )
                }
            }
        }
        .buttonStyle( .plain )
        .accessibilityIdentifier( "menu-\( title )" )
    }
}

struct DailyChallengesStrip : View {
    @Environment( GameStore.self ) private var store

    var body : some View {
        let challenges = DailyChallengeRules().challenges( for : Date() )
        let state = store.save.daily
        let isToday = state.day == DailyChallengeRules.dayStamp( for : Date() )

        VStack( alignment : .leading, spacing : 6 ) {
            Text( "DAILY CHALLENGES" )
                .font( .label( 12, weight : .heavy ) )
                .foregroundStyle( Theme.secondaryText )

            HStack( spacing : 8 ) {
                ForEach( challenges ) { challenge in
                    let progress = isToday ? ( state.progress[ challenge.id ] ?? 0 ) : 0
                    let isDone = isToday && state.claimed.contains( challenge.id )

                    VStack( alignment : .leading, spacing : 4 ) {
                        Text( challenge.title )
                            .font( .label( 12, weight : .bold ) )
                            .foregroundStyle( isDone ? Theme.success : .white )
                            .lineLimit( 1 )
                            .minimumScaleFactor( 0.8 )

                        ProgressView( value : min( progress, challenge.target ), total : challenge.target )
                            .tint( isDone ? Theme.success : Theme.accent )

                        HStack( spacing : 3 ) {
                            Image( systemName : isDone ? "checkmark.circle.fill" : "c.circle.fill" )
                            Text( isDone ? "Complete" : challenge.credits.formatted( .number ) )
                        }
                        .font( .label( 11, weight : .bold ) )
                        .foregroundStyle( isDone ? Theme.success : Theme.accent )
                    }
                    .padding( 8 )
                    .frame( maxWidth : .infinity, alignment : .leading )
                    .background( Theme.panel, in : RoundedRectangle( cornerRadius : 10 ) )
                }
            }
        }
    }
}
