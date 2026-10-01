import SpriteKit
import UIKit

/// Side-on presentation of a DragRace with parallax scenery.
final class DragScene : SKScene {
    let race : DragRace
    let environment : TrackEnvironment
    let timeOfDay : TimeOfDay
    var onFrame : ( ( Double ) -> Void )?
    var cameraShakeEnabled = true

    static let pixelsPerMetre : CGFloat = 26
    private let world = SKNode()
    private let cameraNode = SKCameraNode()
    private var far = SKNode()
    private var mid = SKNode()
    private var cars : [( body : SKSpriteNode, wheels : [SKSpriteNode], smoke : SKEmitterNode, flame : SKSpriteNode, racer : DragRacer, baseline : CGFloat, scale : CGFloat )] = []
    private var lastUpdate : TimeInterval?
    private var shake = 0.0

    init( race : DragRace, environment : TrackEnvironment, timeOfDay : TimeOfDay, size : CGSize ) {
        self.race = race
        self.environment = environment
        self.timeOfDay = timeOfDay
        super.init( size : size )
        scaleMode = .resizeFill
        anchorPoint = CGPoint( x : 0.5, y : 0.5 )
        build()
    }

    required init?( coder : NSCoder ) {
        fatalError( "init(coder:) is not used" )
    }

    private var skyColours : ( UIColor, UIColor ) {
        switch timeOfDay {
        case .day:
            return ( UIColor( hex : 0x5DADE2 ), UIColor( hex : 0xD6EAF8 ) )
        case .sunset:
            return ( UIColor( hex : 0x6C3483 ), UIColor( hex : 0xF5B041 ) )
        case .night:
            return ( UIColor( hex : 0x070B1A ), UIColor( hex : 0x1B2440 ) )
        }
    }

    private func build() {
        backgroundColor = skyColours.0
        addChild( cameraNode )
        camera = cameraNode

        let sky = SKSpriteNode( texture : SceneryArtist.texture( "sky-\( timeOfDay.rawValue )", size : CGSize( width : 8, height : 256 ) ) { [skyColours] context, size in
            let gradient = CGGradient(
                colorsSpace : CGColorSpaceCreateDeviceRGB(),
                colors : [ skyColours.1.cgColor, skyColours.0.cgColor ] as CFArray,
                locations : [ 0, 1 ]
            )!
            context.drawLinearGradient( gradient, start : CGPoint( x : 0, y : size.height ), end : .zero, options : [] )
        } )
        sky.size = CGSize( width : 4_000, height : 2_400 )
        sky.zPosition = -100
        cameraNode.addChild( sky )

        addChild( far )
        addChild( mid )
        addChild( world )
        buildParallax()
        buildTrack()
        buildCars()

        if timeOfDay == .night {
            let dark = SKSpriteNode( color : UIColor( red : 0.02, green : 0.03, blue : 0.08, alpha : 1 ), size : CGSize( width : 4_000, height : 2_400 ) )
            dark.alpha = 0.45
            dark.zPosition = 90
            cameraNode.addChild( dark )
        }
    }

    private func buildParallax() {
        let length = CGFloat( race.length + 500 ) * DragScene.pixelsPerMetre
        var generator = SeededGenerator( text : "drag-\( environment.rawValue )" )
        let isCity = environment == .neonMeridian
        let farColour = timeOfDay == .night ? UIColor( hex : 0x0E1528 ) : ( environment == .redMesa ? UIColor( hex : 0xA0522D ) : UIColor( hex : 0x5D6D7E ) )
        var x : CGFloat = -1_200

        while x < length * 0.2 + 2_000 {
            let width = CGFloat( generator.range( 80, 220 ) )
            let height = CGFloat( isCity ? generator.range( 120, 380 ) : generator.range( 60, 180 ) )
            let shape = SKSpriteNode( color : farColour, size : CGSize( width : width, height : height ) )
            shape.anchorPoint = CGPoint( x : 0, y : 0 )
            shape.position = CGPoint( x : x, y : 150 )
            shape.zPosition = -50

            if isCity || timeOfDay == .night {
                for _ in 0 ..< Int( width * height / 1_800 ) {
                    let window = SKSpriteNode( color : UIColor( hex : [ 0xFFE08A, 0x00E5FF, 0xFF2D95 ][ Int( generator.next() % 3 ) ] ), size : CGSize( width : 5, height : 7 ) )
                    window.anchorPoint = .zero
                    window.position = CGPoint( x : CGFloat( generator.unit() ) * ( width - 6 ), y : CGFloat( generator.unit() ) * ( height - 8 ) )
                    window.alpha = timeOfDay == .night ? 0.85 : 0.3
                    shape.addChild( window )
                }
            }

            far.addChild( shape )
            x += width * CGFloat( generator.range( 0.7, 1.2 ) )
        }

        x = -1_200

        while x < length * 0.6 + 2_000 {
            let isTree = !isCity && generator.unit() < 0.7
            let node : SKSpriteNode

            if isTree {
                node = SKSpriteNode( texture : SceneryArtist.texture( for : environment == .redMesa ? .cactus : .tree, variant : Int( generator.next() % 4 ), night : false ) )
                node.size = CGSize( width : 90, height : 110 )
            } else {
                node = SKSpriteNode( texture : SceneryArtist.texture( for : .sign, variant : Int( generator.next() % 6 ), night : false ) )
                node.size = CGSize( width : 160, height : 40 )
            }

            node.anchorPoint = CGPoint( x : 0.5, y : 0 )
            node.position = CGPoint( x : x, y : 135 )
            node.zPosition = -30
            node.color = timeOfDay == .night ? .black : .white
            node.colorBlendFactor = timeOfDay == .night ? 0.6 : 0
            mid.addChild( node )
            x += CGFloat( generator.range( 90, 240 ) )
        }
    }

    private func buildTrack() {
        let metres = DragScene.pixelsPerMetre
        let length = CGFloat( race.length + 420 ) * metres
        let asphalt = SKSpriteNode( color : UIColor( hex : environment == .redMesa ? 0x8C7A66 : 0x3A3B3F ), size : CGSize( width : length + 2_000, height : 130 ) )
        asphalt.anchorPoint = CGPoint( x : 0, y : 0 )
        asphalt.position = CGPoint( x : -1_000, y : 0 )
        asphalt.zPosition = -10
        world.addChild( asphalt )

        let verge = SKSpriteNode( color : UIColor( hex : environment.groundHex ), size : CGSize( width : length + 2_000, height : 600 ) )
        verge.anchorPoint = CGPoint( x : 0, y : 1 )
        verge.position = CGPoint( x : -1_000, y : 0 )
        verge.zPosition = -10
        world.addChild( verge )

        let wall = SKSpriteNode( color : UIColor( hex : 0xBFC5CC ), size : CGSize( width : length + 2_000, height : 26 ) )
        wall.anchorPoint = CGPoint( x : 0, y : 0 )
        wall.position = CGPoint( x : -1_000, y : 128 )
        wall.zPosition = -9
        world.addChild( wall )

        for lane in [ CGFloat( 63 ) ] {
            let divider = SKSpriteNode( color : UIColor( white : 0.95, alpha : 0.8 ), size : CGSize( width : length, height : 3 ) )
            divider.anchorPoint = .zero
            divider.position = CGPoint( x : 0, y : lane )
            divider.zPosition = -8
            world.addChild( divider )
        }

        // Distance boards and the finish.
        let marks : [( String, Double )] = [ ( "60 FT", Units.sixtyFeet ), ( "330", 100.584 ), ( "1/8", Units.eighthMile ), ( "1000", 304.8 ), ( "1/4", Units.quarterMile ), ( "1/2", Units.halfMile ), ( "1 KM", Units.kilometre ) ]
            .filter { $0.1 < race.length - 1 }

        for ( label, distance ) in marks {
            addBoard( label, at : CGFloat( distance ) * metres, colour : UIColor( hex : 0x1B2631 ) )
        }

        addBoard( "FINISH", at : CGFloat( race.length ) * metres, colour : UIColor( hex : 0xED2E47 ) )
        let finish = SKSpriteNode( texture : SceneryArtist.checker )
        finish.size = CGSize( width : 14, height : 128 )
        finish.anchorPoint = CGPoint( x : 0.5, y : 0 )
        finish.position = CGPoint( x : CGFloat( race.length ) * metres, y : 0 )
        finish.zPosition = -7
        world.addChild( finish )

        let startLine = SKSpriteNode( color : .white, size : CGSize( width : 6, height : 128 ) )
        startLine.anchorPoint = CGPoint( x : 0.5, y : 0 )
        startLine.position = CGPoint( x : 0, y : 0 )
        startLine.zPosition = -7
        world.addChild( startLine )

        // Advertising boards along the wall.
        var generator = SeededGenerator( text : "drag-signs" )
        var x : CGFloat = 200

        while x < length {
            let sign = SKSpriteNode( texture : SceneryArtist.texture( for : .sign, variant : Int( generator.next() % 6 ), night : false ) )
            sign.size = CGSize( width : 110, height : 22 )
            sign.anchorPoint = CGPoint( x : 0, y : 0 )
            sign.position = CGPoint( x : x, y : 130 )
            sign.zPosition = -8.5
            world.addChild( sign )
            x += CGFloat( generator.range( 300, 600 ) )
        }

        if timeOfDay == .night {
            var lamp : CGFloat = 0

            while lamp < length {
                let glow = SKSpriteNode( texture : SceneryArtist.softDot )
                glow.size = CGSize( width : 220, height : 160 )
                glow.color = UIColor( hex : 0xFFE6A8 )
                glow.colorBlendFactor = 1
                glow.alpha = 0.35
                glow.blendMode = .add
                glow.position = CGPoint( x : lamp, y : 90 )
                glow.zPosition = 95
                world.addChild( glow )
                lamp += 420
            }
        }
    }

    private func addBoard( _ text : String, at x : CGFloat, colour : UIColor ) {
        let board = SKSpriteNode( color : colour, size : CGSize( width : 70, height : 30 ) )
        board.anchorPoint = CGPoint( x : 0.5, y : 0 )
        board.position = CGPoint( x : x, y : 160 )
        board.zPosition = -8
        let label = SKLabelNode( text : text )
        label.fontName = "AvenirNext-HeavyItalic"
        label.fontSize = 16
        label.fontColor = .white
        label.position = CGPoint( x : 0, y : 8 )
        board.addChild( label )
        let pole = SKSpriteNode( color : .darkGray, size : CGSize( width : 4, height : 28 ) )
        pole.anchorPoint = CGPoint( x : 0.5, y : 1 )
        pole.position = CGPoint( x : 0, y : 0 )
        board.addChild( pole )
        world.addChild( board )
    }

    private func buildCars() {
        let lanes : [( DragRacer, CGFloat, CGFloat, CGFloat )] = [ ( race.opponent, 72, 0.86, 1 ), ( race.player, 12, 1, 2 ) ]

        for ( racer, baseline, scale, z ) in lanes {
            let definition = Cars.named( racer.entrant.carID ) ?? Cars.all[ 0 ]
            let image = CarArtist.side( definition, appearance : racer.entrant.appearance )
            let body = SKSpriteNode( texture : SKTexture( image : image ) )
            let metres = DragScene.pixelsPerMetre
            body.size = CGSize( width : CGFloat( definition.length ) * metres * scale, height : CarArtist.sideHeight( for : definition.category ) * metres * scale )
            body.anchorPoint = CGPoint( x : 0.5, y : 0 )
            body.zPosition = z * 2

            let wheelDiameter = body.size.height * 0.48
            let wheelTexture = SKTexture( image : CarArtist.wheel( style : racer.entrant.appearance.wheelStyle, hex : racer.entrant.appearance.wheelHex, diameter : 64 ) )
            let wheels = CarArtist.wheelPositions( for : definition.category ).map { fraction -> SKSpriteNode in
                let wheel = SKSpriteNode( texture : wheelTexture )
                wheel.size = CGSize( width : wheelDiameter, height : wheelDiameter )
                wheel.position = CGPoint( x : ( fraction - 0.5 ) * body.size.width, y : wheelDiameter / 2 )
                wheel.zPosition = 1
                body.addChild( wheel )
                return wheel
            }

            let smoke = SKEmitterNode()
            smoke.particleTexture = SceneryArtist.softDot
            smoke.particleBirthRate = 0
            smoke.particleLifetime = 1.6
            smoke.particleSize = CGSize( width : 40, height : 40 )
            smoke.particleScaleSpeed = 1.5
            smoke.particleAlpha = 0.5
            smoke.particleAlphaSpeed = -0.3
            smoke.particleColor = UIColor( white : 0.9, alpha : 1 )
            smoke.particleColorBlendFactor = 1
            smoke.particleSpeed = 60
            smoke.emissionAngle = .pi
            smoke.emissionAngleRange = 0.8
            smoke.position = CGPoint( x : ( CarArtist.wheelPositions( for : definition.category )[ 0 ] - 0.5 ) * body.size.width, y : 8 )
            smoke.zPosition = 3
            smoke.targetNode = world
            body.addChild( smoke )

            let flame = SKSpriteNode( texture : SceneryArtist.softDot )
            flame.color = UIColor( red : 0.4, green : 0.6, blue : 1, alpha : 1 )
            flame.colorBlendFactor = 1
            flame.size = CGSize( width : 50, height : 16 )
            flame.position = CGPoint( x : -body.size.width / 2 - 18, y : body.size.height * 0.22 )
            flame.blendMode = .add
            flame.alpha = 0
            flame.zPosition = 95
            body.addChild( flame )

            if timeOfDay == .night {
                let beam = SKSpriteNode( texture : SceneryArtist.headlightCone )
                beam.anchorPoint = CGPoint( x : 0, y : 0.5 )
                beam.size = CGSize( width : 420, height : 90 )
                beam.position = CGPoint( x : body.size.width / 2, y : body.size.height * 0.4 )
                beam.blendMode = .add
                beam.alpha = 0.5
                beam.zPosition = 94
                body.addChild( beam )
            }

            world.addChild( body )
            cars.append( ( body, wheels, smoke, flame, racer, baseline, scale ) )
        }
    }

    // MARK: - Frame

    override func update( _ currentTime : TimeInterval ) {
        let delta = lastUpdate.map { min( currentTime - $0, 0.1 ) } ?? 1.0 / 60
        lastUpdate = currentTime
        onFrame?( delta )

        let metres = DragScene.pixelsPerMetre
        let alpha = race.renderAlpha

        for car in cars {
            let state = car.racer.state
            let distance = lerp( car.racer.previousState.position.x, state.position.x, alpha )
            car.body.position = CGPoint( x : CGFloat( distance ) * metres, y : car.baseline )

            // Squat under acceleration, nose-dip on shifts.
            let pitch = clamp( state.longitudinalAcceleration / 160, -0.05, 0.08 )
            car.body.zRotation = CGFloat( pitch )

            let wheelRadius = Double( car.wheels.first?.size.height ?? 30 ) / 2 / Double( metres )
            let spin = state.speed / max( wheelRadius, 0.1 ) * ( 1 + state.wheelspin * 2 ) * delta

            for wheel in car.wheels {
                wheel.zRotation -= CGFloat( spin )
            }

            car.smoke.particleBirthRate = CGFloat( max( state.wheelspin - 0.1, 0 ) * 160 )
            car.flame.alpha = state.isNitrousActive ? CGFloat.random( in : 0.6 ... 1 ) : 0
        }

        let player = race.player.state
        let targetX = CGFloat( player.position.x ) * metres + size.width * 0.18 + CGFloat( player.speed * 2.4 )
        let zoom = 1 + CGFloat( min( player.speed / 120, 0.35 ) )
        var shakeOffset = CGPoint.zero

        if shake > 0.01 {
            shakeOffset = CGPoint( x : CGFloat.random( in : -1 ... 1 ) * CGFloat( shake ) * 8, y : CGFloat.random( in : -1 ... 1 ) * CGFloat( shake ) * 6 )
            shake *= exp( -delta * 7 )
        }

        cameraNode.position = CGPoint( x : targetX + shakeOffset.x, y : 95 + shakeOffset.y )
        cameraNode.setScale( zoom * 440 / max( size.height, 1 ) )
        far.position = CGPoint( x : cameraNode.position.x * 0.92, y : 0 )
        mid.position = CGPoint( x : cameraNode.position.x * 0.55, y : 0 )
    }

    func kick( _ amount : Double ) {
        if cameraShakeEnabled {
            shake = max( shake, amount )
        }
    }
}
