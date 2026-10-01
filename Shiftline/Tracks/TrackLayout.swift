import Foundation

typealias TrackID = String

nonisolated enum RoadPiece {
    case straight( Double )
    case left( radius : Double, degrees : Double )
    case right( radius : Double, degrees : Double )
}

nonisolated enum TrackShape {
    /// Closed circuit through waypoints (centripetal Catmull-Rom).
    case loop( [Vec2] )
    /// Open point-to-point road built from straights and arcs.
    case road( [RoadPiece] )
    /// Straight drag strip of the given racing length.
    case dragStrip( Double )
}

nonisolated enum RoadSurface : String, Codable {
    case asphalt
    case concrete
    case dusty
    case cobbles

    var title : String {
        rawValue.capitalized
    }

    var grip : Double {
        switch self {
        case .asphalt:
            return 1.0
        case .concrete:
            return 0.96
        case .dusty:
            return 0.84
        case .cobbles:
            return 0.9
        }
    }
}

nonisolated enum RunoffKind : String, Codable {
    case grass
    case gravel
    case paved
    case sand
    case pavement

    var grip : Double {
        switch self {
        case .grass:
            return 0.55
        case .gravel:
            return 0.5
        case .paved:
            return 0.95
        case .sand:
            return 0.45
        case .pavement:
            return 0.9
        }
    }

    var rollingDrag : Double {
        switch self {
        case .grass:
            return 4
        case .gravel:
            return 9
        case .paved:
            return 1
        case .sand:
            return 10
        case .pavement:
            return 1.3
        }
    }
}

nonisolated enum BarrierKind : String, Codable {
    case concrete
    case tyres
    case guardrail
    case rock
    case fence
}

nonisolated struct TrackLayout : Identifiable {
    let id : TrackID
    let name : String
    let variant : String
    let environment : TrackEnvironment
    let shape : TrackShape
    var width : Double = 13
    var runoffWidth : Double = 8
    var runoff : RunoffKind = .grass
    var barrier : BarrierKind = .tyres
    var surface : RoadSurface = .asphalt
    /// Average gradient along the direction of travel (positive = uphill).
    var grade : Double = 0
    var isReversed = false
    /// Fractions of the lap/route where drift points are scored in section events.
    var driftZones : [ClosedRange<Double>] = []
    /// Fractions of the route where speed traps sit.
    var speedTraps : [Double] = []
    var summary : String = ""

    var isClosed : Bool {
        if case .loop = shape {
            return true
        }

        return false
    }

    var isDragStrip : Bool {
        if case .dragStrip = shape {
            return true
        }

        return false
    }

    var fullName : String {
        "\( name ) — \( variant )"
    }

    /// Same road driven the other way, with zones and traps mirrored.
    func reversed( id newID : TrackID, variant newVariant : String, summary newSummary : String ) -> TrackLayout {
        TrackLayout(
            id : newID,
            name : name,
            variant : newVariant,
            environment : environment,
            shape : shape,
            width : width,
            runoffWidth : runoffWidth,
            runoff : runoff,
            barrier : barrier,
            surface : surface,
            grade : -grade,
            isReversed : !isReversed,
            driftZones : driftZones.map { ( 1 - $0.upperBound ) ... ( 1 - $0.lowerBound ) },
            speedTraps : speedTraps.map { 1 - $0 }.sorted(),
            summary : newSummary
        )
    }
}
