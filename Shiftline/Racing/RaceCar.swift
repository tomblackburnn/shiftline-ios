import Foundation

nonisolated enum SurfaceZone {
    case road
    case kerb
    case runoff
}

nonisolated enum RacePhase {
    case countdown
    case racing
    case finished
}

/// Things the presentation layer (HUD, audio, haptics, effects) reacts to.
nonisolated enum RaceEvent {
    case countdown( Int )
    case go
    case lap( car : Int, time : Double, isBest : Bool, isValid : Bool )
    case finalLap
    case checkpoint( index : Int, bonus : Double )
    case sector( index : Int, time : Double, delta : Double? )
    case collision( car : Int, intensity : Double, withWall : Bool, point : Vec2 )
    case overtake
    case positionLost
    case eliminated( car : Int, name : String )
    case trackLimits( car : Int, penalty : Double, invalidated : Bool )
    case wrongWay
    case drift( DriftEvent )
    case speedTrap( index : Int, speedKPH : Double )
    case shift( ShiftQuality )
    case finished( position : Int )
    case start( StartQuality )
    case slingshot
    case timeUp
    case message( String )
}

/// A car on track: physics state plus race progress and statistics.
nonisolated final class RaceCar : Identifiable {
    let id : Int
    let entrant : RaceEntrant
    let model : VehicleModel
    var state : VehicleState
    var previousState : VehicleState
    var input = VehicleInput()
    var assists : DrivingAssists
    var ai : AIDriver?
    var speedProfile : [Double] = []

    var trackIndex = 0
    var trackDistance = 0.0
    var lateral = 0.0
    var raceDistance = 0.0
    var surface = SurfaceZone.road

    var lapsCompleted = 0
    var nextCheckpoint = 0
    var lapStartTime = 0.0
    var sectorStartTime = 0.0
    var lapTimes : [Double] = []
    var bestLap : Double?
    var currentSectors : [Double] = []
    var bestSectors : [Double] = []
    var isLapValid = true

    var finishTime : Double?
    var isEliminated = false
    var eliminationOrder = 0
    var penaltySeconds = 0.0
    var trackLimitCount = 0
    var offTrackTime = 0.0
    var wrongWayTime = 0.0
    var stuckTime = 0.0

    var collisions = 0
    var wallHits = 0
    var lastCollisionTime = -100.0
    var topSpeed = 0.0
    var slipstream = 0.0
    /// Fills while drafting; a full charge fires a slingshot boost.
    var slipstreamCharge = SlipstreamCharge()
    var boost : Boost?
    var boostRemaining = 0.0
    var wheelspinPenaltyRemaining = 0.0
    /// Countdown time remaining when the current unbroken throttle hold began.
    var startHoldBegan : Double?
    var pendingEvents : VehicleEvents = []
    var perfectShifts = 0
    var shifts = 0
    var cleanOvertakes = 0
    var position = 1
    var speedTrapSpeeds : [Double] = []

    var isPlayer : Bool {
        entrant.isPlayer
    }

    var name : String {
        entrant.name
    }

    var isFinished : Bool {
        finishTime != nil
    }

    var isActive : Bool {
        !isEliminated
    }

    var totalTime : Double? {
        finishTime.map { $0 + penaltySeconds }
    }

    init( id : Int, entrant : RaceEntrant, assists : DrivingAssists, position : Vec2, heading : Double ) {
        self.id = id
        self.entrant = entrant
        self.assists = assists
        model = VehicleModel( spec : entrant.spec )
        state = model.initialState( at : position, heading : heading )
        previousState = state
    }

    /// Circles used for wall and car collisions: front and rear of the body.
    var collisionCircles : [( centre : Vec2, radius : Double )] {
        let forward = state.forward
        let offset = model.spec.length * 0.28
        let radius = model.spec.width * 0.52
        return [
            ( state.position + forward * offset, radius ),
            ( state.position - forward * offset, radius )
        ]
    }

    /// Records a gear change for statistics and returns the event to present.
    func recordShift() -> RaceEvent? {
        guard let quality = state.lastShiftQuality, state.events.contains( .upshift ) else {
            return nil
        }

        shifts += 1

        if quality == .perfect {
            perfectShifts += 1
        }

        return .shift( quality )
    }
}
