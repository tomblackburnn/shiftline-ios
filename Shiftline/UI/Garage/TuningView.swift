import SwiftUI

struct TuningView : View {
    let ownedID : UUID
    @Environment( GameStore.self ) private var store
    @Environment( \.dismiss ) private var dismiss
    @State private var setup = TuningSetup()
    @State private var hasLoaded = false
    @State private var tutorialStep = 0

    private var isTutorialActive : Bool {
        !store.save.profile.completedTutorials.contains( .tuning )
    }

    private let tutorialSteps = [
        "Tap a PRESET to load a starting setup for a discipline.",
        "Drag FINAL DRIVE right for quicker acceleration, left for more top speed. Watch the stats update.",
        "Move BALANCE towards Loose for more rotation, Stable for security.",
        "Tap SAVE TUNE to keep your setup. You can always RESET."
    ]

    var body : some View {
        if let car = store.save.ownedCar( ownedID ) {
            content( car )
                .onAppear {
                    guard !hasLoaded else {
                        return
                    }

                    hasLoaded = true
                    setup = car.tuning

                    if setup.gearScales.count != car.definition.gears {
                        setup.gearScales = Array( repeating : 1, count : car.definition.gears )
                    }
                }
        }
    }

    private func content( _ car : OwnedCar ) -> some View {
        var tuned = car
        tuned.tuning = setup
        let build = CarBuild( owned : tuned )
        let spec = build.spec
        let performance = PerformanceProfile.measure( spec )
        let saved = PerformanceProfile.measure( CarBuild( owned : car ).spec )

        return VStack( alignment : .leading, spacing : 10 ) {
            ScreenHeader( title : "Tuning", subtitle : car.definition.fullName ) {
                HStack( spacing : 8 ) {
                    Button( "RESET" ) {
                        setup = TuningSetup( gearScales : Array( repeating : 1, count : car.definition.gears ) )
                    }
                    .buttonStyle( .shift( .secondary, compact : true ) )

                    Button( "SAVE TUNE" ) {
                        store.saveTuning( setup, for : car.id )
                        GameAudio.shared.play( .reward )

                        if isTutorialActive {
                            store.completeTutorial( .tuning )
                        } else {
                            store.message = "Tune saved."
                        }
                    }
                    .buttonStyle( .shift( .primary, compact : true ) )
                    .accessibilityIdentifier( "saveTuneButton" )
                }
            }

            if isTutorialActive {
                HStack {
                    Image( systemName : "graduationcap.fill" )
                        .foregroundStyle( Theme.accent )
                    Text( tutorialSteps[ min( tutorialStep, tutorialSteps.count - 1 ) ] )
                        .font( .label( 14, weight : .bold ) )
                        .foregroundStyle( .white )
                }
                .panel( padding : 8, highlighted : true )
            }

            HStack( alignment : .top, spacing : 14 ) {
                ScrollView {
                    VStack( alignment : .leading, spacing : 12 ) {
                        presets( car )
                        gearing( build : build, spec : spec )
                        handling( build : build, spec : spec )
                    }
                }

                ScrollView {
                VStack( alignment : .leading, spacing : 10 ) {
                    HStack {
                        ClassBadge( performance : performance, isLarge : true )

                        if performance.index != saved.index {
                            Text( performance.index > saved.index ? "+\( performance.index - saved.index )" : "\( performance.index - saved.index )" )
                                .font( .numeric( 14 ) )
                                .foregroundStyle( performance.index > saved.index ? Theme.success : Theme.hot )
                        }
                    }

                    PerformanceBars( performance : performance, comparison : nil )
                    SpecGrid( spec : spec, performance : performance, unit : store.settings.speedUnit )
                    GearChart( spec : spec, unit : store.settings.speedUnit )
                        .frame( height : 90 )
                }
                .panel()
                }
                .frame( width : 300 )
            }
        }
        .padding( .horizontal, 22 )
        .padding( .vertical, 12 )
        .gameBackground()
    }

    private func presets( _ car : OwnedCar ) -> some View {
        VStack( alignment : .leading, spacing : 6 ) {
            sectionTitle( "PRESETS" )

            HStack {
                ForEach( TuningPreset.allCases ) { preset in
                    Button {
                        setup = setup.applying( preset )

                        if setup.gearScales.count != car.definition.gears {
                            setup.gearScales = Array( repeating : 1, count : car.definition.gears )
                        }

                        advanceTutorial( from : 0 )
                    } label : {
                        VStack( alignment : .leading, spacing : 2 ) {
                            Text( preset.title.uppercased() )
                                .font( .display( 15 ) )
                                .foregroundStyle( .white )
                            Text( preset.summary )
                                .font( .label( 10 ) )
                                .foregroundStyle( Theme.secondaryText )
                                .lineLimit( 2 )
                        }
                        .frame( maxWidth : .infinity, alignment : .leading )
                        .panel( padding : 8 )
                    }
                    .buttonStyle( .plain )
                    .accessibilityIdentifier( "preset-\( preset.rawValue )" )
                }
            }
        }
    }

    private func gearing( build : CarBuild, spec : VehicleSpec ) -> some View {
        VStack( alignment : .leading, spacing : 8 ) {
            sectionTitle( "GEARING" )

            TuningSlider(
                title : "Final Drive",
                value : $setup.finalDrive,
                range : TuningSetup.finalDriveRange,
                leftLabel : "Top speed",
                rightLabel : "Acceleration",
                help : "Multiplies every gear. Shorter gearing accelerates harder but tops out sooner."
            )
            .onChange( of : setup.finalDrive ) {
                advanceTutorial( from : 1 )
            }

            if build.allowsGearTuning {
                ForEach( setup.gearScales.indices, id : \.self ) { index in
                    TuningSlider(
                        title : "Gear \( index + 1 )",
                        value : $setup.gearScales[ index ],
                        range : TuningSetup.gearScaleRange,
                        leftLabel : "Long",
                        rightLabel : "Short",
                        help : nil
                    )
                }
            } else {
                Label( "Install a Sport transmission to tune individual gear ratios.", systemImage : "lock.fill" )
                    .font( .label( 12 ) )
                    .foregroundStyle( Theme.secondaryText )
            }
        }
        .panel()
    }

    private func handling( build : CarBuild, spec : VehicleSpec ) -> some View {
        VStack( alignment : .leading, spacing : 8 ) {
            sectionTitle( "HANDLING" )

            TuningSlider(
                title : "Differential Lock",
                value : Binding( get : { setup.differentialLock ?? spec.differentialLock }, set : { setup.differentialLock = $0 } ),
                range : build.minimumDifferentialLock ... build.maximumDifferentialLock,
                leftLabel : "Open (grip)",
                rightLabel : "Locked (drift)",
                help : "A locked diff drives both wheels equally: better traction and long slides, more push on entry."
            )

            if build.allowsSuspensionTuning {
                TuningSlider(
                    title : "Balance",
                    value : $setup.suspensionBalance,
                    range : -1 ... 1,
                    leftLabel : "Stable",
                    rightLabel : "Loose",
                    help : "Shifts grip between the axles. Loose rotates eagerly; stable understeers safely."
                )
                .onChange( of : setup.suspensionBalance ) {
                    advanceTutorial( from : 2 )
                }

                TuningSlider(
                    title : "Ride Height",
                    value : $setup.rideHeight,
                    range : -1 ... 1,
                    leftLabel : "Low",
                    rightLabel : "High",
                    help : "Lower cuts weight transfer and adds downforce."
                )
            } else {
                Label( "Install Street suspension to adjust balance and ride height.", systemImage : "lock.fill" )
                    .font( .label( 12 ) )
                    .foregroundStyle( Theme.secondaryText )
            }

            TuningSlider(
                title : "Tyre Pressure",
                value : $setup.tyrePressure,
                range : -1 ... 1,
                leftLabel : "Soft (grip)",
                rightLabel : "Hard (speed)",
                help : "Soft pressures grip more but roll heavier."
            )

            TuningSlider(
                title : "Brake Bias",
                value : $setup.brakeBias,
                range : TuningSetup.brakeBiasRange,
                leftLabel : "Rear",
                rightLabel : "Front",
                help : "More rear bias helps the car rotate on the brakes (trail braking)."
            )

            TuningSlider(
                title : "Steering Sensitivity",
                value : $setup.steeringSensitivity,
                range : TuningSetup.steeringRange,
                leftLabel : "Calm",
                rightLabel : "Quick",
                help : nil
            )

            if spec.drivetrain == .awd {
                TuningSlider(
                    title : "Front Torque Split",
                    value : Binding( get : { setup.frontTorqueSplit ?? spec.frontTorqueSplit }, set : { setup.frontTorqueSplit = $0 } ),
                    range : TuningSetup.torqueSplitRange,
                    leftLabel : "Rear-biased",
                    rightLabel : "Front-biased",
                    help : "Rear bias feels livelier and slides more; front bias is secure."
                )
            }
        }
        .panel()
    }

    private func sectionTitle( _ text : String ) -> some View {
        Text( text )
            .font( .label( 12, weight : .heavy ) )
            .foregroundStyle( Theme.secondaryText )
    }

    private func advanceTutorial( from step : Int ) {
        if isTutorialActive && tutorialStep == step {
            tutorialStep += 1
        }
    }
}

struct TuningSlider : View {
    let title : String
    @Binding var value : Double
    let range : ClosedRange<Double>
    let leftLabel : String
    let rightLabel : String
    let help : String?

    var body : some View {
        VStack( alignment : .leading, spacing : 2 ) {
            HStack {
                Text( title.uppercased() )
                    .font( .label( 13, weight : .bold ) )
                    .foregroundStyle( .white )
                Spacer()
                Text( String( format : "%.2f", value ) )
                    .font( .numeric( 12 ) )
                    .foregroundStyle( Theme.accent )
            }

            Slider( value : $value, in : range )
                .tint( Theme.accent )
                .accessibilityLabel( title )

            HStack {
                Text( leftLabel )
                Spacer()
                Text( rightLabel )
            }
            .font( .label( 10, weight : .bold ) )
            .foregroundStyle( Theme.secondaryText )

            if let help {
                Text( help )
                    .font( .label( 11 ) )
                    .foregroundStyle( Theme.secondaryText.opacity( 0.8 ) )
            }
        }
    }
}

/// Top speed reachable in each gear at redline.
struct GearChart : View {
    let spec : VehicleSpec
    let unit : SpeedUnit

    var body : some View {
        let speeds = ( 1 ... spec.gearCount ).map { spec.speedAtRPM( spec.redlineRPM, gear : $0 ) }
        let maximum = speeds.max() ?? 1

        HStack( alignment : .bottom, spacing : 4 ) {
            ForEach( speeds.indices, id : \.self ) { index in
                VStack( spacing : 2 ) {
                    Text( "\( Int( unit.value( fromMetresPerSecond : speeds[ index ] ) ) )" )
                        .font( .numeric( 8 ) )
                        .foregroundStyle( Theme.secondaryText )
                    RoundedRectangle( cornerRadius : 2 )
                        .fill( Theme.stripe )
                        .frame( height : CGFloat( speeds[ index ] / maximum ) * 60 )
                    Text( "\( index + 1 )" )
                        .font( .label( 10, weight : .bold ) )
                        .foregroundStyle( .white )
                }
            }
        }
        .accessibilityLabel( "Gear speeds" )
    }
}
