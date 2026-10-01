import SwiftUI

extension Color {
    init( hex : UInt32, opacity : Double = 1 ) {
        self.init(
            .sRGB,
            red : Double( ( hex >> 16 ) & 0xFF ) / 255,
            green : Double( ( hex >> 8 ) & 0xFF ) / 255,
            blue : Double( hex & 0xFF ) / 255,
            opacity : opacity
        )
    }
}

enum Theme {
    static let background = Color( hex : 0x0A0C11 )
    static let panel = Color( hex : 0x141922 )
    static let panelRaised = Color( hex : 0x1C2330 )
    static let stroke = Color( hex : 0x2A3342 )
    static let accent = Color( hex : 0xFFB324 )
    static let hot = Color( hex : 0xED2E47 )
    static let orange = Color( hex : 0xFF6B29 )
    static let cool = Color( hex : 0x2EC4FF )
    static let success = Color( hex : 0x3DDC84 )
    static let secondaryText = Color( hex : 0x8A94A6 )
    static let gold = Color( hex : 0xF5C542 )
    static let silver = Color( hex : 0xC7CED9 )
    static let bronze = Color( hex : 0xCD8B4E )

    static let stripe = LinearGradient(
        colors : [ accent, orange, hot ],
        startPoint : .leading,
        endPoint : .trailing
    )

    static func medalColour( _ placement : Int ) -> Color {
        switch placement {
        case 1:
            return gold
        case 2:
            return silver
        case 3:
            return bronze
        default:
            return secondaryText
        }
    }

    static func classColour( _ performanceClass : PerformanceClass ) -> Color {
        Color( hex : performanceClass.colourHex )
    }
}

extension Font {
    /// Condensed heavy italic: the Shiftline display face.
    static func display( _ size : CGFloat ) -> Font {
        .system( size : size, weight : .black ).width( .condensed ).italic()
    }

    static func label( _ size : CGFloat, weight : Font.Weight = .semibold ) -> Font {
        .system( size : size, weight : weight ).width( .condensed )
    }

    static func numeric( _ size : CGFloat ) -> Font {
        .system( size : size, weight : .bold, design : .monospaced )
    }
}

/// Parallelogram used for buttons, tags and headers.
struct SlantedShape : Shape {
    var slant : CGFloat = 10

    func path( in rect : CGRect ) -> Path {
        var path = Path()
        path.move( to : CGPoint( x : rect.minX + slant, y : rect.minY ) )
        path.addLine( to : CGPoint( x : rect.maxX, y : rect.minY ) )
        path.addLine( to : CGPoint( x : rect.maxX - slant, y : rect.maxY ) )
        path.addLine( to : CGPoint( x : rect.minX, y : rect.maxY ) )
        path.closeSubpath()
        return path
    }
}

struct ShiftButtonStyle : ButtonStyle {
    enum Kind {
        case primary
        case secondary
        case destructive
    }

    var kind : Kind = .primary
    var isCompact = false

    func makeBody( configuration : Configuration ) -> some View {
        configuration.label
            .font( .display( isCompact ? 15 : 20 ) )
            .lineLimit( 1 )
            .fixedSize( horizontal : true, vertical : false )
            .foregroundStyle( kind == .primary ? Color.black : Color.white )
            .padding( .horizontal, isCompact ? 16 : 26 )
            .padding( .vertical, isCompact ? 8 : 12 )
            .background {
                switch kind {
                case .primary:
                    SlantedShape().fill( Theme.stripe )
                case .secondary:
                    SlantedShape().fill( Theme.panelRaised ).overlay( SlantedShape().stroke( Theme.stroke, lineWidth : 1 ) )
                case .destructive:
                    SlantedShape().fill( Theme.hot.opacity( 0.85 ) )
                }
            }
            .scaleEffect( configuration.isPressed ? 0.95 : 1 )
            .opacity( configuration.isPressed ? 0.85 : 1 )
            .animation( .spring( response : 0.2, dampingFraction : 0.7 ), value : configuration.isPressed )
    }
}

extension ButtonStyle where Self == ShiftButtonStyle {
    static var shift : ShiftButtonStyle {
        ShiftButtonStyle()
    }

    static func shift( _ kind : ShiftButtonStyle.Kind, compact : Bool = false ) -> ShiftButtonStyle {
        ShiftButtonStyle( kind : kind, isCompact : compact )
    }
}

struct PanelModifier : ViewModifier {
    var padding : CGFloat = 14
    var highlighted = false

    func body( content : Content ) -> some View {
        content
            .padding( padding )
            .background( highlighted ? Theme.panelRaised : Theme.panel, in : RoundedRectangle( cornerRadius : 14, style : .continuous ) )
            .overlay( RoundedRectangle( cornerRadius : 14, style : .continuous ).stroke( highlighted ? Theme.accent.opacity( 0.7 ) : Theme.stroke, lineWidth : 1 ) )
    }
}

extension View {
    func panel( padding : CGFloat = 14, highlighted : Bool = false ) -> some View {
        modifier( PanelModifier( padding : padding, highlighted : highlighted ) )
    }

    /// Full-screen game background with a subtle speed-stripe motif.
    func gameBackground() -> some View {
        background {
            ZStack {
                Theme.background

                GeometryReader { proxy in
                    ForEach( 0 ..< 3, id : \.self ) { index in
                        SlantedShape( slant : 120 )
                            .fill( [ Theme.accent, Theme.orange, Theme.hot ][ index ].opacity( 0.06 ) )
                            .frame( width : 70, height : proxy.size.height * 1.4 )
                            .offset( x : proxy.size.width * 0.72 + CGFloat( index ) * 90, y : -proxy.size.height * 0.2 )
                    }
                }
            }
            .ignoresSafeArea()
        }
    }
}
