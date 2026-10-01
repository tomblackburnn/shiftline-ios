import SwiftUI

extension RaceKind {
    var symbol : String {
        switch self {
        case .circuit:
            return "flag.checkered"
        case .sprint:
            return "arrow.right.to.line"
        case .elimination:
            return "person.fill.xmark"
        case .checkpoint:
            return "timer"
        case .speedTrap:
            return "dot.radiowaves.left.and.right"
        case .timeAttack:
            return "stopwatch"
        case .drift:
            return "tornado"
        case .drag:
            return "gauge.with.dots.needle.100percent"
        case .endurance:
            return "hourglass"
        case .practice:
            return "road.lanes"
        case .tutorial:
            return "graduationcap"
        }
    }

    var rulesSummary : String {
        switch self {
        case .circuit:
            return "Multi-lap race from a grid start. Cutting the track adds a one-second penalty."
        case .sprint:
            return "Point to point. First to the finish line wins."
        case .elimination:
            return "Last place is eliminated each time the leader completes a lap."
        case .checkpoint:
            return "Race the clock. Every checkpoint adds time; run out and it's over."
        case .speedTrap:
            return "Score the sum of your speeds through each radar trap, plus your average between the first and last."
        case .timeAttack:
            return "Solo laps against the clock and your ghost. Leaving the track invalidates the lap."
        case .drift( let format, let duration ):
            switch format {
            case .scoreAttack:
                return "Score as many drift points as possible in \( Int( duration ) ) seconds."
            case .sections:
                return "Only the marked orange zones score. Link them for big combos."
            case .chain:
                return "Your single best unbroken drift chain is your score."
            case .tandem:
                return "Follow the lead car sideways. Staying close multiplies your points."
            }
        case .drag:
            return "Heads-up drag race. Rev into the launch window, go on green, shift in the green zone."
        case .endurance:
            return "A long race with tyre wear. Grip fades as your tyres go off."
        case .practice:
            return "Free driving with lap timing."
        case .tutorial:
            return "Interactive lesson."
        }
    }
}

struct CareerView : View {
    @Binding var path : [Screen]
    @Environment( GameStore.self ) private var store
    @State private var tier = CareerTier.rookie
    @State private var discipline : Discipline?
    private let rules = ProgressionRules()

    var body : some View {
        VStack( alignment : .leading, spacing : 10 ) {
            ScreenHeader( title : "Career", subtitle : tier.tagline )

            ScrollView( .horizontal, showsIndicators : false ) {
                HStack( spacing : 6 ) {
                    ForEach( CareerTier.allCases ) { candidate in
                        let isUnlocked = rules.isTierUnlocked( candidate, in : store.save )

                        Button {
                            tier = candidate
                        } label : {
                            HStack( spacing : 4 ) {
                                if !isUnlocked {
                                    Image( systemName : "lock.fill" )
                                }

                                Text( candidate.title.uppercased() )
                                Text( "\( rules.wins( in : candidate, save : store.save ) )/\( Events.events( in : candidate ).count )" )
                                    .opacity( 0.7 )
                            }
                            .font( .label( 13, weight : .heavy ) )
                            .foregroundStyle( tier == candidate ? Color.black : ( isUnlocked ? .white : Theme.secondaryText ) )
                            .padding( .horizontal, 12 )
                            .padding( .vertical, 7 )
                            .background( SlantedShape( slant : 6 ).fill( tier == candidate ? Theme.accent : Theme.panelRaised ) )
                        }
                        .buttonStyle( .plain )
                        .accessibilityIdentifier( "tier-\( candidate.rawValue )" )
                    }
                }
            }

            HStack( spacing : 6 ) {
                Button {
                    discipline = nil
                } label : {
                    Chip( text : "All", isSelected : discipline == nil )
                }

                ForEach( Discipline.allCases ) { item in
                    Button {
                        discipline = discipline == item ? nil : item
                    } label : {
                        Chip( text : item.title, symbol : item.symbol, isSelected : discipline == item )
                    }
                }
            }
            .buttonStyle( .plain )

            if !rules.isTierUnlocked( tier, in : store.save ) {
                VStack( alignment : .leading, spacing : 4 ) {
                    Label( "\( tier.title ) is locked", systemImage : "lock.fill" )
                        .font( .display( 18 ) )
                        .foregroundStyle( .white )

                    ForEach( rules.tierLockReasons( tier, in : store.save ), id : \.self ) { reason in
                        Text( "• " + reason )
                            .font( .label( 13 ) )
                            .foregroundStyle( Theme.secondaryText )
                    }
                }
                .panel()
            }

            ScrollView {
                LazyVGrid( columns : [ GridItem( .adaptive( minimum : 230 ), spacing : 10 ) ], spacing : 10 ) {
                    ForEach( Events.events( in : tier ).filter { discipline == nil || $0.discipline == discipline } ) { event in
                        Button {
                            path.append( .event( event.id ) )
                        } label : {
                            EventCard( event : event )
                        }
                        .buttonStyle( .plain )
                        .accessibilityIdentifier( "event-\( event.id )" )
                    }
                }
            }
        }
        .padding( .horizontal, 22 )
        .padding( .vertical, 12 )
        .gameBackground()
        .onAppear {
            // Open on the highest unlocked tier the player hasn't cleared.
            tier = CareerTier.allCases.last { rules.isTierUnlocked( $0, in : store.save ) } ?? .rookie
        }
    }
}

struct EventCard : View {
    let event : EventDefinition
    @Environment( GameStore.self ) private var store

    var body : some View {
        let availability = store.availability( of : event )
        let record = store.save.events[ event.id ]

        VStack( alignment : .leading, spacing : 6 ) {
            HStack {
                Label( event.kind.title.uppercased(), systemImage : event.kind.symbol )
                    .font( .label( 11, weight : .heavy ) )
                    .foregroundStyle( event.isRival ? Theme.hot : Theme.accent )
                    .lineLimit( 1 )

                Spacer()

                if let placement = record?.bestPlacement {
                    MedalBadge( placement : placement, isScored : event.kind.isScored )
                } else if !availability.isUnlocked {
                    Image( systemName : "lock.fill" )
                        .foregroundStyle( Theme.secondaryText )
                }
            }

            Text( event.name.uppercased() )
                .font( .display( 20 ) )
                .foregroundStyle( availability.isUnlocked ? .white : Theme.secondaryText )
                .lineLimit( 1 )
                .minimumScaleFactor( 0.8 )

            Text( event.track?.fullName ?? "" )
                .font( .label( 12 ) )
                .foregroundStyle( Theme.secondaryText )
                .lineLimit( 1 )

            HStack( spacing : 8 ) {
                Image( systemName : event.timeOfDay.symbol )
                Image( systemName : event.weather.symbol )

                if event.laps > 1 {
                    Text( "\( event.laps ) LAPS" )
                }

                Spacer()

                Text( "MAX \( ( event.requirements.maximumClass ?? event.tier.classCap ).rawValue )" )
                    .foregroundStyle( Theme.classColour( event.requirements.maximumClass ?? event.tier.classCap ) )

                HStack( spacing : 2 ) {
                    Image( systemName : "c.circle.fill" )
                    Text( event.firstPlacePrize.formatted( .number ) )
                }
                .foregroundStyle( Theme.accent )
            }
            .font( .label( 11, weight : .bold ) )
            .foregroundStyle( .white.opacity( 0.8 ) )

            if case .locked( let reasons ) = availability, let first = reasons.first {
                Text( first )
                    .font( .label( 11 ) )
                    .foregroundStyle( Theme.hot.opacity( 0.9 ) )
                    .lineLimit( 1 )
            } else if case .carIneligible( let issues ) = availability, let first = issues.first {
                Text( first )
                    .font( .label( 11 ) )
                    .foregroundStyle( Theme.orange )
                    .lineLimit( 1 )
            }
        }
        .panel( padding : 12, highlighted : event.isRival && availability.isUnlocked )
        .opacity( availability.isUnlocked ? 1 : 0.7 )
    }
}

struct EventDetailView : View {
    let eventID : String
    @Environment( GameStore.self ) private var store
    @State private var showsCarPicker = false
    private let rules = ProgressionRules()

    var body : some View {
        if let event = Events.named( eventID ) {
            content( event )
        } else {
            Text( "Event not found" )
        }
    }

    private func content( _ event : EventDefinition ) -> some View {
        let availability = store.availability( of : event )
        let rival = event.rivalID.flatMap { Opponents.rival( $0 ) }

        return VStack( alignment : .leading, spacing : 10 ) {
            ScreenHeader( title : event.name, subtitle : "\( event.tier.title ) · \( event.discipline.title )" )

            HStack( alignment : .top, spacing : 14 ) {
                VStack( alignment : .leading, spacing : 8 ) {
                    if let track = event.track {
                        TrackMapView( layout : track )
                            .frame( height : 120 )
                            .panel( padding : 8 )

                        Text( track.fullName.uppercased() )
                            .font( .display( 18 ) )
                            .foregroundStyle( .white )

                        Text( track.summary.isEmpty ? track.environment.summary : track.summary )
                            .font( .label( 12 ) )
                            .foregroundStyle( Theme.secondaryText )
                            .lineLimit( 3 )

                        HStack( spacing : 10 ) {
                            Label( event.timeOfDay.title, systemImage : event.timeOfDay.symbol )
                            Label( event.weather.title, systemImage : event.weather.symbol )
                            Label( track.surface.title, systemImage : "road.lanes" )
                        }
                        .font( .label( 12, weight : .bold ) )
                        .foregroundStyle( .white )
                    }
                }
                .frame( width : 210 )

                ScrollView {
                    VStack( alignment : .leading, spacing : 10 ) {
                        VStack( alignment : .leading, spacing : 4 ) {
                            Label( event.kind.title.uppercased(), systemImage : event.kind.symbol )
                                .font( .display( 16 ) )
                                .foregroundStyle( Theme.accent )
                            Text( event.kind.rulesSummary )
                                .font( .label( 13 ) )
                                .foregroundStyle( .white )
                            Text( event.summary )
                                .font( .label( 12 ) )
                                .foregroundStyle( Theme.secondaryText )

                            if event.kind.usesDriftTyres {
                                Label( "Every car runs on drift tyres for this event.", systemImage : "circle.circle" )
                                    .font( .label( 12, weight : .bold ) )
                                    .foregroundStyle( Theme.cool )
                            }
                        }

                        if let rival {
                            RivalCard( rival : rival )
                        }

                        requirementsList( event )
                        rewardsSummary( event )
                    }
                }
                .frame( maxWidth : .infinity )

                VStack( alignment : .leading, spacing : 10 ) {
                    if let car = store.selectedCar {
                        CompactCarRow( car : car ) {
                            showsCarPicker = true
                        }
                    }

                    AssistQuickToggles()

                    Spacer( minLength : 0 )

                    Button( event.isRival ? "CHALLENGE" : "START RACE" ) {
                        store.startEvent( event )
                    }
                    .buttonStyle( .shift )
                    .disabled( !availability.isAvailable )
                    .opacity( availability.isAvailable ? 1 : 0.4 )
                    .accessibilityIdentifier( "startRaceButton" )
                }
                .frame( width : 240 )
            }
        }
        .padding( .horizontal, 22 )
        .padding( .vertical, 12 )
        .gameBackground()
        .sheet( isPresented : $showsCarPicker ) {
            CarPickerSheet( requirements : event.requirements, tier : event.tier )
        }
    }

    private func requirementsList( _ event : EventDefinition ) -> some View {
        let lines = rules.requirementChecks( for : event.requirements, tier : event.tier, car : store.selectedCar, in : store.save )

        return VStack( alignment : .leading, spacing : 4 ) {
            Text( "REQUIREMENTS" )
                .font( .label( 12, weight : .heavy ) )
                .foregroundStyle( Theme.secondaryText )

            ForEach( Array( lines.enumerated() ), id : \.offset ) { _, line in
                Label( line.text, systemImage : line.isMet ? "checkmark.circle.fill" : "xmark.circle.fill" )
                    .font( .label( 13 ) )
                    .foregroundStyle( line.isMet ? Theme.success : Theme.hot )
            }

            Text( "Recommended performance index: \( event.recommendedIndex )" )
                .font( .label( 11 ) )
                .foregroundStyle( Theme.secondaryText )
        }
        .panel()
    }

    private func rewardsSummary( _ event : EventDefinition ) -> some View {
        let record = store.save.events[ event.id ]
        let isReplay = ( record?.wins ?? 0 ) > 0

        return VStack( alignment : .leading, spacing : 4 ) {
            Text( "REWARDS" )
                .font( .label( 12, weight : .heavy ) )
                .foregroundStyle( Theme.secondaryText )

            HStack {
                Text( event.kind.isScored ? "Gold" : "1st" )
                    .font( .label( 13 ) )
                    .foregroundStyle( .white )
                Spacer( minLength : 4 )
                CreditsLabel( amount : Int( Double( event.firstPlacePrize ) * ( isReplay ? RewardCalculator.replayFactor : 1 ) * store.settings.difficulty.rewardMultiplier ), size : 14 )
                Text( "+\( event.tier.baseXP ) XP" )
                    .font( .numeric( 12 ) )
                    .foregroundStyle( Theme.cool )
            }

            if isReplay {
                Text( "Replay rewards are 75% of first-time winnings." )
                    .font( .label( 11 ) )
                    .foregroundStyle( Theme.secondaryText )
            }

            if let record, let best = record.bestPlacement {
                Text( "Best result: \( event.kind.isScored ? [ "Gold", "Silver", "Bronze", "Finished" ][ min( best, 4 ) - 1 ] : RaceResultFormat.ordinal( best ) )" )
                    .font( .label( 12, weight : .bold ) )
                    .foregroundStyle( Theme.medalColour( best ) )
            }
        }
        .panel()
    }
}

struct RivalCard : View {
    let rival : Rival
    @Environment( GameStore.self ) private var store

    var body : some View {
        let wins = store.save.rivalWins[ rival.id ] ?? 0

        HStack( alignment : .top, spacing : 12 ) {
            ZStack {
                Circle().fill( Color( hex : rival.profile.colourHex ).opacity( 0.25 ) )
                Image( systemName : rival.specialty.symbol )
                    .font( .system( size : 22, weight : .bold ) )
                    .foregroundStyle( Color( hex : rival.profile.colourHex ) )
            }
            .frame( width : 52, height : 52 )

            VStack( alignment : .leading, spacing : 3 ) {
                Text( "RIVAL · \( rival.nickname.uppercased() )" )
                    .font( .label( 11, weight : .heavy ) )
                    .foregroundStyle( Theme.hot )
                Text( rival.profile.name )
                    .font( .display( 18 ) )
                    .foregroundStyle( .white )
                Text( rival.bio )
                    .font( .label( 12 ) )
                    .foregroundStyle( Theme.secondaryText )
                Text( "Defeated \( wins )/\( rival.encounters.count ) · \( rival.profile.style.title ) · \( rival.specialty.title ) specialist" )
                    .font( .label( 11, weight : .bold ) )
                    .foregroundStyle( .white )
            }
        }
        .panel( highlighted : true )
    }
}

/// One-line summary of the selected car with a change button, for setup screens.
struct CompactCarRow : View {
    let car : OwnedCar
    let onChange : () -> Void

    var body : some View {
        let performance = PerformanceProfile.measure( CarBuild( owned : car ).spec )

        HStack( spacing : 8 ) {
            VStack( alignment : .leading, spacing : 0 ) {
                Text( car.definition.fullName.uppercased() )
                    .font( .display( 14 ) )
                    .foregroundStyle( .white )
                    .lineLimit( 1 )
                    .minimumScaleFactor( 0.7 )
                Text( "\( car.drivetrain.title ) · \( car.tyreCompound.title )" )
                    .font( .label( 10, weight : .bold ) )
                    .foregroundStyle( Theme.secondaryText )
            }

            ClassBadge( performance : performance )

            Button( "CHANGE", action : onChange )
                .buttonStyle( .shift( .secondary, compact : true ) )
        }
        .padding( 6 )
        .background( Theme.panel, in : RoundedRectangle( cornerRadius : 10 ) )
    }
}

struct SelectedCarCard : View {
    let car : OwnedCar

    var body : some View {
        let spec = CarBuild( owned : car ).spec
        let performance = PerformanceProfile.measure( spec )

        VStack( alignment : .leading, spacing : 6 ) {
            HStack {
                Text( car.definition.fullName.uppercased() )
                    .font( .display( 16 ) )
                    .foregroundStyle( .white )
                    .lineLimit( 1 )
                    .minimumScaleFactor( 0.7 )
                Spacer()
                ClassBadge( performance : performance )
            }

            CarSideView( definition : car.definition, appearance : car.appearance )
                .frame( height : 56 )

            HStack {
                Text( spec.drivetrain.title )
                Text( "\( Int( performance.horsepower ) ) HP" )
                Text( spec.tyre.title.uppercased() )
            }
            .font( .label( 11, weight : .heavy ) )
            .foregroundStyle( Theme.secondaryText )
        }
        .panel( padding : 10 )
    }
}

struct AssistQuickToggles : View {
    @Environment( GameStore.self ) private var store

    var body : some View {
        VStack( alignment : .leading, spacing : 6 ) {
            Toggle( isOn : Binding(
                get : { !store.settings.assists.automaticTransmission },
                set : { value in store.updateSettings { $0.assists.automaticTransmission = !value } }
            ) ) {
                Text( "MANUAL GEARBOX" ).font( .label( 13, weight : .bold ) )
            }

            Toggle( isOn : Binding(
                get : { store.settings.assists.racingLine },
                set : { value in store.updateSettings { $0.assists.racingLine = value } }
            ) ) {
                Text( "RACING LINE" ).font( .label( 13, weight : .bold ) )
            }
        }
        .tint( Theme.accent )
        .foregroundStyle( .white )
        .panel( padding : 10 )
    }
}

struct CarPickerSheet : View {
    var requirements = EventRequirements()
    var tier : CareerTier?
    @Environment( GameStore.self ) private var store
    @Environment( \.dismiss ) private var dismiss
    private let rules = ProgressionRules()

    var body : some View {
        NavigationStack {
            List( store.save.garage ) { car in
                let issues = rules.carIssues( for : requirements, tier : tier, car : car )
                let performance = PerformanceProfile.measure( CarBuild( owned : car ).spec )

                Button {
                    store.select( car.id )
                    dismiss()
                } label : {
                    HStack {
                        CarTopView( definition : car.definition, appearance : car.appearance )
                            .frame( width : 30, height : 60 )

                        VStack( alignment : .leading ) {
                            Text( car.definition.fullName )
                                .font( .label( 16, weight : .bold ) )
                                .foregroundStyle( .white )

                            if let issue = issues.first {
                                Text( issue )
                                    .font( .label( 12 ) )
                                    .foregroundStyle( Theme.hot )
                            } else {
                                Text( "Eligible" )
                                    .font( .label( 12 ) )
                                    .foregroundStyle( Theme.success )
                            }
                        }

                        Spacer()
                        ClassBadge( performance : performance )

                        if car.id == store.selectedCar?.id {
                            Image( systemName : "checkmark.circle.fill" )
                                .foregroundStyle( Theme.accent )
                        }
                    }
                }
                .listRowBackground( Theme.panel )
            }
            .scrollContentBackground( .hidden )
            .background( Theme.background )
            .navigationTitle( "Choose Car" )
            .navigationBarTitleDisplayMode( .inline )
            .toolbar {
                ToolbarItem( placement : .cancellationAction ) {
                    Button( "Close" ) {
                        dismiss()
                    }
                }
            }
        }
    }
}
