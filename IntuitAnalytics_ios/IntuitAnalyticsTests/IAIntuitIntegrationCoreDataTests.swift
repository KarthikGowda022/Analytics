//
//  IAIntuitIntegrationCoreDataTests.swift
//  IntuitAnalytics
//
//  Created by Hall, Jason on 4/15/16.
//  Copyright © 2016 Intuit, Inc. All rights reserved.
//

import XCTest
@testable import IntuitAnalytics

/*
IMPORTANT:  There are a lot of async operations that occur within the IAIntuitIntegrationCoreData
class.  In order to make these async operations testable, we will use Swift's expectation support
in conjunction with the somewhat clumsy dispatch_after pattern to allow the async processes to
complete before attempting to validate the test.

This is not ideal but it is the only way to test async methods that don't have completion handlers.
All of Apple's expectation functionality depends on the ability to pass a completion block to the
async method under test.  In the case of many methods in IAIntuitIntegrationCoreData, we do not
have a need to notify anyone of the completion of our core data operation so there is no completion
to take advantage of.
*/

class IAIntuitIntegrationCoreDataTests: XCTestCase {
    
    var coreData: IAIntuitIntegrationCoreData?
    var partialMockCoreData: MockIAIntuitIntegrationCoreData?
    
    class MockIAIntuitIntegrationCoreData: IAIntuitIntegrationCoreData
    {
        var eventCountToReturn = 1
        
        override func overallEventCount(completionHandler: (count: Int) -> Void) {
            completionHandler(count: eventCountToReturn)
        }
    }
    
    override func setUp()
    {
        let coreDataConfig = IAIntuitIntegrationCoreDataConfig()
        coreDataConfig.bundleClass = IAIntuitIntegrationCoreData.self
        coreDataConfig.dataModelFile = "IAIntuitIntegrationCoreDataModel"
        coreDataConfig.persistentStoreFile = "IAIntuitIntegrationCoreData"
        
        let coreData = IAIntuitIntegrationCoreData(config: coreDataConfig)
        self.coreData = coreData
        
        let partialMockCoreData = MockIAIntuitIntegrationCoreData(config: coreDataConfig)
        self.partialMockCoreData = partialMockCoreData
    }
    
    func testManagedObjectModelNotFound()
    {
        let coreDataConfig = IAIntuitIntegrationCoreDataConfig()
        coreDataConfig.bundleClass = IAIntuitIntegrationCoreData.self
        coreDataConfig.dataModelFile = "foo"
        coreDataConfig.persistentStoreFile = "IAIntuitIntegrationCoreData"
        
        let coreData = IAIntuitIntegrationCoreData(config: coreDataConfig)
        XCTAssertNil(coreData.managedObjectModel)
        XCTAssertNil(coreData.persistentStoreCoordinator)
    }
    
    func testTrackEvent()
    {
        // Check the case where we have no events in the core data DB
        let allEventsExpectation = self.expectationWithDescription("Async allEvents() call when zero events present")
        coreData!.allEvents { (resultsArray) -> Void in
            XCTAssertEqual(resultsArray?.count, 0)
            allEventsExpectation.fulfill()
        }
        
        coreData!.trackEvent("testEvent", uniqueId: "abcd", properties: ["tesKey" : "testValue"], topic: "cto-test-topic")
        
        let trackEventExpectation = self.expectationWithDescription("Async allEvents() call when 1 event present");
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 1 * Int64(NSEC_PER_SEC)), dispatch_get_main_queue(), { () -> Void in
            self.coreData!.allEvents({ (resultsArray) -> Void in
                XCTAssertEqual(resultsArray?.count, 1)
                
                trackEventExpectation.fulfill()
            })
        })
        
        self.waitForExpectationsWithTimeout(5, handler: nil)
    }
    
    func testAllEventsSeparatedByTopic()
    {
        coreData!.trackEvent("testEvent", uniqueId: "abcd", properties: ["tesKey" : "testValue"], topic: "cto-test-topic")
        coreData!.trackEvent("testEvent", uniqueId: "abcd", properties: ["tesKey" : "testValue"], topic: "other-test-topic")
        
        // Check the case where we have no events in the core data DB
        let allEventsExpectation = self.expectationWithDescription("Async allEvents() call when zero events present")
        coreData!.allEventsSeparatedByTopic({ (resultsDict) -> Void in
            print("Dict: \(resultsDict)")
            allEventsExpectation.fulfill()
        })
        
        
        coreData!.trackEvent("testEvent", uniqueId: "abcd", properties: ["tesKey" : "testValue"], topic: "cto-test-topic")
        
        let trackEventExpectation = self.expectationWithDescription("Async allEvents() call when 1 event present");
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 1 * Int64(NSEC_PER_SEC)), dispatch_get_main_queue(), { () -> Void in
            self.coreData!.allEventsSeparatedByTopic({ (resultsDict) -> Void in
                print("Dict: \(resultsDict)")
                trackEventExpectation.fulfill()
            })
        })
        
        self.waitForExpectationsWithTimeout(5, handler: nil)
    }
    
    func testDeleteEvents()
    {
        coreData!.trackEvent("eventToDelete", uniqueId: "abcd", properties: ["tesKey" : "testValue"], topic: "cto-test-topic")
        coreData!.trackEvent("eventToDelete", uniqueId: "abcd", properties: ["tesKey" : "testValue"], topic: "cto-test-topic")
        coreData!.trackEvent("eventToDelete", uniqueId: "abcd", properties: ["tesKey" : "testValue"], topic: "cto-test-topic")
        
        let expectation = self.expectationWithDescription("Delete all events passed");
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 1 * Int64(NSEC_PER_SEC)), dispatch_get_main_queue(), { () -> Void in
            self.coreData!.allEvents({ (resultsArray) -> Void in
                XCTAssertEqual(resultsArray?.count, 3)
                
                self.coreData!.deleteEvents(resultsArray!)
                
                dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 1 * Int64(NSEC_PER_SEC)), dispatch_get_main_queue(), { () -> Void in
                    self.coreData!.allEvents({ (resultsArray) -> Void in
                        XCTAssertEqual(resultsArray?.count, 0)
                        
                        expectation.fulfill()
                    })
                })
            })
        })
        
        self.waitForExpectationsWithTimeout(5, handler: nil)
    }
    
    func testDeleteOldestEventIfNeeded()
    {
        partialMockCoreData!.trackEvent("event1", uniqueId: "abcd", properties: ["tesKey" : "testValue"], topic: "cto-test-topic")
        partialMockCoreData!.trackEvent("event2", uniqueId: "abcd", properties: ["tesKey" : "testValue"], topic: "cto-test-topic")
        partialMockCoreData!.trackEvent("event3", uniqueId: "abcd", properties: ["tesKey" : "testValue"], topic: "cto-test-topic")
        partialMockCoreData!.trackEvent("event4", uniqueId: "abcd", properties: ["tesKey" : "testValue"], topic: "cto-test-topic")
        
        partialMockCoreData!.eventCountToReturn = 2000
        
        let expectation = expectationWithDescription("Check that only 2 events remain")
        
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 1 * Int64(NSEC_PER_SEC)), dispatch_get_main_queue(), { () -> Void in
            self.partialMockCoreData!.deleteOldestEventIfNeeded({
                self.partialMockCoreData!.allEvents({ (resultsArray) -> Void in
                    XCTAssertEqual(resultsArray?.count, 3)
                    XCTAssertEqual(resultsArray?[0].name, "event2")
                    XCTAssertEqual(resultsArray?[1].name, "event3")
                    XCTAssertEqual(resultsArray?[2].name, "event4")
                    
                    expectation.fulfill()
                })
            })
        })
        
        waitForExpectationsWithTimeout(5, handler: nil)
    }
}
