import SwiftUI

struct CustomiseView : View {
    let ownedID : UUID
    @Environment( GameStore.self ) private var store
    @State private var appearance = CarAppearance( paintHex : 0 )
    @State private var hasLoaded = false
    @State private var editsAccent = false
    private let rules = GarageRules()

    var body : some View {
        if let car = store.save.ownedCar( ownedID ) {
            content( car )
                .onAppear {
                    guard !hasLoaded else {
                        return
                    }

                    hasLoaded = true
                    appearance = car.appearance
                }
        }
    }

    private func content( _ car : OwnedCar ) -> some View {
        let cost = rules.customisationCost( from : car.appearance, to : appearance )
        let isLiveryLocked = store.save.profile.level < appearance.livery.requiredLevel

        return VStack( alignment : .leading, spacing : 10 ) {
            ScreenHeader( title : "Customise", subtitle : car.definition.fullName ) {
                HStack( spacing : 10 ) {
                    if cost > 0 {
                        CreditsLabel( amount : cost )
                    }

                    Button( "REVERT" ) {
                        appearance = car.appearance
                    }
                    .buttonStyle( .shift( .secondary, compact : true ) )

                    Button( "APPLY" ) {
                        store.customise( appearance, for : car.id )
                        GameAudio.shared.play( .reward )
                    }
                    .buttonStyle( .shift( .primary, compact : true ) )
                    .disabled( cost > store.save.profile.credits || isLiveryLocked || appearance == car.appearance )
                    .accessibilityIdentifier( "applyPaintButton" )
                }
            }

            HStack( alignment : .top, spacing : 14 ) {
                VStack( spacing : 10 ) {
                    CarSideView( definition : car.definition, appearance : appearance )
                        .frame( height : 120 )

                    CarTopView( definition : car.definition, appearance : appearance )
                        .frame( height : 150 )
                }
                .frame( maxWidth : .infinity )
                .panel()

                ScrollView {
                    VStack( alignment : .leading, spacing : 12 ) {
                        paintSection
                        liverySection
                        wheelSection
                        detailSection
                    }
                }
                .frame( width : 380 )
            }
        }
        .padding( .horizontal, 22 )
        .padding( .vertical, 12 )
        .gameBackground()
    }

    private var paintSection : some View {
        VStack( alignment : .leading, spacing : 8 ) {
            HStack {
                sectionTitle( "PAINT · \( CarAppearance.paintPrice.formatted( .number ) )" )
                Spacer()
                Picker( "Colour", selection : $editsAccent ) {
                    Text( "Body" ).tag( false )
                    Text( "Accent" ).tag( true )
                }
                .pickerStyle( .segmented )
                .frame( width : 150 )
            }

            LazyVGrid( columns : Array( repeating : GridItem( .flexible(), spacing : 6 ), count : 8 ), spacing : 6 ) {
                ForEach( CarAppearance.palette, id : \.self ) { hex in
                    let isSelected = ( editsAccent ? appearance.accentHex : appearance.paintHex ) == hex

                    Button {
                        if editsAccent {
                            appearance.accentHex = hex
                        } else {
                            appearance.paintHex = hex
                        }
                    } label : {
                        Circle()
                            .fill( Color( hex : hex ) )
                            .frame( height : 30 )
                            .overlay( Circle().stroke( isSelected ? Theme.accent : Color.white.opacity( 0.2 ), lineWidth : isSelected ? 3 : 1 ) )
                    }
                    .buttonStyle( .plain )
                    .accessibilityLabel( ColourName.describe( hex ) )
                    .accessibilityAddTraits( isSelected ? .isSelected : [] )
                }
            }

            Picker( "Finish", selection : $appearance.finish ) {
                ForEach( PaintFinish.allCases ) { finish in
                    Text( finish.title ).tag( finish )
                }
            }
            .pickerStyle( .segmented )
        }
        .panel()
    }

    private var liverySection : some View {
        VStack( alignment : .leading, spacing : 8 ) {
            sectionTitle( "LIVERY · \( Livery.racingStripes.price.formatted( .number ) )" )

            LazyVGrid( columns : [ GridItem( .flexible() ), GridItem( .flexible() ), GridItem( .flexible() ) ], spacing : 6 ) {
                ForEach( Livery.allCases ) { livery in
                    let isLocked = store.save.profile.level < livery.requiredLevel

                    Button {
                        appearance.livery = livery
                    } label : {
                        HStack( spacing : 4 ) {
                            if isLocked {
                                Image( systemName : "lock.fill" )
                            }

                            Text( isLocked ? "LV \( livery.requiredLevel )" : livery.title )
                                .lineLimit( 1 )
                                .minimumScaleFactor( 0.7 )
                        }
                        .font( .label( 12, weight : .bold ) )
                        .foregroundStyle( appearance.livery == livery ? Color.black : ( isLocked ? Theme.secondaryText : .white ) )
                        .frame( maxWidth : .infinity )
                        .padding( .vertical, 7 )
                        .background( SlantedShape( slant : 5 ).fill( appearance.livery == livery ? Theme.accent : Theme.panelRaised ) )
                    }
                    .buttonStyle( .plain )
                    .disabled( isLocked )
                }
            }

            Stepper( value : $appearance.raceNumber, in : 1 ... 99 ) {
                Text( "RACE NUMBER  \( appearance.raceNumber )" )
                    .font( .label( 13, weight : .bold ) )
                    .foregroundStyle( .white )
            }
        }
        .panel()
    }

    private var wheelSection : some View {
        VStack( alignment : .leading, spacing : 8 ) {
            sectionTitle( "WHEELS · \( CarAppearance.wheelPrice.formatted( .number ) )" )

            ScrollView( .horizontal, showsIndicators : false ) {
                HStack( spacing : 8 ) {
                    ForEach( CarAppearance.wheelStyleNames.indices, id : \.self ) { style in
                        Button {
                            appearance.wheelStyle = style
                        } label : {
                            VStack( spacing : 3 ) {
                                Image( uiImage : CarArtist.wheel( style : style, hex : appearance.wheelHex, diameter : 96 ) )
                                    .resizable()
                                    .frame( width : 44, height : 44 )
                                Text( CarAppearance.wheelStyleNames[ style ] )
                                    .font( .label( 10, weight : .bold ) )
                                    .foregroundStyle( appearance.wheelStyle == style ? Theme.accent : .white )
                            }
                            .padding( 6 )
                            .background( RoundedRectangle( cornerRadius : 8 ).fill( appearance.wheelStyle == style ? Theme.panelRaised : Color.clear ) )
                        }
                        .buttonStyle( .plain )
                    }
                }
            }

            HStack( spacing : 6 ) {
                ForEach( [ UInt32( 0x2B2B2B ), 0xC0C0C0, 0xD4AC0D, 0xF5F5F5, 0xC0392B, 0x2874A6 ], id : \.self ) { hex in
                    Button {
                        appearance.wheelHex = hex
                    } label : {
                        Circle()
                            .fill( Color( hex : hex ) )
                            .frame( width : 26, height : 26 )
                            .overlay( Circle().stroke( appearance.wheelHex == hex ? Theme.accent : Color.white.opacity( 0.2 ), lineWidth : 2 ) )
                    }
                    .buttonStyle( .plain )
                    .accessibilityLabel( "\( ColourName.describe( hex ) ) wheels" )
                    .accessibilityAddTraits( appearance.wheelHex == hex ? .isSelected : [] )
                }
            }
        }
        .panel()
    }

    private var detailSection : some View {
        VStack( alignment : .leading, spacing : 8 ) {
            sectionTitle( "WINDOW TINT · \( CarAppearance.tintPrice.formatted( .number ) )" )

            Picker( "Tint", selection : $appearance.windowTint ) {
                ForEach( CarAppearance.tintNames.indices, id : \.self ) { index in
                    Text( CarAppearance.tintNames[ index ] ).tag( index )
                }
            }
            .pickerStyle( .segmented )

            sectionTitle( "NUMBER PLATE · FREE" )

            TextField( "Plate", text : Binding(
                get : { appearance.plate },
                set : { appearance.plate = String( $0.uppercased().filter { $0.isLetter || $0.isNumber || $0 == " " }.prefix( 7 ) ) }
            ) )
            .font( .system( size : 20, weight : .black, design : .monospaced ) )
            .foregroundStyle( .black )
            .padding( 6 )
            .frame( width : 150 )
            .background( Color( hex : 0xF4D03F ), in : RoundedRectangle( cornerRadius : 4 ) )
            .autocorrectionDisabled()
        }
        .panel()
    }

    private func sectionTitle( _ text : String ) -> some View {
        Text( text )
            .font( .label( 12, weight : .heavy ) )
            .foregroundStyle( Theme.secondaryText )
    }
}

/// Spoken names for paint swatches, e.g. "Dark green".
nonisolated enum ColourName {
    static func describe( _ hex : UInt32 ) -> String {
        let red = Double( ( hex >> 16 ) & 0xFF ) / 255
        let green = Double( ( hex >> 8 ) & 0xFF ) / 255
        let blue = Double( hex & 0xFF ) / 255
        let brightest = max( red, green, blue )
        let range = brightest - min( red, green, blue )
        let saturation = brightest > 0 ? range / brightest : 0

        guard saturation >= 0.15 else {
            if brightest > 0.85 {
                return "White"
            }

            return brightest < 0.2 ? "Black" : ( brightest > 0.6 ? "Silver" : "Grey" )
        }

        var hue : Double

        if brightest == red {
            hue = 60 * ( green - blue ) / range
        } else if brightest == green {
            hue = 60 * ( blue - red ) / range + 120
        } else {
            hue = 60 * ( red - green ) / range + 240
        }

        hue = hue < 0 ? hue + 360 : hue
        let names : [( Double, String )] = [ ( 15, "red" ), ( 40, "orange" ), ( 65, "yellow" ), ( 160, "green" ), ( 195, "teal" ), ( 255, "blue" ), ( 290, "purple" ), ( 345, "pink" ), ( 360, "red" ) ]
        let name = names.first { hue < $0.0 }?.1 ?? "red"

        if brightest < 0.45 {
            return "Dark " + name
        }

        return name.prefix( 1 ).uppercased() + name.dropFirst()
    }
}
