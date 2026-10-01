import Foundation

nonisolated enum InductionKit : String, Codable, CaseIterable {
    case stock
    case turbo
    case supercharger

    var title : String {
        switch self {
        case .stock:
            return "Stock"
        case .turbo:
            return "Turbo Kit"
        case .supercharger:
            return "Supercharger Kit"
        }
    }
}

/// A car in the player's garage: the definition plus everything the player has changed.
nonisolated struct OwnedCar : Codable, Identifiable, Equatable {
    var id : UUID = UUID()
    var carID : CarID
    var upgrades : [UpgradeCategory : Int] = [:]
    var tyreCompound : TyreCompound = .street
    var inductionKit : InductionKit = .stock
    var drivetrainOverride : Drivetrain?
    var tuning : TuningSetup = TuningSetup()
    var appearance : CarAppearance
    var isFavourite = false
    var odometer : Double = 0
    var racesEntered = 0
    var wins = 0

    init( carID : CarID ) {
        self.carID = carID
        appearance = CarAppearance( paintHex : Cars.named( carID )?.defaultPaintHex ?? 0xE8453C )
    }

    var definition : CarDefinition {
        Cars.named( carID ) ?? Cars.all[ 0 ]
    }

    func level( of category : UpgradeCategory ) -> Int {
        upgrades[ category ] ?? 0
    }

    var drivetrain : Drivetrain {
        drivetrainOverride ?? definition.drivetrain
    }

    var upgradeCount : Int {
        upgrades.values.reduce( 0, + )
    }

    enum CodingKeys : String, CodingKey {
        case id
        case carID
        case upgrades
        case tyreCompound
        case inductionKit
        case drivetrainOverride
        case tuning
        case appearance
        case isFavourite
        case odometer
        case racesEntered
        case wins
    }

    init( from decoder : Decoder ) throws {
        let container = try decoder.container( keyedBy : CodingKeys.self )
        id = try container.decodeIfPresent( UUID.self, forKey : .id ) ?? UUID()
        carID = try container.decode( CarID.self, forKey : .carID )
        upgrades = try container.decodeIfPresent( [UpgradeCategory : Int].self, forKey : .upgrades ) ?? [:]
        tyreCompound = try container.decodeIfPresent( TyreCompound.self, forKey : .tyreCompound ) ?? .street
        inductionKit = try container.decodeIfPresent( InductionKit.self, forKey : .inductionKit ) ?? .stock
        drivetrainOverride = try container.decodeIfPresent( Drivetrain.self, forKey : .drivetrainOverride )
        tuning = try container.decodeIfPresent( TuningSetup.self, forKey : .tuning ) ?? TuningSetup()
        appearance = try container.decodeIfPresent( CarAppearance.self, forKey : .appearance )
            ?? CarAppearance( paintHex : Cars.named( carID )?.defaultPaintHex ?? 0xE8453C )
        isFavourite = try container.decodeIfPresent( Bool.self, forKey : .isFavourite ) ?? false
        odometer = try container.decodeIfPresent( Double.self, forKey : .odometer ) ?? 0
        racesEntered = try container.decodeIfPresent( Int.self, forKey : .racesEntered ) ?? 0
        wins = try container.decodeIfPresent( Int.self, forKey : .wins ) ?? 0
    }
}
