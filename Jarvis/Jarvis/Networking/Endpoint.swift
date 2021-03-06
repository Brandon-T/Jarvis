//
//  Endpoint.swift
//  Jarvis
//
//  Created by Brandon on 2018-12-09.
//  Copyright © 2018 XIO. All rights reserved.
//

import Foundation

#if canImport(Alamofire)
import Alamofire
#endif

/// An enum representing the type of an HTTP request.
public enum HTTPMethod: String {
    case GET
    case HEAD
    case POST
    case PUT
    case PATCH
    case DELETE
}

/// An enum that determines how we want to encode a request's parameters
public enum EndpointParameter {
    /// Encodes the parameters as JSON in the request's body
    case json([String: Any])
    
    /// Encodes the parameters as Data(raw bytes) in the request's body
    case data(Data)
    
    /// Encodes the parameters to the request's query parameters
    case query([String: Any])
    
    /// Encodes the `Encodable` model as JSON in the request's body
    case jsonCodable(Encodable, JSONEncoder?)
    
    /// Encodes the `Encodable` model to the request's query parameters
    case queryCodable(Encodable, JSONEncoder?)
    
    /// Performs custom encoding on the parameters specified by the encoder block
    case customData(_ encoder: () throws -> Data)
    
    /// Performs custom encoding on the parameters specified by the encoder block
    case customQuery(_ encoder: () throws -> [String: Any])
    
    /// Performs custom encoding on the parameters specified by the encoder block
    case customJSON(_ encoder: () throws -> [String: Any])
    
    /// Performs custom encoding on the parameters specified by the encoder
    case custom(_ parameters: Any, _ encoder: RequestEncoder)
}

/// The endpoint structure that defines which server endpoint to hit for the request.
public struct Endpoint<T> {
    public let method: HTTPMethod
    public let baseURL: String?
    public let path: String
    public let parameters: EndpointParameter?
    public let headers: [String: String]
    public let shouldHandleCookies: Bool
    
    public init(_ method: HTTPMethod, _ path: String, parameters: EndpointParameter? = nil, headers: [String: String]? = nil, shouldHandleCookies: Bool = true) {
        
        var path = path
        
        if let url = URL(string: path), let scheme = url.scheme, let host = url.host {
            self.baseURL = scheme.appending("://").appending(host)
            path = "\(url.path)\(path.hasSuffix("/") ? "/" : "")"
        }
        else {
            self.baseURL = nil
        }
        
        self.method = method
        self.path = path.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? path
        self.parameters = parameters
        self.headers = headers ?? [:]
        self.shouldHandleCookies = shouldHandleCookies
    }
    
    public init(_ method: HTTPMethod, baseURL: String, path: String, parameters: EndpointParameter? = nil, headers: [String: String]? = nil, shouldHandleCookies: Bool = true) {
        
        #if DEBUG
        /// URL Validation for debug only
        if let url = URL(string: path), url.scheme != nil || url.host != nil {
            fatalError("Invalid path provided to Endpoint")
        }
        
        if URL(string: baseURL) == nil {
            fatalError("Invalid baseURL provided to Endpoint")
        }
        #endif
        
        self.method = method
        self.baseURL = baseURL.isEmpty ? nil : baseURL
        self.path = path.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? path
        self.parameters = parameters
        self.headers = headers ?? [:]
        self.shouldHandleCookies = shouldHandleCookies
    }
    
    /// Encodes this endpoint to a URLRequest
    public func encode(_ baseURL: String? = nil, headers: [String: String]? = nil) throws -> URLRequest? { //swiftlint:disable:this cyclomatic_complexity
        
        guard let baseURL = URL(string: baseURL ?? self.baseURL ?? "") else { return nil }
        guard let url = path.isEmpty ? baseURL : URL(string: path, relativeTo: baseURL) else { return nil }
        var request = URLRequest(url: url, cachePolicy: .useProtocolCachePolicy, timeoutInterval: 30.0)
        
        #if canImport(Alamofire)
        /// Encode method
        request.httpMethod = method.rawValue
        request.httpShouldHandleCookies = shouldHandleCookies
        
        /// Encode headers
        var extraHeaders = headers ?? [:]
        self.headers.forEach({
            extraHeaders[$0.key] = $0.value
            if $0.value.isEmpty {
                extraHeaders.removeValue(forKey: $0.key)
            }
        })
        
        extraHeaders.forEach({ request.setValue($0.value, forHTTPHeaderField: $0.key) })
        
        /// Encode parameters
        if let parameters = parameters {
            switch parameters {
            case .json(let json):
                request = try JSONEncoding.default.encode(request, with: json)
                
            case .data(let data):
                request.setValue("application/octet-stream", forHTTPHeaderField: "Content-Type")
                request.httpBody = data
                
            case .query(let query):
                request = try URLEncoding.default.encode(request, with: query)
                
            case .jsonCodable:
                request = try JSONEncoding.default.encode(request, with: parameters.jsonCodable)

            case .queryCodable:
                request = try URLEncoding.default.encode(request, with: parameters.queryCodable)

            case .customData(let encoder):
                request.setValue("application/octet-stream", forHTTPHeaderField: "Content-Type")
                request.httpBody = try encoder()

            case .customQuery(let encoder):
                request = try URLEncoding.default.encode(request, with: try encoder())

            case .customJSON(let encoder):
                request = try JSONEncoding.default.encode(request, with: try encoder())

            case .custom(let parameters, let encoder):
                request = try encoder.encode(request, with: parameters)
            }
        }

        return request
        #else
        /// Encode method
        request.httpMethod = method.rawValue
        request.httpShouldHandleCookies = shouldHandleCookies

        /// Encode headers
        var extraHeaders = headers ?? [:]
        self.headers.forEach({
            extraHeaders[$0.key] = $0.value
            if $0.value.isEmpty {
                extraHeaders.removeValue(forKey: $0.key)
            }
        })

        extraHeaders.forEach({ request.setValue($0.value, forHTTPHeaderField: $0.key) })

        /// Encode parameters
        if let parameters = parameters {
            switch parameters {
            case .json(let json):
                request = try JSONURLEncoder.default.encode(request, with: json)

            case .data(let data):
                request = try DataURLEncoder.default.encode(request, with: data)

            case .query(let query):
                request = try QueryURLEncoder.default.encode(request, with: query)

            case .jsonCodable:
                request = try JSONURLEncoder.default.encode(request, with: parameters.jsonCodable)

            case .queryCodable:
                request = try QueryURLEncoder.default.encode(request, with: parameters.queryCodable)

            case .customData(let encoder):
                request = try DataURLEncoder.default.encode(request, with: try encoder())

            case .customQuery(let encoder):
                request = try QueryURLEncoder.default.encode(request, with: try encoder())

            case .customJSON(let encoder):
                request = try JSONURLEncoder.default.encode(request, with: try encoder())
                
            case .custom(let parameters, let encoder):
                request = try encoder.encode(request, with: parameters)
            }
        }
        
        return request
        #endif
    }

    /// Creates a coercive Data-Endpoint from this endpoint..
    /// For use when converting one endpoint's type to data without casting..
    internal func asDataEndpoint() -> Endpoint<Data> {
        return Endpoint<Data>(method, baseURL: baseURL ?? "", path: path, parameters: parameters, headers: headers, shouldHandleCookies: shouldHandleCookies)
    }

    /// Creates a coercive Endpoint from this endpoint..
    /// For use when converting one endpoint's type to another without casting..
    internal func asGenericEndpoint<T>() -> Endpoint<T> {
        return Endpoint<T>(method, baseURL: baseURL ?? "", path: path, parameters: parameters, headers: headers, shouldHandleCookies: shouldHandleCookies)
    }
}

// MARK: - Private

extension Encodable {
    /// Encodes an Encodable structure as JSON-Data.
    fileprivate func encode(_ encoder: JSONEncoder) throws -> Data? {
        return try encoder.encode(self)
    }
}

extension EndpointParameter {
    /// Convenience to unwrap the json arguments
    fileprivate var json: [String: Any]? {
        if case let .json(json) = self {
            return json
        }
        return nil
    }

    /// Convenience to unwrap the data arguments
    fileprivate var data: Data? {
        if case let .data(data) = self {
            return data
        }
        return nil
    }

    /// Convenience to unwrap the query arguments
    fileprivate var query: [String: Any]? {
        if case let .query(query) = self {
            return query
        }
        return nil
    }

    /// Convenience to unwrap the json model arguments
    fileprivate var jsonCodable: [String: Any]? {
        if case let .jsonCodable(model, encoder) = self {
            if let data = try? model.encode(encoder ?? JSONEncoder()) {
                return try? JSONSerialization.jsonObject(with: data, options: .init(rawValue: 0)) as? [String: Any]
            }
        }
        return nil
    }

    /// Convenience to unwrap the query model arguments
    fileprivate var queryCodable: [String: Any]? {
        if case let .jsonCodable(model, encoder) = self {
            if let data = try? model.encode(encoder ?? JSONEncoder()) {
                return try? JSONSerialization.jsonObject(with: data, options: .init(rawValue: 0)) as? [String: Any]
            }
        }
        return nil
    }
    
    internal func rawData() -> Data? { //swiftlint:disable:this cyclomatic_complexity
        switch self {
        case .json(let json):
            return try? JSONSerialization.data(withJSONObject: json, options: .prettyPrinted)
            
        case .data(let data):
            if let json = try? JSONSerialization.jsonObject(with: data, options: .init(rawValue: 0)) as? [String: Any] {
                return (try? JSONSerialization.data(withJSONObject: json, options: .prettyPrinted)) ?? data
            }
            return data
            
        case .query(let query):
            return try? JSONSerialization.data(withJSONObject: query, options: .prettyPrinted)
            
        case .jsonCodable(let model, let encoder), .queryCodable(let model, let encoder):
            if let data = try? model.encode(encoder ?? JSONEncoder()) {
                if let json = try? JSONSerialization.jsonObject(with: data, options: .init(rawValue: 0)) as? [String: Any] {
                    return (try? JSONSerialization.data(withJSONObject: json, options: .prettyPrinted)) ?? data
                }
                return data
            }
            return nil
            
        case .customData(let encoder):
            if let data = try? encoder() {
                if let json = try? JSONSerialization.jsonObject(with: data, options: .init(rawValue: 0)) as? [String: Any] {
                    return (try? JSONSerialization.data(withJSONObject: json, options: .prettyPrinted)) ?? data
                }
                return data
            }
            return nil
            
        case .customQuery(let encoder):
            if let json = try? encoder() {
                return try? JSONSerialization.data(withJSONObject: json, options: .prettyPrinted)
            }
            return nil
            
        case .customJSON(let encoder):
            if let json = try? encoder() {
                return try? JSONSerialization.data(withJSONObject: json, options: .prettyPrinted)
            }
            return nil
            
        case .custom(let parameters, let encoder):
            if let request = try? encoder.encode(URLRequest(url: URL(string: "127.0.0.1")!), with: parameters) { //swiftlint:disable:this force_unwrapping
                if let json = try? JSONSerialization.jsonObject(with: request.httpBody ?? Data(), options: .init(rawValue: 0)) as? [String: Any] {
                    return (try? JSONSerialization.data(withJSONObject: json, options: .prettyPrinted)) ?? request.httpBody
                }
                return request.httpBody
            }
            return nil
        }
    }
}
