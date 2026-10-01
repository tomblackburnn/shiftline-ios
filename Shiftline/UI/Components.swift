import SwiftUI
import UIKit

struct ScreenHeader<Trailing : View> : View {
    let title : String
    var subtitle : String?
    @ViewBuilder var trailing : () -> Trailing
    @Environment( \.dismiss ) private var dismiss

    var body : some View {
        HStack( alignment : .center, spacing : 14 ) {
            Button {
                GameAudio.shared.play( .tap )
                dismiss()
            } label : {
                Image( systemName : "chevron.left" )
                    .font( .system( size : 18, weight : .bold ) )
                    .frame( width : 40, height : 36 )
                    .background( SlantedShape( slant : 6 ).fill( Theme.panelRaised ) )
            }
            .foregroundStyle( .white )
            .accessibilityLabel( "Back" )

            VStack( alignment : .leading, spacing : 0 ) {
                Text( title.uppercased() )
                    .font( .display( 26 ) )
                    .foregroundStyle( .white )

                if let subtitle {
                    Text( subtitle )
                        .font( .label( 13 ) )
                        .foregroundStyle( Theme.secondaryText )
                }
            }

            Spacer()
            trailing()
        }
    }
}

extension ScreenHeader where Trailing == ProfileStrip {
    init( title : String, subtitle : String? = nil ) {
        self.title = title
        self.subtitle = subtitle
        trailing = { ProfileStrip() }
    }
}

/// Level, XP and credits, shown at the top of most screens.
struct ProfileStrip : View {
    @Environment( GameStore.self ) private var store

    var body : some View {
        let progress = ProgressionRules.experienceIntoLevel( store.save.profile.experience )

        HStack( spacing : 12 ) {
            HStack( spacing : 8 ) {
                Text( "LV \( store.save.profile.level )" )
                    .font( .display( 16 ) )
                    .foregroundStyle( .black )
                    .padding( .horizontal, 10 )
                    .padding( .vertical, 3 )
                    .background( SlantedShape( slant : 5 ).fill( Theme.accent ) )

                ProgressView( value : Double( progress.current ), total : Double( max( progress.needed, 1 ) ) )
                    .tint( Theme.accent )
                    .frame( width : 70 )
            }

            CreditsLabel( amount : store.save.profile.credits )
        }
    }
}

struct CreditsLabel : View {
    let amount : Int
    var size : CGFloat = 17

    var body : some View {
        HStack( spacing : 4 ) {
            Image( systemName : "c.circle.fill" )
                .foregroundStyle( Theme.accent )
            Text( amount.formatted( .number ) )
                .font( .numeric( size ) )
                .foregroundStyle( .white )
                .lineLimit( 1 )
                .fixedSize()
                .contentTransition( .numericText() )
        }
    }
}

struct StatBar : View {
    let label : String
    let value : Double
    var comparison : Double?
    var detail : String?

    var body : some View {
        VStack( alignment : .leading, spacing : 3 ) {
            HStack {
                Text( label.uppercased() )
                    .font( .label( 11, weight : .bold ) )
                    .foregroundStyle( Theme.secondaryText )
                Spacer()

                if let detail {
                    Text( detail )
                        .font( .label( 11, weight : .bold ) )
                        .foregroundStyle( .white )
                }
            }

            GeometryReader { proxy in
                ZStack( alignment : .leading ) {
                    Capsule().fill( Theme.stroke )

                    if let comparison, comparison > value {
                        Capsule()
                            .fill( Theme.success )
                            .frame( width : proxy.size.width * clamp( comparison / 10, 0, 1 ) )
                    }

                    Capsule()
                        .fill( Theme.stripe )
                        .frame( width : proxy.size.width * clamp( min( value, comparison ?? value ) / 10, 0, 1 ) )

                    if let comparison, comparison < value {
                        Capsule()
                            .fill( Theme.hot.opacity( 0.7 ) )
                            .frame( width : proxy.size.width * clamp( value / 10, 0, 1 ) )
                            .mask(
                                HStack( spacing : 0 ) {
                                    Color.clear.frame( width : proxy.size.width * clamp( comparison / 10, 0, 1 ) )
                                    Color.white
                                }
                            )
                    }
                }
            }
            .frame( height : 6 )
            .animation( .easeOut( duration : 0.35 ), value : value )
            .animation( .easeOut( duration : 0.35 ), value : comparison )
        }
        .accessibilityElement( children : .ignore )
        .accessibilityLabel( label )
        .accessibilityValue( accessibilityValue )
    }

    private var accessibilityValue : String {
        let rating = String( format : "%.1f out of 10", value )
        let summary = detail.map { "\( $0 ), \( rating )" } ?? rating

        guard let comparison, abs( comparison - value ) >= 0.05 else {
            return summary
        }

        return summary + String( format : ", compared with %.1f", comparison )
    }
}

struct ClassBadge : View {
    let performance : PerformanceProfile
    var isLarge = false

    var body : some View {
        HStack( spacing : 0 ) {
            Text( performance.performanceClass.rawValue )
                .font( .display( isLarge ? 22 : 14 ) )
                .foregroundStyle( .black )
                .frame( width : isLarge ? 34 : 22 )
                .padding( .vertical, isLarge ? 4 : 2 )
                .background( Theme.classColour( performance.performanceClass ) )

            Text( "\( performance.index )" )
                .font( .numeric( isLarge ? 18 : 12 ) )
                .foregroundStyle( .white )
                .padding( .horizontal, isLarge ? 10 : 6 )
                .padding( .vertical, isLarge ? 4 : 2 )
                .background( Color.black.opacity( 0.6 ) )
        }
        .clipShape( RoundedRectangle( cornerRadius : 4 ) )
        .accessibilityLabel( "Class \( performance.performanceClass.rawValue ), performance index \( performance.index )" )
    }
}

struct Chip : View {
    let text : String
    var symbol : String?
    var isSelected = false
    var colour : Color = Theme.accent

    var body : some View {
        HStack( spacing : 4 ) {
            if let symbol {
                Image( systemName : symbol )
            }

            Text( text.uppercased() )
        }
        .font( .label( 12, weight : .bold ) )
        .foregroundStyle( isSelected ? Color.black : Color.white )
        .padding( .horizontal, 10 )
        .padding( .vertical, 5 )
        .background( SlantedShape( slant : 5 ).fill( isSelected ? colour : Theme.panelRaised ) )
    }
}

/// Side-profile car render with wheels, sized to fit its frame.
struct CarSideView : View {
    let definition : CarDefinition
    let appearance : CarAppearance

    var body : some View {
        GeometryReader { proxy in
            let image = CarArtist.side( definition, appearance : appearance )
            let wheel = CarArtist.wheel( style : appearance.wheelStyle, hex : appearance.wheelHex, diameter : 96 )
            let scale = min( proxy.size.width / image.size.width, proxy.size.height / image.size.height )
            let width = image.size.width * scale
            let height = image.size.height * scale
            let wheelDiameter = height * 0.48

            ZStack( alignment : .bottomLeading ) {
                Ellipse()
                    .fill( Color.black.opacity( 0.45 ) )
                    .frame( width : width * 1.05, height : height * 0.12 )
                    .offset( x : -width * 0.025, y : height * 0.05 )
                    .blur( radius : 6 )

                Image( uiImage : image )
                    .resizable()
                    .frame( width : width, height : height )

                ForEach( Array( CarArtist.wheelPositions( for : definition.category ).enumerated() ), id : \.offset ) { _, fraction in
                    Image( uiImage : wheel )
                        .resizable()
                        .frame( width : wheelDiameter, height : wheelDiameter )
                        .offset( x : width * fraction - wheelDiameter / 2, y : 0 )
                }
            }
            .frame( width : width, height : height )
            .position( x : proxy.size.width / 2, y : proxy.size.height / 2 )
        }
        .accessibilityLabel( definition.fullName )
    }
}

struct CarTopView : View {
    let definition : CarDefinition
    let appearance : CarAppearance

    /// The sprite points right; it is shown nose-up, so it is fitted by its rotated bounds.
    var body : some View {
        GeometryReader { proxy in
            let image = CarArtist.topDown( definition, appearance : appearance )
            let scale = min( proxy.size.width / image.size.height, proxy.size.height / image.size.width )

            Image( uiImage : image )
                .resizable()
                .frame( width : image.size.width * scale, height : image.size.height * scale )
                .rotationEffect( .degrees( -90 ) )
                .position( x : proxy.size.width / 2, y : proxy.size.height / 2 )
        }
        .accessibilityLabel( definition.fullName )
    }
}

/// Outline of a track layout with the start marked.
struct TrackMapView : View {
    let layout : TrackLayout
    var lineWidth : CGFloat = 4

    private static var cache : [TrackID : [CGPoint]] = [:]

    private var points : [CGPoint] {
        if let cached = TrackMapView.cache[ layout.id ] {
            return cached
        }

        let geometry = TrackGeometry( layout : layout )
        let points = stride( from : 0, to : geometry.sampleCount, by : 4 ).map { geometry.points[ $0 ].cgPoint }
        TrackMapView.cache[ layout.id ] = points
        return points
    }

    var body : some View {
        Canvas { context, size in
            let points = self.points

            guard let minX = points.map( \.x ).min(),
                  let maxX = points.map( \.x ).max(),
                  let minY = points.map( \.y ).min(),
                  let maxY = points.map( \.y ).max() else {
                return
            }

            let scale = min( ( size.width - 16 ) / max( maxX - minX, 1 ), ( size.height - 16 ) / max( maxY - minY, 1 ) )
            let offsetX = ( size.width - ( maxX - minX ) * scale ) / 2
            let offsetY = ( size.height - ( maxY - minY ) * scale ) / 2
            let transform : ( CGPoint ) -> CGPoint = { point in
                CGPoint( x : offsetX + ( point.x - minX ) * scale, y : size.height - offsetY - ( point.y - minY ) * scale )
            }

            var path = Path()
            path.addLines( points.map( transform ) )

            if layout.isClosed {
                path.closeSubpath()
            }

            context.stroke( path, with : .color( .white.opacity( 0.25 ) ), style : StrokeStyle( lineWidth : lineWidth + 3, lineCap : .round, lineJoin : .round ) )
            context.stroke( path, with : .color( .white ), style : StrokeStyle( lineWidth : lineWidth, lineCap : .round, lineJoin : .round ) )

            if let first = points.first {
                let start = transform( first )
                context.fill( Path( ellipseIn : CGRect( x : start.x - 5, y : start.y - 5, width : 10, height : 10 ) ), with : .color( Theme.accent ) )
            }

            if !layout.isClosed, let last = points.last {
                let end = transform( last )
                context.fill( Path( ellipseIn : CGRect( x : end.x - 5, y : end.y - 5, width : 10, height : 10 ) ), with : .color( Theme.hot ) )
            }
        }
        .accessibilityLabel( "Map of \( layout.fullName )" )
    }
}

struct MedalBadge : View {
    let placement : Int
    let isScored : Bool

    var body : some View {
        let colour = Theme.medalColour( placement )

        ZStack {
            Circle().fill( colour.opacity( 0.2 ) )
            Circle().stroke( colour, lineWidth : 2 )

            if isScored {
                Image( systemName : placement <= 3 ? "medal.fill" : "flag.checkered" )
                    .font( .system( size : 13, weight : .bold ) )
                    .foregroundStyle( colour )
            } else {
                Text( "\( placement )" )
                    .font( .display( 14 ) )
                    .foregroundStyle( colour )
            }
        }
        .frame( width : 28, height : 28 )
    }
}

struct ToastView : View {
    let message : String

    var body : some View {
        Text( message )
            .font( .label( 15, weight : .bold ) )
            .foregroundStyle( .white )
            .padding( .horizontal, 18 )
            .padding( .vertical, 10 )
            .background( Theme.panelRaised, in : Capsule() )
            .overlay( Capsule().stroke( Theme.accent, lineWidth : 1 ) )
            .shadow( radius : 12 )
    }
}

/// Condensed raw spec line used in garage, dealership and comparison.
struct SpecGrid : View {
    let spec : VehicleSpec
    let performance : PerformanceProfile
    let unit : SpeedUnit

    var body : some View {
        let items : [( String, String )] = [
            ( "Power", "\( Int( performance.horsepower ) ) hp" ),
            ( "Torque", "\( Int( performance.torque ) ) Nm" ),
            ( "Weight", "\( Int( spec.massKilograms ) ) kg" ),
            ( "Drive", spec.drivetrain.title ),
            ( "0-100", String( format : "%.1f s", performance.zeroToHundred ) ),
            ( "Top speed", "\( Int( unit.value( fromKPH : performance.topSpeedKPH ) ) ) \( unit.title )" ),
            ( "Grip", String( format : "%.2f g", performance.lateralG ) ),
            ( "Gears", "\( spec.gearCount )" )
        ]

        LazyVGrid( columns : [ GridItem( .flexible() ), GridItem( .flexible() ) ], alignment : .leading, spacing : 6 ) {
            ForEach( items, id : \.0 ) { item in
                HStack {
                    Text( item.0.uppercased() )
                        .font( .label( 11, weight : .bold ) )
                        .foregroundStyle( Theme.secondaryText )
                    Spacer()
                    Text( item.1 )
                        .font( .numeric( 12 ) )
                        .foregroundStyle( .white )
                        .lineLimit( 1 )
                        .minimumScaleFactor( 0.7 )
                }
            }
        }
    }
}

struct PerformanceBars : View {
    let performance : PerformanceProfile
    var comparison : PerformanceProfile?

    var body : some View {
        VStack( spacing : 7 ) {
            StatBar( label : "Power", value : performance.powerRating, comparison : comparison?.powerRating )
            StatBar( label : "Acceleration", value : performance.accelerationRating, comparison : comparison?.accelerationRating )
            StatBar( label : "Top Speed", value : performance.topSpeedRating, comparison : comparison?.topSpeedRating )
            StatBar( label : "Handling", value : performance.handlingRating, comparison : comparison?.handlingRating )
            StatBar( label : "Braking", value : performance.brakingRating, comparison : comparison?.brakingRating )
            StatBar( label : "Drift", value : performance.driftRating, comparison : comparison?.driftRating )
        }
    }
}
