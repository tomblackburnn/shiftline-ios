import CoreHaptics
import Foundation

enum HapticEvent {
    case shift( perfect : Bool )
    case launch
    case collision( Double )
    case kerb
    case wheelspin( Double )
    case driftTransition
    case countdown
    case go
    case finish
    case achievement
    case tap
}

/// Core Haptics transients with intensity and sharpness per event. Silently does nothing on unsupported hardware.
final class Haptics {
    static let shared = Haptics()

    var isEnabled = true
    private var engine : CHHapticEngine?
    private var lastContinuous = Date.distantPast

    private init() {
        guard CHHapticEngine.capabilitiesForHardware().supportsHaptics else {
            return
        }

        engine = try? CHHapticEngine()
        engine?.isAutoShutdownEnabled = true
        engine?.resetHandler = { [weak self] in
            try? self?.engine?.start()
        }
        try? engine?.start()
    }

    func play( _ event : HapticEvent ) {
        guard isEnabled, let engine else {
            return
        }

        let pattern : [( delay : Double, intensity : Double, sharpness : Double )]

        switch event {
        case .shift( let perfect ):
            pattern = perfect ? [ ( 0, 0.9, 0.9 ), ( 0.05, 0.5, 1 ) ] : [ ( 0, 0.6, 0.5 ) ]
        case .launch:
            pattern = [ ( 0, 1, 0.3 ), ( 0.08, 0.7, 0.2 ), ( 0.16, 0.4, 0.2 ) ]
        case .collision( let intensity ):
            let strength = clamp( intensity / 12, 0.3, 1 )
            pattern = [ ( 0, strength, 0.2 ), ( 0.06, strength * 0.5, 0.1 ) ]
        case .kerb, .wheelspin:
            // Continuous textures are rate-limited to a gentle buzz.
            guard Date().timeIntervalSince( lastContinuous ) > 0.09 else {
                return
            }

            lastContinuous = Date()

            if case .wheelspin( let amount ) = event {
                pattern = [ ( 0, clamp( amount, 0.2, 0.7 ), 0.6 ) ]
            } else {
                pattern = [ ( 0, 0.45, 0.8 ) ]
            }
        case .driftTransition:
            pattern = [ ( 0, 0.6, 0.7 ) ]
        case .countdown:
            pattern = [ ( 0, 0.5, 0.5 ) ]
        case .go:
            pattern = [ ( 0, 1, 0.8 ), ( 0.1, 0.6, 0.6 ) ]
        case .finish:
            pattern = [ ( 0, 0.8, 0.5 ), ( 0.12, 0.8, 0.5 ), ( 0.24, 1, 0.7 ) ]
        case .achievement:
            pattern = [ ( 0, 0.6, 1 ), ( 0.1, 0.8, 1 ), ( 0.2, 1, 1 ) ]
        case .tap:
            pattern = [ ( 0, 0.35, 0.9 ) ]
        }

        let events = pattern.map { item in
            CHHapticEvent(
                eventType : .hapticTransient,
                parameters : [
                    CHHapticEventParameter( parameterID : .hapticIntensity, value : Float( item.intensity ) ),
                    CHHapticEventParameter( parameterID : .hapticSharpness, value : Float( item.sharpness ) )
                ],
                relativeTime : item.delay
            )
        }

        do {
            let player = try engine.makePlayer( with : CHHapticPattern( events : events, parameters : [] ) )
            try player.start( atTime : CHHapticTimeImmediate )
        } catch {
            try? engine.start()
        }
    }
}
