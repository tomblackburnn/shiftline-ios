import SpriteKit
import UIKit

/// Visual representation of a car on track. Pure presentation: reads VehicleState each frame.
final class CarNode : SKNode {
    let body : SKSpriteNode
    private let shadow : SKSpriteNode
    private let brakeLights : [SKSpriteNode]
    private let headlights : [SKSpriteNode]
    private static let nitrousColour = UIColor( red : 0.35, green : 0.6, blue : 1, alpha : 1 )
    private static let boostColour = UIColor( red : 1, green : 0.55, blue : 0.15, alpha : 1 )
    private let nitrousFlame : SKSpriteNode
    private let smoke : SKEmitterNode
    let lengthMetres : CGFloat
    let widthMetres : CGFloat

    init( definition : CarDefinition, appearance : CarAppearance, night : Bool, isGhost : Bool = false ) {
        lengthMetres = CGFloat( definition.length )
        widthMetres = CGFloat( definition.width )
        let image = CarArtist.topDown( definition, appearance : appearance )
        body = SKSpriteNode( texture : SKTexture( image : image ) )
        body.size = CGSize( width : lengthMetres, height : widthMetres )
        body.zPosition = 2

        shadow = SKSpriteNode( texture : SceneryArtist.softDot )
        shadow.color = .black
        shadow.colorBlendFactor = 1
        shadow.alpha = isGhost ? 0 : 0.45
        shadow.size = CGSize( width : lengthMetres * 1.15, height : widthMetres * 1.25 )
        shadow.position = CGPoint( x : -0.25, y : -0.3 )
        shadow.zPosition = 1

        brakeLights = [ -1.0, 1.0 ].map { side in
            let light = SKSpriteNode( texture : SceneryArtist.softDot )
            light.color = UIColor( red : 1, green : 0.08, blue : 0.05, alpha : 1 )
            light.colorBlendFactor = 1
            light.size = CGSize( width : 1.4, height : 1.4 )
            light.position = CGPoint( x : -CGFloat( definition.length ) / 2 + 0.1, y : CGFloat( side ) * CGFloat( definition.width ) * 0.32 )
            light.blendMode = .add
            light.alpha = 0
            light.zPosition = 94
            return light
        }

        headlights = night ? [ -1.0, 1.0 ].map { side in
            let cone = SKSpriteNode( texture : SceneryArtist.headlightCone )
            cone.anchorPoint = CGPoint( x : 0, y : 0.5 )
            cone.size = CGSize( width : 20, height : 9 )
            cone.position = CGPoint( x : CGFloat( definition.length ) / 2 - 0.2, y : CGFloat( side ) * CGFloat( definition.width ) * 0.3 )
            cone.zRotation = CGFloat( side ) * 0.04
            cone.blendMode = .add
            cone.alpha = 0.28
            cone.zPosition = 93
            return cone
        } : []

        nitrousFlame = SKSpriteNode( texture : SceneryArtist.softDot )
        nitrousFlame.color = CarNode.nitrousColour
        nitrousFlame.colorBlendFactor = 1
        nitrousFlame.size = CGSize( width : 3.2, height : 1.2 )
        nitrousFlame.position = CGPoint( x : -CGFloat( definition.length ) / 2 - 1.1, y : 0 )
        nitrousFlame.blendMode = .add
        nitrousFlame.alpha = 0
        nitrousFlame.zPosition = 94

        smoke = SKEmitterNode()
        smoke.particleTexture = SceneryArtist.softDot
        smoke.particleBirthRate = 0
        smoke.particleLifetime = 1.4
        smoke.particleLifetimeRange = 0.6
        smoke.particleSize = CGSize( width : 2.2, height : 2.2 )
        smoke.particleScaleSpeed = 2.2
        smoke.particleAlpha = 0.32
        smoke.particleAlphaSpeed = -0.24
        smoke.particleColor = UIColor( white : 0.92, alpha : 1 )
        smoke.particleColorBlendFactor = 1
        smoke.particleSpeed = 1.5
        smoke.particleSpeedRange = 1.5
        smoke.emissionAngleRange = .pi * 2
        smoke.particlePositionRange = CGVector( dx : 0.6, dy : CGFloat( definition.width ) )
        smoke.position = CGPoint( x : -CGFloat( definition.length ) * 0.32, y : 0 )
        smoke.zPosition = 12

        super.init()
        addChild( shadow )
        addChild( body )
        brakeLights.forEach { addChild( $0 ) }
        headlights.forEach { addChild( $0 ) }
        addChild( nitrousFlame )

        if isGhost {
            body.alpha = 0.4
            body.color = UIColor( hex : 0x7FE3FF )
            body.colorBlendFactor = 0.5
        } else {
            addChild( smoke )
        }
    }

    required init?( coder : NSCoder ) {
        fatalError( "init(coder:) is not used" )
    }

    /// Smoke particles must live in world space so they trail behind the car.
    func attachSmoke( to world : SKNode ) {
        smoke.targetNode = world
    }

    func update( state : VehicleState, previous : VehicleState, alpha : Double, surfaceIsRunoff : Bool, isBoosting : Bool = false ) {
        let position = lerp( previous.position, state.position, alpha )
        let headingDelta = wrapAngle( state.heading - previous.heading )
        self.position = position.cgPoint
        zRotation = CGFloat( previous.heading + headingDelta * alpha )

        // Weight transfer: a touch of squat, dive and body roll.
        let pitch = clamp( state.longitudinalAcceleration / 30, -0.04, 0.04 )
        let roll = clamp( state.lateralAcceleration / 40, -0.035, 0.035 )
        body.xScale = CGFloat( 1 - abs( pitch ) * 0.5 )
        body.yScale = CGFloat( 1 - abs( roll ) )
        body.position = CGPoint( x : CGFloat( -pitch * 4 ), y : CGFloat( -roll * 5 ) )
        shadow.position = CGPoint( x : -0.25 + CGFloat( pitch * 6 ), y : -0.3 + CGFloat( roll * 6 ) )

        let braking = state.brake > 0.05 && state.forwardSpeed > 0.5
        brakeLights.forEach { $0.alpha = braking ? 0.95 : 0.12 }
        // Nitrous burns blue; start and slingshot boosts burn orange.
        let hasFlame = state.isNitrousActive || isBoosting
        nitrousFlame.color = state.isNitrousActive ? CarNode.nitrousColour : CarNode.boostColour
        nitrousFlame.alpha = hasFlame ? CGFloat( 0.7 + 0.3 * Double.random( in : 0 ... 1 ) ) : 0
        nitrousFlame.xScale = hasFlame ? CGFloat.random( in : 0.8 ... 1.3 ) : 1

        let slide = max( state.rearSlide - 0.55, 0 ) * 2.2 + max( state.wheelspin - 0.1, 0 ) * 1.4
        let slideSmoke = min( slide, 1.5 ) * ( state.speed > 3 || state.wheelspin > 0.3 ? 1 : 0 )
        smoke.particleBirthRate = CGFloat( slideSmoke * 90 + ( surfaceIsRunoff && state.speed > 8 ? 30 : 0 ) )
        smoke.particleColor = surfaceIsRunoff ? UIColor( hex : 0xB39B77 ) : UIColor( white : 0.92, alpha : 1 )
    }
}

/// Recycles thin dark quads for tyre marks; oldest marks are reused first and fade over time.
final class SkidMarkLayer : SKNode {
    private var pool : [SKSpriteNode] = []
    private var nextIndex = 0
    private var lastPositions : [Int : [Vec2]] = [:]
    static let capacity = 700

    override init() {
        super.init()
        zPosition = 5

        for _ in 0 ..< SkidMarkLayer.capacity {
            let mark = SKSpriteNode( color : UIColor( white : 0.05, alpha : 1 ), size : CGSize( width : 1, height : 0.28 ) )
            mark.alpha = 0
            addChild( mark )
            pool.append( mark )
        }
    }

    required init?( coder : NSCoder ) {
        fatalError( "init(coder:) is not used" )
    }

    /// Lays marks from each rear wheel while the car is sliding, spinning or locked.
    func update( carID : Int, state : VehicleState, width : Double, length : Double ) {
        let intensity = max( state.rearSlide - 0.5, 0 ) * 1.8 + max( state.wheelspin - 0.15, 0 ) + ( state.isLockingWheels ? 0.8 : 0 )
        let forward = state.forward
        let left = forward.perpendicular
        let wheels = [ -1.0, 1.0 ].map { state.position - forward * ( length * 0.3 ) + left * ( $0 * width * 0.4 ) }

        guard intensity > 0.05 && state.speed > 1 else {
            lastPositions[ carID ] = nil
            return
        }

        let previous = lastPositions[ carID ] ?? wheels

        for ( index, wheel ) in wheels.enumerated() {
            let start = previous[ index ]
            let segment = wheel - start
            let length = segment.length

            guard length > 0.25 && length < 6 else {
                continue
            }

            let mark = pool[ nextIndex ]
            nextIndex = ( nextIndex + 1 ) % pool.count
            mark.removeAllActions()
            mark.position = ( ( start + wheel ) / 2 ).cgPoint
            mark.zRotation = CGFloat( segment.angle )
            mark.size = CGSize( width : length + 0.1, height : 0.28 )
            mark.alpha = CGFloat( min( intensity, 1 ) * 0.5 )
            mark.run( SKAction.sequence( [ SKAction.wait( forDuration : 12 ), SKAction.fadeOut( withDuration : 6 ) ] ) )
        }

        lastPositions[ carID ] = wheels
    }
}

/// A handful of reusable spark bursts for collisions.
final class SparkPool : SKNode {
    private var emitters : [SKEmitterNode] = []
    private var nextIndex = 0

    override init() {
        super.init()
        zPosition = 20

        for _ in 0 ..< 6 {
            let emitter = SKEmitterNode()
            emitter.particleTexture = SceneryArtist.spark
            emitter.particleBirthRate = 0
            emitter.particleLifetime = 0.35
            emitter.particleLifetimeRange = 0.2
            emitter.particleSize = CGSize( width : 0.5, height : 0.12 )
            emitter.particleSpeed = 22
            emitter.particleSpeedRange = 12
            emitter.emissionAngleRange = .pi * 2
            emitter.particleColor = UIColor( red : 1, green : 0.75, blue : 0.3, alpha : 1 )
            emitter.particleColorBlendFactor = 1
            emitter.particleAlphaSpeed = -2.5
            emitter.particleBlendMode = .add
            emitter.particleRotationRange = .pi
            addChild( emitter )
            emitters.append( emitter )
        }
    }

    required init?( coder : NSCoder ) {
        fatalError( "init(coder:) is not used" )
    }

    func burst( at point : Vec2, intensity : Double ) {
        let emitter = emitters[ nextIndex ]
        nextIndex = ( nextIndex + 1 ) % emitters.count
        emitter.position = point.cgPoint
        emitter.numParticlesToEmit = Int( clamp( intensity * 6, 8, 60 ) )
        emitter.particleBirthRate = 600
        emitter.resetSimulation()
    }
}
