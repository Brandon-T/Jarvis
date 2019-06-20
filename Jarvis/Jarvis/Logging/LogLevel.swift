//
//  LogLevel.swift
//  Jarvis
//
//  Created by Brandon on 2019-06-18.
//  Copyright © 2019 SO. All rights reserved.
//

import Foundation

/// The level of logging that should be output
public enum LogLevel: Int {
    
    /// No logging - Logging disabled
    case none
    
    /// Request  - method
    ///          - url
    ///
    /// Response - statusCode
    ///          - error
    case simple
    
    /// Request  - method
    ///          - url
    ///          - parameters
    ///
    /// Response - statusCode
    ///          - error
    case verbose
    
    /// Request  - method
    ///          - url
    ///          - headers
    ///          - parameters
    ///
    /// Response - statusCode
    ///          - body
    ///          - error
    case trace
    
    /// Request  - method
    ///          - url
    ///          - headers
    ///          - parameters
    ///
    /// Response - statusCode
    ///          - headers
    ///          - body
    ///          - error
    case all
}

extension LogLevel: Comparable {
    public static func == (lhs: LogLevel, rhs: LogLevel) -> Bool {
        return lhs.rawValue == rhs.rawValue
    }
    
    public static func < (lhs: LogLevel, rhs: LogLevel) -> Bool {
        return lhs.rawValue < rhs.rawValue
    }
    
    public static func <= (lhs: LogLevel, rhs: LogLevel) -> Bool {
        return lhs.rawValue <= rhs.rawValue
    }
    
    public static func > (lhs: LogLevel, rhs: LogLevel) -> Bool {
        return lhs.rawValue > rhs.rawValue
    }
    
    public static func >= (lhs: LogLevel, rhs: LogLevel) -> Bool {
        return lhs.rawValue >= rhs.rawValue
    }
}
