//
//  IAIntuitIntegration.swift
//  IntuitAnalytics
//
//  Created by Hall, Jason on 4/15/16.
//  Copyright © 2016 Intuit, Inc. All rights reserved.
//

import XCTest
import CoreData
@testable import IntuitAnalytics

class IAIntuitIntegrationTests: XCTestCase, IAMobileComponentEventDelegate {
    
    var config: IAConfiguration?
    
    class MockEvent: Event
    {
        override init(entity: NSEntityDescription, insertIntoManagedObjectContext context: NSManagedObjectContext?) {
            super.init(entity: entity, insertIntoManagedObjectContext: nil)
        }
    }
    
    class MockIntuitIntegrationCoreData: IAIntuitIntegrationCoreData
    {
        var expectation: XCTestExpectation?
        var mockOverallEventCount = 1
        var trackEventVerificationHandler: ((String?, String?, [String : AnyObject]?) -> Void)?
        
        override func trackEvent(name: String?, uniqueId: String?, properties: [String : AnyObject]?, topic: String)
        {
            guard let verificationHandler = trackEventVerificationHandler else
            {
                return
            }
            
            verificationHandler(name, uniqueId, properties)
        }
        
        override func overallEventCount(completionHandler: (count: Int) -> Void) {
            completionHandler(count: mockOverallEventCount)
        }
        
        override func allEventsSeparatedByTopic(completionHandler: (resultsDict: [String : [Event]]?) -> Void) {
            var resultsDict = [String : [Event]]()
            
            
            let topic = NSEntityDescription.insertNewObjectForEntityForName("Topic", inManagedObjectContext: privateManagedObjectContext) as! Topic
            topic.name = "BogusTopic"
            
            let event = NSEntityDescription.insertNewObjectForEntityForName("Event", inManagedObjectContext: privateManagedObjectContext) as! Event
            event.name = "MockEvent"
            event.topic = topic
            
            resultsDict["topic1"] = [event]
            resultsDict["topic2"] = [event]
            resultsDict["topic3"] = [event]
            
            completionHandler(resultsDict: resultsDict)
            
            expectation?.fulfill()
        }
        
        override func deleteEvents(events: [Event]) {
            // No-op
        }
    }
    
    class MockIntuitIntegrationTrinityDispatcher: IAIntuitIntegrationTrinityDispatcher
    {
        override func dispatch(events: [Event], completionHandler: (NSData?, NSURLResponse?, NSError?) -> Void) {
            let url = NSURL(string: "http://fake.server.com")
            let response = NSHTTPURLResponse(URL: url!, statusCode: 200, HTTPVersion: nil, headerFields: nil)
            
            completionHandler(nil, response, nil)
        }
    }
    
    func mobileComponentEventPosted(eventName: String, eventDictionary: [String : AnyObject]?, topic: String) -> [String : AnyObject]? {
        return ["delegate_key" : "delegate_value"]
    }
    
    override func setUp() {
        let aConfig = IAConfiguration()
        aConfig.intuitIntegrationTopic = "DummyTopic"
        aConfig.uniqueId = "abc123"
        
        self.config = aConfig
    }
    
    func testInit()
    {
        let instance = IAIntuitIntegration(configuration: config!)
        XCTAssertNotNil(instance.coreData)
        XCTAssertNotNil(instance.dispatcher)
    }
    
    func testTrackEvent()
    {
        let verification: (String?, String?, [String : AnyObject]?) -> Void = {
            (eventName, uniqueId, properties) -> Void in
                XCTAssertEqual(eventName, "testEvent")
                XCTAssertEqual(uniqueId, "abc123")
                XCTAssertEqual(properties!["testKey"] as? String, "testValue")
        }
        
        let coreDataConfig = IAIntuitIntegrationCoreDataConfig()
        let mockIntuitIntegrationCoreData = MockIntuitIntegrationCoreData(config:coreDataConfig)
        mockIntuitIntegrationCoreData.trackEventVerificationHandler = verification
        
        let intuitIntegration: IAIntuitIntegration = IAIntuitIntegration(configuration: config!, coreData: mockIntuitIntegrationCoreData, dispatcher: IAIntuitIntegrationTrinityDispatcher(configuration: config!))
        intuitIntegration.trackEvent("testEvent", properties: ["testKey" : "testValue"])
    }
    
    func testTrackEventWithMaxEventCount()
    {
        self.expectationForNotification("IAIntegrationFlushRequiredNotification", object: nil) { (notification) -> Bool in
            if let userInfo = notification.userInfo
            {
                let eventCount = userInfo["eventCount"]
                
                XCTAssertEqual(eventCount?.integerValue, 100)
            }
            
            return true
        }
        
        let coreDataConfig = IAIntuitIntegrationCoreDataConfig()
        let mockIntuitIntegrationCoreData = MockIntuitIntegrationCoreData(config:coreDataConfig)
        mockIntuitIntegrationCoreData.mockOverallEventCount = 100
        
        let intuitIntegration = IAIntuitIntegration(configuration: config!, coreData: mockIntuitIntegrationCoreData, dispatcher: IAIntuitIntegrationTrinityDispatcher(configuration: config!))
        intuitIntegration.trackEvent("eventThatGoesOverLimit", properties: nil)
        
        self.waitForExpectationsWithTimeout(5, handler: nil)
    }
    
    func testFlush()
    {
        let coreDataConfig = IAIntuitIntegrationCoreDataConfig()
        coreDataConfig.bundleClass = IAIntuitIntegrationCoreData.self
        coreDataConfig.dataModelFile = "IAIntuitIntegrationCoreDataModel"
        coreDataConfig.persistentStoreFile = "IAIntuitIntegrationCoreData"
        
        let mockIntuitIntegrationCoreData = MockIntuitIntegrationCoreData(config:coreDataConfig)
        
        let intuitIntegration = IAIntuitIntegration(configuration: config!, coreData: mockIntuitIntegrationCoreData, dispatcher: MockIntuitIntegrationTrinityDispatcher(configuration: config!))
        intuitIntegration.isFlushing = false
        
        let coreDataAllEventsSeparatedByTopicExpectation = expectationWithDescription("CoreData allEventsSeparatedByTopic should be called.")
        mockIntuitIntegrationCoreData.expectation = coreDataAllEventsSeparatedByTopicExpectation
        
        intuitIntegration.flush()
        
        self.waitForExpectationsWithTimeout(5, handler: nil)
    }
    
    func testMergeDictionaries()
    {
        let intuitIntegration: IAIntuitIntegration = IAIntuitIntegration(configuration: config!)
        
        let dict1 = ["d1k1" : "d1v1", "d1k2" : "d1v2"]
        let dict2 = ["d2k1" : "d2v1"]
        
        if let mergedDict = intuitIntegration.mergeDictionaries(dict1, dict2: dict2)
        {
            var expectedDict = ["d1k1" : "d1v1", "d1k2" : "d1v2", "d2k1" : "d2v1"]
            
            for key in mergedDict.keys
            {
                XCTAssertEqual(mergedDict[key] as? String, expectedDict[key])
                expectedDict.removeValueForKey(key)
            }
            
            XCTAssertEqual(expectedDict.count, 0)
        }
    }
        
    func testDispatch()
    {
        let config = IAConfiguration()
        config.intuitIntegrationTopic = "cto-test-topic"
        
        let intuitIntegration: IAIntuitIntegration = IAIntuitIntegration(configuration: config)
        intuitIntegration.trackEvent("testEvent", properties: ["testKey" : "testValue"])
        intuitIntegration.flush()
        
        let flushExpectation = self.expectationWithDescription("Flush")
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 5 * Int64(NSEC_PER_SEC)), dispatch_get_main_queue(), { () -> Void in
            
            flushExpectation.fulfill()
        })
        
        self.waitForExpectationsWithTimeout(10, handler: nil)
    }
    
    func testTrackMobileComponentEvent()
    {
        let trackMobileComponentEventExpectation = expectationWithDescription("Track Mobile Component event created.")
        
        let verification: (String?, String?, [String : AnyObject]?) -> Void = {
            (eventName, uniqueId, properties) -> Void in
            XCTAssertEqual(eventName, "TestEvent")
            XCTAssertEqual(uniqueId, "abc123")
            XCTAssertEqual(properties!["prop1"] as? String, "val1")
            XCTAssertEqual(properties!["prop2"] as? String, "val2")
            XCTAssertEqual(properties!["delegate_key"] as? String, "delegate_value")
            
            trackMobileComponentEventExpectation.fulfill()
        }
        
        let coreDataConfig = IAIntuitIntegrationCoreDataConfig()
        let mockIntuitIntegrationCoreData = MockIntuitIntegrationCoreData(config:coreDataConfig)
        mockIntuitIntegrationCoreData.trackEventVerificationHandler = verification
        
        let intuitIntegration: IAIntuitIntegration = IAIntuitIntegration(configuration: config!, coreData: mockIntuitIntegrationCoreData, dispatcher: IAIntuitIntegrationTrinityDispatcher(configuration: config!))
        intuitIntegration.delegate = self

        let mockNotification = NSNotification(name: "MobileComponentEvent", object: ["topic" : "dummy-topic"], userInfo: ["event_name" : "TestEvent", "event_properties" : ["prop1" : "val1", "prop2" : "val2"]])
        intuitIntegration.trackMobileComponentEvent(mockNotification)
        
        waitForExpectationsWithTimeout(5, handler: nil)
    }
}
