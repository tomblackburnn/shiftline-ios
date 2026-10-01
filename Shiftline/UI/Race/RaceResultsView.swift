import SwiftUI

struct RaceResultsView : View {
    let outcome : RaceOutcome
    let rewards : RaceRewards?
    let race : PendingRace
    var session : RaceSession?
    var dragRace : DragRace?
    let onContinue : () -> Void
    let onRestart : () -> Void

    @Environment( GameStore.self ) private var store
    @State private var revealedLines = 0

    private var headline : String {
        if race.context.tutorial != nil {
            return outcome.didFinish ? "LESSON COMPLETE" : "LESSON INCOMPLETE"
        }

        if !outcome.didFinish {
            return "DID NOT FINISH"
        }

        if outcome.kind.isScored {
            return [ "GOLD", "SILVER", "BRONZE", "FINISHED" ][ min( outcome.placement, 4 ) - 1 ]
        }

        return outcome.placement == 1 ? "VICTORY" : "\( RaceResultFormat.ordinal( outcome.placement ) ) PLACE"
    }

    private var headlineColour : Color {
        outcome.didFinish ? Theme.medalColour( outcome.placement ) : Theme.hot
    }

    var body : some View {
        ZStack {
            Color.black.opacity( 0.82 ).ignoresSafeArea()

            HStack( alignment : .top, spacing : 18 ) {
                VStack( alignment : .leading, spacing : 12 ) {
                    VStack( alignment : .leading, spacing : 2 ) {
                        Text( race.config.title.uppercased() )
                            .font( .label( 14, weight : .heavy ) )
                            .foregroundStyle( Theme.secondaryText )

                        Text( headline )
                            .font( .display( 46 ) )
                            .foregroundStyle( headlineColour )
                    }

                    ScrollView {
                        detailPanel
                    }
                }
                .frame( maxWidth : .infinity, alignment : .leading )

                VStack( alignment : .leading, spacing : 10 ) {
                    rewardsPanel
                    Spacer( minLength : 0 )

                    HStack {
                        Button( "RESTART", action : onRestart )
                            .buttonStyle( .shift( .secondary, compact : true ) )

                        Spacer()

                        Button( "CONTINUE", action : onContinue )
                            .buttonStyle( .shift( .primary, compact : true ) )
                    }
                }
                .frame( width : 330 )
            }
            .padding( 24 )
        }
        .task {
            GameAudio.shared.play( .reward )

            for index in 0 ..< ( rewards?.lines.count ?? 0 ) {
                try? await Task.sleep( for : .milliseconds( 220 ) )
                withAnimation( .spring( response : 0.3 ) ) {
                    revealedLines = index + 1
                }
                GameAudio.shared.play( .tap, volume : 0.5 )
            }
        }
    }

    @ViewBuilder
    private var detailPanel : some View {
        VStack( alignment : .leading, spacing : 10 ) {
            if let drag = outcome.drag {
                DragTimeslip( result : drag, opponent : dragRace.map { $0.opponent.result( greenTime : $0.greenTime ?? 0 ) }, opponentName : dragRace?.opponent.name ?? "", unit : store.settings.speedUnit )
            } else if let session, !outcome.kind.isScored && session.cars.count > 1 {
                StandingsTable( session : session )
            } else {
                scoredSummary
            }

            HStack( spacing : 16 ) {
                statistic( "TOP SPEED", "\( Int( store.settings.speedUnit.value( fromKPH : outcome.topSpeedKPH ) ) ) \( store.settings.speedUnit.title )" )
                statistic( "COLLISIONS", "\( outcome.collisions )" )

                if outcome.shifts > 0 {
                    statistic( "PERFECT SHIFTS", "\( outcome.perfectShifts )/\( outcome.shifts )" )
                }

                if outcome.cleanOvertakes > 0 {
                    statistic( "OVERTAKES", "\( outcome.cleanOvertakes )" )
                }
            }
        }
        .panel()
    }

    @ViewBuilder
    private var scoredSummary : some View {
        VStack( alignment : .leading, spacing : 6 ) {
            if let score = outcome.score {
                Text( scoreText( score ) )
                    .font( .display( 34 ) )
                    .foregroundStyle( .white )
            }

            if let targets = race.config.targets {
                HStack( spacing : 14 ) {
                    targetLabel( "GOLD", targets.gold, Theme.gold )
                    targetLabel( "SILVER", targets.silver, Theme.silver )
                    targetLabel( "BRONZE", targets.bronze, Theme.bronze )
                }
            }

            if let session, let mode = session.mode as? TimeAttackMode {
                HStack( spacing : 16 ) {
                    ForEach( Array( session.player.lapTimes.enumerated() ), id : \.offset ) { index, lap in
                        statistic( "LAP \( index + 1 )", RaceFormat.time( lap ) )
                    }

                    if let theoretical = mode.theoreticalBest( session ) {
                        statistic( "IDEAL LAP", RaceFormat.time( theoretical ) )
                    }
                }
            }

            if let session, let mode = session.mode as? SpeedTrapMode {
                HStack( spacing : 16 ) {
                    ForEach( Array( mode.trapSpeeds.enumerated() ), id : \.offset ) { index, speed in
                        statistic( "TRAP \( index + 1 )", "\( Int( store.settings.speedUnit.value( fromKPH : speed ) ) )" )
                    }

                    if let zone = mode.zoneAverageSpeed {
                        statistic( "AVG ZONE", "\( Int( store.settings.speedUnit.value( fromKPH : zone ) ) )" )
                    }
                }
            }

            if case .drift = outcome.kind {
                statistic( "BEST CHAIN", RaceFormat.points( outcome.driftBestChain ) )
            }
        }
    }

    private func scoreText( _ score : Double ) -> String {
        switch outcome.kind {
        case .timeAttack:
            return RaceFormat.time( score )
        case .checkpoint:
            return String( format : "%.2f s left", score )
        case .speedTrap:
            return "\( Int( score ) ) km/h total"
        case .drift:
            return "\( RaceFormat.points( Int( score ) ) ) pts"
        default:
            return "\( score )"
        }
    }

    private func targetLabel( _ title : String, _ value : Double, _ colour : Color ) -> some View {
        VStack( alignment : .leading, spacing : 0 ) {
            Text( title )
                .font( .label( 10, weight : .heavy ) )
                .foregroundStyle( colour )
            Text( scoreText( value ) )
                .font( .numeric( 12 ) )
                .foregroundStyle( .white )
        }
    }

    private func statistic( _ title : String, _ value : String ) -> some View {
        VStack( alignment : .leading, spacing : 0 ) {
            Text( title )
                .font( .label( 10, weight : .heavy ) )
                .foregroundStyle( Theme.secondaryText )
            Text( value )
                .font( .numeric( 14 ) )
                .foregroundStyle( .white )
        }
    }

    @ViewBuilder
    private var rewardsPanel : some View {
        VStack( alignment : .leading, spacing : 8 ) {
            Text( "REWARDS" )
                .font( .display( 18 ) )
                .foregroundStyle( .white )

            if let rewards {
                ForEach( Array( rewards.lines.prefix( revealedLines ).enumerated() ), id : \.offset ) { _, line in
                    HStack {
                        Text( line.label )
                            .font( .label( 13 ) )
                            .foregroundStyle( .white )
                            .lineLimit( 1 )
                        Spacer()

                        if line.experience > 0 {
                            Text( "+\( line.experience ) XP" )
                                .font( .numeric( 11 ) )
                                .foregroundStyle( Theme.cool )
                        }

                        if line.credits != 0 {
                            Text( "+\( line.credits.formatted( .number ) )" )
                                .font( .numeric( 12 ) )
                                .foregroundStyle( Theme.accent )
                        }
                    }
                    .transition( .move( edge : .trailing ).combined( with : .opacity ) )
                }

                Divider().overlay( Theme.stroke )

                HStack {
                    Text( "TOTAL" )
                        .font( .display( 16 ) )
                    Spacer()
                    Text( "+\( rewards.experience ) XP" )
                        .font( .numeric( 13 ) )
                        .foregroundStyle( Theme.cool )
                    CreditsLabel( amount : rewards.credits, size : 15 )
                }
                .foregroundStyle( .white )

                if rewards.didLevelUp {
                    Label( "LEVEL UP! Now level \( rewards.levelAfter )", systemImage : "arrow.up.circle.fill" )
                        .font( .display( 18 ) )
                        .foregroundStyle( Theme.accent )
                }

                ForEach( rewards.newPersonalBests, id : \.self ) { name in
                    Label( "New personal best · \( name )", systemImage : "stopwatch.fill" )
                        .font( .label( 13, weight : .bold ) )
                        .foregroundStyle( Theme.success )
                }

                if let rival = rewards.rivalDefeated {
                    Label( "Rival defeated: \( rival )", systemImage : "person.2.fill" )
                        .font( .label( 13, weight : .bold ) )
                        .foregroundStyle( Theme.hot )
                }

                ForEach( rewards.unlockedAchievements, id : \.self ) { title in
                    Label( "Achievement · \( title )", systemImage : "trophy.fill" )
                        .font( .label( 13, weight : .bold ) )
                        .foregroundStyle( Theme.gold )
                }

                ForEach( rewards.unlockedEvents.prefix( 4 ), id : \.self ) { name in
                    Label( "Unlocked · \( name )", systemImage : "lock.open.fill" )
                        .font( .label( 13, weight : .bold ) )
                        .foregroundStyle( Theme.cool )
                }

                ForEach( rewards.completedChallenges, id : \.self ) { name in
                    Label( "Daily · \( name )", systemImage : "calendar.badge.checkmark" )
                        .font( .label( 13, weight : .bold ) )
                        .foregroundStyle( Theme.success )
                }
            } else {
                ProgressView()
            }
        }
        .panel()
    }
}

struct StandingsTable : View {
    let session : RaceSession

    var body : some View {
        let standings = session.standings
        let winnerTime = standings.first?.totalTime

        VStack( spacing : 4 ) {
            ForEach( standings, id : \.id ) { car in
                HStack( spacing : 10 ) {
                    Text( "\( car.position )" )
                        .font( .display( 18 ) )
                        .frame( width : 26 )
                        .foregroundStyle( car.position <= 3 ? Theme.medalColour( car.position ) : .white )

                    VStack( alignment : .leading, spacing : 0 ) {
                        Text( car.name )
                            .font( .label( 14, weight : car.isPlayer ? .heavy : .semibold ) )
                            .foregroundStyle( car.isPlayer ? Theme.accent : .white )

                        Text( Cars.named( car.entrant.carID )?.fullName ?? "" )
                            .font( .label( 11 ) )
                            .foregroundStyle( Theme.secondaryText )
                    }

                    Spacer()

                    if car.isEliminated {
                        Text( "OUT" )
                            .font( .label( 12, weight : .heavy ) )
                            .foregroundStyle( Theme.hot )
                    } else if let time = car.totalTime {
                        Text( car.position == 1 || winnerTime == nil ? RaceFormat.time( time ) : RaceFormat.delta( time - ( winnerTime ?? time ) ) )
                            .font( .numeric( 13 ) )
                            .foregroundStyle( .white )
                    }

                    Text( car.bestLap.map { RaceFormat.time( $0 ) } ?? "" )
                        .font( .numeric( 11 ) )
                        .foregroundStyle( Theme.secondaryText )
                        .frame( width : 74, alignment : .trailing )
                }
                .padding( .vertical, 3 )
                .padding( .horizontal, 8 )
                .background( car.isPlayer ? Theme.accent.opacity( 0.12 ) : Color.clear, in : RoundedRectangle( cornerRadius : 6 ) )
            }
        }
    }
}

struct DragTimeslip : View {
    let result : DragRunResult
    let opponent : DragRunResult?
    let opponentName : String
    let unit : SpeedUnit

    var body : some View {
        Grid( alignment : .leading, horizontalSpacing : 18, verticalSpacing : 5 ) {
            GridRow {
                Text( "" )
                Text( "YOU" ).font( .label( 12, weight : .heavy ) ).foregroundStyle( Theme.accent )

                if opponent != nil {
                    Text( opponentName.uppercased() ).font( .label( 12, weight : .heavy ) ).foregroundStyle( Theme.hot )
                }
            }

            row( "LAUNCH", result.launch.title, opponent?.launch.title )
            row( "REACTION", result.isFoul ? "RED LIGHT" : String( format : "%.3f", result.reactionTime ), opponent.map { $0.isFoul ? "RED LIGHT" : String( format : "%.3f", $0.reactionTime ) } )
            row( "60 FT", result.sixtyFoot.map { String( format : "%.3f", $0 ) } ?? "-", opponent?.sixtyFoot.map { String( format : "%.3f", $0 ) } )
            row( "1/8 MILE", result.eighthMile.map { String( format : "%.3f", $0 ) } ?? "-", opponent?.eighthMile.map { String( format : "%.3f", $0 ) } )
            row( "ET", String( format : "%.3f", result.elapsedTime ), opponent.map { String( format : "%.3f", $0.elapsedTime ) } )
            row( "TRAP", "\( Int( unit.value( fromKPH : result.trapSpeedKPH ) ) ) \( unit.title )", opponent.map { "\( Int( unit.value( fromKPH : $0.trapSpeedKPH ) ) ) \( unit.title )" } )
            row( "TOTAL", String( format : "%.3f", result.totalTime ), opponent.map { String( format : "%.3f", $0.totalTime ) } )
        }
    }

    private func row( _ title : String, _ mine : String, _ theirs : String? ) -> some View {
        GridRow {
            Text( title ).font( .label( 11, weight : .heavy ) ).foregroundStyle( Theme.secondaryText )
            Text( mine ).font( .numeric( 14 ) ).foregroundStyle( .white )

            if let theirs {
                Text( theirs ).font( .numeric( 14 ) ).foregroundStyle( .white.opacity( 0.8 ) )
            }
        }
    }
}
