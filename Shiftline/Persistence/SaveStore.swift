import Foundation

nonisolated struct ProfileSummary : Codable, Identifiable, Equatable {
    var id : UUID
    var name : String
    var level : Int
    var carCount : Int
    var lastPlayed : Date
}

nonisolated enum SaveLoadOutcome : Equatable {
    case loaded
    case recoveredFromBackup
    case resetAfterCorruption
    case created
}

/// JSON saves per profile with an atomic write, a rolling backup and corrupt-file quarantine.
nonisolated struct SaveStore {
    let root : URL
    private let encoder : JSONEncoder
    private let decoder : JSONDecoder

    init( root : URL? = nil ) {
        let base = root ?? FileManager.default.urls( for : .applicationSupportDirectory, in : .userDomainMask )[ 0 ]
            .appendingPathComponent( "Shiftline", isDirectory : true )
        self.root = base
        // Default (numeric) date encoding round-trips exactly; ISO 8601 would drop sub-second precision.
        encoder = JSONEncoder()
        decoder = JSONDecoder()
        try? FileManager.default.createDirectory( at : base, withIntermediateDirectories : true )
    }

    private var indexURL : URL {
        root.appendingPathComponent( "profiles.json" )
    }

    func profileDirectory( _ id : UUID ) -> URL {
        root.appendingPathComponent( "Profiles/\( id.uuidString )", isDirectory : true )
    }

    private func saveURL( _ id : UUID ) -> URL {
        profileDirectory( id ).appendingPathComponent( "save.json" )
    }

    private func backupURL( _ id : UUID ) -> URL {
        profileDirectory( id ).appendingPathComponent( "save.backup.json" )
    }

    // MARK: - Profiles

    func profiles() -> [ProfileSummary] {
        guard let data = try? Data( contentsOf : indexURL ),
              let summaries = try? decoder.decode( [ProfileSummary].self, from : data ) else {
            return []
        }

        return summaries.sorted { $0.lastPlayed > $1.lastPlayed }
    }

    func writeProfiles( _ summaries : [ProfileSummary] ) {
        guard let data = try? encoder.encode( summaries ) else {
            return
        }

        try? data.write( to : indexURL, options : .atomic )
    }

    func createProfile( named name : String ) -> ( UUID, SaveData ) {
        let id = UUID()
        let save = SaveData( profileName : name )
        write( save, for : id )
        return ( id, save )
    }

    func deleteProfile( _ id : UUID ) {
        try? FileManager.default.removeItem( at : profileDirectory( id ) )
        writeProfiles( profiles().filter { $0.id != id } )
    }

    // MARK: - Save files

    /// Loads a profile, falling back to the backup, then to a fresh save. Never throws.
    func load( _ id : UUID, fallbackName : String ) -> ( SaveData, SaveLoadOutcome ) {
        if let save = decode( saveURL( id ) ) {
            return ( save.migrated(), .loaded )
        }

        if FileManager.default.fileExists( atPath : saveURL( id ).path ) {
            quarantine( saveURL( id ) )

            if let backup = decode( backupURL( id ) ) {
                let recovered = backup.migrated()
                write( recovered, for : id )
                return ( recovered, .recoveredFromBackup )
            }

            let fresh = SaveData( profileName : fallbackName )
            write( fresh, for : id )
            return ( fresh, .resetAfterCorruption )
        }

        if let backup = decode( backupURL( id ) ) {
            return ( backup.migrated(), .recoveredFromBackup )
        }

        let fresh = SaveData( profileName : fallbackName )
        write( fresh, for : id )
        return ( fresh, .created )
    }

    func write( _ save : SaveData, for id : UUID ) {
        let directory = profileDirectory( id )
        try? FileManager.default.createDirectory( at : directory, withIntermediateDirectories : true )

        guard let data = try? encoder.encode( save ) else {
            return
        }

        let current = saveURL( id )

        // Keep the last good save as a backup before replacing it.
        if decode( current ) != nil {
            try? FileManager.default.removeItem( at : backupURL( id ) )
            try? FileManager.default.copyItem( at : current, to : backupURL( id ) )
        }

        try? data.write( to : current, options : .atomic )
        updateIndex( for : id, save : save )
    }

    private func updateIndex( for id : UUID, save : SaveData ) {
        var summaries = profiles().filter { $0.id != id }
        summaries.append(
            ProfileSummary(
                id : id,
                name : save.profile.name,
                level : save.profile.level,
                carCount : save.garage.count,
                lastPlayed : save.profile.lastPlayed
            )
        )
        writeProfiles( summaries )
    }

    private func decode( _ url : URL ) -> SaveData? {
        guard let data = try? Data( contentsOf : url ),
              let save = try? decoder.decode( SaveData.self, from : data ),
              save.version <= SaveData.currentVersion else {
            return nil
        }

        return save
    }

    private func quarantine( _ url : URL ) {
        let stamp = Int( Date().timeIntervalSince1970 )
        let destination = url.deletingLastPathComponent().appendingPathComponent( "save.corrupt-\( stamp ).json" )
        try? FileManager.default.moveItem( at : url, to : destination )
    }

    // MARK: - Ghosts

    private func ghostURL( _ id : UUID, key : String ) -> URL {
        profileDirectory( id ).appendingPathComponent( "ghosts/\( key ).json" )
    }

    func loadGhost( _ id : UUID, key : String ) -> GhostRecording? {
        guard let data = try? Data( contentsOf : ghostURL( id, key : key ) ) else {
            return nil
        }

        return try? decoder.decode( GhostRecording.self, from : data )
    }

    func writeGhost( _ ghost : GhostRecording, for id : UUID, key : String ) {
        let url = ghostURL( id, key : key )
        try? FileManager.default.createDirectory( at : url.deletingLastPathComponent(), withIntermediateDirectories : true )

        guard let data = try? encoder.encode( ghost ) else {
            return
        }

        try? data.write( to : url, options : .atomic )
    }
}
