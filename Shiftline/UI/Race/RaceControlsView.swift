import SwiftUI

/// A press-and-hold touch area. Works simultaneously with other controls (multi-touch).
/// VoiceOver can't hold a touch, so its activate action latches the control on and off instead.
struct HoldButton<Label : View> : View {
    let name : String
    let onChange : ( Bool ) -> Void
    @ViewBuilder var label : ( Bool ) -> Label
    @State private var isPressed = false

    var body : some View {
        label( isPressed )
            .contentShape( Rectangle() )
            .gesture(
                DragGesture( minimumDistance : 0 )
                    .onChanged { _ in
                        if !isPressed {
                            isPressed = true
                            onChange( true )
                        }
                    }
                    .onEnded { _ in
                        isPressed = false
                        onChange( false )
                    }
            )
            .accessibilityElement( children : .ignore )
            .accessibilityLabel( name )
            .accessibilityValue( isPressed ? "Held" : "Released" )
            .accessibilityHint( "Double-tap to hold, double-tap again to release." )
            .accessibilityAddTraits( .isButton )
            .accessibilityAction {
                isPressed.toggle()
                onChange( isPressed )
            }
    }
}

struct PedalLabel : View {
    let title : String
    let symbol : String
    let colour : Color
    let isPressed : Bool
    var width : CGFloat = 96
    var height : CGFloat = 120

    var body : some View {
        VStack( spacing : 4 ) {
            Image( systemName : symbol )
                .font( .system( size : 26, weight : .black ) )
                .accessibilityHidden( true )
            Text( title )
                .font( .display( 14 ) )
        }
        .foregroundStyle( isPressed ? Color.black : Color.white )
        .frame( width : width, height : height )
        .background(
            RoundedRectangle( cornerRadius : 16, style : .continuous )
                .fill( isPressed ? colour : Color.black.opacity( 0.35 ) )
        )
        .overlay( RoundedRectangle( cornerRadius : 16, style : .continuous ).stroke( colour.opacity( 0.8 ), lineWidth : 2 ) )
        .scaleEffect( isPressed ? 0.96 : 1 )
    }
}

struct RaceControlsView : View {
    let model : RaceViewModel
    let settings : GameSettings
    @State private var wheelAngle = 0.0

    var body : some View {
        let isManual = !model.session.player.assists.automaticTransmission
        let hasNitrous = model.session.player.model.spec.nitrousCapacity > 0

        HStack( alignment : .bottom ) {
            steeringControls
            Spacer()

            HStack( alignment : .bottom, spacing : 10 ) {
                VStack( spacing : 10 ) {
                    if hasNitrous {
                        HoldButton( name : "Nitrous", onChange : { model.nitrousHeld = $0 } ) { pressed in
                            PedalLabel( title : "N2O", symbol : "bolt.fill", colour : Theme.cool, isPressed : pressed, width : 70, height : 54 )
                        }
                    }

                    HoldButton( name : "Handbrake", onChange : { model.handbrakeHeld = $0 } ) { pressed in
                        PedalLabel( title : "E-BRAKE", symbol : "parkingsign", colour : Theme.orange, isPressed : pressed, width : 70, height : 54 )
                    }

                    HoldButton( name : "Brake", onChange : { model.brakeHeld = $0 } ) { pressed in
                        PedalLabel( title : "BRAKE", symbol : "chevron.down.2", colour : Theme.hot, isPressed : pressed, width : 86, height : 96 )
                    }
                }

                VStack( spacing : 10 ) {
                    if isManual {
                        Button {
                            model.shiftUp()
                        } label : {
                            PedalLabel( title : "UP", symbol : "arrowtriangle.up.fill", colour : Theme.success, isPressed : false, width : 86, height : 54 )
                        }
                        .buttonStyle( .plain )
                        .accessibilityLabel( "Shift up" )

                        Button {
                            model.shiftDown()
                        } label : {
                            PedalLabel( title : "DOWN", symbol : "arrowtriangle.down.fill", colour : Theme.secondaryText, isPressed : false, width : 86, height : 44 )
                        }
                        .buttonStyle( .plain )
                        .accessibilityLabel( "Shift down" )
                    }

                    HoldButton( name : "Gas", onChange : { model.throttleHeld = $0 } ) { pressed in
                        PedalLabel( title : "GAS", symbol : "chevron.up.2", colour : Theme.success, isPressed : pressed, width : 96, height : isManual ? 110 : 150 )
                    }
                }
            }
        }
        .environment( \.layoutDirection, settings.leftHandedControls ? .rightToLeft : .leftToRight )
        .padding( .horizontal, 18 )
        .padding( .bottom, 12 )
    }

    @ViewBuilder
    private var steeringControls : some View {
        switch settings.steeringMode {
        case .buttons:
            HStack( spacing : 12 ) {
                HoldButton( name : "Steer left", onChange : { pressed in model.steerInput = pressed ? 1 : ( model.steerInput == 1 ? 0 : model.steerInput ) } ) { pressed in
                    PedalLabel( title : "LEFT", symbol : "arrowtriangle.left.fill", colour : Theme.accent, isPressed : pressed, width : 104, height : 104 )
                }

                HoldButton( name : "Steer right", onChange : { pressed in model.steerInput = pressed ? -1 : ( model.steerInput == -1 ? 0 : model.steerInput ) } ) { pressed in
                    PedalLabel( title : "RIGHT", symbol : "arrowtriangle.right.fill", colour : Theme.accent, isPressed : pressed, width : 104, height : 104 )
                }
            }
            .environment( \.layoutDirection, .leftToRight )
        case .wheel:
            SteeringWheelControl( angle : $wheelAngle ) { value in
                model.steerInput = value
            }
            .frame( width : 170, height : 170 )
        case .swipe:
            SwipeSteeringPad { value in
                model.steerInput = value
            }
            .frame( width : 260, height : 170 )
        case .tilt:
            VStack( spacing : 6 ) {
                Image( systemName : "iphone.landscape" )
                    .font( .system( size : 30 ) )
                Text( "TILT TO STEER" )
                    .font( .label( 12, weight : .heavy ) )
            }
            .foregroundStyle( .white.opacity( 0.6 ) )
            .padding()
            .background( Color.black.opacity( 0.3 ), in : RoundedRectangle( cornerRadius : 14 ) )
        }
    }
}

/// Drag horizontally to turn a virtual wheel; springs back when released.
struct SteeringWheelControl : View {
    @Binding var angle : Double
    let onSteer : ( Double ) -> Void

    var body : some View {
        ZStack {
            Circle()
                .stroke( Color.white.opacity( 0.8 ), lineWidth : 14 )
            Circle()
                .fill( Color.black.opacity( 0.3 ) )
            Rectangle()
                .fill( Color.white.opacity( 0.8 ) )
                .frame( width : 120, height : 10 )
            Rectangle()
                .fill( Theme.accent )
                .frame( width : 8, height : 22 )
                .offset( y : -74 )
        }
        .rotationEffect( .degrees( angle * 120 ) )
        .contentShape( Circle() )
        .gesture(
            DragGesture( minimumDistance : 0 )
                .onChanged { value in
                    angle = clamp( Double( value.translation.width ) / 80, -1, 1 )
                    onSteer( -angle )
                }
                .onEnded { _ in
                    withAnimation( .spring( response : 0.25 ) ) {
                        angle = 0
                    }

                    onSteer( 0 )
                }
        )
        .accessibilityLabel( "Steering wheel" )
    }
}

/// Touch anywhere on the pad and slide left or right: a floating virtual stick.
struct SwipeSteeringPad : View {
    let onSteer : ( Double ) -> Void
    @State private var origin : CGPoint?
    @State private var current : CGPoint?

    var body : some View {
        ZStack {
            RoundedRectangle( cornerRadius : 18 )
                .fill( Color.white.opacity( 0.05 ) )
                .overlay( RoundedRectangle( cornerRadius : 18 ).stroke( Color.white.opacity( 0.15 ), style : StrokeStyle( lineWidth : 1, dash : [ 6 ] ) ) )

            if let origin, let current {
                Circle()
                    .stroke( Color.white.opacity( 0.4 ), lineWidth : 2 )
                    .frame( width : 120, height : 120 )
                    .position( origin )
                Circle()
                    .fill( Theme.accent )
                    .frame( width : 44, height : 44 )
                    .position( x : origin.x + clamp( current.x - origin.x, -60, 60 ), y : origin.y )
            } else {
                Text( "SWIPE TO STEER" )
                    .font( .label( 12, weight : .heavy ) )
                    .foregroundStyle( .white.opacity( 0.5 ) )
            }
        }
        .contentShape( Rectangle() )
        .gesture(
            DragGesture( minimumDistance : 0 )
                .onChanged { value in
                    if origin == nil {
                        origin = value.startLocation
                    }

                    current = value.location
                    onSteer( -clamp( Double( value.location.x - value.startLocation.x ) / 60, -1, 1 ) )
                }
                .onEnded { _ in
                    origin = nil
                    current = nil
                    onSteer( 0 )
                }
        )
    }
}
