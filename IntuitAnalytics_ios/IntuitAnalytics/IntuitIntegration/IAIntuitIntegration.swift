//
//  IAIntuitIntegration.swift
//  IntuitAnalytics
//
//  Created by Hall, Jason on 4/8/16.
//  Copyright © 2016 Intuit, Inc. All rights reserved.
//

import Foundation

class IAIntuitIntegration: NSObject, IAIntegration
{
    let maximumEventCount = 100
    
    var isFlushing = false
    let coreData: IAIntuitIntegrationCoreData
    let dispatcher: IAIntuitIntegrationTrinityDispatcher
    let configuration: IAConfiguration
    var delegate: IAMobileComponentEventDelegate?
    
    internal init(configuration: IAConfiguration, coreData: IAIntuitIntegrationCoreData, dispatcher: IAIntuitIntegrationTrinityDispatcher)
    {
        self.configuration = configuration
        self.coreData = coreData
        self.dispatcher = dispatcher
        
        super.init()

        NSNotificationCenter.defaultCenter().addObserver(self, selector: "trackMobileComponentEvent:", name: "MobileComponentEvent", object: nil)
    }
    
    convenience required init(configuration: IAConfiguration)
    {
        let coreDataConfig = IAIntuitIntegrationCoreDataConfig()
        coreDataConfig.bundleClass = IAIntuitIntegrationCoreData.self
        coreDataConfig.dataModelFile = "IAIntuitIntegrationCoreDataModel"
        coreDataConfig.persistentStoreFile = "IAIntuitIntegrationCoreData"

        let intuitIntegrationCoreData = IAIntuitIntegrationCoreData(config: coreDataConfig)
        let intuitIntegrationTrinityDispatcher = IAIntuitIntegrationTrinityDispatcher(configuration: configuration)
        self.init(configuration: configuration, coreData: intuitIntegrationCoreData, dispatcher: intuitIntegrationTrinityDispatcher)
    }
    
    func trackEvent(name: String, properties: [String : AnyObject]?)
    {
        trackEvent(name, properties: properties, topic: self.configuration.intuitIntegrationTopic!)
    }
    
    internal func trackEvent(name: String, properties: [String : AnyObject]?, topic: String)
    {
        self.coreData.trackEvent(name, uniqueId: self.configuration.uniqueId, properties: properties, topic: topic)
        
        overallEventCount { (count) -> Void in
            if count >= self.maximumEventCount
            {
                NSNotificationCenter.defaultCenter().postNotificationName("IAIntegrationFlushRequiredNotification", object: nil, userInfo: ["eventCount" : count])
            }
        }
    }
    
    func flush()
    {
        if(!isFlushing)
        {
            self.coreData.allEventsSeparatedByTopic { (resultsDict) -> Void in
                
                guard let resultsDict = resultsDict where resultsDict.count > 0 else
                {
                    IALogger.logInfo("Flush called but no events were returned for flushing.")
                    self.isFlushing = false
                    return
                }
                
                for aTopic: String in resultsDict.keys
                {
                    IALogger.logInfo("Flushing events for topic: \(aTopic)")
                    
                    if let events = resultsDict[aTopic]
                    {
                        IALogger.logDebug("Events: \(events)")
                        
                        self.dispatcher.dispatch(events, completionHandler: { (data, urlResponse, error) -> Void in
                            if let httpResponse = urlResponse as? NSHTTPURLResponse
                            {
                                if httpResponse.statusCode == 200
                                {
                                    // If we got a 200 back, we can delete the events that were already dispatched
                                    IALogger.logDebug("Dispatch completed successfully. \(events.count) events sent to \(urlResponse!.URL!).")
                                    self.coreData.deleteEvents(events)
                                }
                                else
                                {
                                    IALogger.logError("Non-200 HTTP Response received: \(httpResponse)")
                                }
                            }
                            
                            if let error = error
                            {
                                IALogger.logError("Error occurred while dispatching events: \(error)")
                            }
                            
                            self.isFlushing = false
                        })
                    }
                }
            }
        }
        else
        {
            IALogger.logInfo("Skipping flush as a flush is already in progress")
        }
    }
    
    func overallEventCount(completionHandler: (count: Int) -> Void)
    {
        self.coreData.overallEventCount { (count) -> Void in
            completionHandler(count: count)
        }
    }
    
    internal func mergeDictionaries(dict1: [String : AnyObject], dict2: [String : AnyObject]) -> [String : AnyObject]?
    {
        let mergedDictionary: NSMutableDictionary = NSMutableDictionary()
        mergedDictionary.addEntriesFromDictionary(dict1)
        mergedDictionary.addEntriesFromDictionary(dict2)
        
        return mergedDictionary as NSDictionary as? [String : AnyObject]
    }
    
// MARK: - Notifications
    
    func trackMobileComponentEvent(notification: NSNotification)
    {
        guard let userInfo = notification.userInfo else
        {
            IALogger.logError("Mobile Component Event notification occurred without userInfo")
            return
        }
        
        guard let name = userInfo["event_name"] as? String, let metadataDictionary = notification.object as? [String : AnyObject] else
        {
            return
        }

        // All Mobile Componet Events should have a topic associated with them.
        guard let topic = metadataDictionary["topic"] as? String else
        {
            return
        }
        
        var finalEventProperties: [String : AnyObject] = [String : AnyObject]();
        if let properties = userInfo["event_properties"] as? [String : AnyObject]
        {
            finalEventProperties = mergeDictionaries(finalEventProperties, dict2: properties)!
        }
        
        if let delegate = self.delegate
        {
            if let delegateModifiedProperties = delegate.mobileComponentEventPosted(name, eventDictionary: finalEventProperties, topic: topic)
            {
                finalEventProperties = mergeDictionaries(finalEventProperties, dict2: delegateModifiedProperties)!
            }
        }
        
        // We are no longer going to use the event-specified topics for endpoint determination in Trinity.
        // Instead, we will be placing this topic name into the event properties and sending ALL mobile
        // events to our cto-mobile-analytics
        finalEventProperties["topic"] = topic
        
        
        
        IALogger.log("Tracking mobile component event: \(name) - \(finalEventProperties)", logLevel: .Debug)
        trackEvent(name, properties: finalEventProperties, topic: "cto-mobile-analytics")
    }
    
    deinit
    {
        IALogger.logDebug("Deinit called on IAIntuitIntegration.")
        
        // This work will no longer be required once we move to support only iOS 9 and higher:
        // https://developer.apple.com/library/mac/releasenotes/Foundation/RN-Foundation/index.html#10_11NotificationCenter
        NSNotificationCenter.defaultCenter().removeObserver(self, name: "MobileComponentEvent", object: nil)
    }
}