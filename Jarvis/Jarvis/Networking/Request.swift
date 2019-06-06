//
//  Request.swift
//  Jarvis
//
//  Created by Brandon on 2018-12-09.
//  Copyright © 2018 XIO. All rights reserved.
//

import Foundation

#if canImport(Alamofire)
import Alamofire
#endif

/// A request's completion block
/// This is used to resolve OR reject a request
public struct RequestCompletionPromise<T> {
    /// Resolve the request
    private(set) public var resolve: (T) -> Void
    
    /// Reject the request
    private(set) public var reject: (Error) -> Void
    
    /// Creates a request from an internal completion
    internal init<U>(_ requestCompletion: RequestCompletion<U>) {
        self.resolve = {
            requestCompletion.resolve($0 as! U) // swiftlint:disable:this force_cast
        }
        
        self.reject = {
            requestCompletion.reject($0)
        }
    }
}

/// An internal request completion that represents a promise's resolve and reject interface
internal class RequestCompletion<T> {
    /// Resolve the request - Marks a request successful
    var resolve: (T) -> Void
    
    /// Reject the request - Marks a request as failed
    var reject: (Error) -> Void
    
    /// Creates a RequestCompletion
    init(_ resolve: @escaping (T) -> Void, _ reject: @escaping (Error) -> Void) {
        self.resolve = resolve
        self.reject = reject
    }
}

/// A successful request's internal response
public struct RequestSuccess<T> {
    /// The serialized model of the server response
    public let data: T
    
    /// The raw response data returned from the server
    public let rawData: Data
    
    /// The server's response
    public let response: URLResponse
}

/// A failed request's internal error
public struct RequestFailure: Error, CustomNSError, LocalizedError {
    /// The error returned from the server
    public let error: Error
    
    /// The raw response data returned from the server
    public let rawData: Data?
    
    /// The server's response
    public let response: URLResponse?
    
    // MARK: - NSError Briding Implementation
    public var localizedDescription: String {
        return error.localizedDescription
    }
    
    public var errorCode: Int {
        return (error as NSError).code
    }
    
    public var errorUserInfo: [String: Any] {
        return (error as NSError).userInfo
    }
    
    public static var errorDomain: String {
        return "Jarvis.RequestFailureDomain"
    }
    
    public var errorDescription: String? {
        return (error as NSError).localizedDescription
    }
    
    public var failureReason: String? {
        return (error as NSError).localizedFailureReason
    }
}

private class NetworkRequestInfo<T> {
    public typealias ResponseType = (data: T, response: URLResponse)
    
    private lazy var lock = NSRecursiveLock()
    public let endpoint: Endpoint<T>?
    public weak var sessionManager: Client?
    
    #if canImport(Alamofire)
    public let task: DataRequest?
    #else
    public let task: URLSessionTask?
    #endif
    
    init() {
        self.sessionManager = nil
        self.endpoint = nil
        self.task = nil
    }

    #if canImport(Alamofire)
    init(sessionManager: Client?, endpoint: Endpoint<T>, task: DataRequest?) {
        self.sessionManager = sessionManager
        self.endpoint = endpoint
        self.task = task
    }
    #else
    init(sessionManager: Client?, endpoint: Endpoint<T>, task: URLSessionTask?) {
        self.sessionManager = sessionManager
        self.endpoint = endpoint
        self.task = task
    }
    #endif
}

public class Request<T> {
    // MARK: - Private Promise
    private var state: RequestPromiseState = .pending
    private var value: RequestSuccess<T>?
    private var error: Error?
    private let queue: DispatchQueue
    private lazy var tasks: [RequestPromiseTask<RequestSuccess<T>>] = {
        [RequestPromiseTask<RequestSuccess<T>>]()
    }()
    
    // MARK: - Private Request
    private var endpointInfo = NetworkRequestInfo<T>()
    
    // MARK: - Public Request
    public var currentRequest: URLRequest? {
        #if canImport(Alamofire)
        return self.endpointInfo.task?.request
        #else
        return self.endpointInfo.task?.currentRequest
        #endif
    }
    
    #if canImport(Alamofire)
    /// Creates a request
    /// Use this initializer when the request should be executed immediately
    internal convenience init(_ session: Client, endpoint: Endpoint<T>, task: DataRequest?, promise: RequestCompletion<RequestSuccess<T>>) {
        self.init(.main, task: { resolve, reject in
            promise.resolve = resolve
            promise.reject = reject
        })
        
        self.endpointInfo = NetworkRequestInfo<T>(sessionManager: session, endpoint: endpoint, task: task)
        task?.resume()
    }
    #else
    /// Creates a request
    /// Use this initializer when the request should be executed immediately
    internal convenience init(_ session: Client, endpoint: Endpoint<T>, task: URLSessionTask?, promise: RequestCompletion<RequestSuccess<T>>) {
        self.init(.main, task: { resolve, reject in
            promise.resolve = resolve
            promise.reject = reject
        })
        
        self.endpointInfo = NetworkRequestInfo<T>(sessionManager: session, endpoint: endpoint, task: task)
        task?.resume()
    }
    #endif
    
    private convenience init(promise: RequestCompletion<RequestSuccess<T>>) {
        self.init(nil, task: { resolve, reject in
            promise.resolve = resolve
            promise.reject = reject
        })
        
        self.endpointInfo = NetworkRequestInfo<T>()
    }
    
    /// Used for session renewal to re-execute a request using the internal promise chain
    /// Calls the completion block when the request has been executed/retried
    @discardableResult
    internal func retryChain(_ completion: RequestCompletionPromise<RequestSuccess<T>>) -> Request<T> {
        return self.then {
            completion.resolve($0)
        }
        .catch {
            completion.reject($0)
        }
    }
    
    // MARK: - Public
    
    /// Retry a request for a max amount of times (maxTries)
    @discardableResult
    public func retry(_ maxTries: Int) -> Request<T> {
        guard let sessionManager = self.endpointInfo.sessionManager, let endpoint = self.endpointInfo.endpoint, maxTries > 0 else {
            return self
        }

        func retryRequest(_ count: Int, request: Request<T>) {
            self.then({
                request.fulfill($0)
            }).catch { _ in
                request.endpointInfo = sessionManager.task(endpoint: endpoint).then {
                    request.fulfill($0)
                }
                .catch {
                    count == 1 ? request.reject($0) : retryRequest(count - 1, request: request)
                }.endpointInfo
            }
        }
        
        let request = Request<T>(promise: RequestCompletion<RequestSuccess<T>>({ _ in }, { _ in }))
        request.endpointInfo = self.endpointInfo
        
        retryRequest(maxTries, request: request)
        return request
    }
    
    /// Cancels a request's execution
    @discardableResult
    public func cancel() -> Request {
        self.endpointInfo.task?.cancel()
        return self
    }
    
    /// Synchronously returns the value
    fileprivate func get() throws -> RequestSuccess<T>? {
        return try self.wait(timeout: .now())
    }
    
    /// Waits a specified amount of time for the promise to resolve and returns the response synchronously
    fileprivate func wait(timeout: DispatchTime = DispatchTime.distantFuture) throws -> RequestSuccess<T>? {
        if self.isPending() {
            let lock = DispatchSemaphore(value: 0)
            self.then(
                .global(qos: .userInitiated),
                { [weak self] value in
                    self?.queue.sync { self?.value = value } // swiftlint:disable:previous opening_brace
                    lock.signal()
                }, { [weak self] error in
                    self?.queue.sync { self?.error = error }
                    lock.signal()
                }
            )
            
            if lock.wait(timeout: timeout) == .success {
                return self.queue.sync { self.value }
            }
        }
        
        if let error = self.queue.sync(execute: { self.error }) {
            throw error
        }
        return self.queue.sync { self.value }
    }
    
    /// Determines if the promise is pending
    fileprivate func isPending() -> Bool {
        return self.getValue() == nil && self.getError() == nil
    }
    
    /// Determines if the promise is fulfilled
    fileprivate func isFulfilled() -> Bool {
        return self.getValue() != nil
    }
    
    /// Determines if the promise is rejected
    fileprivate func isRejected() -> Bool {
        return self.getError() == nil
    }
    
    /// Returns the promise's value
    fileprivate func getValue() -> RequestSuccess<T>? {
        return self.queue.sync { self.value }
    }
    
    /// Returns the promise's error
    fileprivate func getError() -> Error? {
        return self.queue.sync { self.error }
    }
    
    /// Fulfills the promise
    fileprivate func fulfill(_ result: RequestSuccess<T>) {
        if self.isPending() {
            self.queue.sync {
                self.value = result
                self.state = .fulfilled
            }
            self.doResolve()
        }
    }
    
    /// Rejects the promise
    fileprivate func reject(_ error: Error) {
        if self.isPending() {
            self.queue.sync {
                self.error = error
                self.state = .rejected
            }
            self.doResolve()
        }
    }
    
    /// Chains the promise when it is successful, catching only resolution
    @discardableResult
    public func then(_ onFulfilled: @escaping (RequestSuccess<T>) -> Void) -> Request<T> {
        return self.then(onFulfilled, { _ in })
    }
    
    /// Chains the promise when it is successful, catching resolution
    /// Chains the promise when it has failed, catching rejection
    @discardableResult //Made private - Use `catch` to catch rejections..
    private func then(_ onFulfilled: @escaping (RequestSuccess<T>) -> Void, _ onRejected: @escaping (Error) -> Void) -> Request<T> {
        return self.then(nil, onFulfilled, onRejected)
    }
    
    /// Chains the promise on a specified queue when it is successful, catching only resolution
    @discardableResult
    public func then(_ on: DispatchQueue? = nil, _ onFulfilled: @escaping (RequestSuccess<T>) -> Void) -> Request<T> {
        return self.then(on, onFulfilled, { _ in })
    }
    
    /// Chains the promise on a specified queue when it is successful, catching resolution
    /// Chains the promise on a specified queue, when it has failed, catching rejection
    @discardableResult //Made private - Use `catch` to catch rejections..
    fileprivate func then(_ on: DispatchQueue? = nil, _ onFulfilled: @escaping (RequestSuccess<T>) -> Void, _ onRejected: @escaping (Error) -> Void) -> Request<T> {
        self.queue.async {
            let queue = on ?? DispatchQueue.main
            self.tasks.append(RequestPromiseTask<RequestSuccess<T>>(queue: queue, onFulfill: onFulfilled, onRejected: onRejected))
        }
        self.doResolve()
        return self
    }
    
    /// Chains the promise when it is successful, catching only resolution, and returning a different promise
    @discardableResult
    public func then<Value>(_ onFulfilled: @escaping (RequestSuccess<T>) throws -> Request<Value>) -> Request<Value> {
        return self.then(nil, onFulfilled)
    }
    
    /// Chains the promise when it is successful on a specified queue, catching only resolution, and returning a different promise
    @discardableResult
    public func then<Value>(_ on: DispatchQueue? = nil, _ onFulfilled: @escaping (RequestSuccess<T>) throws -> Request<Value>) -> Request<Value> {
        
        let promise = RequestCompletion<RequestSuccess<Value>>({ _ in }, { _ in })
        let request = Request<Value>(promise: promise)
        
        self.queue.async {
            let queue = on ?? DispatchQueue.main
            self.tasks.append(
                RequestPromiseTask<RequestSuccess<T>>(
                    queue: queue,
                    onFulfill: { value in
                        do {
                            request.update(try onFulfilled(value)).then(promise.resolve, promise.reject)
                        }
                        catch let error {
                            promise.reject(error)
                        }
                    }, onRejected: { error in
                        promise.reject(error)
                    }
                )
            )
        }
        return request
    }
    
    /// Chains the promise when it fails, catching only rejection
    @discardableResult
    public func `catch`(_ onRejected: @escaping (Error) -> Void) -> Request<T> {
        return self.`catch`(nil, onRejected)
    }
    
    /// Chains the promise on a specified queue when it fails, catching only rejection
    @discardableResult
    public func `catch`(_ on: DispatchQueue? = nil, _ onRejected: @escaping (Error) -> Void) -> Request<T> {
        return self.then(on, { _ in }, onRejected)
    }
    
    // MARK: - Private
    
    /// Handles resolving the promise
    private func doResolve() {
        self.queue.async {
            if self.state != .pending {
                self.tasks.forEach({ [unowned self] task in
                    if self.state == .fulfilled {
                        if let value = self.value {
                            task.queue.async {
                                task.onFulfill(value)
                            }
                        }
                    }
                    else if self.state == .rejected {
                        if let error = self.error {
                            task.queue.async {
                                task.onRejected(error)
                            }
                        }
                    }
                })
                self.tasks = []
            }
        }
    }
    
    // MARK: - Private
    
    /// Initializes the promise queue
    private init() {
        self.queue = DispatchQueue(label: "com.long.shot.promise.queue", qos: .default)
    }
    
    /// Initializes the promise with a task
    private convenience init(_ task: @escaping ( _ resolve: @escaping (RequestSuccess<T>) -> Void, _ reject: @escaping (Error) -> Void) throws -> Void) {
        self.init(nil, task: task)
    }
    
    /// Initializes the promise with a task on a specific queue
    private init(_ on: DispatchQueue? = nil, task: @escaping (_ resolve: @escaping (RequestSuccess<T>) -> Void, _ reject: @escaping (Error) -> Void) throws -> Void) {
        self.queue = DispatchQueue(label: "com.long.shot.promise.queue", qos: .default)
        let queue = on ?? self.queue
        queue.async {
            do {
                try task(self.fulfill, self.reject)
            }
            catch let error {
                self.reject(error)
            }
        }
    }
    
    /// Updates the current request's endpoint and returns the original request
    private func update(_ request: Request<T>) -> Request<T> {
        self.endpointInfo = request.endpointInfo
        return request
    }
    
    /// The state of the promise's resolution
    private enum RequestPromiseState {
        case pending
        case fulfilled
        case rejected
    }
    
    /// A task that represent's a promises' completion
    private struct RequestPromiseTask<T> {
        let queue: DispatchQueue
        let onFulfill: (T) -> Void
        let onRejected: (Error) -> Void
    }
}
