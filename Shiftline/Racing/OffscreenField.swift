import Foundation

/// Headless simulations used to give off-screen competitors genuine results.
nonisolated enum OffscreenField {
    /// Championship time trials and drift rounds are solo runs; everyone else runs the same event off-screen.
    static func runsFieldOffscreen( _ config : RaceConfig, context : RaceContext ) -> Bool {
        guard context.championshipID != nil else {
            return false
        }

        switch config.kind {
        case .timeAttack, .drift:
            return true
        default:
            return false
        }
    }

    static func onTrackConfig( for config : RaceConfig, context : RaceContext ) -> RaceConfig {
        var onTrack = config

        if runsFieldOffscreen( config, context : context ) {
            onTrack.entrants = config.entrants.filter { $0.isPlayer }
        }

        return onTrack
    }

    static func lowerIsBetter( _ kind : RaceKind ) -> Bool {
        if case .timeAttack = kind {
            return true
        }

        return false
    }

    /// Each AI entrant runs the event alone and is scored exactly as the player is (best lap or drift points).
    static func scores( for config : RaceConfig ) -> [( String, Double )] {
        config.entrants.filter { !$0.isPlayer }.compactMap { entrant in
            var solo = config
            solo.entrants = [ entrant ]
            let session = RaceSession( config : solo )
            var steps = 0

            while session.phase != .finished && steps < 120 * 60 * 8 && !Task.isCancelled {
                session.step()
                steps += 1
            }

            guard let score = session.mode.playerScore( session ), let id = entrant.profile?.id else {
                return nil
            }

            return ( id, score )
        }
    }
}
