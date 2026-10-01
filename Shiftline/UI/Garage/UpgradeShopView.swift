import SwiftUI

struct UpgradeShopView : View {
    let ownedID : UUID
    @Environment( GameStore.self ) private var store
    @State private var focused = UpgradeCategory.engine
    private let rules = GarageRules()

    var body : some View {
        if let car = store.save.ownedCar( ownedID ) {
            content( car )
        }
    }

    private func content( _ car : OwnedCar ) -> some View {
        let current = PerformanceProfile.measure( CarBuild( owned : car ).spec )

        return VStack( alignment : .leading, spacing : 10 ) {
            ScreenHeader( title : "Upgrades", subtitle : car.definition.fullName )

            HStack( alignment : .top, spacing : 14 ) {
                ScrollView {
                    VStack( spacing : 6 ) {
                        ForEach( UpgradeCategory.allCases ) { category in
                            categoryRow( category, car : car )
                        }
                    }
                }
                .frame( width : 330 )

                ScrollView {
                    VStack( alignment : .leading, spacing : 10 ) {
                        focusedPanel( car, current : current )

                        if focused == .tyres {
                            compoundPicker( car )
                        }

                        if focused == .forcedInduction {
                            inductionPicker( car )
                        }

                        if focused == .drivetrain {
                            drivetrainPicker( car )
                        }
                    }
                }
            }
        }
        .padding( .horizontal, 22 )
        .padding( .vertical, 12 )
        .gameBackground()
    }

    private func categoryRow( _ category : UpgradeCategory, car : OwnedCar ) -> some View {
        let level = car.level( of : category )

        return Button {
            focused = category
        } label : {
            HStack( spacing : 10 ) {
                Image( systemName : category.symbol )
                    .font( .system( size : 16, weight : .bold ) )
                    .foregroundStyle( Theme.accent )
                    .frame( width : 24 )

                Text( category.title )
                    .font( .label( 14, weight : .bold ) )
                    .foregroundStyle( .white )
                    .lineLimit( 1 )

                Spacer()

                HStack( spacing : 3 ) {
                    ForEach( 1 ... UpgradeRules.maximumLevel, id : \.self ) { pip in
                        SlantedShape( slant : 3 )
                            .fill( pip <= level ? Theme.accent : Theme.stroke )
                            .frame( width : 14, height : 10 )
                    }
                }
            }
            .panel( padding : 9, highlighted : focused == category )
        }
        .buttonStyle( .plain )
        .accessibilityValue( UpgradeRules.levelNames[ level ] )
        .accessibilityAddTraits( focused == category ? .isSelected : [] )
        .accessibilityIdentifier( "upgrade-\( category.rawValue )" )
    }

    private func focusedPanel( _ car : OwnedCar, current : PerformanceProfile ) -> some View {
        let level = car.level( of : focused )
        let cost = rules.upgradeCost( for : focused, on : car )
        var preview = car
        preview.upgrades[ focused ] = min( level + 1, UpgradeRules.maximumLevel )

        if focused == .forcedInduction && preview.inductionKit == .stock {
            preview.inductionKit = .turbo
        }

        let next = PerformanceProfile.measure( CarBuild( owned : preview ).spec )
        let requiredLevel = level < UpgradeRules.maximumLevel ? UpgradeRules.requiredDriverLevel[ level + 1 ] : 0
        let isLevelLocked = store.save.profile.level < requiredLevel

        return VStack( alignment : .leading, spacing : 10 ) {
            HStack {
                Label( focused.title.uppercased(), systemImage : focused.symbol )
                    .font( .display( 22 ) )
                    .foregroundStyle( .white )
                Spacer()
                Text( UpgradeRules.levelNames[ level ].uppercased() )
                    .font( .display( 16 ) )
                    .foregroundStyle( Theme.accent )
            }

            Text( focused.summary )
                .font( .label( 13 ) )
                .foregroundStyle( Theme.secondaryText )

            HStack( alignment : .top, spacing : 20 ) {
                VStack( alignment : .leading, spacing : 3 ) {
                    Text( "CURRENT" )
                        .font( .label( 11, weight : .heavy ) )
                        .foregroundStyle( Theme.secondaryText )
                    Text( focused.effect( atLevel : level ) )
                        .font( .label( 13, weight : .bold ) )
                        .foregroundStyle( .white )
                }

                if level < UpgradeRules.maximumLevel {
                    VStack( alignment : .leading, spacing : 3 ) {
                        Text( "NEXT · \( UpgradeRules.levelNames[ level + 1 ].uppercased() )" )
                            .font( .label( 11, weight : .heavy ) )
                            .foregroundStyle( Theme.success )
                        Text( focused.effect( atLevel : level + 1 ) )
                            .font( .label( 13, weight : .bold ) )
                            .foregroundStyle( .white )
                    }
                }
            }

            HStack {
                ClassBadge( performance : current, isLarge : true )

                if level < UpgradeRules.maximumLevel && next.index != current.index {
                    Image( systemName : "arrow.right" )
                        .foregroundStyle( Theme.secondaryText )
                    ClassBadge( performance : next, isLarge : true )
                }
            }

            HStack {
                if let refund = rules.downgradeRefund( for : focused, on : car ) {
                    Button {
                        store.removeUpgrade( focused, for : car.id )
                        GameAudio.shared.play( .shift )
                    } label : {
                        HStack( spacing : 6 ) {
                            Text( "REMOVE" )
                            Text( "+\( refund.formatted( .number ) )" )
                                .font( .numeric( 12 ) )
                        }
                    }
                    .buttonStyle( .shift( .secondary, compact : true ) )
                    .accessibilityIdentifier( "removeUpgradeButton" )
                }

                if let cost {
                    if isLevelLocked {
                        Label( "Requires driver level \( requiredLevel )", systemImage : "lock.fill" )
                            .font( .label( 13, weight : .bold ) )
                            .foregroundStyle( Theme.secondaryText )
                    } else {
                        CreditsLabel( amount : cost, size : 18 )
                    }

                    Spacer()

                    Button( "INSTALL" ) {
                        store.buyUpgrade( focused, for : car.id )
                        GameAudio.shared.play( .shift )
                        Haptics.shared.play( .shift( perfect : true ) )
                    }
                    .buttonStyle( .shift )
                    .disabled( isLevelLocked || store.save.profile.credits < cost )
                    .opacity( isLevelLocked || store.save.profile.credits < cost ? 0.4 : 1 )
                    .accessibilityIdentifier( "installUpgradeButton" )
                } else {
                    Text( "FULLY UPGRADED" )
                        .font( .display( 18 ) )
                        .foregroundStyle( Theme.success )
                }
            }

            PerformanceBars( performance : current, comparison : level < UpgradeRules.maximumLevel ? next : nil )
        }
        .panel()
    }

    private func compoundPicker( _ car : OwnedCar ) -> some View {
        let unlocked = UpgradeRules.unlockedCompounds( tyreLevel : car.level( of : .tyres ) )

        return VStack( alignment : .leading, spacing : 8 ) {
            Text( "TYRE COMPOUND" )
                .font( .label( 12, weight : .heavy ) )
                .foregroundStyle( Theme.secondaryText )

            ForEach( TyreCompound.allCases ) { compound in
                let isUnlocked = unlocked.contains( compound )

                Button {
                    store.setCompound( compound, for : car.id )
                } label : {
                    HStack {
                        VStack( alignment : .leading, spacing : 1 ) {
                            Text( compound.title.uppercased() )
                                .font( .display( 15 ) )
                                .foregroundStyle( isUnlocked ? .white : Theme.secondaryText )
                            Text( compound.summary )
                                .font( .label( 11 ) )
                                .foregroundStyle( Theme.secondaryText )
                        }

                        Spacer()

                        Text( String( format : "LAT %.2f  LONG %.2f", compound.lateralGrip, compound.longitudinalGrip ) )
                            .font( .numeric( 10 ) )
                            .foregroundStyle( Theme.secondaryText )

                        if car.tyreCompound == compound {
                            Image( systemName : "checkmark.circle.fill" )
                                .foregroundStyle( Theme.accent )
                        } else if !isUnlocked {
                            Image( systemName : "lock.fill" )
                                .foregroundStyle( Theme.secondaryText )
                        }
                    }
                    .panel( padding : 8, highlighted : car.tyreCompound == compound )
                }
                .buttonStyle( .plain )
                .disabled( !isUnlocked )
                .accessibilityIdentifier( "compound-\( compound.rawValue )" )
            }
        }
    }

    @ViewBuilder
    private func inductionPicker( _ car : OwnedCar ) -> some View {
        if case .natural = car.definition.aspiration {
            VStack( alignment : .leading, spacing : 8 ) {
                Text( "INDUCTION KIT" )
                    .font( .label( 12, weight : .heavy ) )
                    .foregroundStyle( Theme.secondaryText )

                Text( car.level( of : .forcedInduction ) == 0 ? "Install a Street kit first, then choose turbo or supercharger." : "Turbos build boost with RPM and lag; superchargers deliver instantly." )
                    .font( .label( 12 ) )
                    .foregroundStyle( Theme.secondaryText )

                HStack {
                    ForEach( [ InductionKit.turbo, .supercharger ], id : \.self ) { kit in
                        Button( kit.title.uppercased() ) {
                            store.setInduction( kit, for : car.id )
                        }
                        .buttonStyle( .shift( car.inductionKit == kit ? .primary : .secondary, compact : true ) )
                        .disabled( car.level( of : .forcedInduction ) == 0 )
                    }
                }
            }
            .panel()
        } else {
            Text( "This car is \( car.definition.aspiration.title.lowercased() ) from the factory; upgrades raise its boost." )
                .font( .label( 12 ) )
                .foregroundStyle( Theme.secondaryText )
                .panel()
        }
    }

    private func drivetrainPicker( _ car : OwnedCar ) -> some View {
        let options = UpgradeRules.availableDrivetrains( for : car.definition, drivetrainLevel : car.level( of : .drivetrain ) )

        return VStack( alignment : .leading, spacing : 8 ) {
            Text( "DRIVETRAIN LAYOUT" )
                .font( .label( 12, weight : .heavy ) )
                .foregroundStyle( Theme.secondaryText )

            Text( options.count > 1 ? "Conversions cost \( UpgradeRules.conversionCost.formatted( .number ) ) credits. Returning to the factory layout is free." : "Drivetrain Sport (level 2) unlocks conversions for this car where possible." )
                .font( .label( 12 ) )
                .foregroundStyle( Theme.secondaryText )

            HStack {
                ForEach( options ) { drivetrain in
                    Button( drivetrain.title ) {
                        store.setDrivetrain( drivetrain, for : car.id )
                    }
                    .buttonStyle( .shift( car.drivetrain == drivetrain ? .primary : .secondary, compact : true ) )
                }
            }

            Text( car.drivetrain.summary )
                .font( .label( 12 ) )
                .foregroundStyle( .white )
        }
        .panel()
    }
}
