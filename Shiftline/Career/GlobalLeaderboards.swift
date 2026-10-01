import Foundation

/// One Game Center leaderboard: the headline measure for a track.
nonisolated struct GlobalLeaderboard : Identifiable, Equatable {
    /// The identifier that must exist in App Store Connect.
    let id : String
    let name : String
    let lowerIsBetter : Bool

    /// Game Center scores are integers: times go in hundredths of a second, drift scores as-is.
    func score( for value : Double ) -> Int {
        Int( ( lowerIsBetter ? value * 100 : value ).rounded() )
    }
}

/// Every track has one global board per headline measure: best lap on circuits, time on point-to-point routes,
/// elapsed time on drag strips, and a 60-second score on the drift venues.
nonisolated enum GlobalLeaderboards {
    static let driftTrackIDs : Set<TrackID> = Set( Events.all.filter { $0.discipline == .drift }.map { $0.trackID } )

    static let all : [GlobalLeaderboard] = Tracks.all.flatMap { layout in
        [ RaceKind.drag, .sprint, .timeAttack, .drift( .scoreAttack, duration : 60 ) ].compactMap { board( for : $0, trackID : layout.id ) }
    }

    /// The board a result counts towards, if any.
    static func board( for kind : RaceKind, trackID : TrackID ) -> GlobalLeaderboard? {
        guard let layout = Tracks.named( trackID ) else {
            return nil
        }

        let prefix = "shiftline." + trackID.replacingOccurrences( of : "-", with : "_" )

        switch kind {
        case .drag where layout.isDragStrip:
            return GlobalLeaderboard( id : prefix + ".drag", name : "\( layout.fullName ) · Elapsed Time", lowerIsBetter : true )
        case .sprint where !layout.isClosed && !layout.isDragStrip:
            return GlobalLeaderboard( id : prefix + ".sprint", name : "\( layout.fullName ) · Sprint Time", lowerIsBetter : true )
        case .circuit, .timeAttack, .endurance, .elimination, .practice:
            return layout.isClosed ? GlobalLeaderboard( id : prefix + ".lap", name : "\( layout.fullName ) · Best Lap", lowerIsBetter : true ) : nil
        case .drift( .scoreAttack, duration : 60 ) where driftTrackIDs.contains( trackID ):
            return GlobalLeaderboard( id : prefix + ".drift", name : "\( layout.fullName ) · Drift Score (60 s)", lowerIsBetter : false )
        default:
            return nil
        }
    }
}
