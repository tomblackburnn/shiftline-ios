import Foundation

nonisolated enum GarageError : Error, Equatable {
    case carNotFound
    case carNotOwned
    case alreadyOwned
    case insufficientCredits
    case levelTooLow( required : Int )
    case maximumLevelReached
    case notAvailable
    case lastCar
}

/// Buying, selling, upgrading, tuning and customising. Pure: takes a save, returns an updated save.
nonisolated struct GarageRules {
    static let startingCredits = 6_000
    static let resaleFraction = 0.55

    func choosingStarter( _ carID : CarID, in save : SaveData ) throws -> SaveData {
        guard Cars.starterIDs.contains( carID ) else {
            throw GarageError.notAvailable
        }

        guard !save.profile.hasChosenStarter else {
            throw GarageError.alreadyOwned
        }

        var updatedSave = save
        let car = OwnedCar( carID : carID )
        updatedSave.garage.append( car )
        updatedSave.selectedCarID = car.id
        updatedSave.profile.hasChosenStarter = true
        updatedSave.profile.credits += GarageRules.startingCredits
        updatedSave.statistics.recordMaximum( 1, for : .carsOwnedPeak )
        return updatedSave
    }

    func canBuy( _ car : CarDefinition, in save : SaveData ) -> Bool {
        save.profile.level >= car.unlockLevel && save.profile.credits >= car.price && !save.owns( car.id )
    }

    func purchasing( _ carID : CarID, from save : SaveData ) throws -> SaveData {
        guard let car = Cars.named( carID ) else {
            throw GarageError.carNotFound
        }

        guard !save.owns( carID ) else {
            throw GarageError.alreadyOwned
        }

        guard save.profile.level >= car.unlockLevel else {
            throw GarageError.levelTooLow( required : car.unlockLevel )
        }

        guard save.profile.credits >= car.price else {
            throw GarageError.insufficientCredits
        }

        var updatedSave = save
        let owned = OwnedCar( carID : carID )
        updatedSave.profile.credits -= car.price
        updatedSave.garage.append( owned )
        updatedSave.selectedCarID = owned.id
        updatedSave.statistics.add( Double( car.price ), to : .creditsSpent )
        updatedSave.statistics.recordMaximum( Double( updatedSave.garage.count ), for : .carsOwnedPeak )
        return updatedSave
    }

    func resaleValue( of owned : OwnedCar ) -> Int {
        let upgradesValue = UpgradeCategory.allCases.reduce( 0 ) { total, category in
            total + ( 0 ... owned.level( of : category ) ).reduce( 0 ) {
                $0 + UpgradeRules.cost( of : category, level : $1, carPrice : owned.definition.price )
            }
        }

        return Int( Double( owned.definition.price + upgradesValue ) * GarageRules.resaleFraction / 50 ) * 50
    }

    func selling( _ ownedID : UUID, from save : SaveData ) throws -> SaveData {
        guard let owned = save.ownedCar( ownedID ) else {
            throw GarageError.carNotOwned
        }

        guard save.garage.count > 1 else {
            throw GarageError.lastCar
        }

        var updatedSave = save
        updatedSave.profile.credits += resaleValue( of : owned )
        updatedSave.garage.removeAll { $0.id == ownedID }

        if updatedSave.selectedCarID == ownedID {
            updatedSave.selectedCarID = updatedSave.garage.first?.id
        }

        return updatedSave
    }

    func selecting( _ ownedID : UUID, in save : SaveData ) throws -> SaveData {
        guard save.ownedCar( ownedID ) != nil else {
            throw GarageError.carNotOwned
        }

        var updatedSave = save
        updatedSave.selectedCarID = ownedID
        return updatedSave
    }

    // MARK: - Upgrades

    func upgradeCost( for category : UpgradeCategory, on owned : OwnedCar ) -> Int? {
        let nextLevel = owned.level( of : category ) + 1

        guard nextLevel <= UpgradeRules.maximumLevel else {
            return nil
        }

        return UpgradeRules.cost( of : category, level : nextLevel, carPrice : owned.definition.price )
    }

    func purchasing(
        _ category : UpgradeCategory,
        for ownedID : UUID,
        from save : SaveData
    ) throws -> SaveData {
        guard var owned = save.ownedCar( ownedID ) else {
            throw GarageError.carNotOwned
        }

        let currentLevel = owned.level( of : category )

        guard currentLevel < UpgradeRules.maximumLevel else {
            throw GarageError.maximumLevelReached
        }

        let requiredLevel = UpgradeRules.requiredDriverLevel[ currentLevel + 1 ]

        guard save.profile.level >= requiredLevel else {
            throw GarageError.levelTooLow( required : requiredLevel )
        }

        let cost = UpgradeRules.cost( of : category, level : currentLevel + 1, carPrice : owned.definition.price )

        guard save.profile.credits >= cost else {
            throw GarageError.insufficientCredits
        }

        var updatedSave = save
        updatedSave.profile.credits -= cost
        owned.upgrades[ category ] = currentLevel + 1

        if category == .forcedInduction && owned.inductionKit == .stock, case .natural = owned.definition.aspiration {
            owned.inductionKit = .turbo
        }

        updatedSave.updateCar( owned )
        updatedSave.statistics.increment( .upgradesPurchased )
        updatedSave.statistics.add( Double( cost ), to : .creditsSpent )
        return updatedSave
    }

    /// Credits returned for removing the current level: the same share a sale would pay for it.
    func downgradeRefund( for category : UpgradeCategory, on owned : OwnedCar ) -> Int? {
        let currentLevel = owned.level( of : category )

        guard currentLevel > 0 else {
            return nil
        }

        let cost = UpgradeRules.cost( of : category, level : currentLevel, carPrice : owned.definition.price )
        return Int( Double( cost ) * GarageRules.resaleFraction / 50 ) * 50
    }

    /// Removes one level and refunds part of its price. Parts the lower level no longer supports are reverted.
    func downgrading(
        _ category : UpgradeCategory,
        for ownedID : UUID,
        from save : SaveData
    ) throws -> SaveData {
        guard var owned = save.ownedCar( ownedID ) else {
            throw GarageError.carNotOwned
        }

        guard let refund = downgradeRefund( for : category, on : owned ) else {
            throw GarageError.notAvailable
        }

        let newLevel = owned.level( of : category ) - 1
        owned.upgrades[ category ] = newLevel == 0 ? nil : newLevel

        switch category {
        case .tyres:
            let unlocked = UpgradeRules.unlockedCompounds( tyreLevel : newLevel )

            if !unlocked.contains( owned.tyreCompound ) {
                owned.tyreCompound = unlocked.last ?? .street
            }
        case .forcedInduction where newLevel == 0:
            owned.inductionKit = .stock
        case .drivetrain:
            if !UpgradeRules.availableDrivetrains( for : owned.definition, drivetrainLevel : newLevel ).contains( owned.drivetrain ) {
                owned.drivetrainOverride = nil
            }
        default:
            break
        }

        var updatedSave = save
        updatedSave.profile.credits += refund
        updatedSave.updateCar( owned )
        return updatedSave
    }

    func settingCompound( _ compound : TyreCompound, for ownedID : UUID, in save : SaveData ) throws -> SaveData {
        guard var owned = save.ownedCar( ownedID ) else {
            throw GarageError.carNotOwned
        }

        guard UpgradeRules.unlockedCompounds( tyreLevel : owned.level( of : .tyres ) ).contains( compound ) else {
            throw GarageError.notAvailable
        }

        var updatedSave = save
        owned.tyreCompound = compound
        updatedSave.updateCar( owned )
        return updatedSave
    }

    /// Switches a naturally aspirated car between a turbo and supercharger kit (free once fitted).
    func settingInduction( _ kit : InductionKit, for ownedID : UUID, in save : SaveData ) throws -> SaveData {
        guard var owned = save.ownedCar( ownedID ) else {
            throw GarageError.carNotOwned
        }

        guard case .natural = owned.definition.aspiration, owned.level( of : .forcedInduction ) > 0, kit != .stock else {
            throw GarageError.notAvailable
        }

        var updatedSave = save
        owned.inductionKit = kit
        updatedSave.updateCar( owned )
        return updatedSave
    }

    func settingDrivetrain( _ drivetrain : Drivetrain, for ownedID : UUID, in save : SaveData ) throws -> SaveData {
        guard var owned = save.ownedCar( ownedID ) else {
            throw GarageError.carNotOwned
        }

        let available = UpgradeRules.availableDrivetrains( for : owned.definition, drivetrainLevel : owned.level( of : .drivetrain ) )

        guard available.contains( drivetrain ) else {
            throw GarageError.notAvailable
        }

        guard drivetrain != owned.drivetrain else {
            return save
        }

        let isConversion = drivetrain != owned.definition.drivetrain
        let cost = isConversion ? UpgradeRules.conversionCost : 0

        guard save.profile.credits >= cost else {
            throw GarageError.insufficientCredits
        }

        var updatedSave = save
        updatedSave.profile.credits -= cost
        updatedSave.statistics.add( Double( cost ), to : .creditsSpent )
        owned.drivetrainOverride = isConversion ? drivetrain : nil
        updatedSave.updateCar( owned )
        return updatedSave
    }

    // MARK: - Tuning

    func tuning( _ setup : TuningSetup, for ownedID : UUID, in save : SaveData ) throws -> SaveData {
        guard var owned = save.ownedCar( ownedID ) else {
            throw GarageError.carNotOwned
        }

        var updatedSave = save
        owned.tuning = setup

        if owned.tuning.gearScales.count != owned.definition.gears {
            owned.tuning.gearScales = Array( repeating : 1, count : owned.definition.gears )
        }

        updatedSave.updateCar( owned )
        updatedSave.statistics.increment( .tuningsSaved )
        return updatedSave
    }

    // MARK: - Customisation

    /// Price of changing from the current look to `appearance`.
    func customisationCost( from current : CarAppearance, to appearance : CarAppearance ) -> Int {
        var cost = 0

        if current.paintHex != appearance.paintHex || current.accentHex != appearance.accentHex || current.finish != appearance.finish {
            cost += CarAppearance.paintPrice
        }

        if current.livery != appearance.livery {
            cost += appearance.livery.price
        }

        if current.wheelStyle != appearance.wheelStyle || current.wheelHex != appearance.wheelHex {
            cost += CarAppearance.wheelPrice
        }

        if current.windowTint != appearance.windowTint {
            cost += CarAppearance.tintPrice
        }

        return cost
    }

    func customising( _ appearance : CarAppearance, for ownedID : UUID, in save : SaveData ) throws -> SaveData {
        guard var owned = save.ownedCar( ownedID ) else {
            throw GarageError.carNotOwned
        }

        let cost = customisationCost( from : owned.appearance, to : appearance )

        guard save.profile.level >= appearance.livery.requiredLevel else {
            throw GarageError.levelTooLow( required : appearance.livery.requiredLevel )
        }

        guard save.profile.credits >= cost else {
            throw GarageError.insufficientCredits
        }

        var updatedSave = save
        updatedSave.profile.credits -= cost
        updatedSave.statistics.add( Double( cost ), to : .creditsSpent )

        if owned.appearance.livery != appearance.livery && appearance.livery != .none {
            updatedSave.statistics.increment( .liveriesApplied )
        }

        owned.appearance = appearance
        updatedSave.updateCar( owned )
        return updatedSave
    }

    func togglingFavourite( _ ownedID : UUID, in save : SaveData ) -> SaveData {
        guard var owned = save.ownedCar( ownedID ) else {
            return save
        }

        var updatedSave = save
        owned.isFavourite.toggle()
        updatedSave.updateCar( owned )
        return updatedSave
    }
}
