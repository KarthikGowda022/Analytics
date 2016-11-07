//
//  IntuitAnalytics.swift
//  IntuitAnalytics
//
//  Created by Hall, Jason on 4/15/16.
//  Copyright © 2016 Intuit, Inc. All rights reserved.
//

import Foundation

/**
    This is the main class where all work is orchestrated.  It is recommended that you instantiate
    this class as early on as possible (i.e. in your AppDelegate class) since
    calls to track events can be made at any time in the lifecycle of an app.
 
    It is important to note that this class registers for applicationDidFinishLaunching and
    applicationDidEnterBackground notifications to handle internal timer events.  You do not need
    to call flush() when going into the background, this class will do that on its own.
 */
public class IntuitAnalytics: NSObject
{
    var dispatchTimerStarted: Bool = false
    var dispatchTimer: NSTimer?
    
    public let configuration: IAConfiguration
    let intuitIntegration: IAIntuitIntegration
    let externalIntegrations: [IAIntegration]?
    
    /**
        Specifies the delegate that should be notified when a Mobile Componet Event has been published by one
        of the Mobile Components team's libraries, e.g. Image Capture or Push Notification.
     
        Callbacks made to this delegate will allow an implementing mobile application to supplement the Mobile
        Component Event with additional properties that the mobile application would like to track.
     
        - SeeAlso: IAMobileComponentEventDelegate
     */
    public var delegate: IAMobileComponentEventDelegate?
    {
        didSet
        {
            self.intuitIntegration.delegate = self.delegate
        }
    }
    
    internal init(configuration: IAConfiguration, intuitIntegration: IAIntuitIntegration, externalIntegrations: [IAIntegration]?)
    {
        IALogger.debug = configuration.debug
        IALogger.logLevel = configuration.debugLogLevel
        
        self.configuration = configuration
        self.intuitIntegration = intuitIntegration
        self.externalIntegrations = externalIntegrations
        
        super.init()
        
        NSNotificationCenter.defaultCenter().addObserver(self, selector: "applicationDidFinishLaunchingNotification:", name: "UIApplicationDidFinishLaunchingNotification", object: nil)
        NSNotificationCenter.defaultCenter().addObserver(self, selector: "applicationDidEnterBackgroundNotification:", name: "UIApplicationDidEnterBackgroundNotification", object: nil)
        NSNotificationCenter.defaultCenter().addObserver(self, selector: "flushRequiredNotification:", name: "IAIntegrationFlushRequiredNotification", object: nil)
    }
    
    /**
        Constructs an instance of this class when you have a list of external integrations that you would like this library
        to work with.
 
        - Parameters:
            - configuration: The configuration object to use with this instance.
            - externalIntegrations: An array of classes conforming to the IAIntegration protocol.
     
        - SeeAlso: IAIntegration
    */
    public convenience init(configuration: IAConfiguration, externalIntegrations: [IAIntegration]?)
    {
        let intuitIntegration = IAIntuitIntegration(configuration: configuration)
        self.init(configuration: configuration, intuitIntegration: intuitIntegration, externalIntegrations: externalIntegrations)
    }
    
    /**
        Constructs an instance of this class when there are no external integrations.  Instances created like this will only
        send events to Intuit's Trinity analytics endpoint.
     
        - Parameters:
            - configuration: The configuration object to use with this instance.
     */
    public convenience init(configuration: IAConfiguration)
    {
        self.init(configuration: configuration, externalIntegrations: nil)
    }
    
    /**
        Tracks an event with no properties.  This method will track this event within the Intuit Analytics library for
        Trinity tracking in addition to calling the corresponding event tracking method in the external integrations.
 
        - Parameter name: The name of the event to track.
     
        - SeeAlso: `trackEvent(name:properties:)`
     */
    public func trackEvent(name: String)
    {
        trackEvent(name, properties: nil)
    }
    
    /**
        Tracks an event with properties.  This method will track this event within the Intuit Analytics library for
        Trinity tracking in addition to calling the corresponding event tracking method in the external integrations.
 
        - Parameter name: The name of the event to track.
        - Parameter properties: A dictionary of properties associated with this event.  This dictionary may only
                                contain strings, dictionaries, and arrays.
     
        - SeeAlso: `trackEvent(name:)`
     */
    public func trackEvent(name: String, properties: [String : AnyObject]?)
    {
        IALogger.logInfo("Track event: name: \(name) - properties: \(properties)")
        
        self.intuitIntegration.trackEvent(name, properties: properties)
        
        guard let externalIntegrations = self.externalIntegrations where self.externalIntegrations!.count > 0 else
        {
            return
        }
        
        for anExternalIntegration in externalIntegrations
        {
            anExternalIntegration.trackEvent(name, properties: properties)
        }
    }
    
    /**
        Invokes a dispatch of all events immediately to Trinity and any external integrations.  There is no need to
        call this method when your application is going into the background.  This class already registers for
        applicationDidEnterBackground notifications and calls this method accordingly.
     */
    public func flush()
    {
        IALogger.logInfo("Flush events")
        
        self.intuitIntegration.flush()
        
        guard let externalIntegrations = self.externalIntegrations where self.externalIntegrations!.count > 0 else
        {
            return
        }
        
        for anExternalIntegration in externalIntegrations
        {
            anExternalIntegration.flush()
        }
    }
    
    internal func startDispatchTimer()
    {
        if !dispatchTimerStarted
        {
            // We need to dispatch this timer on the main queue so that we can ensure that we can call invalidate() on the timer
            // using the same thread.
            // https://developer.apple.com/library/mac/documentation/Cocoa/Reference/Foundation/Classes/NSTimer_Class/#//apple_ref/occ/instm/NSTimer/invalidate
            dispatch_async(dispatch_get_main_queue()) { () -> Void in
                IALogger.logDebug("Starting dispatch timer.")
                
                let dispatchInterval = self.dispatchIntervalFromConfiguration(self.configuration)
                self.dispatchTimer = NSTimer.scheduledTimerWithTimeInterval(dispatchInterval, target: self, selector: "timerBasedFlush", userInfo: nil, repeats: true)
                NSRunLoop.currentRunLoop().addTimer(self.dispatchTimer!, forMode: NSRunLoopCommonModes)
                
                self.dispatchTimerStarted = true
                IALogger.logDebug("IntuitAnalytics configured with dispatch interval of \(dispatchInterval) seconds")
            }
        }
    }
    
    internal func stopDispatchTimer()
    {
        IALogger.logDebug("Stopping dispatch timer.")
        
        // We invalidate() this timer using the main queue since that's where the timer was installed.
        // https://developer.apple.com/library/mac/documentation/Cocoa/Reference/Foundation/Classes/NSTimer_Class/#//apple_ref/occ/instm/NSTimer/invalidate
        dispatch_async(dispatch_get_main_queue()) { () -> Void in
            self.dispatchTimerStarted = false
            self.dispatchTimer!.invalidate()
        }
    }
    
    internal func dispatchIntervalFromConfiguration(configuration: IAConfiguration) -> NSTimeInterval
    {
        if configuration.dispatchInterval >= 30 || configuration.debug == true
        {
            return configuration.dispatchInterval
        }
        
        return 30
    }
    
    internal func timerBasedFlush()
    {
        IALogger.logDebug("Flush called by dispatch timer.")
        flush()
    }
    
    // MARK: Notification Handling
    func applicationDidFinishLaunchingNotification(notification: NSNotification)
    {
        startDispatchTimer()
    }
    
    func applicationDidEnterBackgroundNotification(notification: NSNotification)
    {
        stopDispatchTimer()
        
        guard let application = notification.object as? UIApplication else
        {
            return
        }
        
        
        IALogger.logDebug("Background time remaining: \(application.backgroundTimeRemaining) seconds.")
        
        flush()
    }
    
    func flushRequiredNotification(notification: NSNotification)
    {
        stopDispatchTimer()
        
        if let userInfo = notification.userInfo
        {
            IALogger.logDebug("Flush required notification.  Hit maximum event count: \(userInfo["eventCount"])")
        }
        
        flush()
        
        startDispatchTimer()
    }
    
    deinit
    {
        IALogger.logDebug("Deinit called on IntuitAnalytics.")
        
        // This work will no longer be required once we move to support only iOS 9 and higher:
        // https://developer.apple.com/library/mac/releasenotes/Foundation/RN-Foundation/index.html#10_11NotificationCenter
        NSNotificationCenter.defaultCenter().removeObserver(self, name: "UIApplicationDidFinishLaunchingNotification", object: nil)
        NSNotificationCenter.defaultCenter().removeObserver(self, name: "UIApplicationDidEnterBackgroundNotification", object: nil)
        NSNotificationCenter.defaultCenter().removeObserver(self, name: "IAIntegrationFlushRequiredNotification", object: nil)
    }
}
