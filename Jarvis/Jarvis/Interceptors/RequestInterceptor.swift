//
//  RequestInterceptor.swift
//  Jarvis
//
//  Created by Brandon Anthony on 2019-06-19.
//  Copyright © 2019 SO. All rights reserved.
//

import Foundation

/// A client interceptor protocol
/// All request interceptors must implement this protocol
public protocol RequestInterceptor {
    
    /// MUST be weak in the implementation!
    var client: Client? { get set }
    
    /// A request is about to be executed
    func willLaunchRequest<T>(_ request: inout URLRequest, for endpoint: Endpoint<T>)
    
    /// A request has succeeded
    func requestSucceeded<T>(_ request: URLRequest, for endpoint: Endpoint<T>, data: Data, response: URLResponse)
    
    /// A request has failed
    func requestFailed<T>(_ request: URLRequest, for endpoint: Endpoint<T>, error: Error, response: URLResponse?, completion: RequestCompletionPromise<RequestSuccess<T>>)
}
