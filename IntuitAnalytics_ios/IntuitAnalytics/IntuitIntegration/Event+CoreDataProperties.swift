//
//  Event+CoreDataProperties.swift
//  IntuitAnalytics
//
//  Created by Hall, Jason on 5/2/16.
//  Copyright © 2016 Intuit, Inc. All rights reserved.
//
//  Choose "Create NSManagedObject Subclass…" from the Core Data editor menu
//  to delete and recreate this implementation file for your updated model.
//

import Foundation
import CoreData

extension Event {

    @NSManaged var uniqueId: String?
    @NSManaged var name: String?
    @NSManaged var properties: NSObject?
    @NSManaged var timestamp: NSDate?
    @NSManaged var topic: Topic?

}
