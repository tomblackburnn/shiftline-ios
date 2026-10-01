import Foundation

nonisolated enum ChampionshipError : Error, Equatable {
    case notFound
    case locked
    case notStarted
    case alreadyComplete
}

/// Championship lifecycle: entering, scoring rounds, standings with tie-breaks, and the final prize.
nonisolated struct ChampionshipRules {
    /// The fixed AI field for a championship, chosen deterministically.
    func field( for championship : ChampionshipDefinition ) -> [DriverProfile] {
        Opponents.field( count : championship.fieldSize - 1, seed : championship.id )
    }

    func entering( _ championship : ChampionshipDefinition, with car : OwnedCar, in save : SaveData ) throws -> SaveData {
        let locks = ProgressionRules().lockReasons( for : championship.requirements, tier : championship.tier, in : save )

        guard locks.isEmpty else {
            throw ChampionshipError.locked
        }

        var standings = [ ChampionshipStanding( id : "player", name : save.profile.name, carID : car.carID, isPlayer : true ) ]

        for ( index, driver ) in field( for : championship ).enumerated() {
            let carID = RaceFactory.opponentCarID(
                index : index,
                classCap : championship.requirements.maximumClass ?? championship.tier.classCap,
                seed : championship.id,
                requirements : championship.requirements
            )
            standings.append( ChampionshipStanding( id : driver.id, name : driver.name, carID : carID, isPlayer : false ) )
        }

        var updatedSave = save
        let timesWon = save.championships[ championship.id ]?.timesWon ?? 0
        updatedSave.championships[ championship.id ] = ChampionshipProgress(
            championshipID : championship.id,
            standings : standings,
            timesWon : timesWon
        )
        updatedSave.statistics.increment( .championshipsEntered )
        return updatedSave
    }

    /// Standings order: points, then wins, then best finishing positions (count-back), then name.
    func sorted( _ standings : [ChampionshipStanding] ) -> [ChampionshipStanding] {
        standings.sorted { lhs, rhs in
            if lhs.points != rhs.points {
                return lhs.points > rhs.points
            }

            if lhs.wins != rhs.wins {
                return lhs.wins > rhs.wins
            }

            let lhsFinishes = lhs.finishes.sorted()
            let rhsFinishes = rhs.finishes.sorted()

            for ( left, right ) in zip( lhsFinishes, rhsFinishes ) where left != right {
                return left < right
            }

            return lhs.name < rhs.name
        }
    }

    /// Applies a round's finishing order (driver ids, winner first).
    func applyingRound(
        order : [String],
        to championship : ChampionshipDefinition,
        in save : SaveData
    ) throws -> ( save : SaveData, finalPosition : Int? ) {
        guard var progress = save.championships[ championship.id ] else {
            throw ChampionshipError.notStarted
        }

        guard !progress.isComplete else {
            throw ChampionshipError.alreadyComplete
        }

        for ( index, driverID ) in order.enumerated() {
            guard let standingIndex = progress.standings.firstIndex( where : { $0.id == driverID } ) else {
                continue
            }

            let position = index + 1
            progress.standings[ standingIndex ].points += ChampionshipScoring.points( forPosition : position )
            progress.standings[ standingIndex ].finishes.append( position )

            if position == 1 {
                progress.standings[ standingIndex ].wins += 1
            }

            if position <= 3 {
                progress.standings[ standingIndex ].podiums += 1
            }
        }

        progress.nextRound += 1
        progress.standings = sorted( progress.standings )
        var finalPosition : Int?

        if progress.nextRound >= championship.rounds.count {
            progress.isComplete = true
            finalPosition = ( progress.standings.firstIndex { $0.isPlayer } ?? 0 ) + 1
            progress.finalPosition = finalPosition

            if finalPosition == 1 {
                progress.timesWon += 1
            }
        }

        var updatedSave = save
        updatedSave.championships[ championship.id ] = progress

        if finalPosition == 1 {
            updatedSave.statistics.increment( .championshipsWon )
        }

        return ( updatedSave, finalPosition )
    }

    func finalPrize( for championship : ChampionshipDefinition, position : Int ) -> RewardLine {
        let shares = [ 1.0, 0.5, 0.3 ]
        let share = position <= shares.count ? shares[ position - 1 ] : 0.1
        return RewardLine(
            label : "\( championship.name ): \( RaceResultFormat.ordinal( position ) ) overall",
            credits : Int( Double( championship.prize ) * share ),
            experience : Int( Double( championship.tier.baseXP ) * 3 * share )
        )
    }

    func roundPrize( for championship : ChampionshipDefinition ) -> Int {
        Int( Double( championship.tier.basePayout ) * 0.8 )
    }
}
