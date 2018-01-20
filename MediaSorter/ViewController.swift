//
//  ViewController.swift
//  MediaSorter
//
//  Created by Doug Diego on 11/7/17.
//  Copyright © 2017 diego.org. All rights reserved.
//

import Cocoa
import Foundation

public enum LocalStorageKey: String {
    case identifier = "IDENTIFIER"
    case dateFormat = "DATE_FOMAT"
    //case lastInputDirectory = "LAST_INPUT_DIRETORY"
    //case lastOutputDirectory = "LAST_OUTPUT_DIRECTORY"
}

public enum DefaultValues: String {
    case identifer = ""
    case dateFormat = "yyyyMMdd-HHmmss"
}

class ViewController: NSViewController {

    @IBOutlet weak var statusLabel: NSTextField!
    @IBOutlet weak var tableView: NSTableView!
    @IBOutlet weak var progressIndicator: NSProgressIndicator!
    @IBOutlet weak var identifierTextField: NSTextField!
    @IBOutlet weak var dateFormatTextField: NSTextField!
    let debugDelay = false

    let sizeFormatter = ByteCountFormatter()
    var directory: Directory?
    var directoryItems: [Metadata]?
    var sortOrder = Directory.FileOrder.name
    var sortAscending = true

    override var representedObject: Any? {
        didSet {
            if let url = representedObject as? URL {
                log.debug("Represented object: \(url)")
                self.updateStatus("Loading media")
                DispatchQueue.global(qos: .background).async {
                    self.directory = Directory(folderURL: url)
                    DispatchQueue.main.async {
                        self.updateStatus("Processing media")
                        self.reloadFileList()
                        //self.updateStatus()
                    }
                }
            }
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        statusLabel.stringValue = ""
        tableView.delegate = self
        tableView.dataSource = self
        tableView.target = self
        tableView.doubleAction = #selector(tableViewDoubleClick(_:))

        let descriptorName = NSSortDescriptor(key: Directory.FileOrder.name.rawValue, ascending: true)
        let descriptorNewPath = NSSortDescriptor(key: Directory.FileOrder.newPath.rawValue, ascending: true)
        let descriptorExifDate = NSSortDescriptor(key: Directory.FileOrder.exifDate.rawValue, ascending: true)
        let descriptorCreatedDate = NSSortDescriptor(key: Directory.FileOrder.createDate.rawValue, ascending: true)
        let descriptorModifiedDate = NSSortDescriptor(key: Directory.FileOrder.modifiedDate.rawValue, ascending: true)
        let descriptorSize = NSSortDescriptor(key: Directory.FileOrder.size.rawValue, ascending: true)

        tableView.tableColumns[0].sortDescriptorPrototype = descriptorName
        tableView.tableColumns[1].sortDescriptorPrototype = descriptorNewPath
        tableView.tableColumns[2].sortDescriptorPrototype = descriptorExifDate
        tableView.tableColumns[3].sortDescriptorPrototype = descriptorCreatedDate
        tableView.tableColumns[4].sortDescriptorPrototype = descriptorModifiedDate
        tableView.tableColumns[5].sortDescriptorPrototype = descriptorSize

        identifierTextField.delegate = self

        loadDefaults()

        updateStatus()

        self.progressIndicator.doubleValue = 0
    }

    func reloadFileList() {
        let dateFormat = self.dateFormatTextField.stringValue
        let photoIdentifier = self.identifierTextField.stringValue

        // Save Photo Identifier if one exist
        if !photoIdentifier.isEmpty {
            UserDefaults.standard.set(photoIdentifier, forKey: LocalStorageKey.identifier.rawValue)
            UserDefaults.standard.synchronize()
        }

        // Save Date Format if one exists
        if !dateFormat.isEmpty {
            UserDefaults.standard.set(dateFormat, forKey: LocalStorageKey.dateFormat.rawValue)
            UserDefaults.standard.synchronize()
        }

        DispatchQueue.global(qos: .background).async {
            // Process Media
            self.directory?.processNewPath(photoIdentifier, dateFormat: dateFormat)

            // Sort Media
            self.directoryItems = self.directory?.contentsOrderedBy(self.sortOrder, ascending: self.sortAscending)

            // Reload Table View
            DispatchQueue.main.async {
                self.tableView.reloadData()
            }
        }
    }

    func loadDefaults() {
        // Placeholder Text
        identifierTextField.placeholderString = "Photo Identifier"

        // Restore the user's last entered value
        if let identifier = UserDefaults.standard.string(forKey: LocalStorageKey.identifier.rawValue) {
            identifierTextField.stringValue = identifier
        }
        if let dateFormat = UserDefaults.standard.string(forKey: LocalStorageKey.dateFormat.rawValue) {
            dateFormatTextField.stringValue = dateFormat
        } else {
            dateFormatTextField.stringValue = DefaultValues.dateFormat.rawValue
        }
    }

    func updateStatus(_ status: String? = nil) {
        let text: String

        if let status = status {
            text = status
        } else {
            let itemsSelected = tableView.selectedRowIndexes.count

            if (directoryItems == nil) {
                text = "No Items"
            } else if(itemsSelected == 0) {
                text = "\(directoryItems!.count) items"
            } else {
                text = "\(itemsSelected) of \(directoryItems!.count) selected"
            }
        }
        statusLabel.stringValue = text
    }

    @objc func tableViewDoubleClick(_ sender: AnyObject) {

        guard tableView.selectedRow >= 0,
            let item = directoryItems?[tableView.selectedRow] else {
                return
        }

        if item.isFolder {
            self.representedObject = item.url as Any
        } else {
            NSWorkspace.shared.open(item.url as URL)
        }
    }

    func copy(atPath: String, toPath: String) -> Bool {
        log.debug("cp \(atPath) \(toPath)")

        let fileManager = FileManager.default

        if fileManager.fileExists(atPath: toPath) {
            log.debug("\(atPath) already exists")
            return false
        }

        // Create a FileManager instance
        do {
            try fileManager.copyItem(atPath: atPath, toPath: toPath)
            return true
        } catch let error as NSError {
            log.debug("Ooops! Something went wrong: \(error)")
        }
        return false
    }

    func promptForSaveLocation() {
        log.debug("promptForSaveLocation")
        let openPanel = NSOpenPanel()
        openPanel.allowsMultipleSelection = false
        openPanel.canChooseDirectories = true
        openPanel.canCreateDirectories = true
        openPanel.canChooseFiles = false
        let i = openPanel.runModal()
        let destUrl: URL?
        if i == NSApplication.ModalResponse.OK {
            destUrl = openPanel.url
            //log.debug((destUrl?.path)!)
            if let destUrl = destUrl {
                createMediaDirectories(destUrl)
                processMedia(destUrl)
            } else {
                log.debug("unable to unwrap destURL")
            }
        } else {
            log.debug("User did not choose OK")
        }
    }

    func createMediaDirectories(_ baseUrl: URL) {
        if !self.createMediaDirectory(baseUrl, directoryName: OutputDirs.error.rawValue) {
            log.debug("error creating error directory")
        }
        if !self.createMediaDirectory(baseUrl, directoryName: OutputDirs.image.rawValue) {
            log.debug("error creating image directory")
        }
        if !self.createMediaDirectory(baseUrl, directoryName: OutputDirs.video.rawValue) {
            log.debug("error creating video directory")
        }
    }

    func createMediaDirectory(_ baseUrl: URL, directoryName: String) -> Bool {
        let fileManager = FileManager.default
        if let newUrl = NSURL(fileURLWithPath: baseUrl.path).appendingPathComponent(directoryName) {
            log.debug("Processing \(newUrl)...")
            if fileManager.fileExists(atPath: newUrl.path) {
                log.debug("\(newUrl.path) already exists")
                return true
            } else {
                do {
                    try fileManager.createDirectory(at: newUrl, withIntermediateDirectories: false, attributes: nil)
                    log.debug("Created directory: \(directoryName)")
                    return true
                } catch {
                    log.debug("Error creating directory: \(directoryName)")
                    return false
                }
            }
        }
        log.debug("create directory fell through directory: \(directoryName)")
        return false
    }

    func processMedia(_ destUrl: URL) {
        log.debug("processMedia")

        guard let files = directoryItems else {
            log.debug("no files")
            return
        }

        self.progressIndicator.minValue = 0
        self.progressIndicator.doubleValue = 0
        self.progressIndicator.maxValue = Double(files.count)
        self.progressIndicator.doubleValue = Double(1)
        DispatchQueue.global(qos: .background).async {

            for (index, file) in files.enumerated() {
                log.debug("\(index) \(file)")
                DispatchQueue.main.async {
                    self.updateStatus("Processing \(file.name) - \(index+1) of \(files.count)")
                }
                if let newUrl = NSURL(fileURLWithPath: destUrl.path).appendingPathComponent(file.newPath) {
                    log.debug("Processing \(newUrl)...")
                    let success = self.copy(atPath: file.url.path, toPath: newUrl.path)
                    log.debug("copy status: \(success)")
                }
                if self.debugDelay {
                    log.debug("sleeping")
                    sleep(5)
                    log.debug("done sleeping")
                }
                DispatchQueue.main.async {
                    self.progressIndicator.doubleValue = Double(index+1)
                }
            }
            DispatchQueue.main.async {
                self.updateStatus()
            }
        }
    }
}

// MARK: - Actions

extension ViewController {
    @IBAction func runButtonPressed(_ sender: Any) {
        log.debug("runButtonPressed")
        promptForSaveLocation()
    }

    @IBAction func refreshButtonTouched(_ sender: Any) {

        reloadFileList()
    }
}

// MARK: - NSTableViewDataSource

extension ViewController: NSTableViewDataSource {

    func numberOfRows(in tableView: NSTableView) -> Int {
        return directoryItems?.count ?? 0
    }

    func tableView(_ tableView: NSTableView, sortDescriptorsDidChange oldDescriptors: [NSSortDescriptor]) {
        guard let sortDescriptor = tableView.sortDescriptors.first else {
            return
        }
        if let order = Directory.FileOrder(rawValue: sortDescriptor.key!) {
            sortOrder = order
            sortAscending = sortDescriptor.ascending
            reloadFileList()
        }
    }
}

// MARK: - NSTableViewDelegate

extension ViewController: NSTableViewDelegate {

    fileprivate enum CellIdentifiers {
        static let NameCell = "NameCellID"
        static let NewPathCell = "NewPathCellID"
        static let ExifDateCell = "ExifDateCellID"
        static let DateModifiedCell = "DateModifiedCellID"
        static let DateCreatedCell = "DateCreatedCellID"
        static let SizeCell = "SizeCellID"
    }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {

        var image: NSImage?
        var text: String = ""
        var cellIdentifier: String = ""

        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .short
        dateFormatter.timeStyle = .short

        guard let item = directoryItems?[row] else {
            return nil
        }

        if tableColumn == tableView.tableColumns[0] {
            image = item.icon
            text = item.name
            cellIdentifier = CellIdentifiers.NameCell

        } else if tableColumn == tableView.tableColumns[1] {
            text = item.newPath
            cellIdentifier = CellIdentifiers.NewPathCell

        } else if tableColumn == tableView.tableColumns[2] {
            if let date = item.exifDateTimeOriginal {
                text = dateFormatter.string(from: date)
            } else {
                text = "--"
            }
            cellIdentifier = CellIdentifiers.ExifDateCell

        } else if tableColumn == tableView.tableColumns[3] {
            text = dateFormatter.string(from: item.createDate)
            cellIdentifier = CellIdentifiers.DateCreatedCell

        } else if tableColumn == tableView.tableColumns[4] {
            text = dateFormatter.string(from: item.modifiedDate)
            cellIdentifier = CellIdentifiers.DateModifiedCell

        } else if tableColumn == tableView.tableColumns[5] {
            text = item.isFolder ? "--" : sizeFormatter.string(fromByteCount: item.size)
            cellIdentifier = CellIdentifiers.SizeCell

        }

        if let cell = tableView.makeView(withIdentifier: NSUserInterfaceItemIdentifier(rawValue: cellIdentifier), owner: nil) as? NSTableCellView {
            cell.textField?.stringValue = text
            cell.imageView?.image = image ?? nil
            return cell
        }
        return nil
    }

    func tableViewSelectionDidChange(_ notification: Notification) {
        updateStatus()
    }

}

// MARK: - NSTextFieldDelegate

extension ViewController: NSTextFieldDelegate {
    func control(_ control: NSControl, textShouldEndEditing fieldEditor: NSText) -> Bool {
        log.debug("textShouldEndEditing")
        //reloadFileList()
        return true
    }
}
