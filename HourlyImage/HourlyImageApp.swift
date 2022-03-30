//
//  HourlyImageApp.swift
//  HourlyImage
//
//  Created by Pascal on 30/03/2022.
//

import SwiftUI

@main
struct HourlyImageApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        Settings {
            ContentView()
        }
    }
}
