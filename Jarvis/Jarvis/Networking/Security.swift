//
//  Security.swift
//  Jarvis
//
//  Created by Brandon Anthony on 2019-06-14.
//  Copyright © 2019 SO. All rights reserved.
//

import Foundation

#if canImport(Alamofire)
import Alamofire

typealias CertificateEvaluator = PinnedCertificatesTrustEvaluator
typealias PublicKeyEvaluator = PublicKeysTrustEvaluator

public class ClientTrustManager: ServerTrustManager {
    private var evaluateAllHosts: Bool
    private var trustEvaluators: [String: ServerTrustEvaluating]
    private let lock = NSRecursiveLock()
    
    public var isEmpty: Bool {
        return trustEvaluators.isEmpty
    }
    
    public override init(allHostsMustBeEvaluated: Bool = true, evaluators: [String: ServerTrustEvaluating]) {
        self.evaluateAllHosts = allHostsMustBeEvaluated
        self.trustEvaluators = evaluators
        
        super.init(allHostsMustBeEvaluated: allHostsMustBeEvaluated, evaluators: [:])
    }
    
    public override func serverTrustEvaluator(forHost host: String) throws -> ServerTrustEvaluating? {
        lock.lock(); defer { lock.unlock() }
        
        guard let evaluator = trustEvaluators[host] else {
            if evaluateAllHosts {
                throw AFError.serverTrustEvaluationFailed(reason: .noRequiredEvaluator(host: host))
            }
            
            return nil
        }
        
        return evaluator
    }
    
    /// Adds or Removes a trust evaluator for the specified host
    public func setEvaluator(_ evaluator: ServerTrustEvaluating?, for host: String) {
        lock.lock(); defer { lock.unlock() }
        trustEvaluators[host] = evaluator
    }
}
#else
/// SecTrust evaluation protocol
public protocol TrustEvaluator {
    
    /// Evaluates the given trust against the provided host
    /// Throws an error if evaluation fails
    func evaluate(_ trust: SecTrust, forHost host: String) throws
}

/// Evaluates certificate trusts by comparing the certificates for an exact binary match
public final class CertificateEvaluator: TrustEvaluator {
    private let certificates: [SecCertificate]
    private let acceptSelfSignedCertificates: Bool
    private let performDefaultValidation: Bool
    private let validateHost: Bool
    
    public init(certificates: [SecCertificate] = Bundle.main.certificates,
                acceptSelfSignedCertificates: Bool = false,
                performDefaultValidation: Bool = true,
                validateHost: Bool = true) {
        
        self.certificates = certificates
        self.acceptSelfSignedCertificates = acceptSelfSignedCertificates
        self.performDefaultValidation = performDefaultValidation
        self.validateHost = validateHost
    }
    
    public func evaluate(_ trust: SecTrust, forHost host: String) throws {
        guard !certificates.isEmpty else {
            throw RuntimeError("Empty Certificates")
        }
        
        if acceptSelfSignedCertificates {
            guard SecTrustSetAnchorCertificates(trust, certificates as CFArray) == errSecSuccess else {
                throw RuntimeError("Self Signing Certificate Anchor Failed")
            }
            
            guard SecTrustSetAnchorCertificatesOnly(trust, true) == errSecSuccess else {
                throw RuntimeError("Self Signing Certificate Anchor Only Failed")
            }
        }
        
        if performDefaultValidation {
            guard SecTrustSetPolicies(trust, SecPolicyCreateSSL(true, nil)) == errSecSuccess else {
                throw RuntimeError("Trust Set Policies Failed")
            }
            
            var result: SecTrustResultType = .invalid
            guard SecTrustEvaluate(trust, &result) == errSecSuccess, result == .unspecified || result == .proceed else {
                throw RuntimeError("Trust Evaluation Failed")
            }
        }
        
        if validateHost {
            guard SecTrustSetPolicies(trust, SecPolicyCreateSSL(true, host as CFString)) == errSecSuccess else {
                throw RuntimeError("Trust Set Policies for Host Failed")
            }
            
            var result: SecTrustResultType = .invalid
            guard SecTrustEvaluate(trust, &result) == errSecSuccess, result == .unspecified || result == .proceed else {
                throw RuntimeError("Trust Evaluation Failed")
            }
        }
        
        let serverCertificates = Set((0..<SecTrustGetCertificateCount(trust))
            .compactMap { SecTrustGetCertificateAtIndex(trust, $0) }
            .compactMap({ SecCertificateCopyData($0) as Data }))
        
        let clientCertificates = Set(certificates.compactMap({ SecCertificateCopyData($0) as Data }))
        if serverCertificates.isDisjoint(with: clientCertificates) {
            throw RuntimeError("Pinning Failed")
        }
    }
}

/// Evaluates public key trusts by comparing the keys for an exact binary match
public final class PublicKeyEvaluator: TrustEvaluator {
    private let keys: [SecKey]
    private let performDefaultValidation: Bool
    private let validateHost: Bool
    
    public init(keys: [SecKey] = Bundle.main.publicKeys,
                performDefaultValidation: Bool = true,
                validateHost: Bool = true) {
        self.keys = keys
        self.performDefaultValidation = performDefaultValidation
        self.validateHost = validateHost
    }
    
    public func evaluate(_ trust: SecTrust, forHost host: String) throws {
        guard !keys.isEmpty else {
            throw RuntimeError("Empty Public Keys")
        }
        
        if performDefaultValidation {
            guard SecTrustSetPolicies(trust, SecPolicyCreateSSL(true, nil)) == errSecSuccess else {
                throw RuntimeError("Trust Set Policies Failed")
            }
            
            var result: SecTrustResultType = .invalid
            guard SecTrustEvaluate(trust, &result) == errSecSuccess, result == .unspecified || result == .proceed else {
                throw RuntimeError("Trust Evaluation Failed")
            }
        }
        
        if validateHost {
            guard SecTrustSetPolicies(trust, SecPolicyCreateSSL(true, host as CFString)) == errSecSuccess else {
                throw RuntimeError("Trust Set Policies for Host Failed")
            }
            
            var result: SecTrustResultType = .invalid
            guard SecTrustEvaluate(trust, &result) == errSecSuccess, result == .unspecified || result == .proceed else {
                throw RuntimeError("Trust Evaluation Failed")
            }
        }
        
        let serverKeys = Set((0..<SecTrustGetCertificateCount(trust))
            .compactMap { SecTrustGetCertificateAtIndex(trust, $0) }
            .compactMap({ certificate -> SecKey? in
                var trust: SecTrust?
                let status = SecTrustCreateWithCertificates(certificate, SecPolicyCreateBasicX509(), &trust)
                guard status == errSecSuccess, let certTrust = trust else { return nil }
                return SecTrustCopyPublicKey(certTrust)
            })
            .compactMap({ SecKeyCopyExternalRepresentation($0, nil) as Data? }))
        
        let clientKeys = Set(keys.compactMap({ SecKeyCopyExternalRepresentation($0, nil) as Data? }))
        
        if serverKeys.isDisjoint(with: clientKeys) {
            throw RuntimeError("Pinning Failed")
        }
    }
}

protocol ServerTrustManager {
    init(allHostsMustBeEvaluated: Bool, evaluators: [String: TrustEvaluator])
    func serverTrustEvaluator(forHost host: String) throws -> TrustEvaluator?
}

/// Trust Manager that manages which hosts gets evaluated
public class ClientTrustManager: ServerTrustManager {
    private var evaluateAllHosts: Bool
    private var trustEvaluators: [String: TrustEvaluator]
    private let lock = NSRecursiveLock()
    
    public var isEmpty: Bool {
        return trustEvaluators.isEmpty
    }
    
    required public init(allHostsMustBeEvaluated: Bool = true, evaluators: [String: TrustEvaluator]) {
        self.evaluateAllHosts = allHostsMustBeEvaluated
        self.trustEvaluators = evaluators
    }
    
    /// Returns a trust evaluator for the specified host if any exists
    public func serverTrustEvaluator(forHost host: String) throws -> TrustEvaluator? {
        lock.lock(); defer { lock.unlock() }
        
        guard let evaluator = trustEvaluators[host] else {
            if evaluateAllHosts {
                throw RuntimeError("No Evaluators found, for the specified host: \(host)")
            }
            return nil
        }
        return evaluator
    }
    
    /// Adds or Removes a trust evaluator for the specified host
    public func setEvaluator(_ evaluator: TrustEvaluator?, for host: String) {
        lock.lock(); defer { lock.unlock() }
        trustEvaluators[host] = evaluator
    }
}

extension Bundle {
    /// Retrieves all public keys within the bundle.
    public var publicKeys: [SecKey] {
        return certificates.compactMap({ certificate -> SecKey? in
            var trust: SecTrust?
            let status = SecTrustCreateWithCertificates(certificate, SecPolicyCreateBasicX509(), &trust)
            guard status == errSecSuccess, let certTrust = trust else { return nil }
            return SecTrustCopyPublicKey(certTrust)
        })
    }
    
    /// Retrieves all certificates within the bundle.
    public var certificates: [SecCertificate] {
        let paths = Set([".cer", ".CER", ".crt", ".CRT", ".der", ".DER"].map {
            self.paths(forResourcesOfType: $0, inDirectory: nil)
        }.joined())
        
        return paths.compactMap({ path -> SecCertificate? in
            guard let certificateData = try? Data(contentsOf: URL(fileURLWithPath: path)) as CFData else {
                return nil
            }
            return SecCertificateCreateWithData(nil, certificateData)
        })
    }
}
#endif
