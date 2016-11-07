//
//  IAConfiguration
//  IntuitAnalytics
//
//  Created by Hall, Jason on 4/22/16.
//  Copyright © 2016 Intuit, Inc. All rights reserved.
//

import Foundation

public class IAConfiguration: NSObject
{
    /// Enables or disables the printing of debugging messages.
    public var debug: Bool = false
    
    /// Specifies the log level for which debugging messages should be printed.
    public var debugLogLevel: LogLevel = .Error
    
    /// Use this property to override the server hostname for Trinity.  By default
    /// this property is set to `trinity.platform.intuit.com`.
    public var intuitIntegrationHostname: String = "trinity.platform.intuit.com"
    
    /// Use this property to override the base path for Trinity requests.  By default
    /// this property is set to `/trinity/v1/`.
    public var intuitIntegrationBasePath: String = "/trinity/v1/"
    
    /// This property must have a value.  This is the Trinity topic that all of your
    /// events will be dispatched to.
    public var intuitIntegrationTopic: String?
    
    /// Use this property to override the time interval (in seconds) that this library
    /// will dispatch events to the server.  The default value is 30 seconds.
    public var dispatchInterval: NSTimeInterval = 30
    
    /// The unique Application Id for this mobile application.
    public var appId: String?
    
    /// The unique Application Name for this mobile application.
    public var appName: String?
    
    /// The Application Version for this mobile application.
    public var appVersion: String?
    
    /// The Device Id for this mobile device.  This value should be obtained by integrating
    /// with the Device Identity Service.
    public var deviceId: String?
    
    /// Use this property to uniquely identify the current user.
    public var uniqueId: String?
}