import SpriteKit
import UIKit

/// Builds the static track scene: ground, run-off, road, markings, kerbs, barriers, gates and scenery.
/// Geometry is split into short chunks so SpriteKit can cull what the camera can't see.
enum TrackRenderer {
    static let chunkSamples = 30

    struct Result {
        let root : SKNode
        let racingLineDots : [SKSpriteNode]
        let groundColour : UIColor
    }

    static func build(
        track : TrackGeometry,
        weather : Weather,
        timeOfDay : TimeOfDay,
        checkpoints : [Double],
        speedTraps : [Double],
        driftZones : [ClosedRange<Double>],
        showsGates : Bool,
        showsZones : Bool
    ) -> Result {
        let root = SKNode()
        let environment = track.layout.environment
        let isWet = weather == .rain
        let roadColour = UIColor( hex : environment.roadHex ).adjusted( brightness : isWet ? 0.72 : 1 )
        let runoffColour = runoffColour( for : track.layout, environment : environment ).adjusted( brightness : isWet ? 0.8 : 1 )
        let groundColour = UIColor( hex : environment.groundHex ).adjusted( brightness : isWet ? 0.85 : 1 )

        addGroundDetail( to : root, track : track, colour : groundColour )
        addBand( to : root, track : track, inner : -track.barrierOffset, outer : track.barrierOffset, colour : runoffColour, z : 1 )
        addBand( to : root, track : track, inner : -track.halfWidth, outer : track.halfWidth, colour : roadColour, z : 2 )
        addEdgeLines( to : root, track : track )
        // Kerbs belong on circuits, not on public roads.
        if track.isClosed && environment != .neonMeridian && environment != .oldTown {
            addKerbs( to : root, track : track )
        }
        addBarriers( to : root, track : track )
        addStartFinish( to : root, track : track )

        if showsGates {
            addGates( to : root, track : track, distances : checkpoints.dropLast(), colour : UIColor( hex : 0x00E5FF ) )
        }

        if !speedTraps.isEmpty {
            addGates( to : root, track : track, distances : Array( speedTraps ), colour : UIColor( hex : 0xFF2D95 ) )
        }

        if showsZones {
            for zone in driftZones {
                addZone( to : root, track : track, range : zone )
            }
        }

        addScenery( to : root, track : track, night : timeOfDay == .night )
        let dots = addRacingLineDots( to : root )

        return Result( root : root, racingLineDots : dots, groundColour : groundColour )
    }

    private static func runoffColour( for layout : TrackLayout, environment : TrackEnvironment ) -> UIColor {
        switch layout.runoff {
        case .gravel:
            return UIColor( hex : 0xB9A98A )
        case .sand:
            return UIColor( hex : 0xD9BF84 )
        case .paved, .pavement:
            return UIColor( hex : environment.roadHex ).adjusted( brightness : 1.35 )
        case .grass:
            return UIColor( hex : environment.runoffHex )
        }
    }

    // MARK: - Geometry helpers

    private static func chunkRanges( _ track : TrackGeometry ) -> [ClosedRange<Int>] {
        let count = track.sampleCount
        var ranges : [ClosedRange<Int>] = []
        var start = 0

        while start < count - ( track.isClosed ? 0 : 1 ) {
            let end = track.isClosed ? start + chunkSamples : min( start + chunkSamples, count - 1 )
            ranges.append( start ... end )
            start += chunkSamples
        }

        return ranges
    }

    private static func point( _ track : TrackGeometry, _ index : Int, _ lateral : Double ) -> CGPoint {
        let wrapped = track.isClosed ? index % track.sampleCount : min( index, track.sampleCount - 1 )
        return ( track.points[ wrapped ] + track.normals[ wrapped ] * lateral ).cgPoint
    }

    private static func strip( _ track : TrackGeometry, _ range : ClosedRange<Int>, inner : Double, outer : Double ) -> CGPath {
        let path = CGMutablePath()
        path.move( to : point( track, range.lowerBound, outer ) )

        for index in range {
            path.addLine( to : point( track, index, outer ) )
        }

        for index in range.reversed() {
            path.addLine( to : point( track, index, inner ) )
        }

        path.closeSubpath()
        return path
    }

    private static func shape( _ path : CGPath, fill : UIColor, z : CGFloat ) -> SKShapeNode {
        let node = SKShapeNode( path : path )
        node.fillColor = fill
        node.strokeColor = .clear
        node.lineWidth = 0
        node.isAntialiased = false
        node.zPosition = z
        return node
    }

    private static func addBand( to root : SKNode, track : TrackGeometry, inner : Double, outer : Double, colour : UIColor, z : CGFloat ) {
        for range in chunkRanges( track ) {
            root.addChild( shape( strip( track, range, inner : inner, outer : outer ), fill : colour, z : z ) )
        }
    }

    // MARK: - Layers

    private static func addGroundDetail( to root : SKNode, track : TrackGeometry, colour : UIColor ) {
        let xs = track.points.map { $0.x }
        let ys = track.points.map { $0.y }
        let bounds = CGRect(
            x : ( xs.min() ?? 0 ) - 250,
            y : ( ys.min() ?? 0 ) - 250,
            width : ( xs.max() ?? 0 ) - ( xs.min() ?? 0 ) + 500,
            height : ( ys.max() ?? 0 ) - ( ys.min() ?? 0 ) + 500
        )
        var generator = SeededGenerator( text : track.layout.id + "ground" )
        let count = min( Int( bounds.width * bounds.height / 5_000 ), 700 )
        let texture = SceneryArtist.softDot

        for _ in 0 ..< count {
            let dot = SKSpriteNode( texture : texture )
            let size = CGFloat( generator.range( 8, 34 ) )
            dot.size = CGSize( width : size, height : size * CGFloat( generator.range( 0.5, 1 ) ) )
            dot.position = CGPoint( x : bounds.minX + CGFloat( generator.unit() ) * bounds.width, y : bounds.minY + CGFloat( generator.unit() ) * bounds.height )
            dot.zRotation = CGFloat( generator.range( 0, .pi ) )
            dot.color = generator.unit() < 0.5 ? colour.adjusted( brightness : 0.8 ) : colour.adjusted( brightness : 1.15 )
            dot.colorBlendFactor = 1
            dot.alpha = 0.35
            dot.zPosition = 0.5
            root.addChild( dot )
        }
    }

    private static func addEdgeLines( to root : SKNode, track : TrackGeometry ) {
        let white = UIColor( white : 0.92, alpha : 0.9 )
        let lineWidth = 0.28

        for range in chunkRanges( track ) {
            for side in [ -1.0, 1.0 ] {
                let inner = side * ( track.halfWidth - 0.45 )
                let outer = side * ( track.halfWidth - 0.45 + lineWidth )
                root.addChild( shape( strip( track, range, inner : min( inner, outer ), outer : max( inner, outer ) ), fill : white, z : 3 ) )
            }
        }

        // Dashed centre line on public roads.
        let environment = track.layout.environment
        let isRoad = !track.isClosed || environment == .neonMeridian || environment == .oldTown

        guard isRoad else {
            return
        }

        let dashes = CGMutablePath()
        var index = 0

        while index < track.sampleCount - 3 {
            dashes.addPath( strip( track, index ... index + 2, inner : -0.1, outer : 0.1 ) )
            index += 6
        }

        root.addChild( shape( dashes, fill : UIColor( hex : 0xF4D03F, alpha : 0.8 ), z : 3 ) )
    }

    private static func addKerbs( to root : SKNode, track : TrackGeometry ) {
        let red = CGMutablePath()
        let white = CGMutablePath()

        for index in 0 ..< track.sampleCount - 1 where abs( track.curvatures[ index ] ) > 1 / 160 {
            let block = ( index / 1 ) % 2 == 0 ? red : white

            for side in [ -1.0, 1.0 ] {
                block.addPath( strip( track, index ... index + 1, inner : side > 0 ? track.halfWidth : -track.halfWidth - 1.1, outer : side > 0 ? track.halfWidth + 1.1 : -track.halfWidth ) )
            }
        }

        root.addChild( shape( red, fill : UIColor( hex : 0xD62C2C ), z : 3.5 ) )
        root.addChild( shape( white, fill : UIColor( white : 0.95, alpha : 1 ), z : 3.5 ) )
    }

    private static func addBarriers( to root : SKNode, track : TrackGeometry ) {
        let colour : UIColor
        let width : CGFloat

        switch track.layout.barrier {
        case .concrete:
            colour = UIColor( hex : 0xBFC5CC )
            width = 0.9
        case .tyres:
            colour = UIColor( white : 0.1, alpha : 1 )
            width = 1.2
        case .guardrail:
            colour = UIColor( hex : 0xD5DBDB )
            width = 0.4
        case .rock:
            colour = UIColor( hex : 0x6E5F4D )
            width = 1.4
        case .fence:
            colour = UIColor( hex : 0x95A5A6 )
            width = 0.3
        }

        for range in chunkRanges( track ) {
            for side in [ -1.0, 1.0 ] {
                let offset = side * track.barrierOffset
                let path = strip( track, range, inner : offset - Double( width ) / 2, outer : offset + Double( width ) / 2 )
                root.addChild( shape( path, fill : colour, z : 6 ) )
            }
        }

        if track.layout.barrier == .tyres {
            let bands = CGMutablePath()
            var index = 0

            while index < track.sampleCount - 1 {
                for side in [ -1.0, 1.0 ] {
                    let offset = side * track.barrierOffset
                    bands.addPath( strip( track, index ... index + 1, inner : offset - 0.6, outer : offset + 0.6 ) )
                }

                index += 4
            }

            root.addChild( shape( bands, fill : UIColor( hex : 0xE74C3C ), z : 6.1 ) )
        }
    }

    private static func addStartFinish( to root : SKNode, track : TrackGeometry ) {
        var lines = [ track.startDistance ]

        if !track.isClosed {
            lines.append( track.finishDistance )
        }

        for distance in lines {
            let line = SKSpriteNode( texture : SceneryArtist.checker )
            line.size = CGSize( width : 2.4, height : track.layout.width )
            line.position = track.point( atDistance : distance ).cgPoint
            line.zRotation = CGFloat( track.tangent( atDistance : distance ).angle )
            line.zPosition = 4
            root.addChild( line )
        }

        // Grid boxes behind the start.
        for slot in 0 ..< 8 {
            let grid = track.gridSlot( slot )
            let box = SKSpriteNode( color : UIColor( white : 1, alpha : 0.7 ), size : CGSize( width : 0.3, height : 2.4 ) )
            box.position = ( grid.position + Vec2( angle : grid.heading ) * 2.6 ).cgPoint
            box.zRotation = CGFloat( grid.heading )
            box.zPosition = 4
            root.addChild( box )
        }

        // Finish gantry for point-to-point routes.
        if !track.isClosed {
            let tangent = track.tangent( atDistance : track.finishDistance )

            for side in [ -1.0, 1.0 ] {
                let post = SKSpriteNode( color : UIColor( hex : 0xFFB324 ), size : CGSize( width : 1.2, height : 1.2 ) )
                post.position = track.point( atDistance : track.finishDistance, lateral : side * ( track.halfWidth + 1.5 ) ).cgPoint
                post.zRotation = CGFloat( tangent.angle )
                post.zPosition = 20
                root.addChild( post )
            }
        }
    }

    private static func addGates<Distances : Sequence>( to root : SKNode, track : TrackGeometry, distances : Distances, colour : UIColor ) where Distances.Element == Double {
        for distance in distances {
            let tangent = track.tangent( atDistance : distance )
            let band = SKSpriteNode( color : colour.withAlphaComponent( 0.55 ), size : CGSize( width : 1.2, height : track.layout.width ) )
            band.position = track.point( atDistance : distance ).cgPoint
            band.zRotation = CGFloat( tangent.angle )
            band.zPosition = 4.5
            band.blendMode = .add
            root.addChild( band )

            for side in [ -1.0, 1.0 ] {
                let post = SKSpriteNode( texture : SceneryArtist.softDot )
                post.color = colour
                post.colorBlendFactor = 1
                post.size = CGSize( width : 3, height : 3 )
                post.position = track.point( atDistance : distance, lateral : side * ( track.halfWidth + 0.8 ) ).cgPoint
                post.zPosition = 20
                post.blendMode = .add
                root.addChild( post )
            }
        }
    }

    private static func addZone( to root : SKNode, track : TrackGeometry, range : ClosedRange<Double> ) {
        let lower = track.index( forDistance : range.lowerBound )
        let upper = track.index( forDistance : range.upperBound )

        guard upper > lower else {
            return
        }

        let path = strip( track, lower ... upper, inner : -track.halfWidth, outer : track.halfWidth )
        root.addChild( shape( path, fill : UIColor( hex : 0xFF9F1C, alpha : 0.16 ), z : 2.5 ) )
    }

    private static func addRacingLineDots( to root : SKNode ) -> [SKSpriteNode] {
        ( 0 ..< 48 ).map { _ in
            let dot = SKSpriteNode( color : .green, size : CGSize( width : 1.6, height : 0.45 ) )
            dot.zPosition = 7
            dot.alpha = 0.75
            dot.isHidden = true
            root.addChild( dot )
            return dot
        }
    }

    // MARK: - Scenery

    private struct SceneryRule {
        let kind : SceneryKind
        let weight : Double
        let size : ClosedRange<Double>
        let gap : ClosedRange<Double>
        let aligned : Bool
        let aspect : Double
    }

    private static func rules( for environment : TrackEnvironment ) -> [SceneryRule] {
        switch environment {
        case .velocityPark:
            return [
                SceneryRule( kind : .grandstand, weight : 1, size : 40 ... 60, gap : 5 ... 8, aligned : true, aspect : 0.3 ),
                SceneryRule( kind : .tree, weight : 3, size : 6 ... 12, gap : 10 ... 60, aligned : false, aspect : 1 ),
                SceneryRule( kind : .tyreStack, weight : 1.5, size : 1.6 ... 2, gap : 0.4 ... 1, aligned : false, aspect : 1 ),
                SceneryRule( kind : .sign, weight : 1, size : 10 ... 14, gap : 1.5 ... 3, aligned : true, aspect : 0.25 ),
                SceneryRule( kind : .lightPole, weight : 0.8, size : 1.5 ... 1.5, gap : 3 ... 5, aligned : false, aspect : 1 )
            ]
        case .solanoHarbour:
            return [
                SceneryRule( kind : .container, weight : 4, size : 12 ... 12, gap : 2 ... 30, aligned : true, aspect : 0.41 ),
                SceneryRule( kind : .crane, weight : 0.5, size : 45 ... 60, gap : 15 ... 40, aligned : false, aspect : 0.125 ),
                SceneryRule( kind : .warehouse, weight : 1, size : 30 ... 50, gap : 20 ... 50, aligned : true, aspect : 0.7 ),
                SceneryRule( kind : .lightPole, weight : 1.2, size : 1.5 ... 1.5, gap : 1 ... 3, aligned : false, aspect : 1 )
            ]
        case .neonMeridian:
            return [
                SceneryRule( kind : .tower, weight : 3, size : 25 ... 45, gap : 6 ... 30, aligned : true, aspect : 1 ),
                SceneryRule( kind : .building, weight : 2, size : 18 ... 30, gap : 4 ... 25, aligned : true, aspect : 1 ),
                SceneryRule( kind : .lightPole, weight : 2, size : 1.5 ... 1.5, gap : 0.6 ... 1.5, aligned : false, aspect : 1 ),
                SceneryRule( kind : .sign, weight : 1, size : 12 ... 16, gap : 1 ... 3, aligned : true, aspect : 0.25 )
            ]
        case .ashgrove:
            return [
                SceneryRule( kind : .warehouse, weight : 3, size : 30 ... 60, gap : 8 ... 40, aligned : true, aspect : 0.6 ),
                SceneryRule( kind : .container, weight : 1.5, size : 12 ... 12, gap : 3 ... 20, aligned : true, aspect : 0.41 ),
                SceneryRule( kind : .rock, weight : 1, size : 2 ... 4, gap : 2 ... 20, aligned : false, aspect : 1 ),
                SceneryRule( kind : .lightPole, weight : 1, size : 1.5 ... 1.5, gap : 1 ... 3, aligned : false, aspect : 1 )
            ]
        case .redMesa:
            return [
                SceneryRule( kind : .rock, weight : 3, size : 3 ... 18, gap : 8 ... 90, aligned : false, aspect : 1 ),
                SceneryRule( kind : .cactus, weight : 3, size : 2 ... 3, gap : 4 ... 60, aligned : false, aspect : 1 ),
                SceneryRule( kind : .sign, weight : 0.3, size : 10 ... 12, gap : 3 ... 6, aligned : true, aspect : 0.25 )
            ]
        case .hollowPines:
            return [
                SceneryRule( kind : .pine, weight : 6, size : 6 ... 11, gap : 1 ... 45, aligned : false, aspect : 1 ),
                SceneryRule( kind : .tree, weight : 1.5, size : 7 ... 12, gap : 3 ... 45, aligned : false, aspect : 1 ),
                SceneryRule( kind : .rock, weight : 0.6, size : 2 ... 4, gap : 1 ... 10, aligned : false, aspect : 1 )
            ]
        case .serpentRidge:
            return [
                SceneryRule( kind : .rock, weight : 3, size : 3 ... 10, gap : 1 ... 30, aligned : false, aspect : 1 ),
                SceneryRule( kind : .pine, weight : 2, size : 5 ... 9, gap : 3 ... 30, aligned : false, aspect : 1 ),
                SceneryRule( kind : .bush, weight : 1.5, size : 2 ... 4, gap : 1 ... 15, aligned : false, aspect : 1 )
            ]
        case .brightwater:
            return [
                SceneryRule( kind : .palm, weight : 3, size : 6 ... 9, gap : 2 ... 30, aligned : false, aspect : 1 ),
                SceneryRule( kind : .building, weight : 1, size : 14 ... 22, gap : 10 ... 40, aligned : true, aspect : 1 ),
                SceneryRule( kind : .rock, weight : 1, size : 3 ... 8, gap : 3 ... 30, aligned : false, aspect : 1 ),
                SceneryRule( kind : .sign, weight : 0.4, size : 10 ... 12, gap : 2 ... 4, aligned : true, aspect : 0.25 )
            ]
        case .kestrelAirfield:
            return [
                SceneryRule( kind : .warehouse, weight : 1.5, size : 50 ... 70, gap : 25 ... 60, aligned : true, aspect : 0.7 ),
                SceneryRule( kind : .cone, weight : 3, size : 0.7 ... 0.7, gap : 0.3 ... 2, aligned : false, aspect : 1 ),
                SceneryRule( kind : .tyreStack, weight : 1, size : 1.6 ... 2, gap : 0.5 ... 1, aligned : false, aspect : 1 ),
                SceneryRule( kind : .lightPole, weight : 1, size : 1.5 ... 1.5, gap : 3 ... 6, aligned : false, aspect : 1 )
            ]
        case .oldTown:
            return [
                SceneryRule( kind : .building, weight : 6, size : 12 ... 22, gap : 0.5 ... 6, aligned : true, aspect : 1 ),
                SceneryRule( kind : .tree, weight : 1, size : 5 ... 8, gap : 1 ... 10, aligned : false, aspect : 1 ),
                SceneryRule( kind : .lightPole, weight : 1, size : 1.5 ... 1.5, gap : 0.4 ... 1, aligned : false, aspect : 1 )
            ]
        }
    }

    private static func addScenery( to root : SKNode, track : TrackGeometry, night : Bool ) {
        let sceneryRules = rules( for : track.layout.environment )
        let totalWeight = sceneryRules.reduce( 0 ) { $0 + $1.weight }
        var generator = SeededGenerator( text : track.layout.id + "scenery" )
        let density = track.layout.environment == .oldTown || track.layout.environment == .neonMeridian ? 9.0 : 14.0
        var distance = 0.0

        while distance < track.length {
            for side in [ -1.0, 1.0 ] where generator.unit() < 0.85 {
                var pick = generator.unit() * totalWeight
                var rule = sceneryRules[ 0 ]

                for candidate in sceneryRules {
                    pick -= candidate.weight

                    if pick <= 0 {
                        rule = candidate
                        break
                    }
                }

                let size = generator.range( rule.size.lowerBound, rule.size.upperBound )
                let depth = size * rule.aspect
                let lateral = side * ( track.barrierOffset + generator.range( rule.gap.lowerBound, rule.gap.upperBound ) + depth / 2 )
                let position = track.point( atDistance : distance, lateral : lateral )

                // Keep clear of every part of the track, including other straights passing nearby.
                let nearest = track.project( position )

                guard abs( nearest.lateral ) - max( size, depth ) / 2 > track.barrierOffset + 0.3 else {
                    continue
                }

                let node = SKSpriteNode( texture : SceneryArtist.texture( for : rule.kind, variant : Int( generator.next() % 6 ), night : night ) )
                node.size = CGSize( width : size, height : depth )
                node.position = position.cgPoint
                node.zRotation = rule.aligned ? CGFloat( track.tangent( atDistance : distance ).angle ) : CGFloat( generator.range( 0, 2 * .pi ) )
                node.zPosition = rule.kind == .crane || rule.kind == .tower ? 40 : ( rule.kind == .tree || rule.kind == .pine || rule.kind == .palm ? 30 : 15 )
                root.addChild( node )

                if night && rule.kind == .lightPole {
                    let glow = SKSpriteNode( texture : SceneryArtist.softDot )
                    glow.size = CGSize( width : 26, height : 26 )
                    glow.color = UIColor( hex : 0xFFE6A8 )
                    glow.colorBlendFactor = 1
                    glow.alpha = 0.55
                    glow.blendMode = .add
                    glow.position = track.point( atDistance : distance, lateral : side * track.halfWidth * 0.6 ).cgPoint
                    glow.zPosition = 95
                    root.addChild( glow )
                }
            }

            distance += density * generator.range( 0.6, 1.4 )
        }
    }
}
