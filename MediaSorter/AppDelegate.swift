//
//  AppDelegate.swift
//  MediaSorter
//
//  Created by Doug Diego on 11/7/17.
//  Copyright © 2017 diego.org. All rights reserved.
//

import Cocoa
import XCGLogger

let log = XCGLogger.default

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {

    func applicationDidFinishLaunching(_ notification: Notification) {

        // Setup Logging
        log.setup(level: .debug,
                  showThreadName: true,
                  showLevel: true,
                  showFileNames: true,
                  showLineNumbers: true,
                  writeToFile: nil,
                  fileLevel: .debug)
    }
}
