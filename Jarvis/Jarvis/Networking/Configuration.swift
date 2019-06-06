//
//  Configuration.swift
//  Jarvis
//
//  Created by Brandon on 2019-05-05.
//  Copyright © 2019 SO. All rights reserved.
//

import Foundation

/// A class for configuring the client
public class Configuration {
    /// Base URL used for this configuration's requests
    private let baseURL: URL
    
    /// Static headers used for each request
    private let headers: [String: String]
    
    //Access token for this configuration's requests
    public var accessToken: String?
    
    public init(baseURL: URL, headers: [String: String]) {
        self.baseURL = baseURL
        self.headers = headers
        self.accessToken = nil
    }
    
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
        return self.headers
    }
}
