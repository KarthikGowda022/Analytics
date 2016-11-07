//
//  IAIntuitIntegrationTrinityDispatcher.swift
//  IntuitAnalytics
//
//  Created by Hall, Jason on 4/19/16.
//  Copyright © 2016 Intuit, Inc. All rights reserved.
//

import Foundation
import DeviceInfoLibrary

class IAIntuitIntegrationTrinityDispatcher
{
    let configuration: IAConfiguration
    let session: NSURLSession
    
    var carrierName: String!
    var localeString: String!
    var osString: String!
    var platformString: String!
    
    init(configuration: IAConfiguration)
    {
        self.configuration = configuration

        assert(configuration.intuitIntegrationTopic != nil, "ERROR: A value must be provided for IAConfiguration.intuitIntegrationTopic.  This value should correspond to your Trinity topic name.")
        self.session = NSURLSession(configuration: NSURLSessionConfiguration.defaultSessionConfiguration())
        
        self.carrierName = DeviceInfo.sharedInstance().carrierNetworkName()
        self.localeString = DeviceInfo.sharedInstance().userLocaleString()
        self.osString = DeviceInfo.sharedInstance().operatingSystemVersionString()
        self.platformString = DeviceInfo.sharedInstance().hardwareMachineString()
        
    }
    
    lazy var sessionDictionary: [String : AnyObject] = {
        var sessionDict = [String : AnyObject]()
        sessionDict["properties"] = [String : AnyObject]()
        
        return sessionDict
    }()
    
    func applicationDictionary() -> [String : AnyObject] {
        var applicationDict = [String : AnyObject]()
        applicationDict["app_id"] = self.configuration.appId
        applicationDict["app_name"] = self.configuration.appName
        applicationDict["app_version"] = self.configuration.appVersion
        applicationDict["device_id"] = self.configuration.deviceId
        applicationDict["carrier"] = carrierName
        applicationDict["locale"] = localeString
        applicationDict["os"] = osString
        applicationDict["platform"] = platformString
        
        return applicationDict
    }
    
    func mobileClickStreamApplicationDictionary() -> [String : AnyObject] {
        var applicationDict = [String : AnyObject]()
        applicationDict["app_id"] = self.configuration.appId
        applicationDict["app_name"] = self.configuration.appName
        applicationDict["app_version"] = self.configuration.appVersion
        applicationDict["device_id"] = self.configuration.deviceId
        applicationDict["carrier"] = carrierName
        applicationDict["locale"] = localeString
        applicationDict["os"] = osString
        applicationDict["os_version"] = osString;
        applicationDict["platform"] = platformString
        applicationDict["device"] = platformString
        applicationDict["properties"] = [String : AnyObject]()
        applicationDict["server"] = [ "test" : false ]
        
        return applicationDict
    }
    
    func dispatch(events: [Event], completionHandler:(NSData?, NSURLResponse?, NSError?) -> Void)
    {
        guard let topicName = events[0].topic!.name else
        {
            IALogger.logError("Call to dispatch() failed because the topic name for this set of events was not found: \(events)")
            return
        }
        
        let topicURL = "https://\(configuration.intuitIntegrationHostname)\(configuration.intuitIntegrationBasePath)\(topicName)"
        
        var payload: AnyObject!
        if topicName == "mobile-clickstream" {
            payload = constructMobileClickStreamPayload(events)
        }
        else {
            payload = constructAnalyticsPayloadDictionary(events)
        }
        
        let payloadData = jsonDataRepresentationForObject(payload)
        
        if configuration.debug == true, let payloadData = payloadData
        {
            if let payloadString = NSString(data: payloadData, encoding: NSUTF8StringEncoding) as? String
            {
                IALogger.logDebug(payloadString)
            }
        }

        guard let gzippedHTTPBody = payloadData!.gzippedData() else
        {
            return
        }
        
        let contentLength = "\(gzippedHTTPBody.length)"
        
        let urlRequest = NSMutableURLRequest(URL: NSURL(string: topicURL)!)
        urlRequest.HTTPBody = gzippedHTTPBody
        urlRequest.HTTPMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.setValue("gzip", forHTTPHeaderField: "Content-Encoding")
        urlRequest.setValue(contentLength, forHTTPHeaderField: "Content-Length")
        
        
        let task = self.session.dataTaskWithRequest(urlRequest, completionHandler: { (data, urlResponse, error) -> Void in
            // Execute the completion handler that was passed to us
            completionHandler(data, urlResponse, error)
        })
        
        task.resume()
    }
    
    func constructAnalyticsPayloadDictionary(events: [Event]) -> [String : AnyObject]
    {
        var payloadDictionary = [String : AnyObject]()
        payloadDictionary["data_version"] = "2.0"
        payloadDictionary["application"] = applicationDictionary()
        
        // Add the events to the payload
        if events.count > 0
        {
            var eventArray = [AnyObject]()
            
            for anEvent in events
            {
                guard let eventDictionary = anEvent.dictionaryRepresentation() else
                {
                    break
                }
                
                eventArray.append(eventDictionary)
            }
            
            var eventDictionary = [String : AnyObject]()
            eventDictionary["events"] = eventArray
            payloadDictionary["data"] = eventDictionary
        }
        
        return payloadDictionary
    }
    
    func constructMobileClickStreamPayload(events: [Event]) -> [AnyObject] {
        var payloadDictionary = [String : AnyObject]()
        
        payloadDictionary["data_version"] = "2.0"
        payloadDictionary["application"] = mobileClickStreamApplicationDictionary()
        
        // Add the events to the payload
        if events.count > 0
        {
            var eventArray = [AnyObject]()
            
            for anEvent in events
            {
                guard var eventDictionary = anEvent.dictionaryRepresentation() else
                {
                    break
                }
                
                eventDictionary["event_sequence_number"] = eventDictionary["timestamp"]
                eventArray.append(eventDictionary)
            }
            

            var dataDictionary = [String : AnyObject]()
            dataDictionary["session"] = ["properties" : [String : AnyObject]()]
            dataDictionary["events"] = eventArray
            
            payloadDictionary["data"] = [dataDictionary]
        }
        
        return [payloadDictionary];
    }
    
    func jsonDataRepresentationForObject(object: AnyObject) -> NSData?
    {
        do
        {
            let jsonData = try NSJSONSerialization.dataWithJSONObject(object, options: [])
            
            return jsonData
        }
        catch
        {
            IALogger.logError("Error while creating JSON data: \(error)")
        }
        
        return nil
    }
}