//
//  AppDelegate.swift
//  Sunsetter
//
//  Created by Michael Hulet on 9/28/18.
//  Copyright © 2018 Michael Hulet. All rights reserved.
//

import Cocoa
import ServiceManagement

@NSApplicationMain
class SSAppDelegate: NSObject, NSApplicationDelegate{
    func applicationDidFinishLaunching(_ aNotification: Notification) -> Void{
        // Insert code here to initialize your application
        let sunriserID = "tech.hulet.Sunsetter.Sunriser"
        SMLoginItemSetEnabled(sunriserID as CFString, true)
        if NSWorkspace.shared.runningApplications.contains(where: {$0.bundleIdentifier == sunriserID}){ // If Sunriser is currently running
            DistributedNotificationCenter.default().post(name: .killSunriser, object: Bundle.main.bundleIdentifier)
        }
    }

    func applicationWillTerminate(_ aNotification: Notification) -> Void{
        // Insert code here to tear down your application
    }
}

public extension Notification.Name{
    public static let killSunriser = Notification.Name("tech.hulet.Sunsetter.killSunriserNotification")
}
