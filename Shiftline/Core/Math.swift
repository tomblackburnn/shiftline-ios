import CoreGraphics
import Foundation

typealias Vec2 = SIMD2<Double>

nonisolated extension SIMD2 where Scalar == Double {
    init( angle : Double ) {
        self.init( cos( angle ), sin( angle ) )
    }

    var length : Double {
        ( x * x + y * y ).squareRoot()
    }

    var lengthSquared : Double {
        x * x + y * y
    }

    var normalized : Vec2 {
        let currentLength = length
        return currentLength > 1e-9 ? self / currentLength : .zero
    }

    /// Left-hand perpendicular (rotated +90°).
    var perpendicular : Vec2 {
        Vec2( -y, x )
    }

    var angle : Double {
        atan2( y, x )
    }

    var cgPoint : CGPoint {
        CGPoint( x : x, y : y )
    }

    func dot( _ other : Vec2 ) -> Double {
        x * other.x + y * other.y
    }

    func cross( _ other : Vec2 ) -> Double {
        x * other.y - y * other.x
    }

    func rotated( by radians : Double ) -> Vec2 {
        let cosine = cos( radians )
        let sine = sin( radians )
        return Vec2( x * cosine - y * sine, x * sine + y * cosine )
    }
}

nonisolated func clamp<Value : Comparable>(
    _ value : Value,
    _ lower : Value,
    _ upper : Value
) -> Value {
    min( max( value, lower ), upper )
}

nonisolated func lerp( _ from : Double, _ to : Double, _ amount : Double ) -> Double {
    from + ( to - from ) * amount
}

nonisolated func lerp( _ from : Vec2, _ to : Vec2, _ amount : Double ) -> Vec2 {
    from + ( to - from ) * amount
}

/// Moves `current` towards `target` by at most `maximumStep`.
nonisolated func approach(
    _ current : Double,
    _ target : Double,
    _ maximumStep : Double
) -> Double {
    current < target
        ? min( current + maximumStep, target )
        : max( current - maximumStep, target )
}

/// Wraps an angle into -π...π.
nonisolated func wrapAngle( _ radians : Double ) -> Double {
    var wrapped = radians.truncatingRemainder( dividingBy : 2 * .pi )

    if wrapped > .pi {
        wrapped -= 2 * .pi
    } else if wrapped < -.pi {
        wrapped += 2 * .pi
    }

    return wrapped
}

nonisolated func smoothstep( _ edge0 : Double, _ edge1 : Double, _ value : Double ) -> Double {
    let amount = clamp( ( value - edge0 ) / ( edge1 - edge0 ), 0, 1 )
    return amount * amount * ( 3 - 2 * amount )
}

/// Deterministic SplitMix64 generator so seeded content (scenery, AI noise, daily challenges) is repeatable.
nonisolated struct SeededGenerator : RandomNumberGenerator {
    private var state : UInt64

    init( seed : UInt64 ) {
        state = seed
    }

    init( text : String ) {
        var hash : UInt64 = 1_469_598_103_934_665_603

        for byte in text.utf8 {
            hash = ( hash ^ UInt64( byte ) ) &* 1_099_511_628_211
        }

        state = hash
    }

    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var mixed = state
        mixed = ( mixed ^ ( mixed >> 30 ) ) &* 0xBF58_476D_1CE4_E5B9
        mixed = ( mixed ^ ( mixed >> 27 ) ) &* 0x94D0_49BB_1331_11EB
        return mixed ^ ( mixed >> 31 )
    }

    mutating func unit() -> Double {
        Double.random( in : 0 ..< 1, using : &self )
    }

    mutating func range( _ lower : Double, _ upper : Double ) -> Double {
        lower + unit() * ( upper - lower )
    }
}

nonisolated enum Units {
    static let gravity = 9.81
    static let metresPerSecondToKPH = 3.6
    static let metresPerSecondToMPH = 2.236_936
    static let kilowattsToHorsepower = 1.341_02
    static let quarterMile = 402.336
    static let eighthMile = 201.168
    static let halfMile = 804.672
    static let kilometre = 1_000.0
    static let sixtyFeet = 18.288
}
