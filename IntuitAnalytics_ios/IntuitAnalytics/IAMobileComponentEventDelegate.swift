//
//  IAMobileComponentEventDelegate.swift
//  IntuitAnalytics
//
//  Created by Hall, Jason on 4/26/16.
//  Copyright © 2016 Intuit, Inc. All rights reserved.
//

import Foundation

/**
    Whenever Mobile Component libraries generate events, applications that integrate these mobile
    components will be able to access/modify these events through this listener.  The
    `mobileComponentEventPosted(eventName:eventDictionary:topic:)` method is called on every Mobile Component
    event.  You will have access to the contents of the Mobile Component event.  In addition, you
    will be given the opportunity to append your own information to this event by returning a dictionary
    of event properties from `mobileComponentEventPosted(eventName:eventDictionary:topic:)`.
 */
@objc public protocol IAMobileComponentEventDelegate
{
    /**
        The delegate must implement this method and may optionally return a dictionary of properties to append to the Mobile
        Component event's properties.
 
        - Parameters:
            - eventName: The name of the Mobile Component event.
            - eventDictionary: The properties associated with this Mobile Component event.
            - topic: The Mobile Component event topic associated with this event.
     
        - Returns: A dictionary containing any properties you would like to add to the eventDictionary.
     */
    func mobileComponentEventPosted(eventName: String, eventDictionary: [String : AnyObject]?, topic: String) -> [String : AnyObject]?
}