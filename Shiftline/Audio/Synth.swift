import AVFoundation
import Foundation

/// Parameters written by the game on the main thread and read by audio render blocks.
/// Plain doubles: a torn read only affects one sample, so no locking is needed.
nonisolated final class EngineVoiceParameters : @unchecked Sendable {
    var rpm = 900.0
    var load = 0.0
    var volume = 0.0
    var cylinders = 4.0
    var boost = 0.0
    var isLimiting = false
    var exhaust = 0.0
    var pan = 0.0
}

nonisolated final class TyreVoiceParameters : @unchecked Sendable {
    var squeal = 0.0
    var skid = 0.0
    var rumble = 0.0
    var wind = 0.0
    var surfaceNoise = 0.0
}

/// Procedural engine: harmonics of the firing frequency, crank-rate burble, combustion noise and turbo whistle.
nonisolated final class EngineVoice : @unchecked Sendable {
    let parameters = EngineVoiceParameters()
    private var phase = 0.0
    private var whistlePhase = 0.0
    private var smoothedRPM = 900.0
    private var smoothedVolume = 0.0
    private var smoothedLoad = 0.0
    private var filter = 0.0
    private var limiterPhase = 0.0
    private var noiseState : UInt32 = 22_222

    func makeNode( sampleRate : Double ) -> AVAudioSourceNode {
        let format = AVAudioFormat( standardFormatWithSampleRate : sampleRate, channels : 1 )!

        return AVAudioSourceNode( format : format ) { [unowned self] _, _, frameCount, bufferList in
            let buffers = UnsafeMutableAudioBufferListPointer( bufferList )
            let parameters = self.parameters
            let targetRPM = parameters.rpm
            let targetVolume = parameters.volume
            let targetLoad = parameters.load
            let cylinders = parameters.cylinders
            let boost = parameters.boost
            let exhaust = parameters.exhaust
            let isLimiting = parameters.isLimiting

            for frame in 0 ..< Int( frameCount ) {
                self.smoothedRPM += ( targetRPM - self.smoothedRPM ) * 0.0025
                self.smoothedVolume += ( targetVolume - self.smoothedVolume ) * 0.002
                self.smoothedLoad += ( targetLoad - self.smoothedLoad ) * 0.001

                let firing = self.smoothedRPM / 60 * cylinders / 2
                self.phase += firing / sampleRate

                if self.phase > 1 {
                    self.phase -= 1
                }

                let angle = self.phase * 2 * .pi
                let load = self.smoothedLoad
                let brightness = 0.35 + 0.65 * load + 0.2 * exhaust
                var sample = sin( angle )
                sample += 0.55 * sin( 2 * angle + 0.6 )
                sample += 0.35 * brightness * sin( 3 * angle + 1.1 )
                sample += 0.22 * brightness * sin( 4 * angle + 0.3 )
                sample += 0.3 * sin( angle / 2 ) * ( 1 - load * 0.5 )

                self.noiseState = self.noiseState &* 1_664_525 &+ 1_013_904_223
                let noise = Double( self.noiseState >> 9 ) / Double( 1 << 23 ) - 1
                let pulse = max( sin( angle ), 0 )
                sample += noise * pulse * ( 0.25 + 0.35 * load + 0.3 * exhaust )
                sample = tanh( sample * ( 1.2 + 1.4 * load + exhaust ) )

                let cutoff = 0.08 + 0.35 * brightness * min( self.smoothedRPM / 7_000, 1.3 )
                self.filter += ( sample - self.filter ) * min( cutoff, 0.95 )
                var output = self.filter

                if boost > 0.05 {
                    self.whistlePhase += ( 2_600 + boost * 4_200 ) / sampleRate
                    output += sin( self.whistlePhase * 2 * .pi ) * boost * 0.05
                }

                if isLimiting {
                    self.limiterPhase += 28 / sampleRate
                    output *= self.limiterPhase.truncatingRemainder( dividingBy : 1 ) < 0.5 ? 1 : 0.35
                }

                let value = Float( output * self.smoothedVolume * ( 0.45 + 0.55 * load ) )

                for buffer in buffers {
                    buffer.mData?.assumingMemoryBound( to : Float.self )[ frame ] = value
                }
            }

            return noErr
        }
    }
}

/// Tyre squeal, lock-up skid, kerb rumble and wind rush.
nonisolated final class TyreVoice : @unchecked Sendable {
    let parameters = TyreVoiceParameters()
    private var squealPhase = 0.0
    private var wobble = 0.0
    private var rumblePhase = 0.0
    private var noiseState : UInt32 = 987_654
    private var windFilter = 0.0
    private var skidFilter = 0.0
    private var smoothed = ( squeal : 0.0, skid : 0.0, rumble : 0.0, wind : 0.0 )

    func makeNode( sampleRate : Double ) -> AVAudioSourceNode {
        let format = AVAudioFormat( standardFormatWithSampleRate : sampleRate, channels : 1 )!

        return AVAudioSourceNode( format : format ) { [unowned self] _, _, frameCount, bufferList in
            let buffers = UnsafeMutableAudioBufferListPointer( bufferList )
            let parameters = self.parameters

            for frame in 0 ..< Int( frameCount ) {
                self.smoothed.squeal += ( parameters.squeal - self.smoothed.squeal ) * 0.002
                self.smoothed.skid += ( parameters.skid - self.smoothed.skid ) * 0.002
                self.smoothed.rumble += ( parameters.rumble - self.smoothed.rumble ) * 0.004
                self.smoothed.wind += ( parameters.wind - self.smoothed.wind ) * 0.001

                self.noiseState = self.noiseState &* 1_103_515_245 &+ 12_345
                let noise = Double( self.noiseState >> 9 ) / Double( 1 << 22 ) - 1

                self.wobble += 3.1 / sampleRate
                let squealFrequency = 820 + 110 * sin( self.wobble * 2 * .pi ) + noise * 30
                self.squealPhase += squealFrequency / sampleRate
                let squeal = ( sin( self.squealPhase * 2 * .pi ) * 0.7 + noise * 0.2 ) * self.smoothed.squeal

                self.skidFilter += ( noise - self.skidFilter ) * 0.12
                let skid = self.skidFilter * self.smoothed.skid * 1.4

                self.rumblePhase += 38 / sampleRate
                let rumble = ( self.rumblePhase.truncatingRemainder( dividingBy : 1 ) < 0.5 ? 1.0 : -1.0 ) * 0.25 * self.smoothed.rumble

                self.windFilter += ( noise - self.windFilter ) * 0.03
                let wind = self.windFilter * self.smoothed.wind * 1.6

                let value = Float( ( squeal + skid + rumble + wind ) * 0.5 )

                for buffer in buffers {
                    buffer.mData?.assumingMemoryBound( to : Float.self )[ frame ] = value
                }
            }

            return noErr
        }
    }
}

nonisolated enum MusicStyle : String, CaseIterable {
    case menu
    case race
    case championship
    case rival
    case silent

    var tempo : Double {
        switch self {
        case .menu:
            return 96
        case .race:
            return 128
        case .championship:
            return 118
        case .rival:
            return 140
        case .silent:
            return 100
        }
    }

    /// Chord roots in semitones above A1, one per bar.
    var progression : [Int] {
        switch self {
        case .menu:
            return [ 0, 8, 3, 10 ]
        case .race:
            return [ 0, 0, 5, 7 ]
        case .championship:
            return [ 3, 10, 0, 8 ]
        case .rival:
            return [ 0, 1, 0, 6 ]
        case .silent:
            return [ 0 ]
        }
    }
}

/// A small step sequencer: kick, snare, hats, a filtered saw bass and a soft pad.
nonisolated final class MusicSequencer : @unchecked Sendable {
    var style = MusicStyle.menu
    var volume = 0.5
    private var sampleClock = 0.0
    private var bassPhase = 0.0
    private var padPhases = [ 0.0, 0.0, 0.0 ]
    private var kickPhase = 0.0
    private var bassFilter = 0.0
    private var noiseState : UInt32 = 13_579
    private var smoothedVolume = 0.0

    func makeNode( sampleRate : Double ) -> AVAudioSourceNode {
        let format = AVAudioFormat( standardFormatWithSampleRate : sampleRate, channels : 1 )!

        return AVAudioSourceNode( format : format ) { [unowned self] _, _, frameCount, bufferList in
            let buffers = UnsafeMutableAudioBufferListPointer( bufferList )
            let style = self.style
            let stepLength = sampleRate * 60 / style.tempo / 4
            let targetVolume = style == .silent ? 0 : self.volume

            for frame in 0 ..< Int( frameCount ) {
                self.smoothedVolume += ( targetVolume - self.smoothedVolume ) * 0.0005
                self.sampleClock += 1
                let stepPosition = self.sampleClock / stepLength
                let step = Int( stepPosition ) % 16
                let bar = Int( stepPosition / 16 ) % style.progression.count
                let stepTime = ( stepPosition - Double( Int( stepPosition ) ) ) * stepLength / sampleRate
                let root = 55 * pow( 2, Double( style.progression[ bar ] ) / 12 )

                self.noiseState = self.noiseState &* 1_664_525 &+ 1_013_904_223
                let noise = Double( self.noiseState >> 9 ) / Double( 1 << 22 ) - 1
                var sample = 0.0

                // Kick on the beat (half-time on the menu).
                let kickStep = style == .menu ? step % 8 == 0 : step % 4 == 0

                if kickStep {
                    let frequency = 45 + 90 * exp( -stepTime * 30 )
                    self.kickPhase += frequency / sampleRate
                    sample += sin( self.kickPhase * 2 * .pi ) * exp( -stepTime * 9 ) * 0.9
                }

                if step % 8 == 4 && style != .menu {
                    sample += noise * exp( -stepTime * 22 ) * 0.35
                }

                if step % 2 == 1 || style == .rival {
                    sample += noise * exp( -stepTime * 90 ) * 0.12
                }

                // Bass: eighth notes following the chord root.
                let bassNote = step % 4 == 3 ? root * 2 : root
                self.bassPhase += bassNote / sampleRate
                let saw = 2 * ( self.bassPhase - Double( Int( self.bassPhase ) ) ) - 1
                let bassEnvelope = exp( -stepTime * ( style == .menu ? 3 : 7 ) )
                self.bassFilter += ( saw - self.bassFilter ) * ( 0.03 + 0.1 * bassEnvelope )
                sample += self.bassFilter * 0.45 * bassEnvelope

                // Pad: minor triad, slow and soft.
                let intervals = [ 0.0, 3, 7 ]

                for index in 0 ..< 3 {
                    let frequency = root * 4 * pow( 2, intervals[ index ] / 12 ) * ( 1 + 0.002 * Double( index ) )
                    self.padPhases[ index ] += frequency / sampleRate
                    sample += sin( self.padPhases[ index ] * 2 * .pi ) * 0.06
                }

                let value = Float( tanh( sample ) * self.smoothedVolume * 0.5 )

                for buffer in buffers {
                    buffer.mData?.assumingMemoryBound( to : Float.self )[ frame ] = value
                }
            }

            return noErr
        }
    }
}
