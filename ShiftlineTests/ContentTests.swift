import Foundation
import Testing
@testable import Shiftline

struct ContentTests {
    @Test func contentMeetsTargets() {
        #expect( Cars.all.count >= 20 )
        #expect( Manufacturers.all.count >= 5 )
        #expect( TrackEnvironment.allCases.count >= 8 )
        #expect( Tracks.all.count >= 25 )
        #expect( Events.all.count >= 60 )
        #expect( Championships.all.count >= 5 )
        #expect( Opponents.rivals.count >= 5 )
        #expect( CareerTier.allCases.count >= 5 )
        #expect( UpgradeCategory.allCases.count == 15 )
    }

    @Test func everyCategoryAndDrivetrainIsRepresented() {
        #expect( Set( Cars.all.map { $0.category } ) == Set( CarCategory.allCases ) )
        #expect( Set( Cars.all.map { $0.drivetrain } ) == Set( Drivetrain.allCases ) )
    }

    @Test func identifiersAreUnique() {
        #expect( Set( Cars.all.map { $0.id } ).count == Cars.all.count )
        #expect( Set( Tracks.all.map { $0.id } ).count == Tracks.all.count )
        #expect( Set( Events.all.map { $0.id } ).count == Events.all.count )
        #expect( Set( Opponents.pool.map { $0.id } ).count == Opponents.pool.count )
    }

    @Test func eventsReferenceValidContent() {
        for event in Events.all {
            #expect( Tracks.named( event.trackID ) != nil, "\( event.id ) track" )

            for required in event.requirements.requiredEventIDs {
                #expect( Events.named( required ) != nil, "\( event.id ) requires \( required )" )
            }

            if let rivalID = event.rivalID {
                #expect( Opponents.rival( rivalID ) != nil, "\( event.id ) rival" )
            }

            let isDragStrip = Tracks.named( event.trackID )?.isDragStrip ?? false

            if case .drag = event.kind {
                #expect( isDragStrip, "\( event.id ) drag on strip" )
            } else {
                #expect( !isDragStrip, "\( event.id ) circuit on strip" )
            }

            if event.kind.usesLaps && event.kind != .elimination && event.kind != .practice {
                if case .drift( .scoreAttack, _ ) = event.kind {
                    continue
                }

                #expect( Tracks.named( event.trackID )?.isClosed == true, "\( event.id ) needs a loop" )
            }
        }
    }

    @Test func everyTierHasEventsInSeveralDisciplines() {
        for tier in CareerTier.allCases {
            let disciplines = Set( Events.events( in : tier ).map { $0.discipline } )
            #expect( disciplines.count >= 4, "\( tier.title )" )
        }
    }

    @Test func rivalsHaveEncountersWithRealCars() {
        for rival in Opponents.rivals {
            #expect( rival.encounters.count >= 3 )

            for encounter in rival.encounters {
                #expect( Cars.named( encounter.carID ) != nil )
            }

            #expect( Events.all.contains { $0.rivalID == rival.id } )
        }
    }

    @Test func championshipsReferenceValidTracks() {
        for championship in Championships.all {
            #expect( championship.rounds.count >= 4 )

            for round in championship.rounds {
                let layout = Tracks.named( round.trackID )
                #expect( layout != nil, "\( round.id )" )

                if case .drag = round.kind {
                    #expect( layout?.isDragStrip == true )
                }
            }
        }
    }

    @Test func startersAreClassDAndDifferent() {
        let starters = Cars.starterIDs.compactMap { Cars.named( $0 ) }
        #expect( starters.count == 3 )
        #expect( Set( starters.map { $0.drivetrain } ).count == 3 )

        for starter in starters {
            #expect( PerformanceProfile.measure( starter.baseSpec ).performanceClass == .d )
            #expect( starter.unlockLevel == 1 )
        }
    }

    @Test func performanceClassesSpanTheRoster() {
        let classes = Set( Cars.all.map { PerformanceProfile.measure( $0.baseSpec ).performanceClass } )
        #expect( classes == Set( PerformanceClass.allCases ) )
    }

    @Test func carsSpecialiseDifferently() {
        let drift = PerformanceProfile.measure( Cars.named( "hayase-arc-s" )!.baseSpec )
        let grip = PerformanceProfile.measure( Cars.named( "hayase-tempo-z" )!.baseSpec )
        #expect( drift.driftPotential > grip.driftPotential * 3 )
        #expect( grip.lateralG > drift.lateralG )
    }

    @Test func upgradeCostsScaleWithLevelAndCarValue() {
        for category in UpgradeCategory.allCases {
            let cheap = ( 1 ... 4 ).map { UpgradeRules.cost( of : category, level : $0, carPrice : 10_000 ) }
            let expensive = ( 1 ... 4 ).map { UpgradeRules.cost( of : category, level : $0, carPrice : 500_000 ) }
            #expect( cheap == cheap.sorted() )
            #expect( zip( cheap, expensive ).allSatisfy { $0 <= $1 } )
        }
    }

    @Test func eventTargetsAreOrdered() {
        for event in Events.all where event.kind.isScored {
            let config = RaceFactory( save : TestSupport.saveWithStarter() ).config( for : event, car : OwnedCar( carID : "hayase-pip" ) )
            let targets = config.targets
            #expect( targets != nil, "\( event.id )" )

            if let targets {
                if targets.lowerIsBetter {
                    #expect( targets.gold < targets.silver && targets.silver < targets.bronze )
                } else {
                    #expect( targets.gold > targets.silver && targets.silver > targets.bronze )
                }
            }

            if case .checkpoint( let start, let bonus ) = config.kind {
                #expect( start > 0 && bonus > 0 )
            }
        }
    }

    @Test func careerEventsBuildPlayableConfigurations() {
        let save = TestSupport.saveWithStarter()
        let factory = RaceFactory( save : save )

        for event in Events.all {
            let config = factory.config( for : event, car : save.garage[ 0 ] )
            #expect( config.entrants.filter { $0.isPlayer }.count == 1 )
            #expect( config.entrants.count == 1 + ( event.isRival ? 1 : event.opponents ) )
        }
    }
}

struct GlobalLeaderboardTests {
    @Test func everyTrackHasAValidUniqueBoard() {
        let boards = GlobalLeaderboards.all
        let allowed = CharacterSet( charactersIn : "abcdefghijklmnopqrstuvwxyz0123456789._" )

        #expect( Set( boards.map { $0.id } ).count == boards.count )
        #expect( boards.allSatisfy { $0.id.count <= 100 && $0.id.unicodeScalars.allSatisfy( allowed.contains ) } )

        for layout in Tracks.all {
            let prefix = "shiftline." + layout.id.replacingOccurrences( of : "-", with : "_" ) + "."
            #expect( boards.contains { $0.id.hasPrefix( prefix ) }, "\( layout.id ) has no global board" )
        }
    }

    @Test func resultsMapToTheHeadlineBoardForTheirTrack() {
        #expect( GlobalLeaderboards.board( for : .circuit, trackID : "velocity-gp" )?.id == "shiftline.velocity_gp.lap" )
        #expect( GlobalLeaderboards.board( for : .timeAttack, trackID : "velocity-gp" )?.id == "shiftline.velocity_gp.lap" )
        #expect( GlobalLeaderboards.board( for : .drag, trackID : "kestrel-quarter" )?.id == "shiftline.kestrel_quarter.drag" )
        #expect( GlobalLeaderboards.board( for : .sprint, trackID : "harbour-sprint" )?.id == "shiftline.harbour_sprint.sprint" )
        #expect( GlobalLeaderboards.board( for : .drift( .scoreAttack, duration : 60 ), trackID : "harbour-yard" )?.lowerIsBetter == false )
        #expect( GlobalLeaderboards.board( for : .drift( .chain, duration : 0 ), trackID : "harbour-yard" ) == nil )
        #expect( GlobalLeaderboards.board( for : .speedTrap, trackID : "velocity-gp" ) == nil )
        #expect( GlobalLeaderboards.board( for : .sprint, trackID : "velocity-gp" ) == nil )
    }

    @Test func timesAreSubmittedInHundredthsAndScoresAsPoints() {
        let lap = GlobalLeaderboards.board( for : .timeAttack, trackID : "velocity-gp" )!
        let drift = GlobalLeaderboards.board( for : .drift( .scoreAttack, duration : 60 ), trackID : "harbour-yard" )!
        #expect( lap.score( for : 83.456 ) == 8_346 )
        #expect( drift.score( for : 2_150 ) == 2_150 )
    }
}
