import Foundation

nonisolated enum DailyMetric : String, CaseIterable {
    case wins
    case podiums
    case driftPoints
    case personalBests
    case perfectShifts
    case cleanRaces
    case dragWins
    case overtakes
    case distance
    case perfectLaunches

    func amount( from outcome : RaceOutcome, isNewPersonalBest : Bool ) -> Double {
        switch self {
        case .wins:
            return outcome.isWin ? 1 : 0
        case .podiums:
            return outcome.isPodium ? 1 : 0
        case .driftPoints:
            return Double( outcome.driftScore )
        case .personalBests:
            return isNewPersonalBest ? 1 : 0
        case .perfectShifts:
            return Double( outcome.perfectShifts )
        case .cleanRaces:
            return outcome.isClean && outcome.fieldSize > 1 ? 1 : 0
        case .dragWins:
            return outcome.kind == .drag && outcome.isWin ? 1 : 0
        case .overtakes:
            return Double( outcome.cleanOvertakes )
        case .distance:
            return outcome.distance / 1_000
        case .perfectLaunches:
            return outcome.drag?.launch == .perfect ? 1 : 0
        }
    }
}

nonisolated struct DailyChallenge : Identifiable, Equatable {
    let id : String
    let metric : DailyMetric
    let target : Double
    let credits : Int

    var title : String {
        let amount = target.formatted( .number.precision( .fractionLength( 0 ) ) )

        switch metric {
        case .wins:
            return "Win \( amount ) races"
        case .podiums:
            return "Finish on the podium \( amount ) times"
        case .driftPoints:
            return "Score \( amount ) drift points"
        case .personalBests:
            return "Set \( amount ) personal bests"
        case .perfectShifts:
            return "Hit \( amount ) perfect shifts"
        case .cleanRaces:
            return "Finish \( amount ) clean races"
        case .dragWins:
            return "Win \( amount ) drag races"
        case .overtakes:
            return "Make \( amount ) clean overtakes"
        case .distance:
            return "Drive \( amount ) km"
        case .perfectLaunches:
            return "Get \( amount ) perfect launches"
        }
    }
}

/// Three challenges per day, generated locally from the date so every player gets the same set.
nonisolated struct DailyChallengeRules {
    static func dayStamp( for date : Date ) -> String {
        let components = Calendar( identifier : .gregorian ).dateComponents( [ .year, .month, .day ], from : date )
        return String( format : "%04d-%02d-%02d", components.year ?? 0, components.month ?? 0, components.day ?? 0 )
    }

    func challenges( for date : Date ) -> [DailyChallenge] {
        let day = DailyChallengeRules.dayStamp( for : date )
        var generator = SeededGenerator( text : "daily-" + day )
        let metrics = DailyMetric.allCases.shuffled( using : &generator ).prefix( 3 )

        return metrics.map { metric in
            let difficulty = generator.unit()
            let target : Double

            switch metric {
            case .wins, .podiums, .personalBests, .cleanRaces, .dragWins, .perfectLaunches:
                target = difficulty < 0.5 ? 2 : 3
            case .driftPoints:
                target = difficulty < 0.5 ? 4_000 : 8_000
            case .perfectShifts:
                target = difficulty < 0.5 ? 10 : 20
            case .overtakes:
                target = difficulty < 0.5 ? 6 : 12
            case .distance:
                target = difficulty < 0.5 ? 15 : 30
            }

            return DailyChallenge(
                id : "\( day )-\( metric.rawValue )",
                metric : metric,
                target : target,
                credits : difficulty < 0.5 ? 2_500 : 4_500
            )
        }
    }

    func recording(
        _ outcome : RaceOutcome,
        isNewPersonalBest : Bool,
        in save : SaveData,
        date : Date
    ) -> ( save : SaveData, rewards : [RewardLine], completed : [String] ) {
        var updatedSave = save
        let day = DailyChallengeRules.dayStamp( for : date )

        if updatedSave.daily.day != day {
            updatedSave.daily = DailyChallengeState( day : day )
        }

        var rewards : [RewardLine] = []
        var completed : [String] = []

        for challenge in challenges( for : date ) where !updatedSave.daily.claimed.contains( challenge.id ) {
            let progress = ( updatedSave.daily.progress[ challenge.id ] ?? 0 )
                + challenge.metric.amount( from : outcome, isNewPersonalBest : isNewPersonalBest )
            updatedSave.daily.progress[ challenge.id ] = progress

            if progress >= challenge.target {
                updatedSave.daily.claimed.insert( challenge.id )
                updatedSave.statistics.increment( .dailyChallengesCompleted )
                rewards.append( RewardLine( label : "Daily: \( challenge.title )", credits : challenge.credits, experience : 100 ) )
                completed.append( challenge.title )
            }
        }

        return ( updatedSave, rewards, completed )
    }
}
