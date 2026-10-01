import SpriteKit
import UIKit

extension UIColor {
    convenience init( hex : UInt32, alpha : CGFloat = 1 ) {
        self.init(
            red : CGFloat( ( hex >> 16 ) & 0xFF ) / 255,
            green : CGFloat( ( hex >> 8 ) & 0xFF ) / 255,
            blue : CGFloat( hex & 0xFF ) / 255,
            alpha : alpha
        )
    }

    func adjusted( brightness factor : CGFloat ) -> UIColor {
        var hue : CGFloat = 0
        var saturation : CGFloat = 0
        var brightness : CGFloat = 0
        var alpha : CGFloat = 0
        getHue( &hue, saturation : &saturation, brightness : &brightness, alpha : &alpha )
        return UIColor( hue : hue, saturation : saturation, brightness : clamp( brightness * factor, 0, 1 ), alpha : alpha )
    }
}

/// Draws original car artwork procedurally: top-down sprites for track racing and side profiles for drag.
enum CarArtist {
    static let pixelsPerMetre : CGFloat = 40
    private static var cache : [String : UIImage] = [:]

    private static func cached( _ key : String, _ draw : () -> UIImage ) -> UIImage {
        if let image = cache[ key ] {
            return image
        }

        let image = draw()

        if cache.count > 120 {
            cache.removeAll()
        }

        cache[ key ] = image
        return image
    }

    private static func key( _ prefix : String, _ car : CarDefinition, _ appearance : CarAppearance ) -> String {
        "\( prefix )|\( car.id )|\( appearance.paintHex )|\( appearance.accentHex )|\( appearance.finish.rawValue )|\( appearance.livery.rawValue )|\( appearance.wheelStyle )|\( appearance.wheelHex )|\( appearance.windowTint )|\( appearance.raceNumber )|\( appearance.plate )"
    }

    // MARK: - Top-down

    /// Car pointing to the right (+x), sized in pixels at `pixelsPerMetre`.
    static func topDown( _ car : CarDefinition, appearance : CarAppearance ) -> UIImage {
        cached( key( "top", car, appearance ) ) {
            let length = CGFloat( car.length ) * pixelsPerMetre
            let width = CGFloat( car.width ) * pixelsPerMetre
            let size = CGSize( width : length, height : width )
            let renderer = UIGraphicsImageRenderer( size : size )

            return renderer.image { context in
                drawTopDown( car, appearance : appearance, in : CGRect( origin : .zero, size : size ), context : context.cgContext )
            }
        }
    }

    private static func drawTopDown( _ car : CarDefinition, appearance : CarAppearance, in rect : CGRect, context : CGContext ) {
        let paint = UIColor( hex : appearance.paintHex )
        let accent = UIColor( hex : appearance.accentHex )
        let length = rect.width
        let width = rect.height
        let category = car.category
        let noseTaper : CGFloat = [ .supercar, .hypercar, .trackCar, .sports ].contains( category ) ? 0.2 : 0.1
        let tailTaper : CGFloat = category == .muscle ? 0.05 : 0.08

        // Tyres peek out at the corners.
        context.setFillColor( UIColor( white : 0.08, alpha : 1 ).cgColor )
        let tyreLength = length * 0.16
        let tyreWidth = width * 0.14

        for x in [ length * 0.16, length * 0.72 ] {
            context.fill( CGRect( x : x, y : -tyreWidth * 0.1, width : tyreLength, height : tyreWidth ) )
            context.fill( CGRect( x : x, y : width - tyreWidth * 0.9, width : tyreLength, height : tyreWidth ) )
        }

        // Body outline.
        let inset = width * 0.06
        let body = UIBezierPath()
        body.move( to : CGPoint( x : length * 0.04, y : inset + width * tailTaper ) )
        body.addQuadCurve( to : CGPoint( x : length * 0.3, y : inset ), controlPoint : CGPoint( x : length * 0.06, y : inset ) )
        body.addLine( to : CGPoint( x : length * 0.78, y : inset ) )
        body.addQuadCurve( to : CGPoint( x : length, y : width * ( 0.5 - 0.5 + noseTaper ) + inset * 0.6 ), controlPoint : CGPoint( x : length * 0.97, y : inset ) )
        body.addLine( to : CGPoint( x : length, y : width - width * noseTaper - inset * 0.6 ) )
        body.addQuadCurve( to : CGPoint( x : length * 0.78, y : width - inset ), controlPoint : CGPoint( x : length * 0.97, y : width - inset ) )
        body.addLine( to : CGPoint( x : length * 0.3, y : width - inset ) )
        body.addQuadCurve( to : CGPoint( x : length * 0.04, y : width - inset - width * tailTaper ), controlPoint : CGPoint( x : length * 0.06, y : width - inset ) )
        body.close()

        context.saveGState()
        context.addPath( body.cgPath )
        context.clip()
        context.setFillColor( paint.cgColor )
        context.fill( rect )

        drawLivery( appearance.livery, paint : paint, accent : accent, rect : rect, context : context )

        // Paint finish sheen.
        let sheen : CGFloat

        switch appearance.finish {
        case .gloss:
            sheen = 0.18
        case .metallic:
            sheen = 0.32
        case .matte:
            sheen = 0.04
        case .pearl:
            sheen = 0.4
        }

        let gradient = CGGradient(
            colorsSpace : CGColorSpaceCreateDeviceRGB(),
            colors : [ UIColor( white : 1, alpha : sheen ).cgColor, UIColor( white : 1, alpha : 0 ).cgColor, UIColor( white : 0, alpha : sheen * 0.8 ).cgColor ] as CFArray,
            locations : [ 0, 0.5, 1 ]
        )!
        context.drawLinearGradient( gradient, start : CGPoint( x : 0, y : 0 ), end : CGPoint( x : 0, y : width ), options : [] )
        context.restoreGState()

        context.addPath( body.cgPath )
        context.setStrokeColor( paint.adjusted( brightness : 0.55 ).cgColor )
        context.setLineWidth( 2 )
        context.strokePath()

        // Glasshouse.
        let tint = [ 0.45, 0.6, 0.78, 0.92 ][ clamp( appearance.windowTint, 0, 3 ) ]
        let glass = UIColor( red : 0.08, green : 0.12, blue : 0.18, alpha : CGFloat( tint ) )
        let isOpenTop = category == .roadster || category == .trackCar
        let cabinStart = length * ( category == .muscle ? 0.26 : 0.3 )
        let cabinEnd = length * ( category == .hatchback ? 0.74 : 0.66 )

        if isOpenTop {
            context.setFillColor( UIColor( white : 0.12, alpha : 1 ).cgColor )
            context.fill( CGRect( x : cabinStart + length * 0.08, y : width * 0.24, width : cabinEnd - cabinStart - length * 0.1, height : width * 0.52 ) )
            context.setFillColor( UIColor( white : 0.25, alpha : 1 ).cgColor )
            context.fillEllipse( in : CGRect( x : cabinStart + length * 0.12, y : width * 0.3, width : width * 0.22, height : width * 0.18 ) )
            context.setFillColor( glass.cgColor )
            context.fill( CGRect( x : cabinEnd - length * 0.03, y : width * 0.2, width : length * 0.04, height : width * 0.6 ) )
        } else {
            let windscreen = UIBezierPath()
            windscreen.move( to : CGPoint( x : cabinEnd, y : width * 0.2 ) )
            windscreen.addLine( to : CGPoint( x : cabinEnd - length * 0.1, y : width * 0.24 ) )
            windscreen.addLine( to : CGPoint( x : cabinEnd - length * 0.1, y : width * 0.76 ) )
            windscreen.addLine( to : CGPoint( x : cabinEnd, y : width * 0.8 ) )
            windscreen.close()
            context.setFillColor( glass.cgColor )
            context.addPath( windscreen.cgPath )
            context.fillPath()

            let rear = CGRect( x : cabinStart, y : width * 0.25, width : length * 0.07, height : width * 0.5 )
            context.fill( rear )

            context.setFillColor( paint.adjusted( brightness : 0.9 ).cgColor )
            context.fill( CGRect( x : cabinStart + length * 0.07, y : width * 0.24, width : cabinEnd - cabinStart - length * 0.17, height : width * 0.52 ) )

            context.setFillColor( glass.cgColor )
            context.fill( CGRect( x : cabinStart + length * 0.08, y : width * 0.16, width : cabinEnd - cabinStart - length * 0.18, height : width * 0.06 ) )
            context.fill( CGRect( x : cabinStart + length * 0.08, y : width * 0.78, width : cabinEnd - cabinStart - length * 0.18, height : width * 0.06 ) )
        }

        // Race number roundel on the roof or bonnet.
        if appearance.livery != .none {
            let diameter = width * 0.34
            let centre = CGPoint( x : isOpenTop ? length * 0.82 : ( cabinStart + cabinEnd ) / 2 - length * 0.03, y : width / 2 )
            context.setFillColor( UIColor.white.cgColor )
            context.fillEllipse( in : CGRect( x : centre.x - diameter / 2, y : centre.y - diameter / 2, width : diameter, height : diameter ) )
            let number = "\( appearance.raceNumber )" as NSString
            let attributes : [NSAttributedString.Key : Any] = [
                .font : UIFont.systemFont( ofSize : diameter * 0.6, weight : .black ),
                .foregroundColor : UIColor.black
            ]
            let textSize = number.size( withAttributes : attributes )
            context.saveGState()
            context.translateBy( x : centre.x, y : centre.y )
            context.rotate( by : .pi / 2 )
            number.draw( at : CGPoint( x : -textSize.width / 2, y : -textSize.height / 2 ), withAttributes : attributes )
            context.restoreGState()
        }

        // Aero details.
        if [ .trackCar, .supercar, .hypercar ].contains( category ) || car.downforceCoefficient >= 0.5 {
            context.setFillColor( UIColor( white : 0.1, alpha : 1 ).cgColor )
            context.fill( CGRect( x : length * 0.02, y : width * 0.04, width : length * 0.06, height : width * 0.92 ) )
        }

        if category == .muscle {
            context.setFillColor( paint.adjusted( brightness : 0.6 ).cgColor )
            context.fill( CGRect( x : length * 0.78, y : width * 0.4, width : length * 0.1, height : width * 0.2 ) )
        }

        // Lights.
        context.setFillColor( UIColor( white : 0.95, alpha : 1 ).cgColor )
        context.fill( CGRect( x : length * 0.95, y : width * 0.14, width : length * 0.03, height : width * 0.16 ) )
        context.fill( CGRect( x : length * 0.95, y : width * 0.7, width : length * 0.03, height : width * 0.16 ) )
        context.setFillColor( UIColor( red : 0.5, green : 0.05, blue : 0.05, alpha : 1 ).cgColor )
        context.fill( CGRect( x : length * 0.04, y : width * 0.14, width : length * 0.025, height : width * 0.18 ) )
        context.fill( CGRect( x : length * 0.04, y : width * 0.68, width : length * 0.025, height : width * 0.18 ) )
    }

    private static func drawLivery( _ livery : Livery, paint : UIColor, accent : UIColor, rect : CGRect, context : CGContext ) {
        let length = rect.width
        let width = rect.height
        context.setFillColor( accent.cgColor )

        switch livery {
        case .none:
            break
        case .racingStripes:
            context.fill( CGRect( x : 0, y : width * 0.36, width : length, height : width * 0.1 ) )
            context.fill( CGRect( x : 0, y : width * 0.54, width : length, height : width * 0.1 ) )
        case .sideStripe:
            context.fill( CGRect( x : length * 0.1, y : width * 0.06, width : length * 0.8, height : width * 0.07 ) )
            context.fill( CGRect( x : length * 0.1, y : width * 0.87, width : length * 0.8, height : width * 0.07 ) )
        case .twoTone:
            context.fill( CGRect( x : 0, y : 0, width : length * 0.45, height : width ) )
        case .chevron:
            let path = UIBezierPath()
            path.move( to : CGPoint( x : length * 0.62, y : 0 ) )
            path.addLine( to : CGPoint( x : length * 0.95, y : width / 2 ) )
            path.addLine( to : CGPoint( x : length * 0.62, y : width ) )
            path.addLine( to : CGPoint( x : length * 0.5, y : width ) )
            path.addLine( to : CGPoint( x : length * 0.83, y : width / 2 ) )
            path.addLine( to : CGPoint( x : length * 0.5, y : 0 ) )
            path.close()
            context.addPath( path.cgPath )
            context.fillPath()
        case .checkerHood:
            let cell = width / 6

            for row in 0 ..< 6 {
                for column in 0 ..< 4 where ( row + column ) % 2 == 0 {
                    context.fill( CGRect( x : length * 0.72 + CGFloat( column ) * cell, y : CGFloat( row ) * cell, width : cell, height : cell ) )
                }
            }
        case .splitFade:
            let gradient = CGGradient(
                colorsSpace : CGColorSpaceCreateDeviceRGB(),
                colors : [ accent.cgColor, accent.withAlphaComponent( 0 ).cgColor ] as CFArray,
                locations : [ 0, 1 ]
            )!
            context.drawLinearGradient( gradient, start : CGPoint( x : 0, y : 0 ), end : CGPoint( x : length * 0.8, y : 0 ), options : [] )
        case .endurance:
            context.fill( CGRect( x : 0, y : width * 0.44, width : length, height : width * 0.12 ) )
            context.setFillColor( paint.adjusted( brightness : 0.5 ).cgColor )
            context.fill( CGRect( x : length * 0.85, y : 0, width : length * 0.15, height : width ) )
        case .shiftlineWorks:
            for index in 0 ..< 3 {
                let offset = CGFloat( index ) * length * 0.09
                let path = UIBezierPath()
                path.move( to : CGPoint( x : length * 0.18 + offset, y : 0 ) )
                path.addLine( to : CGPoint( x : length * 0.24 + offset, y : 0 ) )
                path.addLine( to : CGPoint( x : length * 0.36 + offset, y : width ) )
                path.addLine( to : CGPoint( x : length * 0.30 + offset, y : width ) )
                path.close()
                context.setFillColor( [ UIColor( hex : 0xFFB324 ), UIColor( hex : 0xFF6B29 ), UIColor( hex : 0xED2E47 ) ][ index ].cgColor )
                context.addPath( path.cgPath )
                context.fillPath()
            }
        }
    }

    // MARK: - Side profile

    /// Side view facing right, without wheels (wheels are separate so they can spin).
    static func side( _ car : CarDefinition, appearance : CarAppearance ) -> UIImage {
        cached( key( "side", car, appearance ) ) {
            let length = CGFloat( car.length ) * pixelsPerMetre
            let height = sideHeight( for : car.category ) * pixelsPerMetre
            let size = CGSize( width : length, height : height )
            let renderer = UIGraphicsImageRenderer( size : size )

            return renderer.image { context in
                drawSide( car, appearance : appearance, size : size, context : context.cgContext )
            }
        }
    }

    static func sideHeight( for category : CarCategory ) -> CGFloat {
        switch category {
        case .hatchback:
            return 1.5
        case .sedan:
            return 1.45
        case .muscle:
            return 1.38
        case .coupe:
            return 1.35
        case .roadster:
            return 1.25
        case .sports:
            return 1.3
        case .supercar, .trackCar:
            return 1.18
        case .hypercar:
            return 1.12
        }
    }

    /// Wheel centres as fractions of the side image (x of length, y from the bottom).
    static func wheelPositions( for category : CarCategory ) -> [CGFloat] {
        switch category {
        case .hatchback:
            return [ 0.17, 0.8 ]
        case .muscle, .sedan:
            return [ 0.18, 0.77 ]
        default:
            return [ 0.19, 0.78 ]
        }
    }

    private static func drawSide( _ car : CarDefinition, appearance : CarAppearance, size : CGSize, context : CGContext ) {
        let paint = UIColor( hex : appearance.paintHex )
        let accent = UIColor( hex : appearance.accentHex )
        let length = size.width
        let height = size.height
        let category = car.category
        // UIKit coordinates: y grows downwards. Build the silhouette from the ground up.
        let ground = height
        let beltline = height * 0.52
        let wheelRadius = height * 0.24
        let roofHeight : CGFloat
        let cabinFront : CGFloat
        let cabinRear : CGFloat

        switch category {
        case .hatchback:
            roofHeight = height * 0.04
            cabinFront = 0.66
            cabinRear = 0.08
        case .sedan:
            roofHeight = height * 0.08
            cabinFront = 0.66
            cabinRear = 0.22
        case .muscle:
            roofHeight = height * 0.14
            cabinFront = 0.6
            cabinRear = 0.22
        case .coupe, .sports:
            roofHeight = height * 0.12
            cabinFront = 0.64
            cabinRear = 0.2
        case .roadster, .trackCar:
            roofHeight = height * 0.42
            cabinFront = 0.62
            cabinRear = 0.34
        case .supercar, .hypercar:
            roofHeight = height * 0.2
            cabinFront = 0.58
            cabinRear = 0.28
        }

        let body = UIBezierPath()
        body.move( to : CGPoint( x : length * 0.02, y : ground - wheelRadius * 0.55 ) )
        body.addLine( to : CGPoint( x : length * 0.01, y : beltline + height * 0.05 ) )
        body.addQuadCurve( to : CGPoint( x : length * cabinRear, y : category == .hatchback ? roofHeight : beltline - height * 0.06 ), controlPoint : CGPoint( x : length * 0.02, y : beltline - height * 0.08 ) )

        if category != .roadster && category != .trackCar {
            body.addQuadCurve( to : CGPoint( x : length * ( cabinRear + 0.12 ), y : roofHeight ), controlPoint : CGPoint( x : length * cabinRear, y : roofHeight ) )
            body.addLine( to : CGPoint( x : length * ( cabinFront - 0.14 ), y : roofHeight ) )
            body.addQuadCurve( to : CGPoint( x : length * cabinFront, y : beltline - height * 0.02 ), controlPoint : CGPoint( x : length * ( cabinFront - 0.06 ), y : roofHeight ) )
        } else {
            body.addLine( to : CGPoint( x : length * cabinFront, y : beltline - height * 0.02 ) )
        }

        let noseDrop : CGFloat = [ .supercar, .hypercar, .trackCar, .sports ].contains( category ) ? 0.18 : 0.08
        body.addQuadCurve( to : CGPoint( x : length * 0.99, y : beltline + height * noseDrop ), controlPoint : CGPoint( x : length * 0.92, y : beltline - height * 0.02 ) )
        body.addLine( to : CGPoint( x : length * 0.995, y : ground - wheelRadius * 0.45 ) )
        body.close()

        context.saveGState()
        context.addPath( body.cgPath )
        context.clip()
        context.setFillColor( paint.cgColor )
        context.fill( CGRect( origin : .zero, size : size ) )

        context.setFillColor( accent.cgColor )

        switch appearance.livery {
        case .racingStripes, .endurance:
            context.fill( CGRect( x : 0, y : beltline + height * 0.08, width : length, height : height * 0.05 ) )
        case .sideStripe:
            context.fill( CGRect( x : length * 0.1, y : beltline + height * 0.18, width : length * 0.8, height : height * 0.06 ) )
        case .twoTone:
            context.fill( CGRect( x : 0, y : beltline + height * 0.16, width : length, height : height ) )
        case .splitFade, .chevron, .checkerHood, .shiftlineWorks:
            for index in 0 ..< 3 {
                let x = length * ( 0.35 + 0.07 * CGFloat( index ) )
                context.fill( CGRect( x : x, y : beltline, width : length * 0.035, height : height ) )
            }
        case .none:
            break
        }

        let sheen = CGGradient(
            colorsSpace : CGColorSpaceCreateDeviceRGB(),
            colors : [ UIColor( white : 1, alpha : appearance.finish == .matte ? 0.04 : 0.3 ).cgColor, UIColor( white : 0, alpha : 0.25 ).cgColor ] as CFArray,
            locations : [ 0, 1 ]
        )!
        context.drawLinearGradient( sheen, start : CGPoint( x : 0, y : 0 ), end : CGPoint( x : 0, y : height ), options : [] )
        context.restoreGState()

        // Windows.
        if category != .roadster && category != .trackCar {
            let tint = [ 0.5, 0.65, 0.8, 0.93 ][ clamp( appearance.windowTint, 0, 3 ) ]
            let window = UIBezierPath()
            window.move( to : CGPoint( x : length * ( cabinRear + 0.05 ), y : beltline - height * 0.03 ) )
            window.addQuadCurve( to : CGPoint( x : length * ( cabinRear + 0.14 ), y : roofHeight + height * 0.05 ), controlPoint : CGPoint( x : length * ( cabinRear + 0.05 ), y : roofHeight + height * 0.05 ) )
            window.addLine( to : CGPoint( x : length * ( cabinFront - 0.16 ), y : roofHeight + height * 0.05 ) )
            window.addQuadCurve( to : CGPoint( x : length * ( cabinFront - 0.04 ), y : beltline - height * 0.03 ), controlPoint : CGPoint( x : length * ( cabinFront - 0.08 ), y : roofHeight + height * 0.05 ) )
            window.close()
            context.setFillColor( UIColor( red : 0.07, green : 0.1, blue : 0.15, alpha : CGFloat( tint ) ).cgColor )
            context.addPath( window.cgPath )
            context.fillPath()
            context.setFillColor( paint.adjusted( brightness : 0.7 ).cgColor )
            context.fill( CGRect( x : length * ( cabinFront - 0.28 ), y : roofHeight + height * 0.04, width : length * 0.02, height : beltline - roofHeight - height * 0.06 ) )
        } else {
            context.setFillColor( UIColor( white : 0.12, alpha : 1 ).cgColor )
            context.fill( CGRect( x : length * ( cabinRear + 0.04 ), y : beltline - height * 0.2, width : length * 0.14, height : height * 0.18 ) )
            context.setFillColor( UIColor( white : 0.2, alpha : 1 ).cgColor )
            context.fillEllipse( in : CGRect( x : length * ( cabinRear + 0.08 ), y : beltline - height * 0.42, width : height * 0.2, height : height * 0.2 ) )
        }

        // Wheel arches.
        context.setFillColor( UIColor( white : 0.05, alpha : 1 ).cgColor )

        for position in wheelPositions( for : category ) {
            context.fillEllipse( in : CGRect( x : length * position - wheelRadius * 1.15, y : ground - wheelRadius * 2.2, width : wheelRadius * 2.3, height : wheelRadius * 2.3 ) )
        }

        // Rear wing on high-downforce cars.
        if car.downforceCoefficient >= 0.5 || category == .trackCar {
            context.setFillColor( UIColor( white : 0.1, alpha : 1 ).cgColor )
            context.fill( CGRect( x : length * 0.01, y : roofHeight - height * 0.02, width : length * 0.14, height : height * 0.05 ) )
            context.fill( CGRect( x : length * 0.07, y : roofHeight, width : length * 0.02, height : beltline - roofHeight ) )
        }

        // Lights, door number and plate.
        context.setFillColor( UIColor( white : 0.95, alpha : 1 ).cgColor )
        context.fill( CGRect( x : length * 0.95, y : beltline + height * 0.04, width : length * 0.04, height : height * 0.07 ) )
        context.setFillColor( UIColor( red : 0.8, green : 0.05, blue : 0.05, alpha : 1 ).cgColor )
        context.fill( CGRect( x : length * 0.005, y : beltline + height * 0.02, width : length * 0.03, height : height * 0.08 ) )

        if appearance.livery != .none {
            let number = "\( appearance.raceNumber )" as NSString
            let attributes : [NSAttributedString.Key : Any] = [
                .font : UIFont.systemFont( ofSize : height * 0.22, weight : .black ).italic(),
                .foregroundColor : accent.adjusted( brightness : 1.2 )
            ]
            number.draw( at : CGPoint( x : length * 0.42, y : beltline + height * 0.02 ), withAttributes : attributes )
        }

        let plate = CGRect( x : length * 0.008, y : ground - wheelRadius * 1.25, width : length * 0.035, height : height * 0.09 )
        context.setFillColor( UIColor( hex : 0xF4D03F ).cgColor )
        context.fill( plate )
    }

    // MARK: - Wheels

    static func wheel( style : Int, hex : UInt32, diameter : CGFloat ) -> UIImage {
        cached( "wheel|\( style )|\( hex )|\( Int( diameter ) )" ) {
            let size = CGSize( width : diameter, height : diameter )
            let renderer = UIGraphicsImageRenderer( size : size )

            return renderer.image { context in
                let cg = context.cgContext
                let centre = CGPoint( x : diameter / 2, y : diameter / 2 )
                cg.setFillColor( UIColor( white : 0.07, alpha : 1 ).cgColor )
                cg.fillEllipse( in : CGRect( origin : .zero, size : size ) )
                let rimRadius = diameter * 0.34
                let rim = UIColor( hex : hex )
                cg.setFillColor( rim.adjusted( brightness : 0.6 ).cgColor )
                cg.fillEllipse( in : CGRect( x : centre.x - rimRadius, y : centre.y - rimRadius, width : rimRadius * 2, height : rimRadius * 2 ) )
                cg.setStrokeColor( rim.cgColor )
                let spokes = [ 5, 10, 7, 6, 6, 0 ][ clamp( style, 0, 5 ) ]
                cg.setLineWidth( style == 1 ? diameter * 0.02 : diameter * 0.07 )

                for index in 0 ..< spokes {
                    let angle = CGFloat( index ) / CGFloat( max( spokes, 1 ) ) * 2 * .pi
                    cg.move( to : centre )
                    cg.addLine( to : CGPoint( x : centre.x + cos( angle ) * rimRadius, y : centre.y + sin( angle ) * rimRadius ) )
                }

                cg.strokePath()

                if style == 3 || style == 5 {
                    cg.setStrokeColor( rim.cgColor )
                    cg.setLineWidth( diameter * 0.05 )
                    cg.strokeEllipse( in : CGRect( x : centre.x - rimRadius * 0.9, y : centre.y - rimRadius * 0.9, width : rimRadius * 1.8, height : rimRadius * 1.8 ) )
                }

                if style == 5 {
                    cg.setFillColor( rim.cgColor )
                    cg.fillEllipse( in : CGRect( x : centre.x - rimRadius * 0.7, y : centre.y - rimRadius * 0.7, width : rimRadius * 1.4, height : rimRadius * 1.4 ) )
                }

                cg.setFillColor( UIColor( white : 0.85, alpha : 1 ).cgColor )
                cg.fillEllipse( in : CGRect( x : centre.x - diameter * 0.06, y : centre.y - diameter * 0.06, width : diameter * 0.12, height : diameter * 0.12 ) )
            }
        }
    }
}

extension UIFont {
    func italic() -> UIFont {
        guard let descriptor = fontDescriptor.withSymbolicTraits( [ .traitItalic, .traitBold ] ) else {
            return self
        }

        return UIFont( descriptor : descriptor, size : pointSize )
    }
}
