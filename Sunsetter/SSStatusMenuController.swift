//
//  SSStatusMenuController.swift
//  Sunsetter
//
//  Created by Michael Hulet on 9/28/18.
//  Copyright © 2018 Michael Hulet. All rights reserved.
//

import Cocoa

class SSStatusMenuController: NSObject {
    @IBOutlet weak var statusMenu: NSMenu!
    let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

    @IBAction func quit(_ sender: NSMenuItem) -> Void{
        NSApplication.shared.terminate(self)
    }

    override func awakeFromNib() -> Void{
        super.awakeFromNib()
        statusItem.button?.image = #imageLiteral(resourceName: "Day")
        statusItem.menu = statusMenu
    }
}
