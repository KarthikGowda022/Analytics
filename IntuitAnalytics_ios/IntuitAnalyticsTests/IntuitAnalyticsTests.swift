//
//  IntuitAnalyticsTests.swift
//  IntuitAnalyticsTests
//
//  Created by Hall, Jason on 4/15/16.
//  Copyright © 2016 Intuit, Inc. All rights reserved.
//

import XCTest
@testable import IntuitAnalytics

class IntuitAnalyticsTests: XCTestCase
{
    var config: IAConfiguration?
    
    class MockIntuitIntegration: IAIntuitIntegration
    {
        var trackEventVerificationHandler: ((String, [String : AnyObject]?) -> Void)?
        
        override func trackEvent(name: String, properties: [String : AnyObject]?)
        {
            guard let verificationHandler = trackEventVerificationHandler else
            {
                return
            }
            
            verificationHandler(name, properties)
        }
    }
    
    class MockExternalIntegration: NSObject, IAIntegration
    {
        var trackEventVerificationHandler: ((String, [String : AnyObject]?) -> Void)?
        
        required init(configuration: IAConfiguration) {}
        
        func trackEvent(name: String, properties: [String : AnyObject]?)
        {
            guard let verificationHandler = trackEventVerificationHandler else
            {
                return
            }
            
            verificationHandler(name, properties)
        }
        
        func flush() {}
    }
    
    class MockDelegate: NSObject, IAMobileComponentEventDelegate
    {
        func mobileComponentEventPosted(eventName: String, eventDictionary: [String : AnyObject]?, topic: String) -> [String : AnyObject]?
        {
            return nil
        }
    }
    
    override func setUp() {
        let config = IAConfiguration()
        config.intuitIntegrationTopic = "DummyTopic"
        
        self.config = config
    }
    
    func testInit()
    {
        var instance = IntuitAnalytics(configuration: config!, externalIntegrations: nil)
        XCTAssertNotNil(instance.intuitIntegration)
        XCTAssertNil(instance.externalIntegrations)
        
        let integrations = [MockExternalIntegration(configuration: config!)]
        instance = IntuitAnalytics(configuration: config!, externalIntegrations: integrations)
        XCTAssertNotNil(instance.intuitIntegration)
        XCTAssertEqual(instance.externalIntegrations!.count, 1)
    }
    
    func testTrackEvent()
    {
        let verification : (String, [String : AnyObject]?) -> Void = {
            (eventName, eventProperties) -> Void in
                XCTAssertEqual(eventName, "testEvent")
                XCTAssertNil(eventProperties)
        }
        
        let mockIntuitIntegration = MockIntuitIntegration(configuration: config!)
        mockIntuitIntegration.trackEventVerificationHandler = verification
        
        let mockExternalIntegration = MockExternalIntegration(configuration: config!)
        mockExternalIntegration.trackEventVerificationHandler = verification
        
        // Test with external integration
        var instance = IntuitAnalytics(configuration: config!, intuitIntegration: mockIntuitIntegration, externalIntegrations: [mockExternalIntegration])
        instance.trackEvent("testEvent")
        
        // Test without external integration
        instance = IntuitAnalytics(configuration: config!, intuitIntegration: mockIntuitIntegration, externalIntegrations: nil)
        instance.trackEvent("testEvent")
    }
    
    func testTrackEventWithProperties()
    {
        let verification : (String, [String : AnyObject]?) -> Void = {
            (eventName, eventProperties) -> Void in
            XCTAssertEqual(eventName, "testEvent")
            XCTAssertEqual(eventProperties, NSDictionary(dictionary: [ "testKey" : "testProperty" ]))
        }
        
        let mockIntuitIntegration = MockIntuitIntegration(configuration: config!)
        mockIntuitIntegration.trackEventVerificationHandler = verification
        
        let mockExternalIntegration = MockExternalIntegration(configuration: config!)
        mockExternalIntegration.trackEventVerificationHandler = verification
        
        // Test with external integration
        var instance = IntuitAnalytics(configuration: config!, intuitIntegration: mockIntuitIntegration, externalIntegrations: [mockExternalIntegration])
        instance.trackEvent("testEvent", properties: [ "testKey" : "testProperty" ])
        
        // Test without external integration
        instance = IntuitAnalytics(configuration: config!, intuitIntegration: mockIntuitIntegration, externalIntegrations: nil)
        instance.trackEvent("testEvent", properties: [ "testKey" : "testProperty" ])
    }
    
    func testFlush()
    {
        let mockIntuitIntegration = MockIntuitIntegration(configuration: config!)
        
        let mockExternalIntegration = MockExternalIntegration(configuration: config!)
        
        // Test with external integration
        var instance = IntuitAnalytics(configuration: config!, intuitIntegration: mockIntuitIntegration, externalIntegrations: [mockExternalIntegration])
        instance.flush()
        
        // Test without external integration
        instance = IntuitAnalytics(configuration: config!, intuitIntegration: mockIntuitIntegration, externalIntegrations: nil)
        instance.flush()
    }
    
    func testDelegate()
    {
        // When the delegate is set on the IntuitAnalytics class, we need to ensure that it gets set automatically on the IAIntuitIntegration class as well.
        let instance = IntuitAnalytics(configuration: config!)
        let delegate = MockDelegate()
        instance.delegate = delegate
        
        XCTAssertNotNil(instance.delegate)
        XCTAssertNotNil(instance.intuitIntegration.delegate)
    }
    
    func testStartDispatchTimer()
    {
        let instance = IntuitAnalytics(configuration: config!)
        instance.dispatchTimerStarted = true
        instance.startDispatchTimer()
        
        // In this first case, we're checking that the timer doesn't get created because there's already supposed to be one according
        // to the dispatchTimerStarted flag.
        let dispatchTimerNilExpectation = self.expectationWithDescription("DispatchTimer should be nil.")
        
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 1 * Int64(NSEC_PER_SEC)), dispatch_get_main_queue(), { () -> Void in
            XCTAssertNil(instance.dispatchTimer)
            
            dispatchTimerNilExpectation.fulfill()
        })
        
        self.waitForExpectationsWithTimeout(5, handler: nil)
        
        // Now we check that one actually does get created when the dispatchTimerStarted flag is false.
        instance.dispatchTimerStarted = false
        instance.startDispatchTimer()
        let dispatchTimerNotNilExpectation = self.expectationWithDescription("DispatchTimer should not be nil.")
        
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 1 * Int64(NSEC_PER_SEC)), dispatch_get_main_queue(), { () -> Void in
            XCTAssertNotNil(instance.dispatchTimer)
            
            dispatchTimerNotNilExpectation.fulfill()
        })
        
        self.waitForExpectationsWithTimeout(5, handler: nil)
    }
    
    func testStopDispatchTimer()
    {
        let instance = IntuitAnalytics(configuration: config!)
        instance.dispatchTimerStarted = false
        instance.startDispatchTimer()
        
        let dispatchTimerNotNilExpectation = self.expectationWithDescription("DispatchTimer should not be nil.")
        
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 1 * Int64(NSEC_PER_SEC)), dispatch_get_main_queue(), { () -> Void in
            XCTAssertNotNil(instance.dispatchTimer)
            
            dispatchTimerNotNilExpectation.fulfill()
        })
        
        self.waitForExpectationsWithTimeout(5, handler: nil)
        
        instance.stopDispatchTimer()
        
        let dispatchTimerInvalidatedExpectation = self.expectationWithDescription("DispatchTimer should have been invalidated.")
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 1 * Int64(NSEC_PER_SEC)), dispatch_get_main_queue(), { () -> Void in
            XCTAssertEqual(instance.dispatchTimerStarted, false)
            XCTAssertEqual(instance.dispatchTimer?.valid, false)
            
            dispatchTimerInvalidatedExpectation.fulfill()
        })
        
        self.waitForExpectationsWithTimeout(5, handler: nil)
    }
    
    func testDispatchIntervalFromConfig()
    {
        let intervalConfig = IAConfiguration()
        intervalConfig.intuitIntegrationTopic = "DummyTopic"
        
        let instance = IntuitAnalytics(configuration: intervalConfig)
        
        XCTAssertEqual(instance.dispatchIntervalFromConfiguration(intervalConfig), 30)
        
        intervalConfig.dispatchInterval = 40
        
        XCTAssertEqual(instance.dispatchIntervalFromConfiguration(intervalConfig), 40)
        
        intervalConfig.dispatchInterval = 10
        
        XCTAssertEqual(instance.dispatchIntervalFromConfiguration(intervalConfig), 30)
        
        intervalConfig.debug = true
        
        XCTAssertEqual(instance.dispatchIntervalFromConfiguration(intervalConfig), 10)
    }
}
