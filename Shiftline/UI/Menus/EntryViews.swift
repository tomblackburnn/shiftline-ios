import SwiftUI

struct ShiftlineLogo : View {
    var size : CGFloat = 54

    var body : some View {
        HStack( spacing : size * 0.18 ) {
            HStack( spacing : size * 0.06 ) {
                ForEach( 0 ..< 3, id : \.self ) { index in
                    SlantedShape( slant : size * 0.18 )
                        .fill( [ Theme.accent, Theme.orange, Theme.hot ][ index ] )
                        .frame( width : size * 0.22, height : size * 0.8 )
                }
            }

            Text( "SHIFTLINE" )
                .font( .display( size ) )
                .foregroundStyle( .white )
                .tracking( size * 0.02 )
        }
        .accessibilityElement( children : .ignore )
        .accessibilityLabel( "Shiftline" )
    }
}

struct ProfileSelectView : View {
    var isManaging = false
    @Environment( GameStore.self ) private var store
    @Environment( \.dismiss ) private var dismiss
    @State private var newName = ""
    @State private var pendingDeletion : ProfileSummary?

    var body : some View {
        HStack( spacing : 30 ) {
            VStack( alignment : .leading, spacing : 14 ) {
                if isManaging {
                    ScreenHeader( title : "Profiles", subtitle : "Switch or create drivers" ) {
                        EmptyView()
                    }
                } else {
                    ShiftlineLogo()
                    Text( "Master every discipline. Build your garage. Become a legend." )
                        .font( .label( 16 ) )
                        .foregroundStyle( Theme.secondaryText )
                }

                Spacer()

                VStack( alignment : .leading, spacing : 8 ) {
                    Text( "NEW DRIVER" )
                        .font( .display( 18 ) )
                        .foregroundStyle( .white )

                    HStack {
                        TextField( "Driver name", text : $newName )
                            .textInputAutocapitalization( .words )
                            .autocorrectionDisabled()
                            .padding( 10 )
                            .background( Theme.panelRaised, in : RoundedRectangle( cornerRadius : 8 ) )
                            .foregroundStyle( .white )
                            .frame( maxWidth : 260 )
                            .accessibilityIdentifier( "profileNameField" )

                        Button( "CREATE" ) {
                            store.createProfile( named : newName )
                            newName = ""

                            if isManaging {
                                dismiss()
                            }
                        }
                        .buttonStyle( .shift( .primary, compact : true ) )
                        .accessibilityIdentifier( "createProfileButton" )
                    }
                }
                .panel()
            }
            .frame( maxWidth : .infinity, alignment : .leading )

            VStack( alignment : .leading, spacing : 10 ) {
                Text( store.profiles.isEmpty ? "NO PROFILES YET" : "CONTINUE" )
                    .font( .display( 18 ) )
                    .foregroundStyle( .white )

                ScrollView {
                    VStack( spacing : 8 ) {
                        ForEach( store.profiles ) { profile in
                            Button {
                                store.loadProfile( profile.id )

                                if isManaging {
                                    dismiss()
                                }
                            } label : {
                                HStack {
                                    VStack( alignment : .leading, spacing : 2 ) {
                                        Text( profile.name )
                                            .font( .display( 20 ) )
                                            .foregroundStyle( .white )
                                        Text( "Level \( profile.level ) · \( profile.carCount ) cars · \( profile.lastPlayed.formatted( date : .abbreviated, time : .omitted ) )" )
                                            .font( .label( 12 ) )
                                            .foregroundStyle( Theme.secondaryText )
                                    }

                                    Spacer()

                                    if profile.id == store.profileID {
                                        Chip( text : "Active", isSelected : true )
                                    }

                                    Image( systemName : "chevron.right" )
                                        .foregroundStyle( Theme.secondaryText )
                                }
                                .panel( highlighted : profile.id == store.profileID )
                            }
                            .buttonStyle( .plain )
                            .contextMenu {
                                Button( "Delete", role : .destructive ) {
                                    pendingDeletion = profile
                                }
                            }
                        }
                    }
                }
            }
            .frame( width : 340 )
        }
        .padding( 28 )
        .gameBackground()
        .confirmationDialog(
            "Delete \( pendingDeletion?.name ?? "" )?",
            isPresented : Binding( get : { pendingDeletion != nil }, set : { if !$0 { pendingDeletion = nil } } ),
            titleVisibility : .visible
        ) {
            Button( "Delete Profile", role : .destructive ) {
                if let profile = pendingDeletion {
                    store.deleteProfile( profile.id )
                }
            }
        } message : {
            Text( "All progress for this driver will be permanently removed." )
        }
    }
}

struct StarterSelectView : View {
    @Environment( GameStore.self ) private var store
    @State private var selected : CarID = Cars.starterIDs[ 0 ]

    private let styles = [
        "hayase-pip" : "BALANCED · FORGIVING",
        "hayase-kite-s" : "LIGHTWEIGHT · PLAYFUL",
        "norrvik-fjell" : "GRIPPY · TURBO"
    ]

    var body : some View {
        VStack( alignment : .leading, spacing : 10 ) {
            HStack {
                VStack( alignment : .leading, spacing : 2 ) {
                    Text( "CHOOSE YOUR FIRST CAR" )
                        .font( .display( 32 ) )
                        .foregroundStyle( .white )
                    Text( "Every starter can win. Each suits a different driving style." )
                        .font( .label( 14 ) )
                        .foregroundStyle( Theme.secondaryText )
                }

                Spacer()
                ShiftlineLogo( size : 26 )
            }

            HStack( spacing : 14 ) {
                ForEach( Cars.starterIDs, id : \.self ) { carID in
                    if let car = Cars.named( carID ) {
                        starterCard( car )
                    }
                }
            }

            HStack {
                Spacer()

                Button( "START YOUR CAREER" ) {
                    store.chooseStarter( selected )
                    store.startTutorial( .basics )
                }
                .buttonStyle( .shift )
                .accessibilityIdentifier( "confirmStarterButton" )
            }
        }
        .padding( .horizontal, 24 )
        .padding( .vertical, 12 )
        .gameBackground()
    }

    private func starterCard( _ car : CarDefinition ) -> some View {
        let isSelected = selected == car.id
        let performance = PerformanceProfile.measure( car.baseSpec )

        return Button {
            selected = car.id
            GameAudio.shared.play( .tap )
            Haptics.shared.play( .tap )
        } label : {
            VStack( alignment : .leading, spacing : 8 ) {
                HStack {
                    Text( car.drivetrain.title )
                        .font( .display( 14 ) )
                        .foregroundStyle( .black )
                        .padding( .horizontal, 8 )
                        .background( SlantedShape( slant : 4 ).fill( Theme.accent ) )
                    Text( styles[ car.id ] ?? "" )
                        .font( .label( 11, weight : .heavy ) )
                        .foregroundStyle( Theme.secondaryText )
                    Spacer()
                    ClassBadge( performance : performance )
                }

                CarSideView( definition : car, appearance : CarAppearance( paintHex : car.defaultPaintHex ) )
                    .frame( height : 56 )

                Text( car.fullName.uppercased() )
                    .font( .display( 19 ) )
                    .foregroundStyle( .white )

                Text( car.blurb )
                    .font( .label( 11 ) )
                    .foregroundStyle( Theme.secondaryText )
                    .lineLimit( 2, reservesSpace : true )

                StatBar( label : "Acceleration", value : performance.accelerationRating )
                StatBar( label : "Handling", value : performance.handlingRating )
                StatBar( label : "Drift", value : performance.driftRating )
            }
            .panel( padding : 10, highlighted : isSelected )
        }
        .buttonStyle( .plain )
        .accessibilityIdentifier( "starter-\( car.id )" )
    }
}
