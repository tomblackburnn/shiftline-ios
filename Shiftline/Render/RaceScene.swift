import SpriteKit
import UIKit

/// Debug-only overlay switches, shared between the debug menu and scenes.
final class DebugOptions {
    static let shared = DebugOptions()
    var showsFullRacingLine = false
    var showsVectors = false
    var showsAITargets = false
    var showsFPS = false
    var showsTelemetry = false
    var forcedWeather : Weather?
    var forcedTimeOfDay : TimeOfDay?
}

/// Top-down chase-camera presentation of a RaceSession.
final class RaceScene : SKScene {
    let session : RaceSession
    var onFrame : ( ( Double ) -> Void )?
    var cameraShakeEnabled = true

    private let world = SKNode()
    private let cameraNode = SKCameraNode()
    private var carNodes : [CarNode] = []
    private var ghostNode : CarNode?
    private let skidMarks = SkidMarkLayer()
    private let sparks = SparkPool()
    private var racingLineDots : [SKSpriteNode] = []
    private var streaks : [SKSpriteNode] = []
    private var debugLayer = SKNode()
    private var lastUpdate : TimeInterval?
    private var shake = 0.0
    private var cameraHeading = 0.0
    private var cameraPosition = Vec2.zero
    private var zoom = 34.0
    private let isDrift : Bool

    init( session : RaceSession, size : CGSize ) {
        self.session = session

        if case .drift = session.config.kind {
            isDrift = true
        } else {
            isDrift = false
        }

        super.init( size : size )
        scaleMode = .resizeFill
        anchorPoint = CGPoint( x : 0.5, y : 0.5 )
        build()
    }

    required init?( coder : NSCoder ) {
        fatalError( "init(coder:) is not used" )
    }

    private var timeOfDay : TimeOfDay {
        DebugOptions.shared.forcedTimeOfDay ?? session.config.timeOfDay
    }

    private var weather : Weather {
        DebugOptions.shared.forcedWeather ?? session.config.weather
    }

    private func build() {
        let isCheckpoint : Bool
        let isSpeedTrap : Bool

        switch session.config.kind {
        case .checkpoint:
            isCheckpoint = true
            isSpeedTrap = false
        case .speedTrap:
            isCheckpoint = false
            isSpeedTrap = true
        default:
            isCheckpoint = false
            isSpeedTrap = false
        }

        var isSections = false

        if case .drift( let format, _ ) = session.config.kind {
            isSections = format == .sections
        }

        let rendered = TrackRenderer.build(
            track : session.track,
            weather : weather,
            timeOfDay : timeOfDay,
            checkpoints : session.track.checkpoints,
            speedTraps : isSpeedTrap ? session.speedTraps : [],
            driftZones : session.driftZones,
            showsGates : isCheckpoint,
            showsZones : isSections
        )
        backgroundColor = rendered.groundColour
        racingLineDots = rendered.racingLineDots
        world.addChild( rendered.root )
        world.addChild( skidMarks )
        world.addChild( sparks )
        addChild( world )

        let night = timeOfDay == .night

        for car in session.cars {
            let definition = Cars.named( car.entrant.carID ) ?? Cars.all[ 0 ]
            let node = CarNode( definition : definition, appearance : car.entrant.appearance, night : night )
            node.zPosition = car.isPlayer ? 11 : 10
            node.attachSmoke( to : world )
            world.addChild( node )
            carNodes.append( node )
        }

        if let ghost = session.config.ghost, let definition = Cars.named( ghost.carID ) {
            let node = CarNode( definition : definition, appearance : CarAppearance( paintHex : ghost.paintHex ), night : false, isGhost : true )
            node.zPosition = 9
            node.isHidden = true
            world.addChild( node )
            ghostNode = node
        }

        addChild( cameraNode )
        camera = cameraNode
        addAtmosphere()
        addStreaks()
        debugLayer.zPosition = 80
        world.addChild( debugLayer )

        let player = session.player.state
        cameraPosition = player.position
        cameraHeading = player.heading
        cameraNode.position = player.position.cgPoint
        cameraNode.zRotation = CGFloat( player.heading - .pi / 2 )
    }

    private func addAtmosphere() {
        let overlaySize = CGSize( width : 6_000, height : 6_000 )

        switch timeOfDay {
        case .night:
            let dark = SKSpriteNode( color : UIColor( red : 0.02, green : 0.03, blue : 0.1, alpha : 1 ), size : overlaySize )
            dark.alpha = 0.62
            dark.zPosition = 90
            cameraNode.addChild( dark )
        case .sunset:
            let warm = SKSpriteNode( color : UIColor( red : 1, green : 0.45, blue : 0.15, alpha : 1 ), size : overlaySize )
            warm.alpha = 0.16
            warm.zPosition = 90
            cameraNode.addChild( warm )
        case .day:
            break
        }

        switch weather {
        case .rain:
            let gloom = SKSpriteNode( color : UIColor( red : 0.2, green : 0.25, blue : 0.35, alpha : 1 ), size : overlaySize )
            gloom.alpha = 0.18
            gloom.zPosition = 91
            cameraNode.addChild( gloom )

            let rain = SKEmitterNode()
            rain.particleTexture = SceneryArtist.spark
            rain.particleBirthRate = 260
            rain.particleLifetime = 0.5
            rain.particleSize = CGSize( width : 14, height : 1.4 )
            rain.particleColor = UIColor( white : 0.85, alpha : 1 )
            rain.particleColorBlendFactor = 1
            rain.particleAlpha = 0.45
            rain.particleSpeed = 900
            rain.emissionAngle = -.pi / 2 - 0.15
            rain.particleRotation = -.pi / 2 - 0.15
            rain.particlePositionRange = CGVector( dx : 1_400, dy : 20 )
            rain.position = CGPoint( x : 0, y : 500 )
            rain.zPosition = 97
            cameraNode.addChild( rain )
        case .fog:
            let fog = SKSpriteNode( color : UIColor( white : 0.85, alpha : 1 ), size : overlaySize )
            fog.alpha = 0.38
            fog.zPosition = 96
            cameraNode.addChild( fog )
        case .clear:
            break
        }
    }

    private func addStreaks() {
        for _ in 0 ..< 18 {
            let streak = SKSpriteNode( color : .white, size : CGSize( width : 2, height : 90 ) )
            streak.alpha = 0
            streak.zPosition = 98
            streak.blendMode = .add
            cameraNode.addChild( streak )
            streaks.append( streak )
        }
    }

    // MARK: - Frame

    override func update( _ currentTime : TimeInterval ) {
        let delta = lastUpdate.map { min( currentTime - $0, 0.1 ) } ?? 1.0 / 60
        lastUpdate = currentTime
        onFrame?( delta )
        syncCars()
        updateCamera( delta )
        updateRacingLine()
        updateStreaks( delta )
        updateGhost()
        updateDebug()
    }

    func impact( at point : Vec2, intensity : Double ) {
        sparks.burst( at : point, intensity : intensity )

        if cameraShakeEnabled {
            shake = max( shake, min( intensity / 12, 1 ) )
        }
    }

    func kick( _ amount : Double ) {
        if cameraShakeEnabled {
            shake = max( shake, amount )
        }
    }

    private func syncCars() {
        let alpha = session.renderAlpha

        for ( index, car ) in session.cars.enumerated() {
            let node = carNodes[ index ]

            if car.isEliminated {
                if node.alpha > 0 {
                    node.alpha = max( node.alpha - 0.03, 0 )
                }
            }

            node.update( state : car.state, previous : car.previousState, alpha : alpha, surfaceIsRunoff : car.surface == .runoff, isBoosting : car.boostRemaining > 0 )
            skidMarks.update( carID : car.id, state : car.state, width : car.model.spec.width, length : car.model.spec.length )
        }
    }

    private func updateCamera( _ delta : Double ) {
        let player = session.player
        let state = player.state
        let position = lerp( player.previousState.position, state.position, session.renderAlpha )
        let speed = state.speed
        // Keep the player in the lower-middle of the screen, above the speedometer, looking ahead with speed.
        let lookAhead = state.velocity.normalized * min( speed * 0.16, 9 )
        let target = position + lookAhead + state.forward * 3
        let follow = 1 - exp( -delta * 7 )
        cameraPosition = lerp( cameraPosition, target, follow )

        let headingTarget = speed > 2 ? ( state.velocity.angle * 0.35 + state.heading * 0.65 ) : state.heading
        let headingBlend = wrapAngle( headingTarget - cameraHeading )
        cameraHeading = wrapAngle( cameraHeading + headingBlend * ( 1 - exp( -delta * 4.5 ) ) )

        let desiredZoom = clamp( 32 + speed * 0.45, 32, 82 ) + ( isDrift ? 14 : 0 )
        zoom = lerp( zoom, desiredZoom, 1 - exp( -delta * 1.5 ) )

        var shakeOffset = Vec2.zero

        if shake > 0.01 {
            shakeOffset = Vec2( Double.random( in : -1 ... 1 ), Double.random( in : -1 ... 1 ) ) * shake * 1.2
            shake *= exp( -delta * 8 )
        }

        cameraNode.position = ( cameraPosition + shakeOffset ).cgPoint
        cameraNode.zRotation = CGFloat( cameraHeading - .pi / 2 )
        cameraNode.setScale( CGFloat( zoom ) / max( size.height, 1 ) )
    }

    private func updateRacingLine() {
        let player = session.player
        let showsLine = ( player.assists.racingLine && !isDrift ) || DebugOptions.shared.showsFullRacingLine
        let track = session.track

        for ( index, dot ) in racingLineDots.enumerated() {
            guard showsLine, !player.speedProfile.isEmpty else {
                dot.isHidden = true
                continue
            }

            let distance = player.trackDistance + 6 + Double( index ) * 4

            if !track.isClosed && distance > track.finishDistance {
                dot.isHidden = true
                continue
            }

            let lateral = track.racingOffset( atDistance : distance )
            dot.isHidden = false
            dot.position = track.point( atDistance : distance, lateral : lateral ).cgPoint
            dot.zRotation = CGFloat( track.tangent( atDistance : distance ).angle )
            let target = player.speedProfile[ track.index( forDistance : distance ) ]
            let excess = player.state.speed - target

            if excess > 6 {
                dot.color = UIColor( red : 1, green : 0.2, blue : 0.2, alpha : 1 )
            } else if excess > 1.5 {
                dot.color = UIColor( red : 1, green : 0.85, blue : 0.1, alpha : 1 )
            } else {
                dot.color = UIColor( red : 0.2, green : 1, blue : 0.4, alpha : 1 )
            }

            dot.alpha = CGFloat( 0.8 - Double( index ) / Double( racingLineDots.count ) * 0.5 )
        }
    }

    private func updateStreaks( _ delta : Double ) {
        let speed = session.player.state.speed
        let intensity = clamp( ( speed - 38 ) / 40, 0, 1 )

        for streak in streaks {
            guard intensity > 0 else {
                streak.alpha = 0
                continue
            }

            if streak.alpha <= 0.01 || streak.position.y < -size.height * 0.7 {
                streak.position = CGPoint(
                    x : CGFloat.random( in : -size.width / 2 ... size.width / 2 ),
                    y : CGFloat.random( in : size.height * 0.1 ... size.height * 0.7 )
                )
                // Keep the centre of the screen clear around the car.
                if abs( streak.position.x ) < size.width * 0.18 {
                    streak.position.x += streak.position.x < 0 ? -size.width * 0.2 : size.width * 0.2
                }

                streak.alpha = CGFloat( intensity * 0.35 )
            }

            streak.position.y -= CGFloat( speed * 45 * delta )
            streak.yScale = CGFloat( 0.6 + intensity )
            streak.alpha = max( streak.alpha - CGFloat( delta * 0.5 ), 0 )
        }
    }

    private func updateGhost() {
        guard let ghostNode, let ghost = session.config.ghost, session.phase == .racing else {
            ghostNode?.isHidden = true
            return
        }

        let lapTime = session.elapsed - session.player.lapStartTime

        guard let sample = ghost.sample( at : lapTime ), lapTime <= ghost.lapTime + 0.5 else {
            ghostNode.isHidden = true
            return
        }

        ghostNode.isHidden = false
        ghostNode.position = CGPoint( x : CGFloat( sample.x ), y : CGFloat( sample.y ) )
        ghostNode.zRotation = CGFloat( sample.heading )
    }

    private func updateDebug() {
        #if DEBUG
        let options = DebugOptions.shared
        view?.showsFPS = options.showsFPS
        view?.showsNodeCount = options.showsFPS
        debugLayer.removeAllChildren()

        if options.showsVectors {
            for car in session.cars {
                let state = car.state
                debugLayer.addChild( line( from : state.position, to : state.position + state.velocity * 0.5, colour : .cyan ) )
                debugLayer.addChild( line( from : state.position, to : state.position + state.forward * 5, colour : .yellow ) )
                let grip = state.forward.perpendicular * state.lateralAcceleration * 0.4
                debugLayer.addChild( line( from : state.position, to : state.position + grip, colour : .magenta ) )
            }
        }

        if options.showsAITargets {
            for car in session.cars where car.ai != nil {
                let distance = car.trackDistance + 7 + car.state.speed * 0.5
                let target = session.track.point( atDistance : distance, lateral : session.track.racingOffset( atDistance : distance ) )
                debugLayer.addChild( line( from : car.state.position, to : target, colour : .orange ) )
            }
        }

        if options.showsFullRacingLine {
            let path = CGMutablePath()
            let track = session.track

            for index in stride( from : 0, to : track.sampleCount, by : 3 ) {
                let point = ( track.points[ index ] + track.normals[ index ] * track.racingOffsets[ index ] ).cgPoint
                index == 0 ? path.move( to : point ) : path.addLine( to : point )
            }

            let node = SKShapeNode( path : path )
            node.strokeColor = UIColor( white : 1, alpha : 0.5 )
            node.lineWidth = 0.3
            debugLayer.addChild( node )
        }
        #endif
    }

    private func line( from start : Vec2, to end : Vec2, colour : UIColor ) -> SKShapeNode {
        let path = CGMutablePath()
        path.move( to : start.cgPoint )
        path.addLine( to : end.cgPoint )
        let node = SKShapeNode( path : path )
        node.strokeColor = colour
        node.lineWidth = 0.25
        return node
    }
}
