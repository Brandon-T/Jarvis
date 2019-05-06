//
//  Configuration.swift
//  Services
//
//  Created by Brandon on 2019-05-05.
//  Copyright © 2019 SO. All rights reserved.
//

import Foundation

/// A class for configuring the client
public struct Configuration {
    /// Base URL used for this configuration's requests
    private let baseURL: URL
    
    /// Static headers used for each request
    private let headers: [String: String]
    
    //Access token for this configuration's requests
    private let accessToken: String?
    
    /// Configure each endpoint with a custom base url
    /// Note: The endpoint parameter should be ignored for now.
    ///       In the future it may be used to identify an endpoint and
    ///       return a baseURL for that specific endpoint instead of
    ///       having multiple clients with multiple configurations.
    public func baseURL<T>(for endpoint: Endpoint<T>) -> URL {
        return self.baseURL
    }
    
    /// Configure each request/endpoint with custom headers
    public func headers<T>(for endpoint: Endpoint<T>) -> [String: String] {
        let timestamp = Date().timeIntervalSince1970
        var headers: [String: String] = [:]
        
        //headers["Accept"] = "application/json"
        //headers["X-LANG"] = Bundle.main.applicationLanguage
        //headers["X-APP-VERSION"] = Bundle.main.applicationVersion
        headers["X-REQUEST-ID"] = UUID().uuidString.lowercased()
        headers["X-TIMESTAMP"] = "\(timestamp)"
        headers["X-SOURCE"] = "ios"
        
        //headers["X-DEVICE-ID"] = deviceId
        //headers["X-CONSUMER-KEY"] = consumerKey
        //headers["X-SIGNATURE"] = generateSignature(secretKey: secretKey, timeStamp: timestamp)
        
        //Some requests use an access token..
        //Some use a bearer token..
        //Others use credentials or jwt..
        //if let token = accessToken {
            //headers["Authorization"] = "Basic \(token)"
            //headers["Authorization"] = "Bearer \(token)"
            //headers["Authorization"] = "Digest \(token)"
            //headers["Authorization"] = "HOBA \(token)"
            //headers["Authorization"] = "Mutual \(token)"
            //headers["Authorization"] = "AWS4-HMAC-SHA256 \(token)"
            //headers["X-ACCESS-TOKEN"] = token
        //}
        
        /// The static headers take priority over the dynamic headers..
        /// Feel free to change the implementation
        self.headers.forEach({
            headers[$0.key] = $0.value
            if $0.value.isEmpty {
                headers.removeValue(forKey: $0.key)
            }
        })
        
        return self.headers
    }
}
