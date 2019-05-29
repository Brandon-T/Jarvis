//
//  BasicRequestInterceptor.swift
//  PromiseClient
//
//  Created by Brandon Anthony on 2019-04-30.
//  Copyright © 2019 SO. All rights reserved.
//

import Foundation

/// A network request interceptor that handles session renewal, logging, and errors that happen during a request.
/// This class will handle automatic token renewal.
/// This class will handle logging a request's lifetime.
public class BasicRequestInterceptor<Token>: RequestInterceptor {
    
    private let lock = NSRecursiveLock()
    private var isRenewingToken: Bool = false
    private var currentRenewTokenRequest: Request<Token>?
    
    private var tasks = [DispatchWorkItem]()
    private let renewSession: (() -> Request<Token>)?
    public weak var client: Client?
    private let onTokenRenewed: ((_ client: Client?, _ token: Token?, _ error: Error?) -> Void)?
    
    /// Initialize an interceptor that does NOT need session token handling..
    public init() {
        self.renewSession = nil
        self.onTokenRenewed = nil
        self.currentRenewTokenRequest = nil
    }
    
    /// Initialize an interceptor that requires session token handling..
    public init(renewSession: @escaping () -> Request<Token>, onTokenRenewed: @escaping (_ client: Client?, _ token: Token?, _ error: Error?) -> Void) {
        self.renewSession = renewSession
        self.onTokenRenewed = onTokenRenewed
        self.currentRenewTokenRequest = nil
    }
    
    public func willLaunchRequest<T>(_ request: URLRequest, for endpoint: Endpoint<T>) {
        /// Request being launched.. Log it to the console..
    }
    
    public func requestSucceeded<T>(_ request: URLRequest, for endpoint: Endpoint<T>, response: URLResponse) {
        /// Request succeeded.. Log it to the console..
    }
    
    public func requestFailed<T>(_ request: URLRequest, for endpoint: Endpoint<T>, error: Error, response: URLResponse?, completion: RequestCompletionPromise<RequestSuccess<T>>) {
        /// Pre-conditions..
        guard let response = response as? HTTPURLResponse else {
            completion.reject(error)
            return
        }
        
        if self.renewSession == nil {
            completion.reject(error)
            return
        }
        
        /// Avoid dead-lock when renewSession fails no matter what..
        if let currentRenewTokenRequestURL = self.currentRenewTokenRequest?.currentRequest?.url {
            if request.url == currentRenewTokenRequestURL {
                completion.reject(error)
                return
            }
        }
        
        /// Avoid dead-lock when renewSession fails with a 401..
        if response.statusCode == 401, let currentRenewTokenRequestURL = self.currentRenewTokenRequest?.currentRequest?.url {
            if request.url == currentRenewTokenRequestURL {
                completion.reject(error)
                return
            }
        }
        
        /// Handle token expiration..
        if response.statusCode == 401 {
            self.lock.lock(); defer { self.lock.unlock() }
            
            self.tasks.append(DispatchWorkItem(block: {
                self.client?.task(endpoint: endpoint).retryChain(completion)
            }))
            
            /// Check if we're already renewing..
            if !isRenewingToken {
                isRenewingToken = true
                
                self.renewSessionToken()
            }
        }
        else {
            /// Request failed for other reasons.. Log it to the console..
            completion.reject(error)
        }
    }
    
    /// Handles the renewing of the session token
    private func renewSessionToken() {
        self.currentRenewTokenRequest = self.renewSession?().then({ [weak self] result in
            self?.onSessionRenewalSucceeded(token: result.data)
        })
        .catch({ [weak self] error in
            self?.onSessionRenewalFailed(error: error)
        })
    }
    
    /// Handles when the session token has successfully renewed
    private func onSessionRenewalSucceeded(token: Token) {
        self.lock.lock(); defer { self.lock.unlock() }
        
        self.onTokenRenewed?(self.client, token, nil)
        isRenewingToken = false
        
        for task in self.tasks {
            DispatchQueue.main.async(execute: task)
        }
        
        self.tasks = []
    }
    
    /// Handles when the session token fails to be renewed
    private func onSessionRenewalFailed(error: Error) {
        self.lock.lock(); defer { self.lock.unlock() }
        

        self.tasks.forEach({ $0.cancel() })
        self.tasks.removeAll()
        
        
        self.onTokenRenewed?(self.client, nil, error)
        isRenewingToken = false
    }
}
