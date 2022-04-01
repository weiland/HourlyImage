//
//  Config.swift
//  HourlyImage
//
//  Created by Pascal on 30/03/2022.
//

import Foundation

struct Config {
    
    static let searchPath:FileManager.SearchPathDirectory = .picturesDirectory
    static let directoryName = "~/Pictures" // must match searchPath above!
    static let subDirectoryName = "Webcam"
    
    /// dateFormat used in the filename
    static let snapshotDateFormat = "yyyyMMdd_HH-mm-ss"
    // after the dateFormat (and before the extension)
    static let snapshotSuffix = "-webcam"
    static let snapshotExtension = "jpg"
    static let snapshotCompressionFactor: Double = 1.0
    
    struct Shell {
        /// upload images via scp if enabled (and also delete local images afterwards)
        static let enabled = true
        /// for debugging we can keep the images locally after uploading
        static let deleteLocalImages = true
        
        static let localDirectory = "~/Pictures/Webcam"
        static let server = "y@spahr.uberspace.de"
        static let remoteDirectory = "selfies/"
        /// key must be in the localDirectory (where the images are)
        static let sshKeyName = ".id_ed25519"
    }
    struct Twitter {
        /// send tweet if enabled
        static let enabled = true
        static let dateFormat = "EEE MMM dd y HH:mm:ss v"
        static let includeLocation = true
        static let includeWifiName = true // requires Location
        /// Twitter UserId of additional owner of media
        static let additional_owners: String? = nil
        static let credentialsFilename = ".twitterCred.json"
    }
    static let isDebug = false
}
