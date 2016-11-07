//
//  EventTests.swift
//  IntuitAnalytics
//
//  Created by Hall, Jason on 4/18/16.
//  Copyright © 2016 Intuit, Inc. All rights reserved.
//

import XCTest
@testable import IntuitAnalytics

class EventTests: XCTestCase {

    func testEventJSONRepresentation()
    {
        let coreDataConfig = IAIntuitIntegrationCoreDataConfig()
        coreDataConfig.bundleClass = IAIntuitIntegrationCoreData.self
        coreDataConfig.dataModelFile = "IAIntuitIntegrationCoreDataModel"
        coreDataConfig.persistentStoreFile = "IAIntuitIntegrationCoreData"
        
        let coreData = IAIntuitIntegrationCoreData(config: coreDataConfig)
        coreData.trackEvent("my test event name", uniqueId: "abcd", properties: ["testKey":"testValue"], topic: "cto-test-topic")
        
        let trackEventExpectation = self.expectationWithDescription("Async trackEvent() call");
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 1 * Int64(NSEC_PER_SEC)), dispatch_get_main_queue(), { () -> Void in
            coreData.allEvents({ (resultsArray) -> Void in
                let event = resultsArray?.first

                let eventDictionary = event!.dictionaryRepresentation()!
                XCTAssertEqual(eventDictionary["name"] as? String, "my test event name")
                XCTAssertEqual(eventDictionary["uniqueId"] as? String, "abcd")
                XCTAssertEqual(eventDictionary["properties"] as? NSDictionary, NSDictionary(dictionary: ["testKey":"testValue"]))
                
                trackEventExpectation.fulfill()
            })
        })
        
        self.waitForExpectationsWithTimeout(5, handler: nil)
    }

}
