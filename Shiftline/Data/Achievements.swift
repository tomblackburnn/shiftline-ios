import Foundation

nonisolated struct AchievementDefinition : Identifiable {
    let id : String
    let title : String
    let summary : String
    let symbol : String
    let credits : Int
    let experience : Int
    /// 0...1 progress from the save; unlocked at 1.
    let progress : ( SaveData ) -> Double
}

nonisolated enum Achievements {
    private static func statistic( _ key : StatisticKey, target : Double ) -> ( SaveData ) -> Double {
        { save in min( save.statistics[ key ] / target, 1 ) }
    }

    static let all : [AchievementDefinition] = [
        AchievementDefinition(
            id : "first-flag", title : "Chequered Debut", summary : "Win your first race.", symbol : "flag.checkered",
            credits : 1_000, experience : 100, progress : statistic( .wins, target : 1 )
        ),
        AchievementDefinition(
            id : "ten-wins", title : "Habit Forming", summary : "Win 10 races.", symbol : "trophy",
            credits : 3_000, experience : 250, progress : statistic( .wins, target : 10 )
        ),
        AchievementDefinition(
            id : "fifty-wins", title : "Serial Winner", summary : "Win 50 races.", symbol : "trophy.fill",
            credits : 15_000, experience : 800, progress : statistic( .wins, target : 50 )
        ),
        AchievementDefinition(
            id : "podium-25", title : "Champagne Taste", summary : "Finish on the podium 25 times.", symbol : "medal",
            credits : 5_000, experience : 300, progress : statistic( .podiums, target : 25 )
        ),
        AchievementDefinition(
            id : "perfect-5", title : "Heel and Toe", summary : "Hit 5 perfect shifts.", symbol : "gearshape",
            credits : 800, experience : 80, progress : statistic( .perfectShifts, target : 5 )
        ),
        AchievementDefinition(
            id : "perfect-250", title : "Synchromesh Soul", summary : "Hit 250 perfect shifts.", symbol : "gearshape.2.fill",
            credits : 8_000, experience : 500, progress : statistic( .perfectShifts, target : 250 )
        ),
        AchievementDefinition(
            id : "launch-perfect", title : "Hole Shot", summary : "Get a perfect drag launch.", symbol : "bolt.horizontal",
            credits : 1_000, experience : 100, progress : statistic( .perfectLaunches, target : 1 )
        ),
        AchievementDefinition(
            id : "reaction", title : "Tree Reader", summary : "React to the green in under 0.200 s.", symbol : "stopwatch",
            credits : 2_000, experience : 150,
            progress : { save in
                let best = save.statistics[ .bestReactionTime ]
                return best > 0 && best < 0.2 ? 1 : 0
            }
        ),
        AchievementDefinition(
            id : "drag-first", title : "Strip Starter", summary : "Win a drag race.", symbol : "gauge.with.dots.needle.67percent",
            credits : 800, experience : 80, progress : statistic( .dragWins, target : 1 )
        ),
        AchievementDefinition(
            id : "drag-king", title : "Christmas Tree Royalty", summary : "Win 15 drag races.", symbol : "crown",
            credits : 8_000, experience : 500, progress : statistic( .dragWins, target : 15 )
        ),
        AchievementDefinition(
            id : "ten-second", title : "Ten-Second Car", summary : "Run a quarter mile in under 11 seconds.", symbol : "timer",
            credits : 6_000, experience : 400,
            progress : { save in
                let best = save.statistics[ .fastestQuarterMile ]
                return best > 0 && best < 11 ? 1 : 0
            }
        ),
        AchievementDefinition(
            id : "sideways-10k", title : "Getting Loose", summary : "Score 10,000 drift points in total.", symbol : "tornado",
            credits : 1_000, experience : 100, progress : statistic( .driftTotalScore, target : 10_000 )
        ),
        AchievementDefinition(
            id : "sideways-100k", title : "Tyre Smoke Artist", summary : "Score 100,000 drift points in total.", symbol : "smoke.fill",
            credits : 10_000, experience : 600, progress : statistic( .driftTotalScore, target : 100_000 )
        ),
        AchievementDefinition(
            id : "chain-6k", title : "Unbroken", summary : "Bank a 6,000-point drift chain.", symbol : "link",
            credits : 5_000, experience : 350, progress : statistic( .highestDriftChain, target : 6_000 )
        ),
        AchievementDefinition(
            id : "drift-gold", title : "Judges' Favourite", summary : "Win gold in a drift event.", symbol : "star.circle",
            credits : 2_000, experience : 150, progress : statistic( .driftGolds, target : 1 )
        ),
        AchievementDefinition(
            id : "circuit-5", title : "Apex Predator", summary : "Win 5 circuit races.", symbol : "point.topleft.down.to.point.bottomright.curvepath",
            credits : 4_000, experience : 300, progress : statistic( .circuitWins, target : 5 )
        ),
        AchievementDefinition(
            id : "sprint-5", title : "A to B", summary : "Win 5 sprint races.", symbol : "arrow.right.to.line",
            credits : 4_000, experience : 300, progress : statistic( .sprintWins, target : 5 )
        ),
        AchievementDefinition(
            id : "street-5", title : "After Dark", summary : "Win 5 street races.", symbol : "moon.stars",
            credits : 4_000, experience : 300, progress : statistic( .streetWins, target : 5 )
        ),
        AchievementDefinition(
            id : "mountain-1", title : "Switchback Survivor", summary : "Win a mountain race.", symbol : "mountain.2",
            credits : 2_000, experience : 150, progress : statistic( .mountainWins, target : 1 )
        ),
        AchievementDefinition(
            id : "mountain-5", title : "Ridge Runner", summary : "Win 5 mountain races.", symbol : "mountain.2.fill",
            credits : 6_000, experience : 400, progress : statistic( .mountainWins, target : 5 )
        ),
        AchievementDefinition(
            id : "elimination", title : "Last One Standing", summary : "Win an elimination race.", symbol : "person.fill.xmark",
            credits : 2_000, experience : 150, progress : statistic( .eliminationWins, target : 1 )
        ),
        AchievementDefinition(
            id : "time-attack", title : "Against the Clock", summary : "Earn a time attack gold.", symbol : "clock.badge.checkmark",
            credits : 2_000, experience : 150, progress : statistic( .timeAttackGolds, target : 1 )
        ),
        AchievementDefinition(
            id : "checkpoint", title : "Beat the Buzzer", summary : "Earn a checkpoint gold.", symbol : "flag.2.crossed",
            credits : 2_000, experience : 150, progress : statistic( .checkpointGolds, target : 1 )
        ),
        AchievementDefinition(
            id : "speed-trap", title : "Radar Magnet", summary : "Earn a speed trap gold.", symbol : "dot.radiowaves.left.and.right",
            credits : 2_000, experience : 150, progress : statistic( .speedTrapGolds, target : 1 )
        ),
        AchievementDefinition(
            id : "endurance", title : "Long Haul", summary : "Win an endurance race.", symbol : "hourglass",
            credits : 5_000, experience : 350, progress : statistic( .enduranceWins, target : 1 )
        ),
        AchievementDefinition(
            id : "speed-250", title : "Two-Fifty Club", summary : "Reach 250 km/h.", symbol : "speedometer",
            credits : 2_000, experience : 150, progress : statistic( .topSpeedKPH, target : 250 )
        ),
        AchievementDefinition(
            id : "speed-350", title : "Terminal", summary : "Reach 350 km/h.", symbol : "bolt.car",
            credits : 10_000, experience : 600, progress : statistic( .topSpeedKPH, target : 350 )
        ),
        AchievementDefinition(
            id : "clean-10", title : "Gentleman Driver", summary : "Finish 10 clean races.", symbol : "hand.thumbsup",
            credits : 3_000, experience : 250, progress : statistic( .cleanRaces, target : 10 )
        ),
        AchievementDefinition(
            id : "overtakes-50", title : "Divebomber", summary : "Make 50 clean overtakes.", symbol : "arrow.up.right",
            credits : 4_000, experience : 300, progress : statistic( .cleanOvertakes, target : 50 )
        ),
        AchievementDefinition(
            id : "rival-first", title : "Grudge Settled", summary : "Defeat a rival.", symbol : "person.2.fill",
            credits : 3_000, experience : 250, progress : statistic( .rivalWins, target : 1 )
        ),
        AchievementDefinition(
            id : "rival-all", title : "Nemesis", summary : "Beat every rival at least once.", symbol : "person.3.fill",
            credits : 20_000, experience : 1_000,
            progress : { save in
                Double( Opponents.rivals.filter { ( save.rivalWins[ $0.id ] ?? 0 ) > 0 }.count ) / Double( Opponents.rivals.count )
            }
        ),
        AchievementDefinition(
            id : "champion", title : "Clean Sweep", summary : "Win a championship.", symbol : "trophy.circle.fill",
            credits : 8_000, experience : 500, progress : statistic( .championshipsWon, target : 1 )
        ),
        AchievementDefinition(
            id : "legend", title : "Shiftline Legend", summary : "Win the Shiftline Legends Cup.", symbol : "crown.fill",
            credits : 50_000, experience : 2_000,
            progress : { save in ( save.championships[ "ch-legend" ]?.timesWon ?? 0 ) > 0 ? 1 : 0 }
        ),
        AchievementDefinition(
            id : "garage-5", title : "Collector", summary : "Own 5 cars.", symbol : "car.2",
            credits : 3_000, experience : 200, progress : statistic( .carsOwnedPeak, target : 5 )
        ),
        AchievementDefinition(
            id : "garage-10", title : "Garage Builder", summary : "Own 10 cars.", symbol : "car.2.fill",
            credits : 10_000, experience : 500, progress : statistic( .carsOwnedPeak, target : 10 )
        ),
        AchievementDefinition(
            id : "upgrades-20", title : "Wrench Time", summary : "Buy 20 upgrades.", symbol : "wrench.and.screwdriver",
            credits : 3_000, experience : 200, progress : statistic( .upgradesPurchased, target : 20 )
        ),
        AchievementDefinition(
            id : "fully-built", title : "Full Build", summary : "Max out every upgrade on one car.", symbol : "hammer.fill",
            credits : 15_000, experience : 700,
            progress : { save in
                let best = save.garage.map { Double( $0.upgradeCount ) }.max() ?? 0
                return min( best / Double( UpgradeCategory.allCases.count * UpgradeRules.maximumLevel ), 1 )
            }
        ),
        AchievementDefinition(
            id : "livery", title : "Show Car", summary : "Apply a livery.", symbol : "paintbrush.fill",
            credits : 500, experience : 50, progress : statistic( .liveriesApplied, target : 1 )
        ),
        AchievementDefinition(
            id : "tuner", title : "Setup Sheet", summary : "Save a tune.", symbol : "slider.horizontal.3",
            credits : 500, experience : 50, progress : statistic( .tuningsSaved, target : 1 )
        ),
        AchievementDefinition(
            id : "distance-500", title : "Road Trip", summary : "Drive 500 km.", symbol : "road.lanes",
            credits : 6_000, experience : 400, progress : statistic( .distanceDriven, target : 500_000 )
        ),
        AchievementDefinition(
            id : "all-drivetrains", title : "Every Wheel", summary : "Win in FWD, RWD and AWD cars.", symbol : "circle.grid.3x3.fill",
            credits : 4_000, experience : 300,
            progress : { save in
                let drivetrains = Set( save.garage.filter { $0.wins > 0 }.map { $0.drivetrain } )
                return Double( drivetrains.count ) / 3
            }
        ),
        AchievementDefinition(
            id : "school", title : "Graduate", summary : "Complete every tutorial.", symbol : "graduationcap.fill",
            credits : 3_000, experience : 250,
            progress : { save in Double( save.profile.completedTutorials.count ) / Double( TutorialKind.allCases.count ) }
        ),
        AchievementDefinition(
            id : "daily-5", title : "Daily Driver", summary : "Complete 5 daily challenges.", symbol : "calendar.badge.checkmark",
            credits : 3_000, experience : 200, progress : statistic( .dailyChallengesCompleted, target : 5 )
        ),
        AchievementDefinition(
            id : "level-10", title : "Rising Star", summary : "Reach driver level 10.", symbol : "star.fill",
            credits : 5_000, experience : 0, progress : { save in min( Double( save.profile.level ) / 10, 1 ) }
        ),
        AchievementDefinition(
            id : "level-25", title : "Veteran", summary : "Reach driver level 25.", symbol : "star.circle.fill",
            credits : 20_000, experience : 0, progress : { save in min( Double( save.profile.level ) / 25, 1 ) }
        )
    ]
}

nonisolated struct AchievementRules {
    func evaluating( _ save : SaveData ) -> ( save : SaveData, unlocked : [AchievementDefinition] ) {
        var updatedSave = save
        var unlocked : [AchievementDefinition] = []

        for achievement in Achievements.all where save.achievements[ achievement.id ] == nil {
            if achievement.progress( save ) >= 1 {
                updatedSave.achievements[ achievement.id ] = Date()
                unlocked.append( achievement )
            }
        }

        return ( updatedSave, unlocked )
    }
}
