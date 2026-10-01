import Foundation

/// Career branches. Each has its own events, rivals and preferred car setups.
nonisolated enum Discipline : String, Codable, CaseIterable, Identifiable {
    case circuit
    case sprint
    case drag
    case drift
    case mountain
    case street

    var id : String {
        rawValue
    }

    var title : String {
        rawValue.capitalized
    }

    var symbol : String {
        switch self {
        case .circuit:
            return "flag.checkered"
        case .sprint:
            return "arrow.right.to.line"
        case .drag:
            return "gauge.with.dots.needle.100percent"
        case .drift:
            return "tornado"
        case .mountain:
            return "mountain.2.fill"
        case .street:
            return "building.2.fill"
        }
    }
}
