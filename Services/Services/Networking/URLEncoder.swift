//
//  URLEncoder.swift
//  Services
//
//  Created by Brandon on 2018-12-09.
//  Copyright © 2018 XIO. All rights reserved.
//

import Foundation

/// A URL request encoder protocol that allows custom encoding of a request's parameters
public protocol RequestEncoder {
    /// Encodes the URLRequest with the parameters provided and returns the result
    func encode<T>(_ urlRequest: URLRequest, with parameters: T?) throws -> URLRequest
}

#if !canImport(Alamofire)
/// A URLEncoder protocol that allows custom encoding of a request's parameters
protocol URLEncoder {
    associatedtype ParamterType
    
    /// Default instance of the encoder
    static var `default`: Self { get }
    
    /// Encodes a URLRequest with the parameters provided and returns the result
    func encode(_ urlRequest: URLRequest, with parameters: ParamterType?) throws -> URLRequest
}

/// Encodes a URLRequest's parameters into the query string
struct QueryURLEncoder: URLEncoder {
    static var `default`: QueryURLEncoder {
        return QueryURLEncoder()
    }
    
    /// Encodes the provided parameters into the request's query string
    func encode(_ urlRequest: URLRequest, with parameters: [String: Any]?) throws -> URLRequest {
        var urlRequest = urlRequest
        var urlComponents = URLComponents()
        urlComponents.scheme = urlRequest.url?.scheme
        urlComponents.host = urlRequest.url?.host
        urlComponents.path = urlRequest.url?.path ?? ""
        urlComponents.queryItems = parameters?.map({
            URLQueryItem(name: $0.key, value: $0.value as? String ?? "")
        })
        
        urlRequest.url = urlComponents.url
        urlRequest.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        urlRequest.httpBody = nil
        return urlRequest
    }
}

/// Encodes a URLRequest's parameters into the body as a raw stream of data
struct DataURLEncoder: URLEncoder {
    static var `default`: DataURLEncoder {
        return DataURLEncoder()
    }
    
    /// Encodes the provided parameters into the request's body as a raw stream of data
    func encode(_ urlRequest: URLRequest, with parameters: Data?) throws -> URLRequest {
        var urlRequest = urlRequest
        urlRequest.setValue("application/octet-stream", forHTTPHeaderField: "Content-Type")
        urlRequest.httpBody = parameters
        return urlRequest
    }
}

/// Encodes a URLRequest's parameters into the body as JSON
struct JSONURLEncoder: URLEncoder {
    static var `default`: JSONURLEncoder {
        return JSONURLEncoder()
    }
    
    /// Encodes the provided parameters into the request's body as JSON
    func encode(_ urlRequest: URLRequest, with parameters: [String: Any]?) throws -> URLRequest {
        var urlRequest = urlRequest
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.httpBody = try JSONSerialization.data(withJSONObject: parameters ?? [:], options: .prettyPrinted)
        return urlRequest
    }
}
#endif
