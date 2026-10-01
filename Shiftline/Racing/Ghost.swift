import Foundation

nonisolated struct GhostSample : Codable, Equatable {
    var time : Float
    var x : Float
    var y : Float
    var heading : Float
    var speed : Float
}

/// A sampled lap for time attack playback. ~10 samples per second, interpolated on playback.
nonisolated struct GhostRecording : Codable, Equatable {
    var trackID : TrackID
    var carID : CarID
    var driverName : String
    var lapTime : Double
    var paintHex : UInt32
    var samples : [GhostSample]

    static let sampleInterval = 0.1

    func sample( at time : Double ) -> GhostSample? {
        guard let first = samples.first, let last = samples.last else {
            return nil
        }

        guard time > Double( first.time ) else {
            return first
        }

        guard time < Double( last.time ) else {
            return last
        }

        let estimate = Int( time / GhostRecording.sampleInterval )
        var upper = clamp( estimate, 1, samples.count - 1 )

        while upper < samples.count - 1 && Double( samples[ upper ].time ) < time {
            upper += 1
        }

        while upper > 1 && Double( samples[ upper - 1 ].time ) > time {
            upper -= 1
        }

        let lower = samples[ upper - 1 ]
        let higher = samples[ upper ]
        let span = max( higher.time - lower.time, 1e-4 )
        let amount = Float( clamp( ( time - Double( lower.time ) ) / Double( span ), 0, 1 ) )
        let headingDelta = Float( wrapAngle( Double( higher.heading - lower.heading ) ) )

        return GhostSample(
            time : Float( time ),
            x : lower.x + ( higher.x - lower.x ) * amount,
            y : lower.y + ( higher.y - lower.y ) * amount,
            heading : lower.heading + headingDelta * amount,
            speed : lower.speed + ( higher.speed - lower.speed ) * amount
        )
    }
}

nonisolated struct GhostRecorder {
    private( set ) var samples : [GhostSample] = []
    private var lastSampleTime = -Double.infinity

    mutating func record( _ state : VehicleState, lapTime : Double ) {
        guard lapTime - lastSampleTime >= GhostRecording.sampleInterval else {
            return
        }

        lastSampleTime = lapTime
        samples.append(
            GhostSample(
                time : Float( lapTime ),
                x : Float( state.position.x ),
                y : Float( state.position.y ),
                heading : Float( state.heading ),
                speed : Float( state.speed )
            )
        )
    }

    mutating func reset() {
        samples.removeAll( keepingCapacity : true )
        lastSampleTime = -Double.infinity
    }
}
