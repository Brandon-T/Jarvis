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
    
    /// Simple logging - Outgoing Request method, and url is logged
    /// Simple logging - Incoming Response method, and url is logged
    case simple
    
    /// Verbose logging - Outgoing Request method, url, headers, and parameters is logged
    /// Verbose logging - Incoming Response method, url, headers, and parameters is logged
    case verbose
    
    /// All logging - Outgoing Request method, url, headers, parameters, and body is logged
    /// All logging - Incoming Response method, url, headers, parameters, and body is logged
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
