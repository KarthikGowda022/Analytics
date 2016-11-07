//
//  Event.swift
//  IntuitAnalytics
//
//  Created by Hall, Jason on 4/15/16.
//  Copyright © 2016 Intuit, Inc. All rights reserved.
//

import Foundation
import CoreData


class Event: NSManagedObject {

// Insert code here to add functionality to your managed object subclass

    func dictionaryRepresentation() -> [String : AnyObject]?
    {
        var dictionary = [String: AnyObject]()
        dictionary["name"] = self.name
        dictionary["uniqueId"] = self.uniqueId
        dictionary["properties"] = self.properties
        
        guard let timeInSeconds = self.timestamp?.timeIntervalSince1970 else {
            dictionary["timestamp"] = 0
            return dictionary
        }
        
        let timeInMilliseconds = timeInSeconds * 1000
        dictionary["timestamp"] = NSNumber(longLong: Int64(timeInMilliseconds))
        
        return dictionary
    }
}
