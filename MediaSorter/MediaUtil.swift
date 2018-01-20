//
//  MediaUtil.swift
//  MediaSorter
//
//  Created by Doug Diego on 11/11/17.
//  Copyright © 2017 razeware. All rights reserved.
//

import CoreGraphics
import AVFoundation

public class MediaUtil {

    public static func getPhotoExifDateTimeOriginal(_ filePath: String) -> Date? {
        let imageURL = URL(fileURLWithPath: filePath)

        guard let imageSource = CGImageSourceCreateWithURL(imageURL as CFURL, nil) else {
            log.debug("💥  Cannot find image at '\(filePath)'")
            return nil
        }

        let imageProperties = CGImageSourceCopyPropertiesAtIndex(imageSource, 0, nil) as Dictionary?
        let exifDict = imageProperties?[kCGImagePropertyExifDictionary]
        if let dateTimeOriginal = exifDict?[kCGImagePropertyExifDateTimeOriginal] as? String {
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy:MM:dd HH:mm:ss"
            let date = dateFormatter.date(from: dateTimeOriginal)
            return date
        } else {
            log.debug("not a string date")
        }
        return nil
    }

    public static func getVideoCreationDate(_ fileUrl: URL) -> Date? {

        let asset = AVURLAsset(url: fileUrl, options: nil)
        if let creationDate = asset.creationDate {
            return creationDate.dateValue
        }
        return nil
    }

}
