import Foundation

/// A finished race, reduced to the facts progression cares about. Built from a RaceSession or DragRace.
nonisolated struct RaceOutcome {
    var eventID : String?
    var championshipID : String?
    var title : String
    var kind : RaceKind
    var discipline : Discipline
    var trackID : TrackID
    var carID : CarID
    var ownedCarID : UUID?
    var tier : CareerTier?
    var rivalID : String?
    var difficulty : Difficulty = .pro

    /// 1 = win / gold. For scored modes 2 = silver, 3 = bronze, 4 = no medal.
    var placement : Int
    var fieldSize : Int
    var didFinish = true
    var score : Double?
    var time : Double?
    var bestLap : Double?
    var isFastestLap = false

    var collisions = 0
    var trackLimitCount = 0
    var cleanOvertakes = 0
    var perfectShifts = 0
    var shifts = 0
    var topSpeedKPH = 0.0
    var distance = 0.0
    var driftScore = 0
    var driftBestChain = 0
    var drag : DragRunResult?
    var ghost : GhostRecording?

    /// Order of finishers, used by championships ([driver id]).
    var finishingOrder : [String] = []

    var isWin : Bool {
        didFinish && placement == 1
    }

    var isPodium : Bool {
        didFinish && placement <= 3
    }

    var isClean : Bool {
        didFinish && collisions == 0 && trackLimitCount == 0
    }
}

nonisolated struct RewardLine : Identifiable, Equatable {
    let label : String
    let credits : Int
    var experience = 0

    var id : String {
        label
    }
}

nonisolated struct RaceRewards : Equatable {
    var lines : [RewardLine] = []
    var levelBefore = 1
    var levelAfter = 1
    var newPersonalBests : [String] = []
    var unlockedAchievements : [String] = []
    var unlockedEvents : [String] = []
    var rivalDefeated : String?
    var completedChallenges : [String] = []

    var credits : Int {
        lines.reduce( 0 ) { $0 + $1.credits }
    }

    var experience : Int {
        lines.reduce( 0 ) { $0 + $1.experience }
    }

    var didLevelUp : Bool {
        levelAfter > levelBefore
    }
}
