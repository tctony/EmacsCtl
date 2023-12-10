//
//  main.swift
//  EmacsCtl
//
//  Created by Tony Tang on 2023/12/10.
//

import Cocoa

// Create the application instance
let application = NSApplication.shared
let appDelegate = AppDelegate()
application.delegate = appDelegate
let menu = AppMenu()
application.mainMenu = menu

// Run the application event loop
application.run()
