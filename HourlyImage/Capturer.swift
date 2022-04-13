//
//  Capturer.swift
//  HourlyImage
//
//  Created by Pascal on 30/03/2022.
//

import AVFoundation
import CoreLocation
import MapKit

class CaptureDel: NSObject, AVCapturePhotoCaptureDelegate {
    let lm = LocationManager()
    
    internal func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        print("PHOTO OUTPUT")
        guard let imageData = photo.fileDataRepresentation() else {
            print("Error while generating image from photo capture data.");
            return
        }
        
        guard let nsImage = NSImage(data: imageData) else {
            print("no NsImage")
            return
        }
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = Config.snapshotDateFormat
        let fileName = dateFormatter.string(from: Date()) + Config.snapshotSuffix

        print(storeImageToDocumentDirectory(image: nsImage, fileName: fileName)!)
        
        Task.init {
            if Config.Twitter.enabled {
                await tweetImage(data: imageData.base64EncodedString())
                print("really tweeted")
            }
            
            if Config.Shell.enabled {
                Shell.scp(localDirectory: Config.Shell.localDirectory, server: Config.Shell.server, remoteDirectory: Config.Shell.remoteDirectory, sshKeyName: Config.Shell.sshKeyName)
                print("finished shell")
            }
            
            await NSApp.terminate(self)
        }
    }
    
    public func storeImageToDocumentDirectory(image: NSImage, fileName: String = "snapshot") -> URL? {
                
        let properties = [NSBitmapImageRep.PropertyKey.compressionFactor: Config.snapshotCompressionFactor]
        
        guard let imageData = image.tiffRepresentation else {
            print("no tiff rep")
            return nil
        }
        
        guard let imageRep = NSBitmapImageRep(data: imageData) else {
            print("bitmap error")
            return nil
        }
        
        guard let fileData = imageRep.representation(using: .jpeg, properties: properties) else {
            print("no fileData")
            return nil
        }
        
        guard let filePath = filePath(key: fileName) else { return nil }
        
        do {
            try fileData.write(to: filePath, options: .atomic)
            print("written: \(fileName)")
        } catch {
            print(error)
            print("failed to write data")
        }
        
        return filePath
    }
    
    private func filePath(key: String) -> URL? {
        let fileManager = FileManager.default
        guard let fileBaseDirectory = fileManager.urls(for: Config.searchPath, in: FileManager.SearchPathDomainMask.userDomainMask).first else { return nil }
        let fileDirectory = fileBaseDirectory.appendingPathComponent(Config.subDirectoryName, isDirectory: true)
        if !fileManager.fileExists(atPath: fileDirectory.path) {
            try! fileManager.createDirectory(at: fileDirectory, withIntermediateDirectories: true)
        }
        return fileDirectory.appendingPathComponent(key).appendingPathExtension(Config.snapshotExtension)
    }
    
    /**
        Uploads image to Twitter and sends tweet with it.
     
        - parameter data: Base64 encoded image data as String
     */
    private func tweetImage(data: String) async {
        let creds = readCredentials()
        let twitter = Twitter(consumerKey: creds.consumerKey,
                              consumerSecret: creds.consumerSecret,
                              oauthToken: creds.oauthToken,
                              oauthTokenSecret: creds.oauthTokenSecret)
        do {
            print(lm.statusString)
            let mediaResponse = try await twitter.upload(data: data)
            debugPrint(mediaResponse)
            guard let mediaId = mediaResponse.media_id_string else { throw TwitterAPIError.message("did not receive mediaId") }
            let df = DateFormatter()
            df.setLocalizedDateFormatFromTemplate(Config.Twitter.dateFormat)
            let status = "\(df.string(from: Date())) (Wifi: \(lm.getSSID()))"
            let coordinates:(Double, Double) = ((lm.lastLocation?.coordinate.latitude ?? 1.1) as Double, (lm.lastLocation?.coordinate.longitude ?? 1.1) as Double)
            let tweetResponse = try await twitter.update(status: status, media_ids: [mediaId], coordinates: coordinates)
            debugPrint(tweetResponse)
            
            if Config.isDebug {
                debugPrint("Delete tweet")
                let _ = try await twitter.destroy(id: tweetResponse.id_str!)
                debugPrint("Tweet destroyed")
            }
        }
        catch {
            print("error: \(error.localizedDescription)")
        }
        print("tweeted")
    }
    
    private func readCredentials() -> TwitterCredentials {
        let fileManager = FileManager.default
        guard let fileBaseDirectory = fileManager.urls(for: Config.searchPath, in: FileManager.SearchPathDomainMask.userDomainMask).first else { fatalError("Could not read twitter credentials") }
        let fileDirectory = fileBaseDirectory.appendingPathComponent(Config.subDirectoryName, isDirectory: true)
        if !fileManager.fileExists(atPath: fileDirectory.path) {
            try! fileManager.createDirectory(at: fileDirectory, withIntermediateDirectories: true)
        }
        let key = Config.Twitter.credentialsFilename
        let file = fileDirectory.appendingPathComponent(key)
        
        let data: Data
        do {
            data = try Data(contentsOf: file)
        } catch {
            fatalError("Could not load \(file.absoluteString) \n\(error)")
        }
        
        do {
            let decoder = JSONDecoder()
            return try decoder.decode(TwitterCredentials.self, from: data)
        } catch {
            fatalError("Could not parse \(file.absoluteString) as \(TwitterCredentials.self): \n\(error)")
        }
    }
}

class Capturer {
    // MARK: - Properties
    var captureSession: AVCaptureSession?
    var captureConnection: AVCaptureConnection?
    var cameraDevice: AVCaptureDevice?
    var photoOutput: AVCapturePhotoOutput?
    
    let captDel:AVCapturePhotoCaptureDelegate
    
    init() {
        captDel = CaptureDel()
        print("Capturer is running")
    }
    
    func startSession() {
        print("startSession")
        if let videoSession = captureSession {
            if !videoSession.isRunning {
                videoSession.startRunning()
                print("was not running before")
            }
        }
    }
    
    func stopSession() {
        if let videoSession = captureSession {
            if videoSession.isRunning {
                print("stopped running session")
                videoSession.stopRunning()
            }
        }
    }
    
    func takePhoto() {
        debugPrint(captureConnection?.isActive ?? "no active connection")
        let photoSettings = AVCapturePhotoSettings()
        debugPrint("take photo")

        photoOutput?.capturePhoto(with: photoSettings, delegate: captDel)
        
        debugPrint("photo process delegated")
    }
    
    func prepareCamera() {
        photoOutput = AVCapturePhotoOutput()
        captureSession = AVCaptureSession()
//        captDel = CaptureDel()
        captureSession!.sessionPreset = AVCaptureSession.Preset.photo
        do {
            let deviceDiscoverySession = AVCaptureDevice.DiscoverySession(deviceTypes: [AVCaptureDevice.DeviceType.builtInWideAngleCamera], mediaType: AVMediaType.video, position: AVCaptureDevice.Position.front)
            let cameraDevice = deviceDiscoverySession.devices[0]
            let videoInput = try AVCaptureDeviceInput(device: cameraDevice)
            captureSession!.beginConfiguration()
            if captureSession!.canAddInput(videoInput) {
                print("Adding videoInput to captureSession")
                captureSession!.addInput(videoInput)
            } else {
                print("Unable to add videoInput to captureSession")
            }
            if captureSession!.canAddOutput(photoOutput!) {
                captureSession!.addOutput(photoOutput!)
                print("Adding videoOutput to captureSession")
            } else {
                print("Unable to add videoOutput to captureSession")
            }
            captureConnection = AVCaptureConnection(inputPorts: videoInput.ports, output: photoOutput!)
            captureSession!.commitConfiguration()
            captureSession!.startRunning()
        } catch {
            print(error.localizedDescription)
        }
    }
}
