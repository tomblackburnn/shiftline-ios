import Foundation

nonisolated struct TrackProjection {
    let index : Int
    /// Distance along the centreline, 0...length.
    let distance : Double
    /// Signed offset from the centreline; positive is left of the direction of travel.
    let lateral : Double
    let tangent : Vec2
}

/// Immutable, uniformly sampled track: centreline, edges, checkpoints and the AI racing line.
nonisolated final class TrackGeometry {
    let layout : TrackLayout
    let spacing = 2.0
    let points : [Vec2]
    let tangents : [Vec2]
    let normals : [Vec2]
    let distances : [Double]
    let curvatures : [Double]
    let racingOffsets : [Double]
    let racingCurvatures : [Double]
    let length : Double
    let checkpoints : [Double]

    /// Where the start/finish line sits. Circuits start at 0; routes start a little in.
    let startDistance : Double
    let finishDistance : Double

    var isClosed : Bool {
        layout.isClosed
    }

    var halfWidth : Double {
        layout.width / 2
    }

    var barrierOffset : Double {
        halfWidth + layout.runoffWidth
    }

    var sampleCount : Int {
        points.count
    }

    /// Racing distance from start to finish (one lap for circuits).
    var raceLength : Double {
        isClosed ? length : finishDistance - startDistance
    }

    init( layout : TrackLayout ) {
        self.layout = layout

        var raw = TrackGeometry.rawPath( for : layout.shape )

        if layout.isReversed {
            raw.reverse()
        }

        let resampled = TrackGeometry.resample( raw, spacing : 2, closed : layout.isClosed )
        points = resampled
        let count = resampled.count

        var tangents = [Vec2]( repeating : Vec2( 1, 0 ), count : count )

        for index in 0 ..< count {
            let previous = layout.isClosed ? resampled[ ( index - 1 + count ) % count ] : resampled[ max( index - 1, 0 ) ]
            let next = layout.isClosed ? resampled[ ( index + 1 ) % count ] : resampled[ min( index + 1, count - 1 ) ]
            tangents[ index ] = ( next - previous ).normalized
        }

        self.tangents = tangents
        normals = tangents.map { $0.perpendicular }
        distances = ( 0 ..< count ).map { Double( $0 ) * 2 }
        length = layout.isClosed ? Double( count ) * 2 : Double( count - 1 ) * 2
        curvatures = TrackGeometry.curvature( of : resampled, closed : layout.isClosed, window : 3 )

        let offsets = TrackGeometry.racingLine(
            points : resampled,
            normals : tangents.map { $0.perpendicular },
            closed : layout.isClosed,
            limit : max( layout.width / 2 - 1.9, 0 )
        )
        racingOffsets = offsets

        let racingPoints = ( 0 ..< count ).map { resampled[ $0 ] + tangents[ $0 ].perpendicular * offsets[ $0 ] }
        racingCurvatures = TrackGeometry.curvature( of : racingPoints, closed : layout.isClosed, window : 4 )

        if layout.isClosed {
            startDistance = 0
            finishDistance = length
        } else {
            startDistance = 60
            finishDistance = layout.isDragStrip ? TrackGeometry.dragLength( layout.shape ) + startDistance : length - 40
        }

        checkpoints = TrackGeometry.makeCheckpoints(
            start : startDistance,
            finish : finishDistance,
            closed : layout.isClosed,
            length : length
        )
    }

    // MARK: - Queries

    func wrapped( _ distance : Double ) -> Double {
        guard isClosed else {
            return clamp( distance, 0, length )
        }

        let remainder = distance.truncatingRemainder( dividingBy : length )
        return remainder < 0 ? remainder + length : remainder
    }

    func index( forDistance distance : Double ) -> Int {
        let position = Int( ( wrapped( distance ) / spacing ).rounded( .down ) )
        return isClosed ? position % sampleCount : min( position, sampleCount - 1 )
    }

    func point( atDistance distance : Double, lateral : Double = 0 ) -> Vec2 {
        let wrappedDistance = wrapped( distance )
        let lower = index( forDistance : wrappedDistance )
        let upper = isClosed ? ( lower + 1 ) % sampleCount : min( lower + 1, sampleCount - 1 )
        let amount = clamp( ( wrappedDistance - Double( lower ) * spacing ) / spacing, 0, 1 )
        let centre = lerp( points[ lower ], points[ upper ], amount )
        let normal = lerp( normals[ lower ], normals[ upper ], amount ).normalized
        return centre + normal * lateral
    }

    func tangent( atDistance distance : Double ) -> Vec2 {
        tangents[ index( forDistance : distance ) ]
    }

    func racingOffset( atDistance distance : Double ) -> Double {
        racingOffsets[ index( forDistance : distance ) ]
    }

    func curvature( atDistance distance : Double ) -> Double {
        curvatures[ index( forDistance : distance ) ]
    }

    /// Nearest point on the centreline. Searches around `hint` first so hairpins never snap to the wrong side.
    func project( _ position : Vec2, near hint : Int? = nil ) -> TrackProjection {
        if let hint {
            let local = nearestSegment( to : position, from : hint - 40, to : hint + 40 )
            let localProjection = projection( of : position, onSegment : local )

            if abs( localProjection.lateral ) < barrierOffset + 25 {
                return localProjection
            }
        }

        let global = nearestSegment( to : position, from : 0, to : isClosed ? sampleCount - 1 : sampleCount - 2 )
        return projection( of : position, onSegment : global )
    }

    private func sampleIndex( _ index : Int ) -> Int {
        isClosed
            ? ( index % sampleCount + sampleCount ) % sampleCount
            : clamp( index, 0, sampleCount - 2 )
    }

    private func nearestSegment( to position : Vec2, from lower : Int, to upper : Int ) -> Int {
        var bestIndex = sampleIndex( lower )
        var bestDistance = Double.infinity

        for rawIndex in lower ... upper {
            let index = sampleIndex( rawIndex )
            let start = points[ index ]
            let end = points[ isClosed ? ( index + 1 ) % sampleCount : index + 1 ]
            let segment = end - start
            let amount = clamp( ( position - start ).dot( segment ) / max( segment.lengthSquared, 1e-9 ), 0, 1 )
            let distance = ( position - ( start + segment * amount ) ).lengthSquared

            if distance < bestDistance {
                bestDistance = distance
                bestIndex = index
            }
        }

        return bestIndex
    }

    private func projection( of position : Vec2, onSegment index : Int ) -> TrackProjection {
        let nextIndex = isClosed ? ( index + 1 ) % sampleCount : min( index + 1, sampleCount - 1 )
        let start = points[ index ]
        let segment = points[ nextIndex ] - start
        let amount = clamp( ( position - start ).dot( segment ) / max( segment.lengthSquared, 1e-9 ), 0, 1 )
        let tangent = lerp( tangents[ index ], tangents[ nextIndex ], amount ).normalized
        let lateral = ( position - ( start + segment * amount ) ).dot( tangent.perpendicular )
        let distance = wrapped( distances[ index ] + amount * spacing )
        return TrackProjection( index : index, distance : distance, lateral : lateral, tangent : tangent )
    }

    /// Target speeds along the racing line for a car with the given limits, including braking zones.
    func speedProfile(
        grip : Double,
        brakingDeceleration : Double,
        topSpeed : Double,
        mass : Double,
        downforce : Double
    ) -> [Double] {
        let count = sampleCount
        var speeds = racingCurvatures.map { rawCurvature -> Double in
            let curvature = max( abs( rawCurvature ), 1e-4 )
            let denominator = mass * curvature - grip * downforce

            guard denominator > 0 else {
                return topSpeed
            }

            return min( ( grip * mass * Units.gravity / denominator ).squareRoot(), topSpeed )
        }

        let passes = isClosed ? 2 : 1

        for _ in 0 ..< passes {
            for step in stride( from : count - 2, through : isClosed ? -count + 1 : 0, by : -1 ) {
                let index = ( step + count ) % count
                let next = ( index + 1 ) % count

                if !isClosed && index == count - 1 {
                    continue
                }

                let allowed = ( speeds[ next ] * speeds[ next ] + 2 * brakingDeceleration * spacing ).squareRoot()
                speeds[ index ] = min( speeds[ index ], allowed )
            }
        }

        return speeds
    }

    /// Grid slots behind the start line, two abreast.
    func gridSlot( _ slot : Int ) -> ( position : Vec2, heading : Double ) {
        let row = Double( slot / 2 )
        let side : Double = slot % 2 == 0 ? 1 : -1
        let distance = startDistance - 8 - row * 9 - ( side < 0 ? 4 : 0 )
        let lateral = side * min( halfWidth * 0.42, 3.2 )
        return ( point( atDistance : distance, lateral : lateral ), tangent( atDistance : distance ).angle )
    }

    // MARK: - Construction

    private static func dragLength( _ shape : TrackShape ) -> Double {
        if case .dragStrip( let length ) = shape {
            return length
        }

        return 0
    }

    private static func rawPath( for shape : TrackShape ) -> [Vec2] {
        switch shape {
        case .loop( let waypoints ):
            return catmullRom( waypoints )
        case .road( let pieces ):
            return turtle( pieces )
        case .dragStrip( let length ):
            return stride( from : 0.0, through : length + 360, by : 5 ).map { Vec2( $0, 0 ) }
        }
    }

    /// Centripetal Catmull-Rom through a closed waypoint list (no cusps or self-loops).
    private static func catmullRom( _ waypoints : [Vec2] ) -> [Vec2] {
        let count = waypoints.count
        var path : [Vec2] = []

        for index in 0 ..< count {
            let p0 = waypoints[ ( index - 1 + count ) % count ]
            let p1 = waypoints[ index ]
            let p2 = waypoints[ ( index + 1 ) % count ]
            let p3 = waypoints[ ( index + 2 ) % count ]

            let t0 = 0.0
            let t1 = t0 + max( ( p1 - p0 ).length.squareRoot(), 1e-3 )
            let t2 = t1 + max( ( p2 - p1 ).length.squareRoot(), 1e-3 )
            let t3 = t2 + max( ( p3 - p2 ).length.squareRoot(), 1e-3 )
            let steps = max( Int( ( p2 - p1 ).length ), 4 )

            for step in 0 ..< steps {
                let t = t1 + ( t2 - t1 ) * Double( step ) / Double( steps )
                let a1 = p0 * ( ( t1 - t ) / ( t1 - t0 ) ) + p1 * ( ( t - t0 ) / ( t1 - t0 ) )
                let a2 = p1 * ( ( t2 - t ) / ( t2 - t1 ) ) + p2 * ( ( t - t1 ) / ( t2 - t1 ) )
                let a3 = p2 * ( ( t3 - t ) / ( t3 - t2 ) ) + p3 * ( ( t - t2 ) / ( t3 - t2 ) )
                let b1 = a1 * ( ( t2 - t ) / ( t2 - t0 ) ) + a2 * ( ( t - t0 ) / ( t2 - t0 ) )
                let b2 = a2 * ( ( t3 - t ) / ( t3 - t1 ) ) + a3 * ( ( t - t1 ) / ( t3 - t1 ) )
                path.append( b1 * ( ( t2 - t ) / ( t2 - t1 ) ) + b2 * ( ( t - t1 ) / ( t2 - t1 ) ) )
            }
        }

        return path
    }

    /// Walks straights and constant-radius arcs, one metre at a time.
    private static func turtle( _ pieces : [RoadPiece] ) -> [Vec2] {
        var position = Vec2.zero
        var heading = 0.0
        var path = [ position ]

        for piece in pieces {
            switch piece {
            case .straight( let length ):
                let steps = max( Int( length ), 1 )

                for _ in 0 ..< steps {
                    position += Vec2( angle : heading ) * ( length / Double( steps ) )
                    path.append( position )
                }
            case .left( let radius, let degrees ), .right( let radius, let degrees ):
                let direction : Double

                if case .left = piece {
                    direction = 1
                } else {
                    direction = -1
                }

                let arc = radius * degrees * .pi / 180
                let steps = max( Int( arc ), 2 )

                for _ in 0 ..< steps {
                    let turn = direction * degrees * .pi / 180 / Double( steps )
                    heading += turn / 2
                    position += Vec2( angle : heading ) * ( arc / Double( steps ) )
                    heading += turn / 2
                    path.append( position )
                }
            }
        }

        return path
    }

    private static func resample( _ raw : [Vec2], spacing : Double, closed : Bool ) -> [Vec2] {
        guard raw.count > 1 else {
            return raw
        }

        var source = raw

        if closed {
            source.append( raw[ 0 ] )
        }

        var cumulative = [ 0.0 ]

        for index in 1 ..< source.count {
            cumulative.append( cumulative[ index - 1 ] + ( source[ index ] - source[ index - 1 ] ).length )
        }

        let total = cumulative.last ?? 0
        let count = closed ? max( Int( ( total / spacing ).rounded() ), 3 ) : Int( total / spacing ) + 1
        let step = closed ? total / Double( count ) : spacing
        var result : [Vec2] = []
        result.reserveCapacity( count )
        var segment = 0

        for sample in 0 ..< count {
            let target = Double( sample ) * step

            while segment < source.count - 2 && cumulative[ segment + 1 ] < target {
                segment += 1
            }

            let segmentLength = max( cumulative[ segment + 1 ] - cumulative[ segment ], 1e-9 )
            let amount = clamp( ( target - cumulative[ segment ] ) / segmentLength, 0, 1 )
            result.append( lerp( source[ segment ], source[ segment + 1 ], amount ) )
        }

        return result
    }

    private static func curvature( of points : [Vec2], closed : Bool, window : Int ) -> [Double] {
        let count = points.count

        return ( 0 ..< count ).map { index in
            let previousIndex = closed ? ( index - window + count ) % count : max( index - window, 0 )
            let nextIndex = closed ? ( index + window ) % count : min( index + window, count - 1 )
            let centre = points[ index ]
            let incoming = centre - points[ previousIndex ]
            let outgoing = points[ nextIndex ] - centre
            let arc = incoming.length + outgoing.length

            guard arc > 1e-6 && incoming.length > 1e-6 && outgoing.length > 1e-6 else {
                return 0
            }

            let turn = wrapAngle( outgoing.angle - incoming.angle )
            return turn / ( arc / 2 )
        }
    }

    /// Minimum-curvature line: iteratively relaxes lateral offsets towards neighbour midpoints on a coarse grid.
    private static func racingLine( points : [Vec2], normals : [Vec2], closed : Bool, limit : Double ) -> [Double] {
        let stride = 5
        let count = points.count
        let coarseCount = max( count / stride, 3 )
        var offsets = [Double]( repeating : 0, count : coarseCount )

        func coarsePoint( _ index : Int ) -> Vec2 {
            let fine = min( index * stride, count - 1 )
            return points[ fine ] + normals[ fine ] * offsets[ index ]
        }

        for _ in 0 ..< 500 {
            for index in 0 ..< coarseCount {
                if !closed && ( index < 2 || index > coarseCount - 3 ) {
                    continue
                }

                let previous = coarsePoint( ( index - 1 + coarseCount ) % coarseCount )
                let next = coarsePoint( ( index + 1 ) % coarseCount )
                let fine = min( index * stride, count - 1 )
                let desired = ( ( previous + next ) / 2 - points[ fine ] ).dot( normals[ fine ] )
                offsets[ index ] = clamp( offsets[ index ] + 0.65 * ( desired - offsets[ index ] ), -limit, limit )
            }
        }

        return ( 0 ..< count ).map { fine in
            let position = Double( fine ) / Double( stride )
            let lower = Int( position ) % coarseCount
            let upper = closed ? ( lower + 1 ) % coarseCount : min( lower + 1, coarseCount - 1 )
            return lerp( offsets[ lower ], offsets[ upper ], position - Double( Int( position ) ) )
        }
    }

    private static func makeCheckpoints( start : Double, finish : Double, closed : Bool, length : Double ) -> [Double] {
        let span = finish - start
        let count = max( 3, Int( span / 320 ) )
        return ( 1 ... count ).map { start + span * Double( $0 ) / Double( count ) }
    }
}
