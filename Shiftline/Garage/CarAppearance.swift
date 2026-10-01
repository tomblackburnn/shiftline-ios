import Foundation

nonisolated enum PaintFinish : String, Codable, CaseIterable, Identifiable {
    case gloss
    case metallic
    case matte
    case pearl

    var id : String {
        rawValue
    }

    var title : String {
        rawValue.capitalized
    }
}

nonisolated enum Livery : String, Codable, CaseIterable, Identifiable {
    case none
    case racingStripes
    case sideStripe
    case twoTone
    case chevron
    case checkerHood
    case splitFade
    case endurance
    case shiftlineWorks

    var id : String {
        rawValue
    }

    var title : String {
        switch self {
        case .none:
            return "Plain"
        case .racingStripes:
            return "Twin Stripes"
        case .sideStripe:
            return "Side Stripe"
        case .twoTone:
            return "Two-Tone"
        case .chevron:
            return "Chevron"
        case .checkerHood:
            return "Checker Hood"
        case .splitFade:
            return "Split Fade"
        case .endurance:
            return "Endurance"
        case .shiftlineWorks:
            return "Shiftline Works"
        }
    }

    var price : Int {
        self == .none ? 0 : 1_500
    }

    /// Driver level that unlocks each livery.
    var requiredLevel : Int {
        switch self {
        case .none, .racingStripes:
            return 1
        case .sideStripe:
            return 2
        case .twoTone:
            return 3
        case .chevron:
            return 5
        case .checkerHood:
            return 7
        case .splitFade:
            return 9
        case .endurance:
            return 12
        case .shiftlineWorks:
            return 15
        }
    }
}

nonisolated struct CarAppearance : Codable, Equatable {
    var paintHex : UInt32
    var accentHex : UInt32 = 0xFFFFFF
    var finish : PaintFinish = .gloss
    var livery : Livery = .none
    var wheelStyle : Int = 0
    var wheelHex : UInt32 = 0x2B2B2B
    var windowTint : Int = 1
    var raceNumber : Int = 7
    var plate : String = "SHIFT"

    static let wheelStyleNames = [ "Five Spoke", "Mesh", "Turbofan", "Deep Dish", "Split Six", "Monoblock" ]
    static let tintNames = [ "Clear", "Light", "Dark", "Limo" ]

    static let palette : [UInt32] = [
        0xF5F5F5, 0x1B1B1D, 0x7F8C8D, 0xC0392B, 0xE8453C, 0xF39C12, 0xF4D03F, 0x27AE60,
        0x145A32, 0x16A085, 0x5DADE2, 0x2874A6, 0x1F3A93, 0x8E44AD, 0xE91E63, 0xD4AC0D
    ]

    static let paintPrice = 600
    static let wheelPrice = 900
    static let tintPrice = 250
}
