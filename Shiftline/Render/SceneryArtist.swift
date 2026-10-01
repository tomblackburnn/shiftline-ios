import SpriteKit
import UIKit

enum SceneryKind : CaseIterable {
    case tree
    case pine
    case palm
    case bush
    case rock
    case cactus
    case building
    case tower
    case warehouse
    case container
    case grandstand
    case lightPole
    case tyreStack
    case cone
    case crane
    case sign
}

/// Procedural top-down textures for trackside objects and effects, cached as SKTextures.
enum SceneryArtist {
    private static var cache : [String : SKTexture] = [:]

    static func texture( _ key : String, size : CGSize, draw : @escaping ( CGContext, CGSize ) -> Void ) -> SKTexture {
        if let texture = cache[ key ] {
            return texture
        }

        let image = UIGraphicsImageRenderer( size : size ).image { context in
            draw( context.cgContext, size )
        }

        let texture = SKTexture( image : image )
        cache[ key ] = texture
        return texture
    }

    static func texture( for kind : SceneryKind, variant : Int, night : Bool ) -> SKTexture {
        let key = "scenery-\( kind )-\( variant )-\( night )"

        switch kind {
        case .tree, .bush:
            let colours : [UInt32] = [ 0x2E6B2E, 0x3D7A35, 0x4A8A3A, 0x2C5E34 ]
            return texture( key, size : CGSize( width : 128, height : 128 ) ) { context, size in
                let base = UIColor( hex : colours[ variant % colours.count ] )
                context.setFillColor( UIColor( white : 0, alpha : 0.25 ).cgColor )
                context.fillEllipse( in : CGRect( x : 14, y : 20, width : size.width - 18, height : size.height - 18 ) )

                for index in 0 ..< 6 {
                    let angle = CGFloat( index ) / 6 * 2 * .pi
                    let radius = size.width * 0.22
                    let centre = CGPoint( x : size.width / 2 + cos( angle ) * radius * 0.7, y : size.height / 2 + sin( angle ) * radius * 0.7 )
                    context.setFillColor( base.adjusted( brightness : 0.85 + CGFloat( index % 3 ) * 0.1 ).cgColor )
                    context.fillEllipse( in : CGRect( x : centre.x - radius, y : centre.y - radius, width : radius * 2, height : radius * 2 ) )
                }

                context.setFillColor( base.adjusted( brightness : 1.25 ).cgColor )
                context.fillEllipse( in : CGRect( x : size.width * 0.32, y : size.height * 0.28, width : size.width * 0.3, height : size.height * 0.3 ) )
            }
        case .pine:
            return texture( key, size : CGSize( width : 96, height : 96 ) ) { context, size in
                let centre = CGPoint( x : size.width / 2, y : size.height / 2 )

                for ring in 0 ..< 4 {
                    let radius = size.width * ( 0.48 - CGFloat( ring ) * 0.1 )
                    context.setFillColor( UIColor( hex : 0x1E4D2B ).adjusted( brightness : 0.8 + CGFloat( ring ) * 0.15 ).cgColor )
                    let path = UIBezierPath()

                    for point in 0 ..< 16 {
                        let angle = CGFloat( point ) / 16 * 2 * .pi
                        let reach = point % 2 == 0 ? radius : radius * 0.72
                        let position = CGPoint( x : centre.x + cos( angle ) * reach, y : centre.y + sin( angle ) * reach )
                        point == 0 ? path.move( to : position ) : path.addLine( to : position )
                    }

                    path.close()
                    context.addPath( path.cgPath )
                    context.fillPath()
                }
            }
        case .palm:
            return texture( key, size : CGSize( width : 128, height : 128 ) ) { context, size in
                let centre = CGPoint( x : size.width / 2, y : size.height / 2 )
                context.setStrokeColor( UIColor( hex : 0x3E8E41 ).cgColor )
                context.setLineWidth( 10 )
                context.setLineCap( .round )

                for index in 0 ..< 7 {
                    let angle = CGFloat( index ) / 7 * 2 * .pi + CGFloat( variant )
                    context.move( to : centre )
                    context.addQuadCurve(
                        to : CGPoint( x : centre.x + cos( angle ) * 58, y : centre.y + sin( angle ) * 58 ),
                        control : CGPoint( x : centre.x + cos( angle + 0.4 ) * 40, y : centre.y + sin( angle + 0.4 ) * 40 )
                    )
                }

                context.strokePath()
                context.setFillColor( UIColor( hex : 0x6B4F2A ).cgColor )
                context.fillEllipse( in : CGRect( x : centre.x - 9, y : centre.y - 9, width : 18, height : 18 ) )
            }
        case .rock:
            return texture( key, size : CGSize( width : 96, height : 96 ) ) { context, size in
                let path = UIBezierPath()
                var generator = SeededGenerator( seed : UInt64( variant + 7 ) )

                for point in 0 ..< 9 {
                    let angle = CGFloat( point ) / 9 * 2 * .pi
                    let reach = size.width * CGFloat( generator.range( 0.32, 0.48 ) )
                    let position = CGPoint( x : size.width / 2 + cos( angle ) * reach, y : size.height / 2 + sin( angle ) * reach )
                    point == 0 ? path.move( to : position ) : path.addLine( to : position )
                }

                path.close()
                context.setFillColor( UIColor( hex : 0x8A7D6B ).cgColor )
                context.addPath( path.cgPath )
                context.fillPath()
                context.setFillColor( UIColor( white : 1, alpha : 0.15 ).cgColor )
                context.fillEllipse( in : CGRect( x : size.width * 0.3, y : size.height * 0.25, width : size.width * 0.3, height : size.height * 0.25 ) )
            }
        case .cactus:
            return texture( key, size : CGSize( width : 64, height : 64 ) ) { context, size in
                context.setFillColor( UIColor( hex : 0x4F7942 ).cgColor )
                context.fillEllipse( in : CGRect( x : 20, y : 20, width : 24, height : 24 ) )
                context.fillEllipse( in : CGRect( x : 6, y : 26, width : 16, height : 12 ) )
                context.fillEllipse( in : CGRect( x : 42, y : 24, width : 16, height : 12 ) )
            }
        case .building, .tower, .warehouse:
            let palette : [UInt32] = kind == .warehouse ? [ 0x7B7F86, 0x8C8577, 0x6E7479 ] : [ 0x4B5563, 0x5B6474, 0x3F4652, 0x6B5E57 ]
            return texture( key, size : CGSize( width : 256, height : 256 ) ) { context, size in
                let base = UIColor( hex : palette[ variant % palette.count ] )
                context.setFillColor( base.cgColor )
                context.fill( CGRect( origin : .zero, size : size ) )
                context.setFillColor( base.adjusted( brightness : 0.75 ).cgColor )
                context.fill( CGRect( x : 16, y : 16, width : size.width - 32, height : size.height - 32 ) )

                if kind == .warehouse {
                    context.setFillColor( base.adjusted( brightness : 1.15 ).cgColor )

                    for stripe in 0 ..< 8 {
                        context.fill( CGRect( x : 0, y : CGFloat( stripe ) * 32, width : size.width, height : 10 ) )
                    }
                } else {
                    // Roof plant and lit windows at night.
                    context.setFillColor( base.adjusted( brightness : 1.2 ).cgColor )
                    context.fill( CGRect( x : 60, y : 70, width : 60, height : 40 ) )
                    context.fill( CGRect( x : 150, y : 140, width : 50, height : 60 ) )

                    if night {
                        let neon : [UInt32] = [ 0xFF2D95, 0x00E5FF, 0xFFD60A, 0x7CFF6B ]
                        context.setStrokeColor( UIColor( hex : neon[ variant % neon.count ] ).cgColor )
                        context.setLineWidth( 6 )
                        context.stroke( CGRect( x : 4, y : 4, width : size.width - 8, height : size.height - 8 ) )
                    }
                }
            }
        case .container:
            let colours : [UInt32] = [ 0xC0392B, 0x2471A3, 0x239B56, 0xD68910, 0x7D3C98, 0x5D6D7E ]
            return texture( key, size : CGSize( width : 244, height : 100 ) ) { context, size in
                let base = UIColor( hex : colours[ variant % colours.count ] )
                context.setFillColor( base.cgColor )
                context.fill( CGRect( origin : .zero, size : size ) )
                context.setFillColor( base.adjusted( brightness : 0.75 ).cgColor )

                for rib in stride( from : 8, to : Int( size.width ), by : 14 ) {
                    context.fill( CGRect( x : CGFloat( rib ), y : 0, width : 5, height : size.height ) )
                }
            }
        case .grandstand:
            return texture( key, size : CGSize( width : 400, height : 120 ) ) { context, size in
                context.setFillColor( UIColor( hex : 0x5D6D7E ).cgColor )
                context.fill( CGRect( origin : .zero, size : size ) )
                var generator = SeededGenerator( seed : UInt64( variant + 3 ) )
                let crowd : [UInt32] = [ 0xE74C3C, 0xF1C40F, 0x3498DB, 0xECF0F1, 0x2ECC71, 0xE67E22, 0x9B59B6 ]

                for row in 0 ..< 8 {
                    for seat in 0 ..< 40 where generator.unit() < 0.8 {
                        context.setFillColor( UIColor( hex : crowd[ Int( generator.next() % UInt64( crowd.count ) ) ] ).cgColor )
                        context.fillEllipse( in : CGRect( x : CGFloat( seat ) * 10 + 2, y : CGFloat( row ) * 14 + 6, width : 7, height : 7 ) )
                    }
                }

                context.setFillColor( UIColor( hex : 0xBDC3C7 ).cgColor )
                context.fill( CGRect( x : 0, y : size.height - 10, width : size.width, height : 10 ) )
            }
        case .lightPole:
            return texture( key, size : CGSize( width : 32, height : 32 ) ) { context, size in
                context.setFillColor( UIColor( white : 0.3, alpha : 1 ).cgColor )
                context.fillEllipse( in : CGRect( x : 8, y : 8, width : 16, height : 16 ) )
                context.setFillColor( UIColor( white : 0.8, alpha : 1 ).cgColor )
                context.fillEllipse( in : CGRect( x : 12, y : 12, width : 8, height : 8 ) )
            }
        case .tyreStack:
            return texture( key, size : CGSize( width : 64, height : 64 ) ) { context, size in
                context.setFillColor( UIColor( white : 0.08, alpha : 1 ).cgColor )
                context.fillEllipse( in : CGRect( x : 4, y : 4, width : 56, height : 56 ) )
                context.setStrokeColor( UIColor( hex : variant % 2 == 0 ? 0xE74C3C : 0xF5F5F5 ).cgColor )
                context.setLineWidth( 6 )
                context.strokeEllipse( in : CGRect( x : 12, y : 12, width : 40, height : 40 ) )
            }
        case .cone:
            return texture( key, size : CGSize( width : 32, height : 32 ) ) { context, size in
                context.setFillColor( UIColor( hex : 0xFF6B00 ).cgColor )
                context.fillEllipse( in : CGRect( x : 4, y : 4, width : 24, height : 24 ) )
                context.setFillColor( UIColor.white.cgColor )
                context.fillEllipse( in : CGRect( x : 11, y : 11, width : 10, height : 10 ) )
            }
        case .crane:
            return texture( key, size : CGSize( width : 512, height : 64 ) ) { context, size in
                context.setFillColor( UIColor( hex : 0xF1C40F ).cgColor )
                context.fill( CGRect( x : 0, y : 20, width : size.width, height : 24 ) )
                context.setStrokeColor( UIColor( hex : 0x7D6608 ).cgColor )
                context.setLineWidth( 3 )

                for x in stride( from : 0, to : Int( size.width ), by : 24 ) {
                    context.move( to : CGPoint( x : CGFloat( x ), y : 20 ) )
                    context.addLine( to : CGPoint( x : CGFloat( x + 24 ), y : 44 ) )
                }

                context.strokePath()
                context.setFillColor( UIColor( hex : 0x34495E ).cgColor )
                context.fill( CGRect( x : 40, y : 4, width : 60, height : 56 ) )
            }
        case .sign:
            return texture( key, size : CGSize( width : 160, height : 40 ) ) { context, size in
                let colours : [UInt32] = [ 0xFFB324, 0xED2E47, 0x2E86DE, 0x1ABC9C ]
                context.setFillColor( UIColor( hex : colours[ variant % colours.count ] ).cgColor )
                context.fill( CGRect( origin : .zero, size : size ) )
                let names = [ "SHIFTLINE", "VOLTA OIL", "GRIPMASTER", "NORTHSTAR", "APEX FUEL", "KESTREL" ]
                let text = names[ variant % names.count ] as NSString
                text.draw(
                    at : CGPoint( x : 10, y : 8 ),
                    withAttributes : [ .font : UIFont.systemFont( ofSize : 20, weight : .black ).italic(), .foregroundColor : UIColor.white ]
                )
            }
        }
    }

    // MARK: - Effects

    static var softDot : SKTexture {
        texture( "soft-dot", size : CGSize( width : 64, height : 64 ) ) { context, size in
            let gradient = CGGradient(
                colorsSpace : CGColorSpaceCreateDeviceRGB(),
                colors : [ UIColor.white.cgColor, UIColor( white : 1, alpha : 0 ).cgColor ] as CFArray,
                locations : [ 0, 1 ]
            )!
            context.drawRadialGradient(
                gradient,
                startCenter : CGPoint( x : size.width / 2, y : size.height / 2 ),
                startRadius : 0,
                endCenter : CGPoint( x : size.width / 2, y : size.height / 2 ),
                endRadius : size.width / 2,
                options : []
            )
        }
    }

    static var spark : SKTexture {
        texture( "spark", size : CGSize( width : 16, height : 4 ) ) { context, size in
            context.setFillColor( UIColor.white.cgColor )
            context.fill( CGRect( origin : .zero, size : size ) )
        }
    }

    static var headlightCone : SKTexture {
        texture( "headlight", size : CGSize( width : 256, height : 128 ) ) { context, size in
            let path = UIBezierPath()
            path.move( to : CGPoint( x : 0, y : size.height * 0.4 ) )
            path.addLine( to : CGPoint( x : size.width, y : 0 ) )
            path.addLine( to : CGPoint( x : size.width, y : size.height ) )
            path.addLine( to : CGPoint( x : 0, y : size.height * 0.6 ) )
            path.close()
            context.addPath( path.cgPath )
            context.clip()
            let gradient = CGGradient(
                colorsSpace : CGColorSpaceCreateDeviceRGB(),
                colors : [ UIColor( white : 1, alpha : 0.55 ).cgColor, UIColor( white : 1, alpha : 0 ).cgColor ] as CFArray,
                locations : [ 0, 1 ]
            )!
            context.drawLinearGradient( gradient, start : .zero, end : CGPoint( x : size.width, y : 0 ), options : [] )
        }
    }

    static var checker : SKTexture {
        texture( "checker", size : CGSize( width : 64, height : 64 ) ) { context, size in
            for row in 0 ..< 8 {
                for column in 0 ..< 8 {
                    context.setFillColor( ( row + column ) % 2 == 0 ? UIColor.white.cgColor : UIColor.black.cgColor )
                    context.fill( CGRect( x : CGFloat( column ) * 8, y : CGFloat( row ) * 8, width : 8, height : 8 ) )
                }
            }
        }
    }
}
