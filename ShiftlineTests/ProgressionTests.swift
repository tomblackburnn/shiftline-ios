import Foundation
import Testing
@testable import Shiftline

struct ProgressionTests {
    private let rules = ProgressionRules()

    private func outcome(
        eventID : String? = Events.firstEventID,
        placement : Int = 1,
        kind : RaceKind = .sprint,
        tier : CareerTier? = .rookie,
        time : Double? = 70
    ) -> RaceOutcome {
        RaceOutcome(
            eventID : eventID,
            title : "Test",
            kind : kind,
            discipline : .sprint,
            trackID : "harbour-sprint",
            carID : "hayase-pip",
            tier : tier,
            placement : placement,
            fieldSize : 5,
            time : time,
            topSpeedKPH : 150,
            distance : 1_800,
            finishingOrder : []
        )
    }

    @Test func levelCurveIsMonotonic() {
        #expect( ProgressionRules.level( forExperience : 0 ) == 1 )
        #expect( ProgressionRules.level( forExperience : ProgressionRules.experienceToNext( level : 1 ) ) == 2 )
        #expect( ProgressionRules.level( forExperience : 10_000_000 ) == ProgressionRules.maximumLevel )

        var previous = 1

        for experience in stride( from : 0, to : 200_000, by : 997 ) {
            let level = ProgressionRules.level( forExperience : experience )
            #expect( level >= previous )
            previous = level
        }
    }

    @Test func winningAwardsCreditsExperienceAndRecords() {
        let save = TestSupport.saveWithStarter()
        let ( updated, rewards ) = rules.applying( outcome(), to : save, prize : 2_600 )
        #expect( rewards.credits > 2_000 )
        #expect( rewards.experience > 0 )
        #expect( updated.profile.credits >= save.profile.credits + rewards.credits )
        #expect( updated.events[ Events.firstEventID ]?.wins == 1 )
        #expect( updated.events[ Events.firstEventID ]?.bestPlacement == 1 )
        #expect( updated.statistics[ .wins ] == 1 )
        #expect( updated.statistics[ .sprintWins ] == 1 )
        #expect( updated.achievements[ "first-flag" ] != nil )
    }

    @Test func lowerPlacesEarnLess() {
        let save = TestSupport.saveWithStarter()
        let first = rules.applying( outcome( placement : 1 ), to : save, prize : 2_600 ).1
        let fourth = rules.applying( outcome( placement : 4 ), to : save, prize : 2_600 ).1
        #expect( first.lines[ 0 ].credits > fourth.lines[ 0 ].credits )
        #expect( first.lines[ 0 ].experience > fourth.lines[ 0 ].experience )
    }

    @Test func replaysPayLess() {
        let save = TestSupport.saveWithStarter()
        let ( afterWin, firstRewards ) = rules.applying( outcome(), to : save, prize : 2_600 )
        let ( _, replayRewards ) = rules.applying( outcome(), to : afterWin, prize : 2_600 )
        #expect( replayRewards.lines[ 0 ].credits < firstRewards.lines[ 0 ].credits )
    }

    @Test func podiumUnlocksDependentEvents() {
        var save = TestSupport.saveWithStarter()
        save = rules.completingTutorial( .basics, in : save )
        let drag = Events.named( "r-drag-1" )!
        #expect( !rules.availability( of : drag, car : save.selectedCar, in : save ).isUnlocked )

        let ( updated, rewards ) = rules.applying( outcome( placement : 3 ), to : save, prize : 2_600 )
        #expect( rules.availability( of : drag, car : updated.selectedCar, in : updated ).isAvailable )
        #expect( rewards.unlockedEvents.contains( drag.name ) )
    }

    @Test func firstEventNeedsTheBasicsTutorial() {
        let save = TestSupport.saveWithStarter()
        let first = Events.named( Events.firstEventID )!
        #expect( !rules.availability( of : first, car : save.selectedCar, in : save ).isUnlocked )
        let tutored = rules.completingTutorial( .basics, in : save )
        #expect( rules.availability( of : first, car : tutored.selectedCar, in : tutored ).isAvailable )
    }

    @Test func tutorialsPayOnce() {
        let save = TestSupport.saveWithStarter()
        let once = rules.completingTutorial( .basics, in : save )
        let twice = rules.completingTutorial( .basics, in : once )
        #expect( once.profile.credits > save.profile.credits )
        #expect( twice.profile.credits == once.profile.credits )
    }

    @Test func tiersNeedLevelAndWins() {
        var save = TestSupport.saveWithStarter()
        #expect( rules.isTierUnlocked( .rookie, in : save ) )
        #expect( !rules.isTierUnlocked( .street, in : save ) )

        save.profile.level = 3

        for event in Events.rookie.prefix( 4 ) {
            save.events[ event.id ] = EventRecord( bestPlacement : 1, completions : 1, wins : 1 )
        }

        #expect( rules.isTierUnlocked( .street, in : save ) )
        #expect( !rules.isTierUnlocked( .club, in : save ) )
    }

    @Test func classCapBlocksFastCars() {
        var save = TestSupport.saveWithStarter()
        save = rules.completingTutorial( .basics, in : save )
        var fast = OwnedCar( carID : "veltra-vortex" )
        fast.id = UUID()
        save.garage.append( fast )
        let first = Events.named( Events.firstEventID )!

        if case .carIneligible( let reasons ) = rules.availability( of : first, car : fast, in : save ) {
            #expect( reasons.first?.hasPrefix( "Class" ) == true )
        } else {
            Issue.record( "Expected the Vortex to be ineligible for a Rookie event" )
        }
    }

    @Test func drivetrainRequirementIsEnforced() {
        var save = TestSupport.saveWithStarter( "hayase-kite-s" )
        let special = Events.named( "r-special-fwd" )!
        save.events[ "r-circuit-1" ] = EventRecord( bestPlacement : 1, completions : 1, wins : 1 )
        let availability = rules.availability( of : special, car : save.selectedCar, in : save )
        #expect( availability.isUnlocked )
        #expect( !availability.isAvailable )
    }

    @Test func personalBestsAreTrackedPerTrackAndCar() {
        let save = TestSupport.saveWithStarter()
        let ( first, _ ) = rules.applying( outcome( time : 80 ), to : save, prize : 2_600 )
        let ( second, rewards ) = rules.applying( outcome( time : 75 ), to : first, prize : 2_600 )
        let ( third, slower ) = rules.applying( outcome( time : 90 ), to : second, prize : 2_600 )
        #expect( second.personalBests[ "harbour-sprint|sprint" ]?.value == 75 )
        #expect( second.personalBests[ "harbour-sprint|sprint|hayase-pip" ]?.value == 75 )
        #expect( !rewards.newPersonalBests.isEmpty )
        #expect( slower.newPersonalBests.isEmpty )
        #expect( third.personalBests[ "harbour-sprint|sprint" ]?.value == 75 )
    }

    @Test func scoredEventsUseMedalShares() {
        let targets = MedalTargets( gold : 100, silver : 80, bronze : 60, lowerIsBetter : false )
        #expect( targets.placement( for : 120 ) == 1 )
        #expect( targets.placement( for : 85 ) == 2 )
        #expect( targets.placement( for : 60 ) == 3 )
        #expect( targets.placement( for : 10 ) == 4 )

        let times = MedalTargets( gold : 60, silver : 65, bronze : 70, lowerIsBetter : true )
        #expect( times.placement( for : 59 ) == 1 )
        #expect( times.placement( for : 69 ) == 3 )
    }

    @Test func levelUpPaysBonus() {
        var save = TestSupport.saveWithStarter()
        save.profile.experience = ProgressionRules.experienceToNext( level : 1 ) - 10
        let credits = save.profile.credits
        let updated = rules.crediting( [ RewardLine( label : "x", credits : 0, experience : 20 ) ], to : save )
        #expect( updated.profile.level == 2 )
        #expect( updated.profile.credits > credits )
    }

    @Test func dailyChallengesAreDeterministicAndComplete() {
        let date = Date( timeIntervalSince1970 : 1_800_000_000 )
        let dailyRules = DailyChallengeRules()
        #expect( dailyRules.challenges( for : date ) == dailyRules.challenges( for : date ) )
        #expect( dailyRules.challenges( for : date ).count == 3 )

        var save = TestSupport.saveWithStarter()
        var bigOutcome = outcome()
        bigOutcome.driftScore = 100_000
        bigOutcome.perfectShifts = 50
        bigOutcome.cleanOvertakes = 50
        bigOutcome.distance = 100_000
        var completed = 0

        for _ in 0 ..< 4 {
            let result = dailyRules.recording( bigOutcome, isNewPersonalBest : true, in : save, date : date )
            save = result.save
            completed += result.completed.count
        }

        let challenges = dailyRules.challenges( for : date )
        let dragOnly = challenges.filter { $0.metric == .dragWins || $0.metric == .perfectLaunches }.count
        #expect( completed == 3 - dragOnly )
        #expect( save.statistics[ .dailyChallengesCompleted ] == Double( completed ) )
    }

    @Test func rivalWinsAreRecorded() {
        let save = TestSupport.saveWithStarter()
        var rivalOutcome = outcome( eventID : "r-rival-voss", kind : .drag )
        rivalOutcome.rivalID = "rival-voss"
        let ( updated, rewards ) = rules.applying( rivalOutcome, to : save, prize : 4_000 )
        #expect( updated.rivalWins[ "rival-voss" ] == 1 )
        #expect( rewards.rivalDefeated != nil )
        #expect( rewards.lines.contains { $0.label == "Rival defeated" } )
    }
}
