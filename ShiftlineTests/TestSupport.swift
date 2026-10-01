import Foundation
@testable import Shiftline

enum TestSupport {
    static func spec( _ carID : CarID ) -> VehicleSpec {
        Cars.named( carID )!.baseSpec
    }

    /// Full throttle in a straight line until `speed` (m/s) or the time limit; returns elapsed seconds.
    static func timeToSpeed(
        _ spec : VehicleSpec,
        speed target : Double,
        assists : DrivingAssists = DrivingAssists(),
        limit : Double = 40
    ) -> Double {
        let model = VehicleModel( spec : spec )
        var state = model.initialState( at : .zero, heading : 0 )
        var input = VehicleInput()
        input.throttle = 1
        var time = 0.0

        while state.speed < target && time < limit {
            state = model.advancing( state, with : input, assists : assists )

            if !assists.automaticTransmission && state.gear >= 1 && state.engineRPM >= model.idealUpshiftRPM( fromGear : state.gear ) {
                state = model.shiftingUp( state )
            }

            time += VehicleModel.timeStep
        }

        return time
    }

    static func entrant( _ carID : CarID, player : Bool, profile : DriverProfile? = nil ) -> RaceEntrant {
        RaceEntrant(
            name : player ? "Player" : ( profile?.name ?? "AI" ),
            carID : carID,
            spec : spec( carID ),
            appearance : CarAppearance( paintHex : 0xFFFFFF ),
            profile : profile,
            isPlayer : player
        )
    }

    /// Runs a session with the player's car driven by an AI until it finishes or time runs out.
    static func runAutopilot( _ session : RaceSession, maximumSeconds : Double = 600 ) {
        session.player.ai = session.player.ai ?? AIDriver( profile : Opponents.pool[ 3 ], skill : 0.8, seed : "test" )
        var elapsed = 0.0

        while session.phase != .finished && elapsed < maximumSeconds {
            session.step()
            elapsed += RaceSession.timeStep
        }
    }

    static func temporaryDirectory() -> URL {
        FileManager.default.temporaryDirectory.appendingPathComponent( "ShiftlineTests-\( UUID().uuidString )", isDirectory : true )
    }

    static func saveWithStarter( _ carID : CarID = "hayase-pip" ) -> SaveData {
        let save = SaveData( profileName : "Tester" )
        return try! GarageRules().choosingStarter( carID, in : save )
    }
}
