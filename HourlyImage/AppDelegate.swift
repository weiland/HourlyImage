//
//  AppDelegate.swift
//  HourlyImage
//
//  Created by Pascal on 30/03/2022.
//

import AppKit

class AppDelegate: NSObject, NSApplicationDelegate {
    
    var statusBarItem : NSStatusItem!
    var statusBarMenu : NSMenu!
    var popover: NSPopover!
    
    let capturer: Capturer = Capturer()

    func applicationDidFinishLaunching(_ notification: Notification) {
//        NSApplication.shared.activate(ignoringOtherApps: true)

        print("app did finsih loading")
        capturer.prepareCamera()
        capturer.startSession()
        sleep(3)
        capturer.takePhoto()
        print("finnnnn")

//        NSApplication.shared.activate(ignoringOtherApps: true)
    }
}
