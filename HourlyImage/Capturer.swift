//
//  Capturer.swift
//  HourlyImage
//
//  Created by Pascal on 30/03/2022.
//

import Foundation
import AVFoundation
import CoreLocation
import Cocoa
import AppKit
import MapKit
import Darwin

struct TwitterCredentials: Decodable {
    var consumerKey: String
    var consumerSecret: String
    var oauthToken: String
    var oauthTokenSecret: String
}

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
        dateFormatter.dateFormat = "yMMd_HH-MM-SS"
        let fileName = dateFormatter.string(from: Date()) + "-webcam"

        print(storeImageToDocumentDirectory(image: nsImage, fileName: fileName)!)
        
        Task.init {
            await tweetImage(data: imageData.base64EncodedString())
            print("really tweeted")
            await NSApp.terminate(self)
        }
        
//        stopSession()
    }
    
    public func storeImageToDocumentDirectory(image: NSImage, fileName: String = "snapshot") -> URL? {
                
        let properties = [NSBitmapImageRep.PropertyKey.compressionFactor: 1.0]
        
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
            print("written")
        } catch {
            print(error)
            print("failed to write data")
        }
        
        return filePath
    }
    
    private func filePath(key: String) -> URL? {
        let fileManager = FileManager.default
        guard let fileBaseDirectory = fileManager.urls(for: .picturesDirectory, in: FileManager.SearchPathDomainMask.userDomainMask).first else { return nil }
        let fileDirectory = fileBaseDirectory.appendingPathComponent("Webcam", isDirectory: true)
        if !fileManager.fileExists(atPath: fileDirectory.path) {
            try! fileManager.createDirectory(at: fileDirectory, withIntermediateDirectories: true)
        }
        return fileDirectory.appendingPathComponent(key).appendingPathExtension("jpg")
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
            let response = try await twitter.upload(data: data)
            debugPrint(response)
            let mediaId = response.media_id_string!
            let response2 = try await twitter.update(status: "\(Date()) (Wifi: \(lm.getSSID())", media_ids: [mediaId], coordinates: ((lm.lastLocation?.coordinate.latitude)! as Double, (lm.lastLocation?.coordinate.longitude)! as Double))
            debugPrint(response2)
        }
        catch {
            print("error: \(error.localizedDescription)")
        }
        print("tweeted")
    }
    
    private func readCredentials() -> TwitterCredentials {
        let fileManager = FileManager.default
        guard let fileBaseDirectory = fileManager.urls(for: .picturesDirectory, in: FileManager.SearchPathDomainMask.userDomainMask).first else { fatalError("Could not read twitter credentials") }
        let fileDirectory = fileBaseDirectory.appendingPathComponent("Webcam", isDirectory: true)
        if !fileManager.fileExists(atPath: fileDirectory.path) {
            try! fileManager.createDirectory(at: fileDirectory, withIntermediateDirectories: true)
        }
        let key = ".twitterCred"
        let file = fileDirectory.appendingPathComponent(key).appendingPathExtension("json")
        
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
    
    let captDel = CaptureDel()
    
//    var lm: LocationManager?
    
    init() {
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
        print(captureConnection?.isActive ?? "notActive")
        let photoSettings = AVCapturePhotoSettings()
        print("take photo")

        photoOutput?.capturePhoto(with: photoSettings, delegate: captDel) 
//        print("error while capturePhoto")
        
        print("took photo?")
    }
    
    func prepareCamera() {
        photoOutput = AVCapturePhotoOutput()
        captureSession = AVCaptureSession()
//        captDel = CaptureDel()
        captureSession!.sessionPreset = AVCaptureSession.Preset.photo
        do {
//            lm = LocationManager()
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
