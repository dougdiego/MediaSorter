//
//  Directory.swift
//  MediaSorter
//
//  Created by Doug Diego on 11/7/17.
//  Copyright © 2017 diego.org. All rights reserved.
//

// TODO: Add Error reasoning... No date in file, unknown type, HEIC, etc...

import AppKit
import AVFoundation

public struct Metadata: CustomDebugStringConvertible, Equatable {
    
    let name: String
    let createDate: Date
    let modifiedDate: Date
    let size: Int64
    let icon: NSImage
    let color: NSColor
    let isFolder: Bool
    let url: URL
    var newPath: String
    var exifDateTimeOriginal: Date?
    
    init(fileURL: URL,
         name: String,
         createDate: Date,
         modifiedDate: Date,
         size: Int64,
         icon: NSImage,
         isFolder: Bool,
         color: NSColor ) {
        
        self.name = name
        self.createDate = createDate
        self.modifiedDate = modifiedDate
        self.size = size
        self.icon = icon
        self.color = color
        self.isFolder = isFolder
        self.url = fileURL
        self.newPath = ""
    }
    
    public var debugDescription: String {
        return name + " " + "Folder: \(isFolder)" + " Size: \(size)"
    }
    
    public var fileExtension: String? {
        let components = name.components(separatedBy: ".")
        
        guard components.count > 1 else {
            return nil
        }
        
        return components.last
    }
    
}

// MARK: - Metadata  Equatable

public func==(lhs: Metadata, rhs: Metadata) -> Bool {
    return (lhs.url == rhs.url)
}

public enum OutputDirs: String {
    case image
    case video
    case error
}

public class Directory {
    
    fileprivate var files: [Metadata] = []
    let url: URL
    
    public enum FileOrder: String {
        case name
        case newPath
        case exifDate
        case createDate
        case modifiedDate
        case size
    }
    
    public init(folderURL: URL) {
        url = folderURL
    }
    
    public func loadFiles(currentFile: @escaping (String) -> Void,
                          completion: @escaping () -> Void,
                          failure: @escaping (_ error: Error?) -> Void ) {
        DispatchQueue.global(qos: .userInitiated).async {
            let requiredAttributes = [URLResourceKey.localizedNameKey,
                                      URLResourceKey.effectiveIconKey,
                                      URLResourceKey.typeIdentifierKey,
                                      URLResourceKey.contentModificationDateKey,
                                      URLResourceKey.creationDateKey,
                                      URLResourceKey.fileSizeKey,
                                      URLResourceKey.isDirectoryKey,
                                      URLResourceKey.isPackageKey]
            if let enumerator = FileManager.default.enumerator(at: self.url,
                                                               includingPropertiesForKeys: requiredAttributes,
                                                               options: [.skipsHiddenFiles, .skipsPackageDescendants, .skipsSubdirectoryDescendants],
                                                               errorHandler: nil) {
                
                while let url = enumerator.nextObject() as? URL {
                    log.debug( "\(url )")
                    
                    do {
                        let properties = try  (url as NSURL).resourceValues(forKeys: requiredAttributes)
                        var icon = properties[URLResourceKey.effectiveIconKey] as? NSImage  ?? NSImage()
                        if url.path.uppercased().hasSuffix("JPG")
                            || url.path.uppercased().hasSuffix("JPEG")
                            || url.path.uppercased().hasSuffix("PNG")
                            || url.path.uppercased().hasSuffix("HEIC")
                            || url.path.uppercased().hasSuffix("CR2") {
                            icon = NSImage(contentsOf: url)!
                        } else if url.path.uppercased().hasSuffix("MOV") {
                            if let image = self.thumbnailForVideoAtURL(url: url) {
                                icon = image
                            }
                        }
                        if let name = properties[URLResourceKey.localizedNameKey] as? String {
                            currentFile(name)
                        }
                        self.files.append(Metadata(fileURL: url,
                                                   name: properties[URLResourceKey.localizedNameKey] as? String ?? "",
                                                   createDate: properties[URLResourceKey.creationDateKey] as? Date ?? Date.distantPast,
                                                   modifiedDate: properties[URLResourceKey.contentModificationDateKey] as? Date ?? Date.distantPast,
                                                   size: (properties[URLResourceKey.fileSizeKey] as? NSNumber)?.int64Value ?? 0,
                                                   icon: icon,
                                                   isFolder: (properties[URLResourceKey.isDirectoryKey] as? NSNumber)?.boolValue ?? false,
                                                   color: NSColor()))
                    } catch {
                        log.debug("Error reading file attributes")
                    }
                }
            }
            
            completion()
        }
        
    }
    
    private func thumbnailForVideoAtURL(url: URL) -> NSImage? {
        
        let asset = AVAsset(url: url)
        let assetImageGenerator = AVAssetImageGenerator(asset: asset)
        
        var time = asset.duration
        time.value = min(time.value, 2)
        
        do {
            let imageRef = try assetImageGenerator.copyCGImage(at: time, actualTime: nil)
            //return NSImage(CGImage: imageRef)
            return NSImage(cgImage: imageRef, size: .zero)
        } catch {
            print("error")
            return nil
        }
    }
    
    func contentsOrderedBy(_ orderedBy: FileOrder, ascending: Bool) -> [Metadata] {
        let sortedFiles: [Metadata]
        switch orderedBy {
        case .name:
            sortedFiles = files.sorted {
                return sortMetadata(lhsIsFolder: true, rhsIsFolder: true, ascending: ascending,
                                    attributeComparation: itemComparator(lhs: $0.name, rhs: $1.name, ascending: ascending))
            }
        case .newPath:
            sortedFiles = files.sorted {
                return sortMetadata(lhsIsFolder: true, rhsIsFolder: true, ascending: ascending,
                                    attributeComparation: itemComparator(lhs: $0.newPath, rhs: $1.newPath, ascending: ascending))
            }
        case .size:
            sortedFiles = files.sorted {
                return sortMetadata(lhsIsFolder: true, rhsIsFolder: true, ascending: ascending,
                                    attributeComparation: itemComparator(lhs: $0.size, rhs: $1.size, ascending: ascending))
            }
        case .exifDate:
            sortedFiles = files.sorted {
                return sortMetadata(lhsIsFolder: true, rhsIsFolder: true, ascending: ascending,
                                    attributeComparation: itemComparator(lhs: $0.exifDateTimeOriginal ?? Date(), rhs: $1.exifDateTimeOriginal ?? Date(), ascending: ascending))
            }
        case .createDate:
            sortedFiles = files.sorted {
                return sortMetadata(lhsIsFolder: true, rhsIsFolder: true, ascending: ascending,
                                    attributeComparation: itemComparator(lhs: $0.createDate, rhs: $1.createDate, ascending: ascending))
            }
        case .modifiedDate:
            sortedFiles = files.sorted {
                return sortMetadata(lhsIsFolder: true, rhsIsFolder: true, ascending: ascending,
                                    attributeComparation: itemComparator(lhs: $0.modifiedDate, rhs: $1.modifiedDate, ascending: ascending))
            }
        }
        return sortedFiles
    }
    
    public func processNewPath(_ photoIdentifer: String = DefaultValues.identifer.rawValue,
                               dateFormat: String? = DefaultValues.dateFormat.rawValue,
                               currentFile: @escaping (String) -> Void,
                               completion: @escaping () -> Void,
                               failure: @escaping (_ error: Error?) -> Void ) {
        
        DispatchQueue.global(qos: .userInitiated).async {
            
            let fileManager = FileManager.default
            
            // TODO: don't hardcode this
            var destFolderPath = ""
            let videoDestFolder = "video"
            let imageDestFolder = "image"
            let errorDestFolder = "error"
            
            for (index, file) in self.files.enumerated() {
                var processedFile = file
                log.debug("file: \(file) ext: \(String(describing: file.fileExtension))")
                
                log.debug("Processing name: \(file.name) path: \(file.url)")
                currentFile(file.name)
                //sleep(1)
                var date: Date?
                var newPath: String?
                
                // TODO: don't hardcode file extensions
                if let fileExtension = file.fileExtension {
                    switch fileExtension.uppercased() {
                    case "JPG", "PNG", "HEIC", "CR2", "JPEG", "TIF":
                        date = MediaUtil.getPhotoExifDateTimeOriginal(file.url.path)
                        destFolderPath = imageDestFolder
                    case "MOV", "MP4", "M4V":
                        date = MediaUtil.getVideoCreationDate(URL(fileURLWithPath: file.url.path))
                        destFolderPath = videoDestFolder
                        
                        // Live Photo should go in image directory
                        let jpgLivePhotoPath = file.url.path.replacingOccurrences(of: fileExtension, with: "JPG")
                        let jpegLivePhotoPath = file.url.path.replacingOccurrences(of: fileExtension, with: "JPEG")
                        let heicLivePhotoPath = file.url.path.replacingOccurrences(of: fileExtension, with: "HEIC")
                        let tifLivePhotoPath = file.url.path.replacingOccurrences(of: fileExtension, with: "TIF")
//                        log.debug("jpgLivePhotoPath: \(jpgLivePhotoPath)")
//                        log.debug("heicLivePhotoPath: \(heicLivePhotoPath)")
                        
//                        if fileManager.fileExists(atPath: jpgLivePhotoPath) ||
//                            fileManager.fileExists(atPath: heicLivePhotoPath) ||
//                            fileManager.fileExists(atPath: jpegLivePhotoPath) ||
//                            fileManager.fileExists(atPath: tifLivePhotoPath) {
//                            log.debug("JPG/HEIC/JPEG/TIF Live Photo Found")
//                            destFolderPath = imageDestFolder
//                        }
                        if fileManager.fileExists(atPath: jpgLivePhotoPath) {
                            log.debug("JPG Live Photo Found")
                            let matchingPhoto = file.url.path.replacingOccurrences(of: fileExtension, with: "JPG")
                            date = MediaUtil.getPhotoExifDateTimeOriginal(matchingPhoto)
                            destFolderPath = imageDestFolder
                        }
                        if fileManager.fileExists(atPath: heicLivePhotoPath) {
                            log.debug("HEIC Live Photo Found")
                            let matchingPhoto = file.url.path.replacingOccurrences(of: fileExtension, with: "HEIC")
                            date = MediaUtil.getPhotoExifDateTimeOriginal(matchingPhoto)
                            destFolderPath = imageDestFolder
                        }
                        if fileManager.fileExists(atPath: jpegLivePhotoPath) {
                            log.debug("JPEG Live Photo Found")
                            let matchingPhoto = file.url.path.replacingOccurrences(of: fileExtension, with: "JPEG")
                            date = MediaUtil.getPhotoExifDateTimeOriginal(matchingPhoto)
                            destFolderPath = imageDestFolder
                        }
                        if fileManager.fileExists(atPath: tifLivePhotoPath) {
                            log.debug("TIF Live Photo Found")
                            let matchingPhoto = file.url.path.replacingOccurrences(of: fileExtension, with: "TIF")
                            date = MediaUtil.getPhotoExifDateTimeOriginal(matchingPhoto)
                            destFolderPath = imageDestFolder
                        }
                        
                    default:
                        log.debug("No valid extension found for: \(fileExtension.uppercased())")
                    }
                }
                log.debug("destFolderPath: \(destFolderPath)")
                log.debug("date: \(String(describing: date))")
                
                if let date = date {
                    processedFile.exifDateTimeOriginal = date
                    let dateFormatter = DateFormatter()
                    dateFormatter.dateFormat = dateFormat
                    let fDate = dateFormatter.string(from: date)
                    let filename: String?
                    
                    if photoIdentifer.isEmpty {
                        filename  = "\(fDate)-\(file.name)"
                    } else {
                        filename  = "\(fDate)-\(photoIdentifer)-\(file.name)"
                    }
                    
                    log.debug("filename: \(String(describing: filename))")
                    if let filename = filename {
                        newPath = "\(destFolderPath)/\(filename)"
                    }
                }
                
                if newPath == nil {
                    newPath = "\(errorDestFolder)/\(file.name)"
                }
                
                processedFile.newPath = newPath!
                self.files[index] = processedFile
            }
            log.debug("calling completion")
            completion()
        }
    }
    
}

// MARK: - Sorting

func sortMetadata(lhsIsFolder: Bool, rhsIsFolder: Bool, ascending: Bool, attributeComparation: Bool ) -> Bool {
    if( lhsIsFolder && !rhsIsFolder) {
        return ascending ? true : false
    } else if ( !lhsIsFolder && rhsIsFolder ) {
        return ascending ? false : true
    }
    return attributeComparation
}

func itemComparator<T: Comparable>(lhs: T, rhs: T, ascending: Bool ) -> Bool {
    return ascending ? (lhs < rhs) : (lhs > rhs)
}

public func == (lhs: Date, rhs: Date) -> Bool {
    if lhs.compare(rhs) == .orderedSame {
        return true
    }
    return false
}

public func<(lhs: Date, rhs: Date) -> Bool {
    if lhs.compare(rhs) == .orderedAscending {
        return true
    }
    return false
}
