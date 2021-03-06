//
//  RuntimeError.swift
//  LongShot
//
//  Created by Brandon on 2018-01-05.
//  Copyright © 2018 XIO. All rights reserved.
//

import Foundation

public class RuntimeError: NSError {
    private let message: String

    public init(_ message: String, code: Int = -1) {
        self.message = message
        
        if #available(iOS 11.0, *) {
            super.init(domain: "Jarvis.RuntimeError", code: code, userInfo: [
                NSLocalizedDescriptionKey: message,
                NSLocalizedFailureErrorKey: message
            ])
        }
        else {
            super.init(domain: "Jarvis.RuntimeError", code: code, userInfo: [
                NSLocalizedDescriptionKey: message
            ])
        }
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError()
    }
}
