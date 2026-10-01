import SwiftUI

enum GarageSort : String, CaseIterable, Identifiable {
    case performance
    case performanceClass
    case drivetrain
    case favourite
    case name

    var id : String {
        rawValue
    }

    var title : String {
        switch self {
        case .performance:
            return "Performance"
        case .performanceClass:
            return "Class"
        case .drivetrain:
            return "Drivetrain"
        case .favourite:
            return "Favourites"
        case .name:
            return "Name"
        }
    }
}

struct GarageView : View {
    @Binding var path : [Screen]
    @Environment( GameStore.self ) private var store
    @State private var focusedID : UUID?
    @State private var sort = GarageSort.performance
    @State private var classFilter : PerformanceClass?
    @State private var drivetrainFilter : Drivetrain?
    @State private var favouritesOnly = false
    @State private var confirmsSale = false
    @State private var showsTopView = false

    private var cars : [OwnedCar] {
        let filtered = store.save.garage.filter { car in
            let performance = PerformanceProfile.measure( CarBuild( owned : car ).spec )
            return ( classFilter.map { performance.performanceClass == $0 } ?? true )
                && ( drivetrainFilter.map { car.drivetrain == $0 } ?? true )
                && ( !favouritesOnly || car.isFavourite )
        }

        return filtered.sorted { lhs, rhs in
            let left = PerformanceProfile.measure( CarBuild( owned : lhs ).spec )
            let right = PerformanceProfile.measure( CarBuild( owned : rhs ).spec )

            switch sort {
            case .performance, .performanceClass:
                return left.index > right.index
            case .drivetrain:
                return lhs.drivetrain.rawValue == rhs.drivetrain.rawValue ? left.index > right.index : lhs.drivetrain.rawValue < rhs.drivetrain.rawValue
            case .favourite:
                return lhs.isFavourite != rhs.isFavourite ? lhs.isFavourite : left.index > right.index
            case .name:
                return lhs.definition.fullName < rhs.definition.fullName
            }
        }
    }

    var body : some View {
        VStack( alignment : .leading, spacing : 10 ) {
            ScreenHeader( title : "Garage", subtitle : "\( store.save.garage.count ) cars" )

            HStack( alignment : .top, spacing : 14 ) {
                VStack( alignment : .leading, spacing : 8 ) {
                    filters

                    ScrollView {
                        VStack( spacing : 6 ) {
                            ForEach( cars ) { car in
                                garageRow( car )
                            }
                        }
                    }
                }
                .frame( width : 300 )

                if let car = store.save.ownedCar( focusedID ?? store.selectedCar?.id ?? UUID() ) ?? store.selectedCar {
                    detail( car )
                }
            }
        }
        .padding( .horizontal, 22 )
        .padding( .vertical, 12 )
        .gameBackground()
    }

    private var filters : some View {
        VStack( alignment : .leading, spacing : 6 ) {
            Picker( "Sort", selection : $sort ) {
                ForEach( GarageSort.allCases ) { option in
                    Text( option.title ).tag( option )
                }
            }
            .pickerStyle( .menu )
            .tint( Theme.accent )

            ScrollView( .horizontal, showsIndicators : false ) {
                HStack( spacing : 5 ) {
                    Button {
                        favouritesOnly.toggle()
                    } label : {
                        Chip( text : "Fav", symbol : "star.fill", isSelected : favouritesOnly )
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
                }
                .buttonStyle( .plain )
            }
        }
    }

    private func garageRow( _ car : OwnedCar ) -> some View {
        let performance = PerformanceProfile.measure( CarBuild( owned : car ).spec )
        let isFocused = car.id == ( focusedID ?? store.selectedCar?.id )

        return Button {
            focusedID = car.id
        } label : {
            HStack( spacing : 10 ) {
                CarTopView( definition : car.definition, appearance : car.appearance )
                    .frame( width : 24, height : 48 )

                VStack( alignment : .leading, spacing : 1 ) {
                    Text( car.definition.fullName )
                        .font( .label( 15, weight : .bold ) )
                        .foregroundStyle( .white )
                        .lineLimit( 1 )

                    HStack( spacing : 6 ) {
                        Text( car.drivetrain.title )
                        Text( "\( car.upgradeCount ) upgrades" )

                        if car.id == store.selectedCar?.id {
                            Text( "SELECTED" ).foregroundStyle( Theme.accent )
                        }
                    }
                    .font( .label( 11, weight : .bold ) )
                    .foregroundStyle( Theme.secondaryText )
                }

                Spacer()

                if car.isFavourite {
                    Image( systemName : "star.fill" )
                        .foregroundStyle( Theme.accent )
                }

                ClassBadge( performance : performance )
            }
            .panel( padding : 8, highlighted : isFocused )
        }
        .buttonStyle( .plain )
        .accessibilityIdentifier( "garage-\( car.carID )" )
    }

    private func detail( _ car : OwnedCar ) -> some View {
        let spec = CarBuild( owned : car ).spec
        let performance = PerformanceProfile.measure( spec )
        let isSelected = car.id == store.selectedCar?.id

        return ScrollView {
            VStack( alignment : .leading, spacing : 10 ) {
                HStack {
                    VStack( alignment : .leading, spacing : 0 ) {
                        Text( car.definition.manufacturer.name.uppercased() )
                            .font( .label( 12, weight : .heavy ) )
                            .foregroundStyle( Color( hex : car.definition.manufacturer.colourHex ) )
                        Text( car.definition.model.uppercased() )
                            .font( .display( 30 ) )
                            .foregroundStyle( .white )
                    }

                    Spacer()

                    Button {
                        store.toggleFavourite( car.id )
                    } label : {
                        Image( systemName : car.isFavourite ? "star.fill" : "star" )
                            .font( .system( size : 22 ) )
                            .foregroundStyle( Theme.accent )
                    }
                    .accessibilityLabel( car.isFavourite ? "Remove favourite" : "Add favourite" )

                    ClassBadge( performance : performance, isLarge : true )
                }

                ZStack( alignment : .topTrailing ) {
                    Group {
                        if showsTopView {
                            CarTopView( definition : car.definition, appearance : car.appearance )
                        } else {
                            CarSideView( definition : car.definition, appearance : car.appearance )
                        }
                    }
                    .frame( height : 120 )
                    .frame( maxWidth : .infinity )

                    Button {
                        showsTopView.toggle()
                    } label : {
                        Image( systemName : "arrow.triangle.2.circlepath" )
                            .foregroundStyle( .white )
                            .padding( 6 )
                            .background( Theme.panelRaised, in : Circle() )
                    }
                    .accessibilityLabel( "Switch view" )
                }

                HStack( spacing : 10 ) {
                    if !isSelected {
                        Button( "SELECT" ) {
                            store.select( car.id )
                        }
                        .buttonStyle( .shift( .primary, compact : true ) )
                        .accessibilityIdentifier( "selectCarButton" )
                    }

                    Button( "UPGRADES" ) {
                        path.append( .upgrades( car.id ) )
                    }
                    .buttonStyle( .shift( .secondary, compact : true ) )
                    .accessibilityIdentifier( "upgradesButton" )

                    Button( "TUNING" ) {
                        path.append( .tuning( car.id ) )
                    }
                    .buttonStyle( .shift( .secondary, compact : true ) )
                    .accessibilityIdentifier( "tuningButton" )

                    Button( "PAINT" ) {
                        path.append( .customise( car.id ) )
                    }
                    .buttonStyle( .shift( .secondary, compact : true ) )
                    .accessibilityIdentifier( "customiseButton" )

                    Spacer()

                    Button( "SELL" ) {
                        confirmsSale = true
                    }
                    .buttonStyle( .shift( .destructive, compact : true ) )
                    .disabled( store.save.garage.count <= 1 )
                }

                HStack( alignment : .top, spacing : 14 ) {
                    PerformanceBars( performance : performance )
                        .frame( maxWidth : .infinity )
                    SpecGrid( spec : spec, performance : performance, unit : store.settings.speedUnit )
                        .frame( maxWidth : .infinity )
                }
                .panel()

                records( for : car )
            }
        }
        .confirmationDialog( "Sell \( car.definition.fullName )?", isPresented : $confirmsSale, titleVisibility : .visible ) {
            Button( "Sell for \( GarageRules().resaleValue( of : car ).formatted( .number ) ) credits", role : .destructive ) {
                store.sell( car.id )
                focusedID = nil
            }
        }
    }

    private func records( for car : OwnedCar ) -> some View {
        let bests = store.save.personalBests
            .filter { $0.key.hasSuffix( "|\( car.carID )" ) }
            .sorted { $0.key < $1.key }
            .prefix( 6 )

        return VStack( alignment : .leading, spacing : 6 ) {
            Text( "RECORDS" )
                .font( .label( 12, weight : .heavy ) )
                .foregroundStyle( Theme.secondaryText )

            HStack( spacing : 20 ) {
                recordItem( "RACES", "\( car.racesEntered )" )
                recordItem( "WINS", "\( car.wins )" )
                recordItem( "DISTANCE", RaceFormat.distance( car.odometer ) )
            }

            ForEach( Array( bests ), id : \.key ) { key, best in
                let parts = key.split( separator : "|" )
                HStack {
                    Text( Tracks.named( String( parts[ 0 ] ) )?.fullName ?? String( parts[ 0 ] ) )
                        .font( .label( 12 ) )
                        .foregroundStyle( .white )
                    Text( String( parts.count > 1 ? parts[ 1 ] : "" ).uppercased() )
                        .font( .label( 10, weight : .heavy ) )
                        .foregroundStyle( Theme.secondaryText )
                    Spacer()
                    Text( best.lowerIsBetter ? RaceFormat.time( best.value ) : "\( Int( best.value ) )" )
                        .font( .numeric( 12 ) )
                        .foregroundStyle( Theme.accent )
                }
            }
        }
        .panel()
    }

    private func recordItem( _ title : String, _ value : String ) -> some View {
        VStack( alignment : .leading, spacing : 0 ) {
            Text( title )
                .font( .label( 10, weight : .heavy ) )
                .foregroundStyle( Theme.secondaryText )
            Text( value )
                .font( .numeric( 15 ) )
                .foregroundStyle( .white )
        }
    }
}
