//
//  RequestLogger.swift
//  Jarvis
//
//  Created by Brandon Anthony on 2019-06-19.
//  Copyright © 2019 SO. All rights reserved.
//

import Foundation
import os

public final class RequestLogger: RequestInterceptor {
    public weak var client: Client?
    private var requests: [URLRequest: Date]
    private let logLevel: LogLevel
    
    public let requestLogs: RequestLogSubscriber<[RequestPacket]>
    
    public init(_ logLevel: LogLevel) {
        self.client = nil
        self.requests = [:]
        self.logLevel = logLevel
        self.requestLogs = RequestLogSubscriber<[RequestPacket]>([])
    }
    
    public func willLaunchRequest<T>(_ request: inout URLRequest, for endpoint: Endpoint<T>) {
        if logLevel != .none {
            requests.updateValue(Date(), forKey: request)
        }
        log(request: request, for: endpoint)
    }
    
    public func requestSucceeded<T>(_ request: URLRequest, for endpoint: Endpoint<T>, data: Data, response: URLResponse) {
        log(request: request, for: endpoint, data: data, response: response)
    }
    
    public func requestFailed<T>(_ request: URLRequest, for endpoint: Endpoint<T>, error: Error, response: URLResponse?, completion: RequestCompletionPromise<RequestSuccess<T>>) {
        log(request: request, for: endpoint, data: (error as? RequestFailure)?.rawData, error: error, response: response)
    }
}

extension RequestLogger {

    private func log<T>(request: URLRequest, for endpoint: Endpoint<T>, data: Data? = nil, error: Error? = nil, response: URLResponse? = nil) {
        guard logLevel != .none, let response = response as? HTTPURLResponse else {
            return
        }
        
        defer { requests.removeValue(forKey: request); }
        
        let startDate = requests[request] ?? Date()
        let endDate = Date()
        let timeInterval = endDate.timeIntervalSince(startDate)
        
        let components = Calendar.current.dateComponents([.second, .minute, .hour], from: startDate)
        let date = String(format: "[%02ld:%02ld:%02ld]", components.hour!, components.minute!, components.second!) //swiftlint:disable:this force_unwrapping

        // Normalize host
        var host = request.url?.host ?? ""
        host = host.isEmpty ? "localhost" : host
        
        // Normalize path
        var path = request.url?.path ?? ""
        path = path.isEmpty ? "/" : path
        
        // Normalize query
        let query = request.url?.query ?? ""
        
        // Normalize headers
        var requestHeaders = request.allHTTPHeaderFields ?? [:]
        var responseHeaders = response.allHeaderFields
        requestHeaders.removeValue(forKey: "Host")
        responseHeaders.removeValue(forKey: "Host")
        
        // Normalize body
        let contentType = response.allHeaderFields["Content-Type"] as? String ?? "application/octet-stream"

        // Log Basic Info
        var logData = ""
        logData += String(format: "%@ %@ %@\n", date, request.httpMethod?.uppercased() ?? "GET", path)
        logData += "Host: \(host)\n"
        
        if logLevel >= .verbose {
            logData += query.isEmpty ? "" : "Query: \(query)\n"
        }
        
        // Log Status Code
        if let error = error as? URLError, error.code == .cancelled {
            logData += "Status: \(response.statusCode) CANCELLED"
            logData += "\n"
        }
        else {
            logData += "Status: \(response.statusCode) \(response.statusCode == 200 ? "OK" : HTTPURLResponse.localizedString(forStatusCode: response.statusCode).uppercased())"
            logData += "\n"
        }
        
        // Log Elapsed Time
        logData += "Elapsed Time: \(String(format: "%.3fs", timeInterval))"
        logData += "\n"
        
        if let error = error {
            logData += error.localizedDescription
            logData += "\n"
        }
        
        if logLevel >= .trace && !requestHeaders.isEmpty {
            logData += "\n"
            logData += "Headers:\n"
            logData += indent(requestHeaders.compactMap({ "\($0.key): \($0.value)" }).joined(separator: "\n"))
            logData += "\n"
        }
        
        if logLevel >= .verbose {
            let body = String(data: request.httpBody ?? Data(), encoding: .utf8) ?? ""
            
            if !body.isEmpty {
                logData += "Body:\n"
                logData += indent(body)
                logData += "\n"
            }
        }
        
        if logLevel >= .all && !responseHeaders.isEmpty {
            logData += "\n"
            logData += "Response Headers:\n"
            logData += indent(responseHeaders.compactMap({ "\($0.key): \($0.value)" }).joined(separator: "\n"))
            logData += "\n"
        }
        
        if logLevel >= .trace, let body = data, !body.isEmpty {
            logData += "\n"
            logData += "Response Body:\n"
            
            if contentType.starts(with: "text") {
                let decodedBody = String(data: body, encoding: .utf8) ?? String(data: body, encoding: .ascii) ?? ""
                logData += decodedBody.isEmpty ? "" : indent(decodedBody)
            }
            else if contentType.starts(with: "image") {
                logData += indent(body.base64EncodedString())
            }
            else if contentType.starts(with: "application/octet-stream") {
                logData += indent(body.base64EncodedString())
            }
            else {
                logData += indent(body.base64EncodedString())
            }
        }
        
        // Log Message
        logMessage(logData)
        
        // Storage
        let packet = RequestPacket(startDate: startDate, endDate: endDate, request: request, response: response, responseData: data, error: error)
        
        var requestLogs = self.requestLogs.value
        requestLogs.insert(packet, at: 0)
        if requestLogs.count > 25 {
            requestLogs.removeLast()
        }
        self.requestLogs.value = requestLogs
    }
    
    // MARK: - Private
    
    private func logMessage(_ message: String) {
        var logData = "\n"
        logData += "\n**********************************\n\n"
        logData += "\(message)"
        logData += "\n**********************************\n\n"
        
        #if USE_OS_LOG
        if logLevel != .none {
            os_log(logData, log: .network, type: .info)
        }
        #else
        if logLevel != .none {
            print(logData)
        }
        #endif
    }
    
    private func indent(_ input: String, amount: Int = 4) -> String {
        let indentation = String(repeating: " ", count: amount)
        return "\(indentation)\(input.components(separatedBy: "\n").joined(separator: "\n\(indentation)"))"
    }
}

extension RequestLogger {
    /// A request packet contains all information about a request and its response
    public struct RequestPacket {
        public let startDate: Date
        public let endDate: Date
        public let request: URLRequest
        public let response: HTTPURLResponse
        public let responseData: Data?
        public let error: Error?
    }
    
    public class RequestLogSubscriber<T> {
        public typealias Observer = (_ newValue: T, _ oldValue: T?) -> Void
        private var subscribers = [(Observer, RequestLogObserver)]()
        
        init(_ value: T) {
            self.value = value
        }
        
        internal(set) public var value: T {
            didSet {
                subscribers.forEach({
                    $0.0(value, oldValue)
                })
            }
        }
        
        @discardableResult
        public func observe(_ observer: @escaping Observer) -> RequestLogObserver {
            let disposable = RequestLogObserver({ [weak self] in self?.removeObserver($0) })
            subscribers.append((observer, disposable))
            subscribers.forEach { $0.0(value, nil) }
            return disposable
        }
        
        private func removeObserver(_ object: RequestLogObserver) {
            object.dispose()
            subscribers = subscribers.filter { $1 !== object }
        }
        
        private func removeAllObservers() {
            subscribers.forEach({ $1.dispose(); })
            subscribers.removeAll()
        }
    }
    
    public class RequestLogObserver {
        private var disposer: ((RequestLogObserver) -> Void)?
        
        init(_ disposer: @escaping (RequestLogObserver) -> Void) {
            self.disposer = disposer
        }
        
        deinit {
            dispose()
        }
        
        public func dispose() {
            self.disposer?(self)
            self.disposer = nil
        }
    }
}

extension OSLog {
    private static var subsystem = Bundle.main.bundleIdentifier ?? "com.jarvis.logging"
    internal static let network = OSLog(subsystem: subsystem, category: "RequestNetworkLog")
}
