import Foundation
import GameKit
import UIKit

nonisolated struct LeaderboardEntry : Identifiable, Equatable {
    let profileName : String
    let carID : CarID
    let value : Double
    let date : Date
    let isCurrentProfile : Bool

    var id : String {
        "\( profileName )-\( carID )-\( value )"
    }
}

/// Anything that can rank personal bests. Local ranking works offline; Game Center mirrors it when configured.
nonisolated protocol LeaderboardService {
    func entries( for key : String, lowerIsBetter : Bool ) -> [LeaderboardEntry]
}

/// Ranks the personal bests of every profile on this device.
nonisolated struct LocalLeaderboard : LeaderboardService {
    let store : SaveStore
    let currentProfileID : UUID?

    func entries( for key : String, lowerIsBetter : Bool ) -> [LeaderboardEntry] {
        let entries = store.profiles().compactMap { summary -> LeaderboardEntry? in
            let ( save, _ ) = store.load( summary.id, fallbackName : summary.name )

            guard let best = save.personalBests[ key ] else {
                return nil
            }

            return LeaderboardEntry(
                profileName : summary.name,
                carID : best.carID,
                value : best.value,
                date : best.date,
                isCurrentProfile : summary.id == currentProfileID
            )
        }

        return entries.sorted { lowerIsBetter ? $0.value < $1.value : $0.value > $1.value }
    }

    /// Every track/mode key any local profile has a record for.
    func keys() -> [String] {
        let all = store.profiles().flatMap { summary in
            store.load( summary.id, fallbackName : summary.name ).0.personalBests.keys.filter { $0.split( separator : "|" ).count == 2 }
        }

        return Array( Set( all ) ).sorted()
    }
}

/// Signs in to Game Center, submits results to the global boards and opens Game Center's leaderboard screen.
/// The boards in `GlobalLeaderboards.all` must exist in App Store Connect (see docs/LEADERBOARDS.md).
final class GameCenterService {
    static let shared = GameCenterService()
    private( set ) var isAuthenticated = false
    private( set ) var status = "Not signed in"

    private init() {}

    func authenticate() {
        GKLocalPlayer.local.authenticateHandler = { [weak self] signIn, error in
            Task { @MainActor in
                // Game Center hands over its sign-in screen when the player isn't signed in on this device.
                if let signIn {
                    GameCenterService.rootViewController?.present( signIn, animated : true )
                }

                self?.isAuthenticated = GKLocalPlayer.local.isAuthenticated
                self?.status = GKLocalPlayer.local.isAuthenticated
                    ? "Signed in as \( GKLocalPlayer.local.displayName )"
                    : ( error == nil ? "Not signed in" : "Unavailable: \( error?.localizedDescription ?? "" )" )
            }
        }
    }

    func submit( _ value : Double, to board : GlobalLeaderboard ) {
        guard isAuthenticated else {
            return
        }

        GKLeaderboard.submitScore( board.score( for : value ), context : 0, player : GKLocalPlayer.local, leaderboardIDs : [ board.id ] ) { _ in }
    }

    /// Opens Game Center's own leaderboard screen over the game.
    func showLeaderboards() {
        GKAccessPoint.shared.trigger( state : .leaderboards ) {}
    }

    private static var rootViewController : UIViewController? {
        UIApplication.shared.connectedScenes
            .compactMap { ( $0 as? UIWindowScene )?.keyWindow?.rootViewController }
            .first
    }
}
