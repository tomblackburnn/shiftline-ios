import Foundation
import Testing
@testable import Shiftline

struct TrackTests {
    @Test( arguments : Tracks.all.filter { !$0.isDragStrip } )
    func layoutsBuildValidGeometry( _ layout : TrackLayout ) {
        let track = TrackGeometry( layout : layout )
        #expect( track.sampleCount > 100 )
        #expect( track.length > 500 )
        #expect( track.checkpoints.count >= 3 )
        #expect( zip( track.checkpoints, track.checkpoints.dropFirst() ).allSatisfy { $0 < $1 } )
        #expect( track.racingOffsets.allSatisfy { abs( $0 ) <= track.halfWidth } )
    }

    @Test func projectionRoundTrips() {
        let track = TrackGeometry( layout : Tracks.velocityParkGP )

        for distance in stride( from : 0.0, to : track.length, by : 157 ) {
            let point = track.point( atDistance : distance, lateral : 3 )
            let projection = track.project( point )
            #expect( abs( projection.distance - distance ) < 3 || abs( abs( projection.distance - distance ) - track.length ) < 3 )
            #expect( abs( projection.lateral - 3 ) < 0.5 )
        }
    }

    @Test func projectionNearHintStaysOnTheRightLegOfAHairpin() {
        let track = TrackGeometry( layout : Tracks.ridgeUphill )
        let distance = 400.0
        let point = track.point( atDistance : distance )
        let projection = track.project( point, near : track.index( forDistance : distance ) )
        #expect( abs( projection.distance - distance ) < 3 )
    }

    @Test func reversedLayoutRunsTheOtherWay() {
        let forward = TrackGeometry( layout : Tracks.ridgeUphill )
        let backward = TrackGeometry( layout : Tracks.ridgeDownhill )
        #expect( abs( forward.length - backward.length ) < 4 )
        #expect( ( forward.points[ 0 ] - backward.points[ backward.sampleCount - 1 ] ).length < 3 )
        #expect( backward.layout.grade == -forward.layout.grade )
    }

    @Test func speedProfileRespectsBraking() {
        let track = TrackGeometry( layout : Tracks.velocityParkGP )
        let deceleration = 9.0
        let speeds = track.speedProfile( grip : 1, brakingDeceleration : deceleration, topSpeed : 90, mass : 1_200, downforce : 0 )

        for index in 0 ..< speeds.count - 1 {
            let allowed = ( speeds[ index + 1 ] * speeds[ index + 1 ] + 2 * deceleration * track.spacing ).squareRoot()
            #expect( speeds[ index ] <= allowed + 1e-6 )
        }

        #expect( ( speeds.min() ?? 0 ) < 25 )
        #expect( ( speeds.max() ?? 0 ) > 60 )
    }

    @Test func dragStripsHaveTheirAdvertisedLength() {
        #expect( abs( TrackGeometry.dragLength( of : Tracks.kestrelQuarter ) - 402.336 ) < 0.01 )
        #expect( abs( TrackGeometry.dragLength( of : Tracks.kestrelHalf ) - 804.672 ) < 0.01 )
    }

    @Test func gridSlotsAreOnTheRoadBehindTheLine() {
        let track = TrackGeometry( layout : Tracks.harbourSprint )

        for slot in 0 ..< 8 {
            let grid = track.gridSlot( slot )
            let projection = track.project( grid.position )
            #expect( abs( projection.lateral ) < track.halfWidth )
            #expect( projection.distance < track.startDistance )
        }
    }
}

extension TrackLayout : @retroactive CustomTestStringConvertible {
    public var testDescription : String {
        id
    }
}
