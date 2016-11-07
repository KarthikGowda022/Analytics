//
//  IAIntuitIntegrationCoreData.swift
//  IntuitAnalytics
//
//  Created by Hall, Jason on 4/15/16.
//  Copyright © 2016 Intuit, Inc. All rights reserved.
//

import Foundation
import CoreData

class IAIntuitIntegrationCoreData
{
    let maximumDatabaseEventCount = 2000
    let config: IAIntuitIntegrationCoreDataConfig
    let mainManagedObjectContext: NSManagedObjectContext
    let privateManagedObjectContext: NSManagedObjectContext
    
    var managedObjectModel: NSManagedObjectModel?
    {
        guard let bundleClass = config.bundleClass else
        {
            IALogger.logError("Bundle class was not set in IAIntuitIntegrationCoreDataConfig")
            return nil
        }
        
        let analyticsFramework = NSBundle(forClass: bundleClass)
        guard let modelURL = NSBundle(path: analyticsFramework.bundlePath)!.URLForResource(config.dataModelFile, withExtension: "momd") else
        {
            IALogger.logError("Unable to find IAIntuitIntegrationCoreDataModel.momd")
            return nil
        }
        
        guard let managedObjectModel = NSManagedObjectModel(contentsOfURL: modelURL) else
        {
            IALogger.logError("Error loading managed object model: \(modelURL)")
            return nil
        }
        
        return managedObjectModel
    }
    
    var persistentStoreCoordinator: NSPersistentStoreCoordinator?
    {
        guard let managedObjectModel = self.managedObjectModel else
        {
            IALogger.logError("Unable to create persistent store coordinator because self.managedObjectModel is nil")
            return nil
        }
        
        let coordinator = NSPersistentStoreCoordinator(managedObjectModel: managedObjectModel)
        
        let applicationDocumentsDirectory = NSFileManager.defaultManager().URLsForDirectory(.DocumentDirectory, inDomains: .UserDomainMask).last
        
        guard let persistentStoreFile = config.persistentStoreFile else
        {
            IALogger.logError("Valid persistent store file was not provided in IAIntuitIntegrationCoreDataConfig")
            return nil
        }
        
        let storeURL = applicationDocumentsDirectory?.URLByAppendingPathComponent("\(persistentStoreFile).sqlite")
        
        do
        {
            try coordinator.addPersistentStoreWithType(NSSQLiteStoreType, configuration: nil, URL: storeURL, options: nil)
        }
        catch
        {
            IALogger.logError("An error occurred while setting up the persistent store coordinator: \(error)")
        }
        
        return coordinator
    }
    
    init(config: IAIntuitIntegrationCoreDataConfig)
    {
        self.config = config
        
        self.mainManagedObjectContext = NSManagedObjectContext(concurrencyType: .MainQueueConcurrencyType)
        self.privateManagedObjectContext = NSManagedObjectContext(concurrencyType: .PrivateQueueConcurrencyType)
        
        self.mainManagedObjectContext.persistentStoreCoordinator = persistentStoreCoordinator
        self.privateManagedObjectContext.parentContext = self.mainManagedObjectContext
    }
    
    func trackEvent(name: String, uniqueId: String?, properties: [String : AnyObject]?, topic: String)
    {
        IALogger.logDebug("IAIntuitIntegrationCoreData.trackEvent: name: \(name) uniqueId: \(uniqueId) properties: \(properties) topic: \(topic)")
        
        deleteOldestEventIfNeeded { () -> Void in
            // The first step is to track this event's topic.  Either a new topic will
            // be created or existing one will be returned.
            self.trackTopic(topic, completionHandler: { (topicObject) -> Void in
                do
                {
                    // Once we have the topicObject, we can associate the new event with its related Topic
                    let newEventObject = NSEntityDescription.insertNewObjectForEntityForName("Event", inManagedObjectContext: self.privateManagedObjectContext) as! Event
                    newEventObject.name = name
                    newEventObject.uniqueId = uniqueId
                    newEventObject.properties = properties
                    newEventObject.topic = topicObject
                    
                    newEventObject.timestamp = NSDate()
                    
                    try self.privateManagedObjectContext.save()
                }
                catch
                {
                    IALogger.logError("Failure to save context: \(error)")
                }
            })
        }
    }
    
    func trackTopic(name: String, completionHandler: (topic: Topic) -> Void)
    {
        IALogger.logDebug("Track topic: \(name)")
        // We try to get the Topic from the DB.  If it doesn't exist, then we need to create it.
        topicForName(name) { (topic) -> Void in
            if let topic = topic
            {
                completionHandler(topic: topic)
            }
            else
            {
                self.privateManagedObjectContext.performBlock {
                    do
                    {
                        let newTopic = NSEntityDescription.insertNewObjectForEntityForName("Topic", inManagedObjectContext: self.privateManagedObjectContext) as! Topic
                        newTopic.name = name
                        
                        try self.privateManagedObjectContext.save()
                        
                        completionHandler(topic: newTopic)
                    }
                    catch
                    {
                        IALogger.logError("Failure to save context: \(error)")
                    }
                    
                }
            }
        }
    }
    
    func topicForName(name: String, completionHandler: (topic: Topic?) -> Void)
    {
        IALogger.logDebug("Fetch topic for name: \(name)")
        self.privateManagedObjectContext.performBlock
            {
                do
                {
                    let predicate = NSPredicate(format: "name = %@", name)
                    let fetchRequest = NSFetchRequest(entityName: "Topic")
                    fetchRequest.predicate = predicate
                    
                    let resultsArray = try self.privateManagedObjectContext.executeFetchRequest(fetchRequest)
                    
                    if resultsArray.count > 0
                    {
                        completionHandler(topic: resultsArray.first as? Topic)
                    }
                    else
                    {
                        completionHandler(topic: nil)
                    }
                }
                catch
                {
                    IALogger.logError("Error while getting allEvents(): \(error)")
                }
        }
    }
    
    func allEvents(completionHandler: (resultsArray: [Event]?) -> Void)
    {
        IALogger.logDebug("Fetch all events")
        self.privateManagedObjectContext.performBlock
        {
            do
            {
                let sortDescriptor = NSSortDescriptor(key: "timestamp", ascending: true)
                let fetchRequest = NSFetchRequest(entityName: "Event")
                fetchRequest.sortDescriptors = [sortDescriptor]
                
                let resultsArray = try self.privateManagedObjectContext.executeFetchRequest(fetchRequest)
                
                completionHandler(resultsArray: resultsArray as? [Event])
            }
            catch
            {
                IALogger.logError("Error while getting allEvents(): \(error)")
            }
        }
    }
    
    func allEventsSeparatedByTopic(completionHandler: (resultsDict: [String : [Event]]?) -> Void)
    {
        allEvents { (resultsArray) -> Void in
            if let resultsArray = resultsArray
            {
                var resultsDict = [String : [Event]]()
                
                for anEvent in resultsArray
                {
                    guard let eventTopic = anEvent.topic?.name else
                    {
                        break
                    }
                    
                    var eventArrayForTopic: [Event]
                    if let existingArray = resultsDict[eventTopic]
                    {
                        eventArrayForTopic = existingArray
                    }
                    else
                    {
                        eventArrayForTopic = [Event]()
                    }
                    
                    eventArrayForTopic.append(anEvent)
                    resultsDict[eventTopic] = eventArrayForTopic
                }
                
                completionHandler(resultsDict: resultsDict)
            }
        }
    }
    
    func overallEventCount(completionHandler:(count: Int) -> Void)
    {
        allEvents { (resultsArray) -> Void in
            if let resultsArray = resultsArray
            {
                 completionHandler(count: resultsArray.count)
            }
            else
            {
                completionHandler(count: 0)
            }
        }
    }
    
    func deleteEvents(events: [Event])
    {
        self.privateManagedObjectContext.performBlock
        {
            do
            {
                for anEvent in events
                {
                    // We need to use if-let here because we can actually get into situations where
                    // this event has already been deleted by another thread (due to things like 
                    // deletion of events because the database maximum count has been reached).  We
                    // have observed crashing on unwrapping the event name for logging when this event
                    // was already deleted.  Thankfully, trying to actually call deleteObject() doesn't
                    // crash when the event is already gone.
                    if let eventName = anEvent.name
                    {
                        IALogger.logInfo("Deleting event: \(eventName)")
                    }
                    else
                    {
                        IALogger.logDebug("It looks like we're attempting to delete an already deleted event.  Moving on...")
                    }
                    
                    self.privateManagedObjectContext.deleteObject(anEvent)
                }
                
                try self.privateManagedObjectContext.save()
            }
            catch
            {
                IALogger.logError("Error while deleting events: \(error)")
            }
            
        }
    }
    
    func deleteOldestEventIfNeeded(completionHandler:() -> Void)
    {
        self.overallEventCount { (count) -> Void in
            if count >= self.maximumDatabaseEventCount
            {
                IALogger.logInfo("Maximum database event count was reached.  Deleting oldest event.")
                self.privateManagedObjectContext.performBlock
                {
                    do
                    {
                        let sortDescriptor = NSSortDescriptor(key: "timestamp", ascending: true)
                        let fetchRequest = NSFetchRequest(entityName: "Event")
                        fetchRequest.sortDescriptors = [sortDescriptor]
                        fetchRequest.fetchLimit = 1
                        
                        let resultsArray = try self.privateManagedObjectContext.executeFetchRequest(fetchRequest)
                        
                        if let event = resultsArray.first as? Event
                        {
                            IALogger.logDebug("Deleted event: \(event.name)")
                            self.privateManagedObjectContext.deleteObject(event)
                        }
                        
                        try self.privateManagedObjectContext.save()
                    }
                    catch
                    {
                        IALogger.logError("Error while deleting oldest event: \(error)")
                    }
                    
                    completionHandler()
                }
            }
            else
            {
                completionHandler()
            }
        }
    }
}