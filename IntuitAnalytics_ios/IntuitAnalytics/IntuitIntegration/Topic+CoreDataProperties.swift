//
//  Topic+CoreDataProperties.swift
//  IntuitAnalytics
//
//  Created by Hall, Jason on 4/26/16.
//  Copyright © 2016 Intuit, Inc. All rights reserved.
//
//  Choose "Create NSManagedObject Subclass…" from the Core Data editor menu
//  to delete and recreate this implementation file for your updated model.
//

import Foundation
import CoreData

extension Topic {

    @NSManaged var name: String?
    @NSManaged var events: Event?

}
