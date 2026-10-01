import Foundation

/// Credits and experience for a finished race, itemised so the results screen can explain them.
nonisolated struct RewardCalculator {
    static let placementShares = [ 1.0, 0.62, 0.45, 0.32, 0.22, 0.15, 0.1, 0.08 ]
    static let medalShares = [ 1.0, 0.62, 0.4, 0.15 ]
    static let experienceShares = [ 1.0, 0.75, 0.6, 0.45, 0.35, 0.3, 0.25, 0.2 ]
    static let replayFactor = 0.75

    /// Prize for races outside the career (quick race, free events): scales with the car's performance.
    static func quickRacePrize( performanceIndex : Int ) -> Int {
        Int( ( 600 + Double( performanceIndex ) * 4 ) / 50 ) * 50
    }

    func lines(
        for outcome : RaceOutcome,
        prize : Int?,
        isReplay : Bool,
        isNewPersonalBest : Bool
    ) -> [RewardLine] {
        if case .practice = outcome.kind {
            return []
        }

        if case .tutorial = outcome.kind {
            return []
        }

        var lines : [RewardLine] = []
        let difficulty = outcome.difficulty.rewardMultiplier
        let baseExperience = Double( outcome.tier?.baseXP ?? 150 )
        let index = max( outcome.placement - 1, 0 )

        if outcome.didFinish {
            let shares = outcome.kind.isScored ? RewardCalculator.medalShares : RewardCalculator.placementShares
            let share = index < shares.count ? shares[ index ] : 0.05
            let replay = isReplay ? RewardCalculator.replayFactor : 1
            let credits = Int( Double( prize ?? 0 ) * share * difficulty * replay )
            let experience = Int( baseExperience * ( index < RewardCalculator.experienceShares.count ? RewardCalculator.experienceShares[ index ] : 0.15 ) )
            lines.append( RewardLine( label : placementLabel( for : outcome ), credits : roundedCredits( credits ), experience : experience ) )
        } else {
            lines.append( RewardLine( label : "Did not finish", credits : 0, experience : Int( baseExperience * 0.15 ) ) )
            return lines
        }

        let scale = Double( prize ?? 2_000 ) / 2_600

        if outcome.isClean && outcome.fieldSize > 1 {
            lines.append( RewardLine( label : "Clean race", credits : roundedCredits( Int( 300 * scale ) ), experience : 40 ) )
        }

        if outcome.cleanOvertakes > 0 {
            let overtakes = min( outcome.cleanOvertakes, 10 )
            lines.append( RewardLine( label : "Clean overtakes ×\( overtakes )", credits : roundedCredits( Int( 90 * scale ) * overtakes ), experience : 8 * overtakes ) )
        }

        if outcome.perfectShifts > 0 {
            let shifts = min( outcome.perfectShifts, 15 )
            lines.append( RewardLine( label : "Perfect shifts ×\( shifts )", credits : roundedCredits( Int( 50 * scale ) * shifts ), experience : 4 * shifts ) )
        }

        if outcome.isFastestLap && outcome.fieldSize > 1 {
            lines.append( RewardLine( label : "Fastest lap", credits : roundedCredits( Int( 350 * scale ) ), experience : 30 ) )
        }

        if outcome.driftBestChain >= 2_000 {
            lines.append( RewardLine( label : "Drift combo", credits : roundedCredits( outcome.driftBestChain / 8 ), experience : 30 ) )
        }

        if let drag = outcome.drag, drag.launch == .perfect, !drag.isFoul {
            lines.append( RewardLine( label : "Perfect launch", credits : roundedCredits( Int( 250 * scale ) ), experience : 20 ) )
        }

        if isNewPersonalBest {
            lines.append( RewardLine( label : "New personal best", credits : roundedCredits( Int( 400 * scale ) ), experience : 50 ) )
        }

        if outcome.rivalID != nil && outcome.isWin {
            lines.append( RewardLine( label : "Rival defeated", credits : roundedCredits( ( prize ?? 0 ) / 2 ), experience : Int( baseExperience ) ) )
        }

        return lines
    }

    private func placementLabel( for outcome : RaceOutcome ) -> String {
        if outcome.kind.isScored {
            return [ "Gold", "Silver", "Bronze", "Finished" ][ min( outcome.placement - 1, 3 ) ]
        }

        return "Finished \( RaceResultFormat.ordinal( outcome.placement ) )"
    }

    private func roundedCredits( _ credits : Int ) -> Int {
        Int( ( Double( credits ) / 10 ).rounded() ) * 10
    }
}

nonisolated enum RaceResultFormat {
    static func ordinal( _ position : Int ) -> String {
        let suffix : String

        switch ( position % 10, position % 100 ) {
        case ( 1, let tens ) where tens != 11:
            suffix = "st"
        case ( 2, let tens ) where tens != 12:
            suffix = "nd"
        case ( 3, let tens ) where tens != 13:
            suffix = "rd"
        default:
            suffix = "th"
        }

        return "\( position )\( suffix )"
    }
}
