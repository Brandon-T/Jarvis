//
//  Client.swift
//  Services
//
//  Created by Brandon on 2018-12-08.
//  Copyright © 2018 XIO. All rights reserved.
//

import Foundation
import CommonCrypto

#if os(macOS)
import Cocoa
#elseif os(iOS)
import UIKit
#endif

#if canImport(Alamofire)
import Alamofire
#endif

/// A client interceptor protocol
/// All request interceptors must implement this protocol
public protocol RequestInterceptor {
    
    /// MUST be weak in the implementation!
    var client: Client? { get set }
    
    /// A request is about to be executed
    func willLaunchRequest<T>(_ request: URLRequest, for endpoint: Endpoint<T>)
    
    /// A request has succeeded
    func requestSucceeded<T>(_ request: URLRequest, for endpoint: Endpoint<T>, response: URLResponse)
    
    /// A request has failed
    func requestFailed<T>(_ request: URLRequest, for endpoint: Endpoint<T>, error: Error, response: URLResponse?, completion: RequestCompletionPromise<RequestSuccess<T>>)
}


/// A client class that executes network requests/tasks and handles serialization automatically
final public class Client: NSObject {
    /// Singleton default instance of Client
    public static let `default` = Client()
    
    //Private initializer
    private override init() {
        super.init()
    }
    
    public init(configuration: Configuration) {
        super.init()
        self.configure(configuration)
    }
    
    public func configure(_ configuration: Configuration) {
        self.configuration = configuration
    }
    
    /// A request interceptor
    public var requestInterceptor: RequestInterceptor? {
        didSet {
            self.requestInterceptor?.client = self //requestInterceptor.client MUST be weak!
        }
    }
    
    /// A configuration instance that is used to configure the client
    private(set) public var configuration: Configuration?
    
    /// Handle alamofire requests
    #if canImport(Alamofire)
    private lazy var sessionManager: Session = {
        let configuration = URLSessionConfiguration.default
        configuration.protocolClasses = nil
        configuration.urlCache = nil
        
        let authenticationMethods = ServerTrustManager(allHostsMustBeEvaluated: false, evaluators: [:])
        
        return Session(configuration: configuration, startRequestsImmediately: false, interceptor: nil, serverTrustManager: authenticationMethods)
    }()
    #else
    
    /// A dictionary with a list of domains and their TrustAuthentication (security implementations)
    /// Use this to implement SSL pinning or certificate trust
    private var authenticationMethods = [String: TrustAuthentication]()
    
    /// The Session Manager.. We can implement certificate pinning here to prevent MITM attack or implement Basic OAuth authentication here..
    private lazy var sessionManager: URLSession = {
        let configuration = URLSessionConfiguration.default
        configuration.protocolClasses = nil
        configuration.urlCache = nil
        
        self.authenticationMethods = [:]
        
        return URLSession.init(configuration: URLSessionConfiguration.default, delegate: self, delegateQueue: nil)
    }()
    #endif
    
    // MARK: - Tasks
    
    /// Returns a request/promise handler for the specified endpoint and immediately executes a request for this endpoint where T is NOT decodable..
    /// IE: Serializes the response to [String: Any] where Any is not Codable..
    public func task<T>(endpoint: Endpoint<T>, interceptor: RequestInterceptor? = nil) -> Request<T> {
        return urlRequest(endpoint: endpoint, interceptor: interceptor, { data -> T in
            if T.self == String.self {
                return (String(data: data, encoding: .utf8) ?? "") as! T
            }
            
            if let result = try JSONSerialization.jsonObject(with: data, options: .mutableLeaves) as? T {
                return result
            }
            
            throw RuntimeError("Cannot Serialize `Data` as Type: \(String(describing: T.self))")
        })
    }
    
    /// Returns a request/promise handler for the specified endpoint and immediately executes a request for this endpoint where T is decodable..
    /// IE: Serializes the response to some model where the model is Codable..
    public func task<T: Decodable>(endpoint: Endpoint<T>, interceptor: RequestInterceptor? = nil) -> Request<T> {
        return urlRequest(endpoint: endpoint, interceptor: interceptor, { data -> T in
            if T.self == String.self {
                return (String(data: data, encoding: .utf8) ?? "") as! T
            }
            return try JSONDecoder().decode(T.self, from: data)
        })
    }

    /// Returns a request/promise handler for the specified endpoint and immediately executes a request for this endpoint where the endpoint returns NOTHING..
    public func task(endpoint: Endpoint<Void>, interceptor: RequestInterceptor? = nil) -> Request<Void> {
        return urlRequest(endpoint: endpoint, interceptor: interceptor, { data -> Void in
            return Void()
        })
    }

    /// Returns a request/promise handler for the specified endpoint and immediately executes a request for this endpoint where the endpoint returns raw data..
    public func task(endpoint: Endpoint<Data>, interceptor: RequestInterceptor? = nil) -> Request<Data> {
        return urlRequest(endpoint: endpoint, interceptor: interceptor, { data -> Data in
            return data
        })
    }
    
    #if os(macOS)
    /// Returns a request/promise handler for the specified endpoint and immediately executes a request for this endpoint where the endpoint returns raw data..
    public func task(endpoint: Endpoint<NSImage>, interceptor: RequestInterceptor? = nil) -> Request<NSImage> {
        return urlRequest(endpoint: endpoint, interceptor: interceptor, { data -> NSImage in
            guard let image = NSImage(data: data) else {
                throw RuntimeError("Cannot Deserialize Data into UIImage")
            }
            return image
        })
    }
    #elseif os(iOS)
    /// Returns a request/promise handler for the specified endpoint and immediately executes a request for this endpoint where the endpoint returns raw data..
    public func task(endpoint: Endpoint<UIImage>, interceptor: RequestInterceptor? = nil) -> Request<UIImage> {
        return urlRequest(endpoint: endpoint, interceptor: interceptor, { data -> UIImage in
            guard let image = UIImage(data: data) else {
                throw RuntimeError("Cannot Deserialize Data into UIImage")
            }
            return image
        })
    }
    #endif
}

// MARK: - Requests

extension Client {
    /// Generic request executer which executes a request to an endpoint and providers a serialization block which is used to resolve the future/promise..
    private func urlRequest<T, U>(endpoint: Endpoint<T>, interceptor: RequestInterceptor? = nil, _ serializer: @escaping (Data) throws -> U) -> Request<U> {
        
        let requestInterceptor = interceptor ?? self.requestInterceptor
        
        /// Create a request with the given endpoint..
        var request: URLRequest! = nil
        do {
            request = try endpoint.encode(configuration?.baseURL(for: endpoint).absoluteString, headers: configuration?.headers(for: endpoint))
        } catch let error {
            let promise = RequestCompletion<RequestSuccess<U>>({ _ in }, { _ in })
            let request = Request<U>(self, endpoint: endpoint.asGenericEndpoint(), task: nil, promise: promise)
            promise.reject(error)
            return request
        }
        
        requestInterceptor?.willLaunchRequest(request, for: endpoint)
        
        #if canImport(Alamofire)
        /// Create a promise that encapsulates the raw request callback
        let promise = RequestCompletion<RequestSuccess<U>>({ _ in }, { _ in })
        let task = self.sessionManager.request(request).validate().responseData(completionHandler: { response in
            /// Reject the request.. Some sort of error has occurred.
            if let error = response.error {
                if let interceptor = requestInterceptor {
                    return interceptor.requestFailed(request, for: endpoint, error: error, response: response.response, completion: .init(promise))
                } else {
                    return promise.reject(RequestFailure(error: error, rawData: response.data, response: response.response))
                }
            }
            
            if let data = response.data, let httpResponse = response.response {
                if let response = response.response {
                    if response.statusCode < 200 || response.statusCode > 299 {
                        let error = RequestFailure(error: RuntimeError("Validation Failed: \(response.statusCode)"), rawData: data, response: response)
                        
                        if let interceptor = requestInterceptor {
                            return interceptor.requestFailed(request, for: endpoint, error: error, response: response, completion: .init(promise))
                        }
                        else {
                            return promise.reject(error)
                        }
                    }
                }
                
                do {
                    /// Ask the external resolver to serialize the data and return it to the promises' resolver.
                    promise.resolve(
                        RequestSuccess<U>(data: try serializer(data),
                                          rawData: data,
                                          response: httpResponse
                        )
                    )
                    
                    return requestInterceptor?.requestSucceeded(request, for: endpoint, response: httpResponse) ?? Void()
                } catch {
                    if let interceptor = requestInterceptor {
                        return interceptor.requestFailed(request, for: endpoint, error: error, response: httpResponse, completion: .init(promise))
                    }
                    else {
                        return promise.reject(RequestFailure(error: error, rawData: data, response: httpResponse))
                    }
                }
            }
            
            /// Reject the request.. We don't know how to handle it.
            let error = RequestFailure(error: RuntimeError("No Response from the server"), rawData: response.data, response: response.response)
            
            if let interceptor = requestInterceptor {
                return interceptor.requestFailed(request, for: endpoint, error: error, response: response.response, completion: .init(promise))
            }
            else {
                return promise.reject(error)
            }
        })
        #else
        /// Create a promise that encapsulates the raw request callback
        let promise = RequestCompletion<RequestSuccess<U>>({ _ in }, { _ in })
        let task = self.sessionManager.dataTask(with: request) { data, response, error in
            /// Reject the request.. Some sort of error has occurred.
            if let error = error {
                if let interceptor = requestInterceptor {
                    return interceptor.requestFailed(request, for: endpoint, error: error, response: response, completion: .init(promise))
                } else {
                    return promise.reject(RequestFailure(error: error, rawData: data, response: response))
                }
            }
            
            if let data = data, let response = response {
                if let response = response as? HTTPURLResponse {
                    if response.statusCode < 200 || response.statusCode > 299 {
                        let error = RequestFailure(error: RuntimeError("Validation Failed: \(response.statusCode)"), rawData: data, response: response)
                        
                        if let interceptor = requestInterceptor {
                            return interceptor.requestFailed(request, for: endpoint, error: error, response: response, completion: .init(promise))
                        }
                        else {
                            return promise.reject(error)
                        }
                    }
                }
                
                do {
                    /// Ask the external resolver to serialize the data and return it to the promises' resolver.
                    promise.resolve(
                        RequestSuccess<U>(data: try serializer(data),
                                          rawData: data,
                                          response: response
                        )
                    )
                    
                    return requestInterceptor?.requestSucceeded(request, for: endpoint, response: response) ?? Void()
                } catch {
                    if let interceptor = requestInterceptor {
                        return interceptor.requestFailed(request, for: endpoint, error: error, response: response, completion: .init(promise))
                    }
                    else {
                        return promise.reject(RequestFailure(error: error, rawData: data, response: response))
                    }
                }
            }
            
            /// Reject the request.. We don't know how to handle it.
            let error = RequestFailure(error: RuntimeError("No Response from the server"), rawData: data, response: response)
            
            if let interceptor = requestInterceptor {
                return interceptor.requestFailed(request, for: endpoint, error: error, response: response, completion: .init(promise))
            }
            else {
                return promise.reject(error)
            }
        }
        #endif

        /// Coercion..
        return Request<U>(self, endpoint: endpoint.asGenericEndpoint(), task: task, promise: promise)
    }
}

#if !canImport(Alamofire)
// MARK: - Security

extension Client: URLSessionDataDelegate {
    
    /// A TrustAuthentication that determines how to handle the server challenge..
    enum TrustAuthentication {
        case pinnedCertificates(_ certificates: SecCertificate)
        case pinnedPublicKeys(_ keys: [SecKey])
        case pinnedCredentials(_ username: String, _ password: String)
    }
    
    /// Handles the server authentication challenge via Basic OAuth OR certificate pinning via certificate OR public key pinning.
    public func urlSession(_ session: URLSession, didReceive challenge: URLAuthenticationChallenge, completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        
        /// NO AUTH
        if self.authenticationMethods.isEmpty {
            return completionHandler(.performDefaultHandling, nil)
        }

        /// BASIC
        if challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodHTTPBasic {
            if challenge.proposedCredential != nil || challenge.previousFailureCount > 0 {
                return completionHandler(.cancelAuthenticationChallenge, nil)
            }
            
            if case let .pinnedCredentials(credentials)? = self.authenticationMethods[challenge.protectionSpace.host] {
                let creds = URLCredential(user: credentials.0, password: credentials.1, persistence: .forSession)
                return completionHandler(.useCredential, creds)
            }
            return completionHandler(.performDefaultHandling, nil)
        }
        
        /// PINNING
        if challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust {
            guard let clientAuthentication = self.authenticationMethods[challenge.protectionSpace.host] else { return completionHandler(.performDefaultHandling, nil) }
            
            if let serverTrust = challenge.protectionSpace.serverTrust {
                var secresult = SecTrustResultType.invalid
                let status = SecTrustEvaluate(serverTrust, &secresult)
                
                if status == errSecSuccess {
                    if let serverCertificate = SecTrustGetCertificateAtIndex(serverTrust, 0) {
                        if case let .pinnedCertificates(certificate) = clientAuthentication {
                            let serverFingerprint = Client.sha1FingerPrint(data: SecCertificateCopyData(serverCertificate) as Data)
                            let clientFingerprint = Client.sha1FingerPrint(data: SecCertificateCopyData(certificate) as Data)
                            
                            if serverFingerprint == clientFingerprint {
                                return completionHandler(.useCredential, URLCredential(trust: serverTrust))
                            }
                            return completionHandler(.cancelAuthenticationChallenge, nil)
                        }
                        
                        if case let .pinnedPublicKeys(publicKeys) = clientAuthentication {
                            if #available(iOS 12.0, macOS 10.14, *) {
                                if let serverKey = SecCertificateCopyKey(serverCertificate), let serverPublicKey = (SecKeyCopyExternalRepresentation(serverKey, nil) as Data?)?.base64EncodedString() {
                                    
                                    for key in publicKeys {
                                        if let localPublicKey = (SecKeyCopyExternalRepresentation(key, nil) as Data?)?.base64EncodedString() {
                                            if localPublicKey == serverPublicKey {
                                                return completionHandler(.useCredential, URLCredential(trust: serverTrust))
                                            }
                                        }
                                    }
                                }
                            }
                            else {
                                #if os(macOS)
                                var serverKey: SecKey? = nil
                                if SecCertificateCopyPublicKey(serverCertificate, &serverKey) == noErr, let serverKey = serverKey, let serverPublicKey = (SecKeyCopyExternalRepresentation(serverKey, nil) as Data?)?.base64EncodedString() {
                                    
                                    for key in publicKeys {
                                        if let localPublicKey = (SecKeyCopyExternalRepresentation(key, nil) as Data?)?.base64EncodedString() {
                                            if localPublicKey == serverPublicKey {
                                                return completionHandler(.useCredential, URLCredential(trust: serverTrust))
                                            }
                                        }
                                    }
                                }
                                #else
                                if let serverKey = SecCertificateCopyPublicKey(serverCertificate), let serverPublicKey = (SecKeyCopyExternalRepresentation(serverKey, nil) as Data?)?.base64EncodedString() {
                                    
                                    for key in publicKeys {
                                        if let localPublicKey = (SecKeyCopyExternalRepresentation(key, nil) as Data?)?.base64EncodedString() {
                                            if localPublicKey == serverPublicKey {
                                                return completionHandler(.useCredential, URLCredential(trust: serverTrust))
                                            }
                                        }
                                    }
                                }
                                #endif
                            }
                            
                            return completionHandler(.cancelAuthenticationChallenge, nil)
                        }
                    }
                }
            }
            
            return completionHandler(.cancelAuthenticationChallenge, nil)
        }
        
        return completionHandler(.performDefaultHandling, nil)
    }
}

// MARK: - Internal

extension Client {
    /// Retrieves all public keys within the bundle.
    private static func publicKeys(in bundle: Bundle = Bundle.main) -> [SecKey] {
        if #available(iOS 12.0, macOS 10.14, *) {
            return certificates(in: bundle).compactMap({ SecCertificateCopyKey($0) })
        }
        else {
            #if os(macOS)
            return certificates(in: bundle).compactMap({
                var publicKey: SecKey? = nil
                SecCertificateCopyPublicKey($0, &publicKey)
                return publicKey
            })
            #else
            return certificates(in: bundle).compactMap({ SecCertificateCopyPublicKey($0) })
            #endif
        }
    }
    
    /// Retrieves all certificates within the bundle.
    private static func certificates(in bundle: Bundle = Bundle.main) -> [SecCertificate] {
        var certificates: [SecCertificate] = []
        
        let paths = Set([".cer", ".CER", ".crt", ".CRT", ".der", ".DER"].map { fileExtension in
            bundle.paths(forResourcesOfType: fileExtension, inDirectory: nil)
            }.joined())
        
        for path in paths {
            if let certificateData = try? Data(contentsOf: URL(fileURLWithPath: path)) as CFData, let certificate = SecCertificateCreateWithData(nil, certificateData) {
                certificates.append(certificate)
            }
        }
        
        return certificates
    }
    
    /// Retrieves a sha1 fingerprint from data (mostly used for certificate data)..
    /// Note that Sha1 is deprecated & broken! but some servers still use it!
    private static func sha1FingerPrint(data: Data) -> String {
        var bytes = [UInt8](repeating: 0, count: Int(CC_SHA1_DIGEST_LENGTH))
        data.withUnsafeBytes {
            _ = CC_SHA1($0.baseAddress, CC_LONG(data.count), &bytes)
        }
        
        var fingerPrint = String()
        for i in 0..<Int(CC_SHA1_DIGEST_LENGTH) {
            fingerPrint = fingerPrint.appendingFormat("%02x", bytes[i])
        }
        return fingerPrint.trimmingCharacters(in: .whitespaces)
    }
}
#endif
