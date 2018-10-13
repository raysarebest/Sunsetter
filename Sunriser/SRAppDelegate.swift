//
//  AppDelegate.swift
//  Sunriser
//
//  Created by Michael Hulet on 10/10/18.
//  Copyright © 2018 Michael Hulet. All rights reserved.
//

import Cocoa

@NSApplicationMain
class SRAppDelegate: NSObject, NSApplicationDelegate{
    func applicationDidFinishLaunching(_ aNotification: Notification) {
        // Insert code here to initialize your application
        let sunsetterID = "tech.hulet.Sunsetter"
        if NSWorkspace.shared.runningApplications.contains(where: {$0.bundleIdentifier == sunsetterID}){ // If Sunsetter is running
            terminate()
        }
        else{ // If not, we need to launch it
            DistributedNotificationCenter.default().addObserver(self, selector: #selector(terminate), name: .killSunriser, object: sunsetterID)

            let bundle = Bundle.main.bundlePath as NSString
            var components = bundle.pathComponents
            components.removeLast(3)
            components.append("MacOS")
            components.append("Sunsetter")

            let _ = try? NSWorkspace.shared.launchApplication(at: URL(fileURLWithPath: components.joined(separator: "/")), options: [], configuration: [:])
        }
    }

    func applicationWillTerminate(_ aNotification: Notification) {
        // Insert code here to tear down your application
    }

    @objc func terminate() -> Void{
        NSApplication.shared.terminate(self)
    }
}

public extension Notification.Name{
    public static let killSunriser = Notification.Name("tech.hulet.Sunsetter.killSunriserNotification")
}
