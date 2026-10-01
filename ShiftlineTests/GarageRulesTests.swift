import Foundation
import Testing
@testable import Shiftline

struct GarageRulesTests {
    private let rules = GarageRules()

    @Test func choosingAStarterGivesCarAndCredits() throws {
        let save = try rules.choosingStarter( "hayase-kite-s", in : SaveData( profileName : "A" ) )
        #expect( save.garage.count == 1 )
        #expect( save.selectedCar?.carID == "hayase-kite-s" )
        #expect( save.profile.credits == GarageRules.startingCredits )
        #expect( throws : GarageError.alreadyOwned ) {
            try rules.choosingStarter( "hayase-pip", in : save )
        }
    }

    @Test func starterMustBeAStarter() {
        #expect( throws : GarageError.notAvailable ) {
            try rules.choosingStarter( "aurex-fulmine", in : SaveData( profileName : "A" ) )
        }
    }

    @Test func buyingACarDeductsCreditsAndSelectsIt() throws {
        var save = TestSupport.saveWithStarter()
        save.profile.credits = 20_000
        save.profile.level = 2
        let bought = try rules.purchasing( "wrenfield-linnet", from : save )
        #expect( bought.garage.count == 2 )
        #expect( bought.profile.credits == 20_000 - 16_500 )
        #expect( bought.selectedCar?.carID == "wrenfield-linnet" )
        #expect( bought.statistics[ .carsOwnedPeak ] == 2 )
    }

    @Test func purchaseRulesAreEnforced() {
        var save = TestSupport.saveWithStarter()
        save.profile.credits = 5_000
        save.profile.level = 2

        #expect( throws : GarageError.insufficientCredits ) {
            try rules.purchasing( "wrenfield-linnet", from : save )
        }

        #expect( throws : GarageError.alreadyOwned ) {
            try rules.purchasing( "hayase-pip", from : save )
        }

        save.profile.credits = 10_000_000

        #expect( throws : GarageError.levelTooLow( required : 30 ) ) {
            try rules.purchasing( "aurex-fulmine", from : save )
        }

        #expect( throws : GarageError.carNotFound ) {
            try rules.purchasing( "not-a-car", from : save )
        }
    }

    @Test func sellingRefundsAndKeepsAtLeastOneCar() throws {
        var save = TestSupport.saveWithStarter()
        #expect( throws : GarageError.lastCar ) {
            try rules.selling( save.garage[ 0 ].id, from : save )
        }

        save.profile.credits = 50_000
        save.profile.level = 5
        save = try rules.purchasing( "hayase-arc-s", from : save )
        let arc = save.garage.first { $0.carID == "hayase-arc-s" }!
        let value = rules.resaleValue( of : arc )
        let sold = try rules.selling( arc.id, from : save )
        #expect( sold.garage.count == 1 )
        #expect( sold.profile.credits == save.profile.credits + value )
        #expect( value < 32_000 )
    }

    @Test func upgradesRaiseLevelCostMoreAndImprovePerformance() throws {
        var save = TestSupport.saveWithStarter()
        save.profile.credits = 1_000_000
        save.profile.level = 20
        let carID = save.garage[ 0 ].id
        let before = PerformanceProfile.measure( CarBuild( owned : save.garage[ 0 ] ).spec )
        var costs : [Int] = []

        for _ in 1 ... UpgradeRules.maximumLevel {
            costs.append( rules.upgradeCost( for : .engine, on : save.ownedCar( carID )! )! )
            save = try rules.purchasing( .engine, for : carID, from : save )
        }

        #expect( save.ownedCar( carID )!.level( of : .engine ) == 4 )
        #expect( costs == costs.sorted() )
        #expect( rules.upgradeCost( for : .engine, on : save.ownedCar( carID )! ) == nil )
        #expect( throws : GarageError.maximumLevelReached ) {
            try rules.purchasing( .engine, for : carID, from : save )
        }

        let after = PerformanceProfile.measure( CarBuild( owned : save.ownedCar( carID )! ).spec )
        #expect( after.horsepower > before.horsepower * 1.15 )
        #expect( after.index > before.index )
        #expect( save.statistics[ .upgradesPurchased ] == 4 )
    }

    @Test func highUpgradeLevelsNeedDriverLevel() throws {
        var save = TestSupport.saveWithStarter()
        save.profile.credits = 1_000_000
        save.profile.level = UpgradeRules.requiredDriverLevel[ 2 ]
        let carID = save.garage[ 0 ].id

        for _ in 0 ..< 2 {
            save = try rules.purchasing( .brakes, for : carID, from : save )
        }

        #expect( throws : GarageError.levelTooLow( required : UpgradeRules.requiredDriverLevel[ 3 ] ) ) {
            try rules.purchasing( .brakes, for : carID, from : save )
        }
    }

    @Test func tyreCompoundsUnlockWithTyreLevel() throws {
        var save = TestSupport.saveWithStarter()
        save.profile.credits = 1_000_000
        save.profile.level = 20
        let carID = save.garage[ 0 ].id

        #expect( throws : GarageError.notAvailable ) {
            try rules.settingCompound( .semiSlick, for : carID, in : save )
        }

        for _ in 0 ..< 3 {
            save = try rules.purchasing( .tyres, for : carID, from : save )
        }

        save = try rules.settingCompound( .semiSlick, for : carID, in : save )
        #expect( CarBuild( owned : save.ownedCar( carID )! ).spec.tyre == .semiSlick )
    }

    @Test func naturallyAspiratedCarsCanFitForcedInduction() throws {
        var save = TestSupport.saveWithStarter( "hayase-kite-s" )
        save.profile.credits = 1_000_000
        let carID = save.garage[ 0 ].id
        let stock = CarBuild( owned : save.garage[ 0 ] ).spec
        #expect( stock.turboBoost == 0 )

        save = try rules.purchasing( .forcedInduction, for : carID, from : save )
        #expect( CarBuild( owned : save.ownedCar( carID )! ).spec.turboBoost > 0 )

        save = try rules.settingInduction( .supercharger, for : carID, in : save )
        let supercharged = CarBuild( owned : save.ownedCar( carID )! ).spec
        #expect( supercharged.turboBoost == 0 )
        #expect( supercharged.superchargerBoost > 0 )
    }

    @Test func drivetrainConversionNeedsUpgradeAndChangesLayout() throws {
        var save = TestSupport.saveWithStarter( "norrvik-fjell" )
        save.profile.credits = 1_000_000
        save.profile.level = 20
        let carID = save.garage[ 0 ].id

        #expect( throws : GarageError.notAvailable ) {
            try rules.settingDrivetrain( .rwd, for : carID, in : save )
        }

        for _ in 0 ..< 2 {
            save = try rules.purchasing( .drivetrain, for : carID, from : save )
        }

        let credits = save.profile.credits
        save = try rules.settingDrivetrain( .rwd, for : carID, in : save )
        #expect( CarBuild( owned : save.ownedCar( carID )! ).spec.drivetrain == .rwd )
        #expect( save.profile.credits == credits - UpgradeRules.conversionCost )
    }

    @Test func downgradingRefundsPartOfTheCostAndLowersPerformance() throws {
        var save = TestSupport.saveWithStarter()
        save.profile.credits = 1_000_000
        save.profile.level = 20
        let carID = save.garage[ 0 ].id
        let stock = PerformanceProfile.measure( CarBuild( owned : save.garage[ 0 ] ).spec )

        #expect( throws : GarageError.notAvailable ) {
            try rules.downgrading( .engine, for : carID, from : save )
        }

        save = try rules.purchasing( .engine, for : carID, from : save )
        let credits = save.profile.credits
        let refund = try #require( rules.downgradeRefund( for : .engine, on : save.ownedCar( carID )! ) )
        let cost = UpgradeRules.cost( of : .engine, level : 1, carPrice : save.garage[ 0 ].definition.price )
        #expect( refund > 0 && refund < cost )

        save = try rules.downgrading( .engine, for : carID, from : save )
        #expect( save.ownedCar( carID )!.level( of : .engine ) == 0 )
        #expect( save.profile.credits == credits + refund )
        #expect( PerformanceProfile.measure( CarBuild( owned : save.ownedCar( carID )! ).spec ).index == stock.index )
    }

    @Test func downgradingRevertsPartsTheLowerLevelCannotRun() throws {
        var save = TestSupport.saveWithStarter( "norrvik-fjell" )
        save.profile.credits = 1_000_000
        save.profile.level = 20
        let carID = save.garage[ 0 ].id

        for _ in 0 ..< 3 {
            save = try rules.purchasing( .tyres, for : carID, from : save )
        }

        for _ in 0 ..< 2 {
            save = try rules.purchasing( .drivetrain, for : carID, from : save )
        }

        save = try rules.settingCompound( .semiSlick, for : carID, in : save )
        save = try rules.settingDrivetrain( .rwd, for : carID, in : save )
        save = try rules.downgrading( .tyres, for : carID, from : save )
        save = try rules.downgrading( .drivetrain, for : carID, from : save )

        let car = save.ownedCar( carID )!
        #expect( car.tyreCompound == .drag )
        #expect( car.drivetrain == car.definition.drivetrain )
    }

    @Test func tuningChangesTheSpec() throws {
        var save = TestSupport.saveWithStarter()
        let carID = save.garage[ 0 ].id
        let base = CarBuild( owned : save.garage[ 0 ] ).spec
        var setup = TuningSetup()
        setup.finalDrive = 1.15
        setup.brakeBias = 0.55
        save = try rules.tuning( setup, for : carID, in : save )
        let tuned = CarBuild( owned : save.ownedCar( carID )! ).spec
        #expect( abs( tuned.finalDrive - base.finalDrive * 1.15 ) < 1e-9 )
        #expect( tuned.brakeBias == 0.55 )
        #expect( save.ownedCar( carID )!.tuning.gearScales.count == base.gearCount )
    }

    @Test func tuningValuesAreClampedToAllowedRanges() {
        var owned = OwnedCar( carID : "hayase-kite-s" )
        owned.tuning.finalDrive = 5
        owned.tuning.differentialLock = 1
        owned.tuning.suspensionBalance = 1
        let build = CarBuild( owned : owned )
        let spec = build.spec
        #expect( spec.finalDrive <= owned.definition.baseSpec.finalDrive * TuningSetup.finalDriveRange.upperBound + 1e-9 )
        #expect( spec.differentialLock <= build.maximumDifferentialLock )
        // Balance needs a suspension upgrade.
        #expect( spec.suspensionBalance == 0 )
    }

    @Test func driftPresetMakesTheCarMoreDriftable() {
        var grip = OwnedCar( carID : "hayase-kite-s" )
        grip.upgrades[ .suspension ] = 1
        grip.upgrades[ .differential ] = 2
        var drift = grip
        grip.tuning = TuningSetup().applying( .grip )
        drift.tuning = TuningSetup().applying( .drift )
        let gripProfile = PerformanceProfile.measure( CarBuild( owned : grip ).spec )
        let driftProfile = PerformanceProfile.measure( CarBuild( owned : drift ).spec )
        #expect( driftProfile.driftPotential > gripProfile.driftPotential )
    }

    @Test func customisationChargesOnlyForChanges() throws {
        var save = TestSupport.saveWithStarter()
        save.profile.credits = 10_000
        save.profile.level = 20
        let car = save.garage[ 0 ]
        var appearance = car.appearance
        #expect( rules.customisationCost( from : car.appearance, to : appearance ) == 0 )

        appearance.paintHex = 0x123456
        appearance.livery = .chevron
        let cost = rules.customisationCost( from : car.appearance, to : appearance )
        #expect( cost == CarAppearance.paintPrice + Livery.chevron.price )

        save = try rules.customising( appearance, for : car.id, in : save )
        #expect( save.profile.credits == 10_000 - cost )
        #expect( save.ownedCar( car.id )!.appearance.paintHex == 0x123456 )
    }

    @Test func liveriesAreLevelLocked() {
        var save = TestSupport.saveWithStarter()
        save.profile.credits = 10_000
        let car = save.garage[ 0 ]
        var appearance = car.appearance
        appearance.livery = .shiftlineWorks

        #expect( throws : GarageError.levelTooLow( required : Livery.shiftlineWorks.requiredLevel ) ) {
            try rules.customising( appearance, for : car.id, in : save )
        }
    }
}

struct ColourNameTests {
    @Test func paletteColoursHaveSpokenNames() {
        #expect( ColourName.describe( 0xF5F5F5 ) == "White" )
        #expect( ColourName.describe( 0x1B1B1D ) == "Black" )
        #expect( ColourName.describe( 0xC0392B ) == "Red" )
        #expect( ColourName.describe( 0x145A32 ) == "Dark green" )
        #expect( ColourName.describe( 0x2874A6 ) == "Blue" )
        #expect( ColourName.describe( 0x8E44AD ) == "Purple" )
        #expect( Set( CarAppearance.palette.map( ColourName.describe ) ).count >= 10 )
    }
}
