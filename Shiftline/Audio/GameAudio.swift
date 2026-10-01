import AVFoundation
import Foundation

enum SoundEffect : CaseIterable {
    case shift
    case backfire
    case blowOff
    case crashLight
    case crashHeavy
    case countdown
    case go
    case checkpoint
    case lap
    case reward
    case tap
    case nitrous
    case eliminated
    case brakeLock
    case driftBank
}

/// Owns the audio graph: engine voices, tyres, sound effects and music.
final class GameAudio {
    static let shared = GameAudio()

    let playerEngine = EngineVoice()
    let opponentEngine = EngineVoice()
    let tyres = TyreVoice()
    let music = MusicSequencer()

    private let engine = AVAudioEngine()
    private var effectPlayers : [AVAudioPlayerNode] = []
    private var effectBuffers : [SoundEffect : AVAudioPCMBuffer] = [:]
    private var nextPlayer = 0
    private var filePlayer : AVAudioPlayerNode?
    private var isRunning = false
    private let effectsMixer = AVAudioMixerNode()
    private let sampleRate = 44_100.0

    var effectsVolume = 0.9 {
        didSet {
            effectsMixer.outputVolume = Float( effectsVolume )
        }
    }

    var engineVolume = 0.9

    private init() {}

    func start() {
        guard !isRunning else {
            return
        }

        do {
            try AVAudioSession.sharedInstance().setCategory( .ambient, mode : .default )
            try AVAudioSession.sharedInstance().setActive( true )
        } catch {
            return
        }

        let mainMixer = engine.mainMixerNode
        let monoFormat = AVAudioFormat( standardFormatWithSampleRate : sampleRate, channels : 1 )!

        for node in [ playerEngine.makeNode( sampleRate : sampleRate ), opponentEngine.makeNode( sampleRate : sampleRate ), tyres.makeNode( sampleRate : sampleRate ), music.makeNode( sampleRate : sampleRate ) ] {
            engine.attach( node )
            engine.connect( node, to : mainMixer, format : monoFormat )
        }

        engine.attach( effectsMixer )
        engine.connect( effectsMixer, to : mainMixer, format : monoFormat )

        for _ in 0 ..< 8 {
            let player = AVAudioPlayerNode()
            engine.attach( player )
            engine.connect( player, to : effectsMixer, format : monoFormat )
            effectPlayers.append( player )
        }

        for effect in SoundEffect.allCases {
            effectBuffers[ effect ] = makeBuffer( for : effect, format : monoFormat )
        }

        do {
            try engine.start()
            effectPlayers.forEach { $0.play() }
            isRunning = true
        } catch {
            isRunning = false
        }
    }

    func play( _ effect : SoundEffect, volume : Double = 1 ) {
        guard isRunning, let buffer = effectBuffers[ effect ], !effectPlayers.isEmpty else {
            return
        }

        let player = effectPlayers[ nextPlayer ]
        nextPlayer = ( nextPlayer + 1 ) % effectPlayers.count
        player.volume = Float( clamp( volume, 0, 1 ) )
        player.scheduleBuffer( buffer, at : nil, options : .interrupts )

        if !player.isPlaying {
            player.play()
        }
    }

    /// Music uses a bundled track named "music_<style>" when present, otherwise the built-in sequencer.
    func playMusic( _ style : MusicStyle, volume : Double ) {
        music.volume = volume
        filePlayer?.stop()

        guard isRunning, style != .silent,
              let url = Bundle.main.url( forResource : "music_\( style.rawValue )", withExtension : "m4a" ),
              let file = try? AVAudioFile( forReading : url ),
              let buffer = AVAudioPCMBuffer( pcmFormat : file.processingFormat, frameCapacity : AVAudioFrameCount( file.length ) ) else {
            music.style = style
            return
        }

        do {
            try file.read( into : buffer )
        } catch {
            music.style = style
            return
        }

        music.style = .silent
        let player = filePlayer ?? AVAudioPlayerNode()

        if filePlayer == nil {
            engine.attach( player )
            engine.connect( player, to : engine.mainMixerNode, format : file.processingFormat )
            filePlayer = player
        }

        player.volume = Float( volume )
        player.scheduleBuffer( buffer, at : nil, options : .loops )
        player.play()
    }

    func silenceRaceVoices() {
        playerEngine.parameters.volume = 0
        opponentEngine.parameters.volume = 0
        tyres.parameters.squeal = 0
        tyres.parameters.skid = 0
        tyres.parameters.rumble = 0
        tyres.parameters.wind = 0
    }

    // MARK: - Effect synthesis

    private func makeBuffer( for effect : SoundEffect, format : AVAudioFormat ) -> AVAudioPCMBuffer? {
        let duration : Double

        switch effect {
        case .shift, .tap, .backfire:
            duration = 0.12
        case .countdown, .checkpoint:
            duration = 0.25
        case .go, .lap, .driftBank:
            duration = 0.5
        case .reward:
            duration = 0.9
        case .crashLight:
            duration = 0.3
        case .crashHeavy, .eliminated:
            duration = 0.8
        case .blowOff, .nitrous, .brakeLock:
            duration = 0.6
        }

        let frames = AVAudioFrameCount( duration * sampleRate )

        guard let buffer = AVAudioPCMBuffer( pcmFormat : format, frameCapacity : frames ),
              let samples = buffer.floatChannelData?[ 0 ] else {
            return nil
        }

        buffer.frameLength = frames
        var noise : UInt32 = 4_242
        var filtered = 0.0
        var phase = 0.0

        for index in 0 ..< Int( frames ) {
            let time = Double( index ) / sampleRate
            noise = noise &* 1_664_525 &+ 1_013_904_223
            let white = Double( noise >> 9 ) / Double( 1 << 22 ) - 1
            var value = 0.0

            switch effect {
            case .shift:
                filtered += ( white - filtered ) * 0.2
                value = ( sin( 2 * .pi * 90 * time ) * 0.6 + filtered ) * exp( -time * 45 )
            case .backfire:
                filtered += ( white - filtered ) * 0.35
                value = filtered * 1.6 * exp( -time * 40 )
            case .blowOff:
                filtered += ( white - filtered ) * ( 0.5 - 0.4 * time / duration )
                value = filtered * 0.7 * exp( -time * 6 )
            case .crashLight:
                filtered += ( white - filtered ) * 0.3
                value = ( filtered + sin( 2 * .pi * 70 * time ) * 0.5 ) * exp( -time * 18 )
            case .crashHeavy:
                filtered += ( white - filtered ) * 0.15
                value = ( filtered * 1.4 + sin( 2 * .pi * 48 * time ) * 0.8 ) * exp( -time * 5 )
            case .countdown:
                value = sin( 2 * .pi * 660 * time ) * 0.5 * ( time < 0.18 ? 1 : 0 )
            case .go:
                value = sin( 2 * .pi * 1_320 * time ) * 0.5 * exp( -time * 3 )
            case .checkpoint:
                value = ( sin( 2 * .pi * 880 * time ) + sin( 2 * .pi * 1_320 * time ) ) * 0.25 * exp( -time * 10 )
            case .lap:
                let frequency = time < 0.15 ? 988.0 : 1_318.0
                value = sin( 2 * .pi * frequency * time ) * 0.35 * exp( -time * 4 )
            case .reward:
                let notes = [ 523.25, 659.25, 783.99, 1_046.5 ]
                let note = notes[ min( Int( time / 0.12 ), notes.count - 1 ) ]
                phase += note / sampleRate
                value = sin( 2 * .pi * phase ) * 0.3 * exp( -( time.truncatingRemainder( dividingBy : 0.12 ) ) * 10 )
            case .tap:
                value = sin( 2 * .pi * 1_800 * time ) * 0.25 * exp( -time * 80 )
            case .nitrous:
                filtered += ( white - filtered ) * 0.6
                value = filtered * 0.5 * min( time * 10, 1 ) * exp( -time * 2 )
            case .eliminated:
                value = ( sin( 2 * .pi * 220 * time ) + sin( 2 * .pi * 233 * time ) ) * 0.25 * exp( -time * 2 )
            case .brakeLock:
                filtered += ( white - filtered ) * 0.1
                value = filtered * 0.6 * exp( -time * 5 )
            case .driftBank:
                phase += ( 600 + 900 * time ) / sampleRate
                value = sin( 2 * .pi * phase ) * 0.3 * exp( -time * 5 )
            }

            samples[ index ] = Float( value )
        }

        return buffer
    }
}
