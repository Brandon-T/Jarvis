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
    private let logsOutgoingRequest: Bool
    
    public init(_ logLevel: LogLevel, logsOutgoingRequest: Bool = false) {
        self.client = nil
        self.requests = [:]
        self.logLevel = logLevel
        self.logsOutgoingRequest = logsOutgoingRequest
    }
    
    public func willLaunchRequest<T>(_ request: inout URLRequest, for endpoint: Endpoint<T>) {
        requests.updateValue(Date(), forKey: request)
        log(request: request, for: endpoint)
    }
    
    public func requestSucceeded<T>(_ request: URLRequest, for endpoint: Endpoint<T>, data: Data, response: URLResponse) {
        log(request: request, for: endpoint, data: data, response: response)
    }
    
    public func requestFailed<T>(_ request: URLRequest, for endpoint: Endpoint<T>, error: Error, response: URLResponse?, completion: RequestCompletionPromise<RequestSuccess<T>>) {
        log(request: request, for: endpoint, error: error, response: response)
    }
}

extension RequestLogger {
    private struct RequestPacket {
        let startDate: Date
        let headers: [String: String]
        let status: String
        let body: String
        
        let response: HTTPURLResponse?
        let responseData: Data?
        let error: Error?
        let endDate: Date?
    }
    
    private func log<T>(request: URLRequest, for endpoint: Endpoint<T>, data: Data? = nil, error: Error? = nil, response: URLResponse? = nil) {
        
        if logLevel == .none {
            return
        }
        
        let startDate = requests[request] ?? Date()
        
        if data == nil && error == nil && response == nil {
            if !logsOutgoingRequest {
                return
            }
            
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
            var headers = request.allHTTPHeaderFields ?? [:]
            headers.removeValue(forKey: "Host")
            headers.removeValue(forKey: "host")
            
            // Normalize body
            let body = String(data: request.httpBody ?? Data(), encoding: .utf8) ?? ""
            
            // Log Build
            var logData = ""
            logData += String(format: "%@ %@ %@\n", date, request.httpMethod?.uppercased() ?? "GET", path)
            logData += query.isEmpty ? "" : "Query: \(query)\n"
            logData += "Host: \(host)\n"
            logData += "Status: Pending\n"
            
            if logLevel >= .verbose && !headers.isEmpty {
                logData += "\n"
                logData += "Headers:\n"
                logData += indent(headers.compactMap({ "\($0.key): \($0.value)" }).joined(separator: "\n"))
                logData += "\n"
            }
            
            if logLevel >= .all && !body.isEmpty {
                logData += "Body:\n"
                logData += indent(body)
            }
            
            // Log Message
            logMessage(logData)
        }
        else {
            guard let response = response as? HTTPURLResponse else {
                return
            }
            
            let components = Calendar.current.dateComponents([.second, .minute, .hour], from: startDate)
            let date = String(format: "[%02ld:%02ld:%02ld]", components.hour!, components.minute!, components.second!) //swiftlint:disable:this force_unwrapping
            
            let endDate = Date()
            let timeInterval = endDate.timeIntervalSince(startDate)
            
            // Normalize host
            var host = request.url?.host ?? ""
            host = host.isEmpty ? "localhost" : host
            
            // Normalize path
            var path = request.url?.path ?? ""
            path = path.isEmpty ? "/" : path
            
            // Normalize query
            let query = request.url?.query ?? ""
            
            // Normalize headers
            var headers = response.allHeaderFields
            headers.removeValue(forKey: "Host")
            headers.removeValue(forKey: "host")
            
            // Normalize body
            let contentType = response.allHeaderFields["Content-Type"] as? String ?? "application/octet-stream"

            // Log Build
            var logData = ""
            logData += String(format: "%@ %@ %@\n", date, request.httpMethod?.uppercased() ?? "GET", path)
            logData += query.isEmpty ? "" : "Query: \(query)\n"
            logData += "Host: \(host)\n"
            logData += "Status: \(response.statusCode == 200 ? "OK" : HTTPURLResponse.localizedString(forStatusCode: response.statusCode).uppercased())\n"
            logData += "Status Code: \(response.statusCode)\n"
            logData += "Elapsed Time: \(String(format: "%.2fs", timeInterval))\n"
            
            if logLevel >= .verbose && !headers.isEmpty {
                logData += "\n"
                logData += "Headers:\n"
                logData += indent(headers.compactMap({ "\($0.key): \($0.value)" }).joined(separator: "\n"))
                logData += "\n"
            }
            
            if logLevel >= .all, let body = data, !body.isEmpty {
                logData += "\nBody \(contentType):\n"
                
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
        }
        
        requests.removeValue(forKey: request)
    }
    
    private func logMessage(_ message: String) {
        print("\n")
        print("\n")
        print("**********************************")
        print("\n")
        
        #if USE_OS_LOG
        if logLevel != .none {
            os_log(message, log: .network, type: .info)
        }
        #else
        if logLevel != .none {
            print(message)
        }
        #endif
        
        print("\n")
        print("**********************************")
        print("\n")
        print("\n")
    }
    
    private func indent(_ input: String, amount: Int = 4) -> String {
        let indentation = String(repeating: " ", count: amount)
        return "\(indentation)\(input.components(separatedBy: "\n").joined(separator: "\n\(indentation)"))"
    }
}

extension OSLog {
    private static var subsystem = Bundle.main.bundleIdentifier ?? "com.jarvis.logging"
    internal static let network = OSLog(subsystem: subsystem, category: "RequestNetworkLog")
}
