//
//  IALogger.swift
//  IntuitAnalytics
//
//  Created by Hall, Jason on 4/29/16.
//  Copyright © 2016 Intuit, Inc. All rights reserved.
//

import Foundation

@objc public enum LogLevel: Int
{
    case Debug
    case Info
    case Error
}

public class IALogger
{
    static var debug: Bool = false
    static var logLevel: LogLevel = .Error
    
    class func log(message: String, logLevel: LogLevel)
    {
        let logMessage = "\(NSDate().description) \(message)"
        
        if logLevel.rawValue >= IALogger.logLevel.rawValue
        {
            print(logMessage)
        }
    }
    
    public class func logDebug(message: String)
    {
        IALogger.log(message, logLevel: .Debug)
    }
    
    public class func logInfo(message: String)
    {
        IALogger.log(message, logLevel: .Info)
    }
    
    public class func logError(message:String)
    {
        IALogger.log(message, logLevel: .Error)
    }
}