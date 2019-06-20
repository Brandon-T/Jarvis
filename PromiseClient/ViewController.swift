//
//  ViewController.swift
//  PromiseClient
//
//  Created by Brandon Anthony on 2019-04-29.
//  Copyright © 2019 SO. All rights reserved.
//

import UIKit
import Jarvis
import os

class ViewController: UIViewController {
    override func viewDidLoad() {
        super.viewDidLoad()

        /// Handling session renewal..
        /// Globally intercepting all requests for modification or logging..
        Client.default.requestInterceptor = BasicRequestInterceptor(
            renewSession: {
                Client.default.task(endpoint: Endpoint<String>(.GET, "https://github.com/")).retry(3)
            },
            onTokenRenewed: { client, token, error in
                
                if let token = token {
                    print("Token Renewed")
                    
                    //<#client.shared.token = token#>
                }
                else {
                    if let error = error {
                        print("Error Renewing Token: \(error)")
                    }
                    
                    //<#client.shared.token = nil#>
                    
                    //<#Logout User#>
                }
        })
        
        
        let logger = RequestLogger(.simple)
        Client.default.requestInterceptor = logger
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.present(RequestLogViewController(logger), animated: true, completion: nil)
        }
        
        Client.default.task(endpoint: Endpoint<String>(.GET, "https://google.ca"))
        .retry(2)
        .then { res in
            print(res)
        }
        .then { result -> Request<String> in
            Client.default.task(endpoint: Endpoint<String>(.GET, "https://imgur.com"))
        }
        .then { result -> Request<String> in
            Client.default.task(endpoint: Endpoint<String>(.GET, "https://stackoverflow.com"))
        }
        .then { result in
            
        }
        .catch {
            print($0)
        }
    }
}
