//
//  IAIntuitIntegrationTrinityDispatcherTests.swift
//  IntuitAnalytics
//
//  Created by Hall, Jason on 5/18/16.
//  Copyright © 2016 Intuit, Inc. All rights reserved.
//

import XCTest
@testable import IntuitAnalytics

class IAIntuitIntegrationTrinityDispatcherTests: XCTestCase
{
    var config: IAConfiguration?
    var coreData: IAIntuitIntegrationCoreData?

    override func setUp()
    {
        let config = IAConfiguration()
        config.intuitIntegrationTopic = "dummy-topic"
        config.intuitIntegrationHostname = "dummy.intuit.com"
        self.config = config
        
        let coreDataConfig = IAIntuitIntegrationCoreDataConfig()
        coreDataConfig.bundleClass = IAIntuitIntegrationCoreData.self
        coreDataConfig.dataModelFile = "IAIntuitIntegrationCoreDataModel"
        coreDataConfig.persistentStoreFile = "IAIntuitIntegrationCoreData"
        
        let coreData = IAIntuitIntegrationCoreData(config: coreDataConfig)
        self.coreData = coreData
        
        let uniqueId = "unique 123"
        coreData.trackEvent("event 1", uniqueId: uniqueId, properties: nil, topic: "topic1")
        coreData.trackEvent("event 1", uniqueId: uniqueId, properties: nil, topic: "topic1")
        
        coreData.trackEvent("event 1", uniqueId: uniqueId, properties: nil, topic: "topic2")
        coreData.trackEvent("event 1", uniqueId: uniqueId, properties: nil, topic: "topic2")
        coreData.trackEvent("event 1", uniqueId: uniqueId, properties: nil, topic: "topic2")
        
        coreData.trackEvent("event 1", uniqueId: uniqueId, properties: nil, topic: "topic3")
    }
    
    func testDispatch()
    {
        let dispatcher = IAIntuitIntegrationTrinityDispatcher(configuration: config!)
        
        let expectation = expectationWithDescription("Complete the dispatch")
        
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 2 * Int64(NSEC_PER_SEC)), dispatch_get_main_queue()) {
            self.coreData?.allEvents({ (resultsArray) in
                
                dispatcher.dispatch(resultsArray!, completionHandler: { (data, response, error) in
                    //
                    
                    expectation.fulfill()
                })
            })
        }
        
        waitForExpectationsWithTimeout(5, handler: nil)
    }
    
    func testConstructAnalyticsPayloadDictionary()
    {
        let expectation = expectationWithDescription("Validate the payload")
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 2 * Int64(NSEC_PER_SEC)), dispatch_get_main_queue()) {
            self.coreData?.allEvents({ (resultsArray) in
                let dispatcher = IAIntuitIntegrationTrinityDispatcher(configuration: self.config!)
                let payload = dispatcher.constructAnalyticsPayloadDictionary(resultsArray!)
                
                XCTAssertEqual(payload["data_version"] as? String, "2.0")
                XCTAssertEqual(payload["data"]!["events"]!!.count, 6)
                
                expectation.fulfill()
            })
        }
        
        waitForExpectationsWithTimeout(5, handler: nil)
    }
}