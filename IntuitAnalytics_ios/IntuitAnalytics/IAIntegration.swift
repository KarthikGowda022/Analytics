//
//  IAIntegration.swift
//  IntuitAnalytics
//
//  Created by Hall, Jason on 4/7/16.
//  Copyright © 2016 Intuit, Inc. All rights reserved.
//

import Foundation

/**
    All external integrations with `IntuitAnalytics` should implement this protocol.
 
    In order to generically support as many external integrations as possible, `trackEvent(name:properties:)`
    only takes an event name and event properties as arguments.
 */
@objc public protocol IAIntegration
{
    init(configuration: IAConfiguration)
    
    /**
        Implement this method to call your external integration's event tracking method.
     
        - Parameter name: The name of the event to track.
        - Parameter properties: The properties associated with this event.
     */
    func trackEvent(name: String, properties: [String : AnyObject]?)
    
    /**
        Implement this method to call your external integration's event dispatching
        mechanism for sending events to its server.
     */
    func flush()
}