//
//  WindowController.swift
//  MediaSorter
//
//  Created by Doug Diego on 11/7/17.
//  Copyright © 2017 diego.org. All rights reserved.
//

import Cocoa

class WindowController: NSWindowController {

  @IBAction func openDocument(_ sender: AnyObject?) {

    let openPanel = NSOpenPanel()
    openPanel.showsHiddenFiles = false
    openPanel.canChooseFiles = false
    openPanel.canChooseDirectories = true

    openPanel.beginSheetModal(for: self.window!) { response in
      guard response.rawValue == NSFileHandlingPanelOKButton else {
        return
      }
      self.contentViewController?.representedObject = openPanel.url
    }
  }

}
