import SwiftUI

struct DealershipView : View {
    @Environment( GameStore.self ) private var store
    @State private var focusedID : CarID = Cars.all[ 0 ].id
    @State private var manufacturer : String?
    @State private var classFilter : PerformanceClass?
    @State private var drivetrainFilter : Drivetrain?
    @State private var category : CarCategory?
    @State private var favouritesOnly = false
    @State private var compareIDs : [CarID] = []
    @State private var showsComparison = false
    @State private var confirmsPurchase = false

    private var cars : [CarDefinition] {
        Cars.all.filter { car in
            let performance = PerformanceProfile.measure( car.baseSpec )
            return ( manufacturer.map { car.manufacturerID == $0 } ?? true )
                && ( classFilter.map { performance.performanceClass == $0 } ?? true )
                && ( drivetrainFilter.map { car.drivetrain == $0 } ?? true )
                && ( category.map { car.category == $0 } ?? true )
                && ( !favouritesOnly || store.save.favouriteDealershipCars.contains( car.id ) )
        }
        .sorted { $0.price < $1.price }
    }

    var body : some View {
        VStack( alignment : .leading, spacing : 10 ) {
            ScreenHeader( title : "Dealership", subtitle : "\( Cars.all.count ) cars from \( Manufacturers.all.count ) makers" )

            filters

            HStack( alignment : .top, spacing : 14 ) {
                ScrollView {
                    VStack( spacing : 6 ) {
                        ForEach( cars ) { car in
                            row( car )
                        }
                    }
                }
                .frame( width : 310 )

                if let car = Cars.named( focusedID ) {
                    detail( car )
                }
            }
        }
        .padding( .horizontal, 22 )
        .padding( .vertical, 12 )
        .gameBackground()
        .sheet( isPresented : $showsComparison ) {
            ComparisonSheet( carIDs : compareIDs )
        }
    }

    private var filters : some View {
        ScrollView( .horizontal, showsIndicators : false ) {
            HStack( spacing : 5 ) {
                Button {
                    favouritesOnly.toggle()
                } label : {
                    Chip( text : "Fav", symbol : "star.fill", isSelected : favouritesOnly )
                }

                Menu {
                    Button( "All makers" ) {
                        manufacturer = nil
                    }

                    ForEach( Manufacturers.all ) { maker in
                        Button( maker.name ) {
                            manufacturer = maker.id
                        }
                    }
                } label : {
                    Chip( text : manufacturer.map { Manufacturers.named( $0 ).name } ?? "Maker", symbol : "building.2", isSelected : manufacturer != nil )
                }

                Menu {
                    Button( "All types" ) {
                        category = nil
                    }

                    ForEach( CarCategory.allCases ) { item in
                        Button( item.title ) {
                            category = item
                        }
                    }
                } label : {
                    Chip( text : category?.title ?? "Type", symbol : "car.side", isSelected : category != nil )
                }

                ForEach( Drivetrain.allCases ) { drivetrain in
                    Button {
                        drivetrainFilter = drivetrainFilter == drivetrain ? nil : drivetrain
                    } label : {
                        Chip( text : drivetrain.title, isSelected : drivetrainFilter == drivetrain )
                    }
                }

                ForEach( PerformanceClass.allCases ) { performanceClass in
                    Button {
                        classFilter = classFilter == performanceClass ? nil : performanceClass
                    } label : {
                        Chip( text : performanceClass.rawValue, isSelected : classFilter == performanceClass, colour : Theme.classColour( performanceClass ) )
                    }
                }

                if compareIDs.count == 2 {
                    Button {
                        showsComparison = true
                    } label : {
                        Chip( text : "Compare 2", symbol : "rectangle.split.2x1", isSelected : true, colour : Theme.cool )
                    }
                    .accessibilityIdentifier( "compareButton" )
                }
            }
            .buttonStyle( .plain )
        }
    }

    private func row( _ car : CarDefinition ) -> some View {
        let performance = PerformanceProfile.measure( car.baseSpec )
        let isOwned = store.save.owns( car.id )
        let isLocked = store.save.profile.level < car.unlockLevel

        return Button {
            focusedID = car.id
        } label : {
            HStack( spacing : 10 ) {
                CarTopView( definition : car, appearance : CarAppearance( paintHex : car.defaultPaintHex ) )
                    .frame( width : 22, height : 46 )

                VStack( alignment : .leading, spacing : 1 ) {
                    Text( car.fullName )
                        .font( .label( 14, weight : .bold ) )
                        .foregroundStyle( isLocked ? Theme.secondaryText : .white )
                        .lineLimit( 1 )

                    HStack( spacing : 6 ) {
                        Text( car.category.title )
                        Text( car.drivetrain.title )
                    }
                    .font( .label( 11, weight : .bold ) )
                    .foregroundStyle( Theme.secondaryText )
                }

                Spacer()

                VStack( alignment : .trailing, spacing : 2 ) {
                    ClassBadge( performance : performance )

                    if isOwned {
                        Text( "OWNED" )
                            .font( .label( 10, weight : .heavy ) )
                            .foregroundStyle( Theme.success )
                    } else if isLocked {
                        Label( "LV \( car.unlockLevel )", systemImage : "lock.fill" )
                            .font( .label( 10, weight : .heavy ) )
                            .foregroundStyle( Theme.secondaryText )
                    } else {
                        Text( car.price.formatted( .number ) )
                            .font( .numeric( 11 ) )
                            .foregroundStyle( store.save.profile.credits >= car.price ? Theme.accent : Theme.hot )
                    }
                }
            }
            .panel( padding : 8, highlighted : car.id == focusedID )
        }
        .buttonStyle( .plain )
        .accessibilityIdentifier( "dealer-\( car.id )" )
    }

    private func detail( _ car : CarDefinition ) -> some View {
        let performance = PerformanceProfile.measure( car.baseSpec )
        let isOwned = store.save.owns( car.id )
        let isFavourite = store.save.favouriteDealershipCars.contains( car.id )
        let isComparing = compareIDs.contains( car.id )
        let canBuy = GarageRules().canBuy( car, in : store.save )

        return ScrollView {
            VStack( alignment : .leading, spacing : 10 ) {
                HStack {
                    VStack( alignment : .leading, spacing : 0 ) {
                        Text( "\( car.manufacturer.name.uppercased() ) · \( String( car.year ) )" )
                            .font( .label( 12, weight : .heavy ) )
                            .foregroundStyle( Color( hex : car.manufacturer.colourHex ) )
                        Text( car.model.uppercased() )
                            .font( .display( 30 ) )
                            .foregroundStyle( .white )
                    }

                    Spacer()

                    Button {
                        store.toggleDealershipFavourite( car.id )
                    } label : {
                        Image( systemName : isFavourite ? "star.fill" : "star" )
                            .font( .system( size : 22 ) )
                            .foregroundStyle( Theme.accent )
                    }
                    .accessibilityLabel( isFavourite ? "Remove favourite" : "Add favourite" )

                    ClassBadge( performance : performance, isLarge : true )
                }

                HStack( alignment : .center, spacing : 14 ) {
                    CarSideView( definition : car, appearance : CarAppearance( paintHex : car.defaultPaintHex ) )
                        .frame( height : 90 )
                        .frame( maxWidth : .infinity )

                    VStack( alignment : .trailing, spacing : 8 ) {
                        if isOwned {
                            Text( "IN YOUR GARAGE" )
                                .font( .display( 18 ) )
                                .foregroundStyle( Theme.success )
                        } else if store.save.profile.level < car.unlockLevel {
                            Label( "Unlocks at level \( car.unlockLevel )", systemImage : "lock.fill" )
                                .font( .label( 14, weight : .bold ) )
                                .foregroundStyle( Theme.secondaryText )
                        } else {
                            CreditsLabel( amount : car.price, size : 20 )

                            Button( "BUY" ) {
                                confirmsPurchase = true
                            }
                            .buttonStyle( .shift )
                            .disabled( !canBuy )
                            .opacity( canBuy ? 1 : 0.4 )
                            .accessibilityIdentifier( "buyCarButton" )
                        }

                        Button( isComparing ? "REMOVE COMPARE" : "COMPARE" ) {
                            if isComparing {
                                compareIDs.removeAll { $0 == car.id }
                            } else {
                                compareIDs = Array( ( compareIDs + [ car.id ] ).suffix( 2 ) )
                            }
                        }
                        .buttonStyle( .shift( .secondary, compact : true ) )
                        .accessibilityIdentifier( "addCompareButton" )
                    }
                }

                Text( car.blurb )
                    .font( .label( 13 ) )
                    .foregroundStyle( Theme.secondaryText )

                HStack( spacing : 6 ) {
                    Text( "EXCELS AT" )
                        .font( .label( 11, weight : .heavy ) )
                        .foregroundStyle( Theme.secondaryText )

                    ForEach( car.strengths ) { strength in
                        Chip( text : strength.title, symbol : strength.symbol )
                    }
                }

                HStack( alignment : .top, spacing : 14 ) {
                    PerformanceBars( performance : performance )
                        .frame( maxWidth : .infinity )
                    SpecGrid( spec : car.baseSpec, performance : performance, unit : store.settings.speedUnit )
                        .frame( maxWidth : .infinity )
                }
                .panel()
            }
        }
        .confirmationDialog( "Buy the \( car.fullName )?", isPresented : $confirmsPurchase, titleVisibility : .visible ) {
            Button( "Buy for \( car.price.formatted( .number ) ) credits" ) {
                if store.buy( car.id ) {
                    GameAudio.shared.play( .reward )
                    Haptics.shared.play( .achievement )
                    store.message = "\( car.fullName ) added to your garage."
                }
            }
            .accessibilityIdentifier( "confirmPurchaseButton" )
        } message : {
            Text( "You have \( store.save.profile.credits.formatted( .number ) ) credits." )
        }
    }
}

struct ComparisonSheet : View {
    let carIDs : [CarID]
    @Environment( GameStore.self ) private var store
    @Environment( \.dismiss ) private var dismiss

    var body : some View {
        let cars = carIDs.compactMap { Cars.named( $0 ) }

        NavigationStack {
            HStack( alignment : .top, spacing : 16 ) {
                ForEach( Array( cars.enumerated() ), id : \.element.id ) { index, car in
                    let performance = PerformanceProfile.measure( car.baseSpec )
                    let other = cars.count == 2 ? PerformanceProfile.measure( cars[ 1 - index ].baseSpec ) : nil

                    VStack( alignment : .leading, spacing : 8 ) {
                        HStack {
                            Text( car.fullName.uppercased() )
                                .font( .display( 18 ) )
                                .foregroundStyle( .white )
                            Spacer()
                            ClassBadge( performance : performance )
                        }

                        CarSideView( definition : car, appearance : CarAppearance( paintHex : car.defaultPaintHex ) )
                            .frame( height : 70 )
                        PerformanceBars( performance : performance, comparison : other )
                        SpecGrid( spec : car.baseSpec, performance : performance, unit : store.settings.speedUnit )
                        CreditsLabel( amount : car.price )
                    }
                    .panel()
                }
            }
            .padding()
            .background( Theme.background )
            .navigationTitle( "Compare" )
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
