//
//  MultiRequestInterceptor.swift
//  Jarvis iOS
//
//  Created by Brandon on 2019-06-18.
//  Copyright © 2019 SO. All rights reserved.
//

import Foundation

/// A network request interceptor that chains multiple request interceptors together.
/// This is useful for having multiple interceptors attached to a client.
/// IE: One for logging, one for session renewal, one for request modification, etc.
public class MultiRequestInterceptor: RequestInterceptor {
    private var interceptors: [RequestInterceptor]
    
    public weak var client: Client? {
        didSet {
            for var interceptor in interceptors {
                interceptor.client = client
            }
        }
    }
    
    public init() {
        self.interceptors = []
    }
    
    public init(_ interceptors: [RequestInterceptor]) {
        self.interceptors = interceptors
    }
    
    public func willLaunchRequest<T>(_ request: inout URLRequest, for endpoint: Endpoint<T>) {
        
        interceptors.forEach({ $0.willLaunchRequest(&request, for: endpoint) })
    }
    
    public func requestSucceeded<T>(_ request: URLRequest, for endpoint: Endpoint<T>, data: Data, response: URLResponse) {
        
        interceptors.forEach({ $0.requestSucceeded(request, for: endpoint, data: data, response: response) })
    }
    
    public func requestFailed<T>(_ request: URLRequest, for endpoint: Endpoint<T>, error: Error, response: URLResponse?, completion: RequestCompletionPromise<RequestSuccess<T>>) {
        
        interceptors.forEach({ $0.requestFailed(request, for: endpoint, error: error, response: response, completion: completion) })
    }
}
