import SwiftUI

struct RaceHUDView : View {
    let model : RaceViewModel
    let settings : GameSettings
    var onPause : () -> Void

    var body : some View {
        let hud = model.hud

        ZStack {
            VStack {
                HStack( alignment : .top ) {
                    ModeItemsPanel( items : hud.items )
                    Spacer()

                    if let drift = hud.drift {
                        DriftScorePanel( drift : drift )
                    }

                    Spacer()

                    VStack( alignment : .trailing, spacing : 8 ) {
                        Button( action : onPause ) {
                            Image( systemName : "pause.fill" )
                                .font( .system( size : 18, weight : .bold ) )
                                .foregroundStyle( .white )
                                .frame( width : 46, height : 40 )
                                .background( SlantedShape( slant : 6 ).fill( Color.black.opacity( 0.55 ) ) )
                        }
                        .accessibilityLabel( "Pause" )

                        if settings.showMinimap {
                            MinimapView( track : model.session.track, dots : model.carDots )
                                .frame( width : 130, height : 100 )
                        }
                    }
                }

                Spacer()
            }
            .padding( .horizontal, 18 )
            .padding( .top, 10 )

            VStack( spacing : 6 ) {
                if let instruction = hud.tutorialInstruction {
                    VStack( spacing : 2 ) {
                        Text( instruction.uppercased() )
                            .font( .display( 20 ) )
                            .foregroundStyle( Theme.accent )

                        if let hint = hud.tutorialHint {
                            Text( hint )
                                .font( .label( 14 ) )
                                .foregroundStyle( .white )
                        }
                    }
                    .padding( .horizontal, 18 )
                    .padding( .vertical, 8 )
                    .background( Color.black.opacity( 0.6 ), in : RoundedRectangle( cornerRadius : 12 ) )
                }

                ForEach( model.banners ) { banner in
                    BannerView( banner : banner )
                        .transition( .scale( scale : 0.6 ).combined( with : .opacity ) )
                }

                if hud.wrongWay {
                    Text( "WRONG WAY" )
                        .font( .display( 28 ) )
                        .foregroundStyle( .white )
                        .padding( .horizontal, 20 )
                        .padding( .vertical, 6 )
                        .background( SlantedShape().fill( Theme.hot ) )
                }

                Spacer()
            }
            .padding( .top, hud.drift == nil ? 60 : 120 )
            .animation( .spring( response : 0.3, dampingFraction : 0.7 ), value : model.banners )

            if let countdown = hud.countdown, countdown <= 3 {
                VStack( spacing : 0 ) {
                    Text( "\( countdown )" )
                        .font( .display( 120 ) )
                        .foregroundStyle( .white )
                        .shadow( color : Theme.hot, radius : 20 )
                        .transition( .scale )
                        .id( countdown )

                    Text( "HIT THE GAS ON 2 FOR A BOOST" )
                        .font( .label( 12, weight : .heavy ) )
                        .foregroundStyle( countdown == 2 ? Theme.accent : .white.opacity( 0.7 ) )
                }
            }

            VStack( spacing : 6 ) {
                Spacer()

                if hud.isBoosting || hud.slipstreamCharge > 0.02 {
                    SlipstreamMeter( charge : hud.slipstreamCharge, isBoosting : hud.isBoosting )
                }

                Speedometer( hud : hud, unit : settings.speedUnit )
                    .padding( .bottom, 8 )
            }
        }
        .allowsHitTesting( true )
    }
}

struct ModeItemsPanel : View {
    let items : [HUDItem]

    var body : some View {
        VStack( alignment : .leading, spacing : 3 ) {
            ForEach( items ) { item in
                HStack( alignment : .firstTextBaseline, spacing : 8 ) {
                    Text( item.label )
                        .font( .label( 11, weight : .heavy ) )
                        .foregroundStyle( item.isWarning ? Theme.hot : Theme.secondaryText )
                        .frame( width : 62, alignment : .leading )

                    Text( item.value )
                        .font( item.isEmphasised ? .display( 30 ) : .numeric( 16 ) )
                        .foregroundStyle( item.isWarning ? Theme.hot : .white )
                        .monospacedDigit()
                }
            }
        }
        .padding( .horizontal, 12 )
        .padding( .vertical, 8 )
        .background( Color.black.opacity( 0.5 ), in : RoundedRectangle( cornerRadius : 10 ) )
    }
}

struct BannerView : View {
    let banner : Banner

    private var colour : Color {
        switch banner.tone {
        case .neutral:
            return .white
        case .good:
            return Theme.success
        case .great:
            return Theme.accent
        case .bad:
            return Theme.hot
        }
    }

    var body : some View {
        VStack( spacing : 0 ) {
            Text( banner.text )
                .font( .display( 30 ) )
                .foregroundStyle( colour )

            if let detail = banner.detail {
                Text( detail )
                    .font( .label( 15, weight : .bold ) )
                    .foregroundStyle( .white )
            }
        }
        .shadow( color : .black.opacity( 0.7 ), radius : 4 )
    }
}

struct DriftScorePanel : View {
    let drift : DriftHUD

    var body : some View {
        VStack( spacing : 2 ) {
            Text( RaceFormat.points( drift.total ) )
                .font( .display( 34 ) )
                .foregroundStyle( .white )
                .contentTransition( .numericText() )

            HStack( spacing : 10 ) {
                Text( drift.pending > 0 ? "+\( RaceFormat.points( drift.pending ) )" : " " )
                    .font( .display( 20 ) )
                    .foregroundStyle( drift.isDrifting ? Theme.accent : Theme.secondaryText )

                Text( String( format : "×%.1f", drift.multiplier ) )
                    .font( .display( 20 ) )
                    .foregroundStyle( .black )
                    .padding( .horizontal, 8 )
                    .background( SlantedShape( slant : 5 ).fill( drift.multiplier > 1 ? Theme.accent : Theme.secondaryText ) )
            }

            DriftAngleIndicator( angle : drift.angle, isActive : drift.isDrifting )
                .frame( width : 140, height : 26 )

            if !drift.isInZone {
                Text( "OUTSIDE ZONE" )
                    .font( .label( 11, weight : .heavy ) )
                    .foregroundStyle( Theme.secondaryText )
            }
        }
        .padding( .horizontal, 14 )
        .padding( .vertical, 6 )
        .background( Color.black.opacity( 0.5 ), in : RoundedRectangle( cornerRadius : 12 ) )
    }
}

struct DriftAngleIndicator : View {
    let angle : Double
    let isActive : Bool

    var body : some View {
        Canvas { context, size in
            var arc = Path()
            arc.addArc( center : CGPoint( x : size.width / 2, y : size.height * 2.2 ), radius : size.height * 2, startAngle : .degrees( -120 ), endAngle : .degrees( -60 ), clockwise : false )
            context.stroke( arc, with : .color( .white.opacity( 0.25 ) ), lineWidth : 3 )
            let clamped = clamp( angle, -70, 70 )
            let needle = Angle.degrees( -90 - clamped * 30 / 70 )
            let centre = CGPoint( x : size.width / 2, y : size.height * 2.2 )
            let reach = size.height * 2
            let tip = CGPoint( x : centre.x + CGFloat( cos( needle.radians ) ) * reach, y : centre.y + CGFloat( sin( needle.radians ) ) * reach )
            context.fill( Path( ellipseIn : CGRect( x : tip.x - 5, y : tip.y - 5, width : 10, height : 10 ) ), with : .color( isActive ? Theme.accent : Theme.secondaryText ) )
        }
        .accessibilityLabel( "Drift angle \( Int( abs( angle ) ) ) degrees" )
    }
}

/// Fills while tucked in behind another car; a full bar fires a slingshot boost.
struct SlipstreamMeter : View {
    let charge : Double
    let isBoosting : Bool

    var body : some View {
        HStack( spacing : 6 ) {
            Image( systemName : isBoosting ? "flame.fill" : "wind" )
            Text( isBoosting ? "BOOST" : "SLIPSTREAM" )
                .font( .label( 11, weight : .heavy ) )

            if !isBoosting {
                Capsule()
                    .fill( Theme.cool )
                    .frame( width : 60 * clamp( charge, 0, 1 ), height : 5 )
                    .frame( width : 60, alignment : .leading )
                    .background( Capsule().fill( Theme.stroke ) )
            }
        }
        .font( .system( size : 11, weight : .bold ) )
        .foregroundStyle( isBoosting ? Theme.orange : Theme.cool )
        .padding( .horizontal, 10 )
        .padding( .vertical, 4 )
        .background( Color.black.opacity( 0.5 ), in : Capsule() )
        .accessibilityElement( children : .ignore )
        .accessibilityLabel( isBoosting ? "Boost" : "Slipstream \( Int( charge * 100 ) ) percent" )
    }
}

struct Speedometer : View {
    let hud : RaceHUD
    let unit : SpeedUnit

    var body : some View {
        let inWindow = hud.isManual && hud.window( contains : hud.rpmFraction )

        HStack( alignment : .center, spacing : 10 ) {
            VStack( alignment : .trailing, spacing : -4 ) {
                Text( "\( hud.speed )" )
                    .font( .display( 38 ) )
                    .foregroundStyle( .white )
                    .monospacedDigit()
                    .frame( minWidth : 74, alignment : .trailing )

                Text( unit.title.uppercased() )
                    .font( .label( 10, weight : .heavy ) )
                    .foregroundStyle( Theme.secondaryText )
            }

            VStack( alignment : .leading, spacing : 4 ) {
                RPMBar( fraction : hud.rpmFraction, window : hud.shiftWindow, isLimiting : hud.isOnLimiter, isManual : hud.isManual )
                    .frame( width : 120, height : 12 )

                HStack( spacing : 6 ) {
                    if hud.boost > 0.02 {
                        Label( "\( Int( hud.boost * 100 ) )%", systemImage : "fanblades.fill" )
                            .font( .label( 10, weight : .bold ) )
                            .foregroundStyle( Theme.cool )
                    }

                    if let nitrous = hud.nitrousFraction {
                        HStack( spacing : 3 ) {
                            Image( systemName : "bolt.fill" )
                                .foregroundStyle( Theme.cool )
                            Capsule()
                                .fill( Theme.cool )
                                .frame( width : 40 * nitrous, height : 4 )
                                .frame( width : 40, alignment : .leading )
                                .background( Capsule().fill( Theme.stroke ) )
                        }
                        .font( .system( size : 10 ) )
                    }
                }
                .frame( height : 12 )
            }

            Text( hud.gear )
                .font( .display( 32 ) )
                .foregroundStyle( inWindow ? Color.black : Color.white )
                .frame( width : 38, height : 44 )
                .background( SlantedShape( slant : 5 ).fill( inWindow ? Theme.success : Color.black.opacity( 0.55 ) ) )
        }
        .padding( .horizontal, 10 )
        .padding( .vertical, 4 )
        .background( Color.black.opacity( 0.45 ), in : RoundedRectangle( cornerRadius : 12 ) )
        .accessibilityElement( children : .combine )
        .accessibilityLabel( "\( hud.speed ) \( unit.title ), gear \( hud.gear )" )
    }
}

extension RaceHUD {
    func window( contains fraction : Double ) -> Bool {
        shiftWindow.contains( fraction )
    }
}

struct RPMBar : View {
    let fraction : Double
    let window : ClosedRange<Double>
    let isLimiting : Bool
    var isManual = true
    var launchWindow : ClosedRange<Double>?

    var body : some View {
        GeometryReader { proxy in
            let width = proxy.size.width

            ZStack( alignment : .leading ) {
                RoundedRectangle( cornerRadius : 3 ).fill( Color.white.opacity( 0.12 ) )

                if let launchWindow {
                    Rectangle()
                        .fill( Theme.cool.opacity( 0.45 ) )
                        .frame( width : width * ( launchWindow.upperBound - launchWindow.lowerBound ) )
                        .offset( x : width * launchWindow.lowerBound )
                }

                if isManual {
                    Rectangle()
                        .fill( Theme.success.opacity( 0.45 ) )
                        .frame( width : width * ( window.upperBound - window.lowerBound ) )
                        .offset( x : width * window.lowerBound )
                }

                Rectangle()
                    .fill( Theme.hot.opacity( 0.45 ) )
                    .frame( width : width * 0.03 )
                    .offset( x : width * 0.97 )

                RoundedRectangle( cornerRadius : 3 )
                    .fill(
                        isLimiting
                            ? AnyShapeStyle( Theme.hot )
                            : AnyShapeStyle( LinearGradient( colors : [ Theme.cool, Theme.accent, Theme.hot ], startPoint : .leading, endPoint : .trailing ) )
                    )
                    .frame( width : width * clamp( fraction, 0, 1 ) )
            }
        }
        .accessibilityLabel( "RPM \( Int( fraction * 100 ) ) percent" )
    }
}

struct MinimapView : View {
    let track : TrackGeometry
    let dots : [( position : CGPoint, isPlayer : Bool, isEliminated : Bool )]

    var body : some View {
        Canvas { context, size in
            let points = stride( from : 0, to : track.sampleCount, by : 5 ).map { track.points[ $0 ].cgPoint }

            guard let minX = points.map( \.x ).min(),
                  let maxX = points.map( \.x ).max(),
                  let minY = points.map( \.y ).min(),
                  let maxY = points.map( \.y ).max() else {
                return
            }

            let scale = min( ( size.width - 12 ) / max( maxX - minX, 1 ), ( size.height - 12 ) / max( maxY - minY, 1 ) )
            let offsetX = ( size.width - ( maxX - minX ) * scale ) / 2
            let offsetY = ( size.height - ( maxY - minY ) * scale ) / 2
            let map : ( CGPoint ) -> CGPoint = { point in
                CGPoint( x : offsetX + ( point.x - minX ) * scale, y : size.height - offsetY - ( point.y - minY ) * scale )
            }

            var path = Path()
            path.addLines( points.map( map ) )

            if track.isClosed {
                path.closeSubpath()
            }

            context.stroke( path, with : .color( .white.opacity( 0.7 ) ), style : StrokeStyle( lineWidth : 3, lineCap : .round, lineJoin : .round ) )

            for checkpoint in track.checkpoints {
                let point = map( track.point( atDistance : checkpoint ).cgPoint )
                context.fill( Path( ellipseIn : CGRect( x : point.x - 2, y : point.y - 2, width : 4, height : 4 ) ), with : .color( Theme.cool ) )
            }

            let finish = map( track.point( atDistance : track.isClosed ? 0 : track.finishDistance ).cgPoint )
            context.fill( Path( CGRect( x : finish.x - 3, y : finish.y - 3, width : 6, height : 6 ) ), with : .color( .white ) )

            for dot in dots where !dot.isEliminated && !dot.isPlayer {
                let point = map( dot.position )
                context.fill( Path( ellipseIn : CGRect( x : point.x - 3, y : point.y - 3, width : 6, height : 6 ) ), with : .color( Theme.hot ) )
            }

            for dot in dots where dot.isPlayer {
                let point = map( dot.position )
                context.fill( Path( ellipseIn : CGRect( x : point.x - 4.5, y : point.y - 4.5, width : 9, height : 9 ) ), with : .color( Theme.accent ) )
            }
        }
        .padding( 4 )
        .background( Color.black.opacity( 0.45 ), in : RoundedRectangle( cornerRadius : 10 ) )
        .accessibilityHidden( true )
    }
}
