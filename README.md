# Jarvis

Configuring the Client:
```Swift
let staticHeaders = [
    "X-CLIENT-PLATFORM": "iOS",
    "Accept": "application/json"
]

Client.default.configure(Configuration(baseURL: "https://example.com", headers: staticHeaders))
```

Custom configuration for the Client:
```Swift
class CustomConfiguration: Configuration {
    override init(baseURL: String, headers: [String: String]) {
        super.init(baseURL, headers)
    }

    public func headers<T>(for endpoint: Endpoint<T>) -> [String: String] {
        let timestamp = Date().timeIntervalSince1970
        var headers: [String: String] = [:]
        
        headers["Accept"] = "application/json"
        headers["X-LANG"] = Bundle.main.applicationLanguage
        headers["X-APP-VERSION"] = Bundle.main.applicationVersion
        headers["X-REQUEST-ID"] = UUID().uuidString.lowercased()
        headers["X-TIMESTAMP"] = "\(timestamp)"
        headers["X-SOURCE"] = "ios"
        
        headers["X-DEVICE-ID"] = deviceId
        headers["X-CONSUMER-KEY"] = consumerKey
        headers["X-SIGNATURE"] = generateSignature(secretKey: secretKey, timeStamp: timestamp)
        
        /// Some requests use an access token..
        /// Some use a bearer token..
        /// Others use credentials or jwt..
        if let token = accessToken {
            headers["Authorization"] = "Basic \(token)"
            headers["Authorization"] = "Bearer \(token)"
            headers["Authorization"] = "Digest \(token)"
            headers["Authorization"] = "HOBA \(token)"
            headers["Authorization"] = "Mutual \(token)"
            headers["Authorization"] = "AWS4-HMAC-SHA256 \(token)"
            headers["X-ACCESS-TOKEN"] = token
        }
        
        /// The static headers take priority over the dynamic headers..
        /// Feel free to change the implementation
        self.headers.forEach({
            headers[$0.key] = $0.value
            if $0.value.isEmpty {
                headers.removeValue(forKey: $0.key)
            }
        })
        
        return self.headers
    }
}


let staticHeaders = [
    "X-CLIENT-PLATFORM": "iOS",
    "Accept": "application/json"
]

Client.default.configure(CustomConfiguration(baseURL: "https://example.com", headers: staticHeaders))
```

Creating a request:
```Swift
Client.default.task(endpoint: Endpoint<String>(.GET, "https://example.com"))
.then { result in
    print(result.data)
    print(result.rawData)
    print(result.response)
}
.catch { error in
    print(error)
}
```

Creating a request with query parameters:
```Swift
Client.default.task(endpoint: Endpoint<String>(.GET, "https://example.com", .query(["id": "something"]))) //Encodes parameters in the query string
.then { result in
    print(result.data)
    print(result.rawData)
    print(result.response)
}
.catch { error in
    print(error)
}
```

Creating a request with json body parameters:
```Swift
Client.default.task(endpoint: Endpoint<String>(.POST, "https://example.com", .json(["id": "something"]))) //Encodes parameters in the body as json
.then { result in
    print(result.data)
    print(result.rawData)
    print(result.response)
}
.catch { error in
    print(error)
}
```

Creating a request with raw data parameters:
```Swift
Client.default.task(endpoint: Endpoint<String>(.POST, "https://example.com", .data("Hello".data(using: .utf8)))) //Encodes parameters in the body as raw data/bytes
.then { result in
    print(result.data)
    print(result.rawData)
    print(result.response)
}
.catch { error in
    print(error)
}
```

Creating a request with Codable parameters:
```Swift
struct Parameters: Encodable {
    let id: String
}

let parameters = Parameters(id: "something")

Client.default.task(endpoint: Endpoint<String>(.POST, "https://example.com", .jsonCodable(parameters))) //Encodes parameters in the body as json
.then { result in
    print(result.data)
    print(result.rawData)
    print(result.response)
}
.catch { error in
    print(error)
}
```

Creating a request with Custom Codable parameters:
```Swift
struct Parameters: Encodable {
    let id: String
}

let parameters = Parameters(id: "something")
let encoder = JSONEncoder()

Client.default.task(endpoint: Endpoint<String>(.POST, "https://example.com", .jsonCodable(parameters, encoder))) //Encodes parameters in the body as json
.then { result in
    print(result.data)
    print(result.rawData)
    print(result.response)
}
.catch { error in
    print(error)
}
```

Creating a request with Custom Encoding Parameters:
```Swift
struct CustomEncoder: RequestEncoder {
    func encode<T>(_ urlRequest: URLRequest, with parameters: T) throws -> URLRequest {
        var urlRequest = urlRequest
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.httpBody = try JSONSerialization.data(withJSONObject: parameters ?? [:], options: .prettyPrinted)
        return urlRequest
    }
}

let parameters = ["id": "something"]

Client.default.task(endpoint: Endpoint<String>(.GET, "https://example.com", .custom(parameters, CustomEncoder()))) //Encodes parameters using the custom encoder
.then { result in
    print(result.data) //A String (serialized response)
    print(result.rawData) //Raw non-serialized data from the response
    print(result.response) //A URLResponse
}
.catch { error in
    print(error)
}
```

Chaining a request:
```Swift
Client.default.task(endpoint: Endpoint<String>(.GET, "https://example.com/getString"))
.then { result in //Non-chaining request
    print(result.data) //data is a string..
    print(result.rawData)
    print(result.response)
}
.then { result -> Request<UIImage> in //Chain the request
    print(result.data) //data is a string..
    print(result.rawData)
    print(result.response)
    
    return Client.default.task(endpoint: Endpoint<String>(.GET, "https://example.com/getImage"))
}
.then { result -> Request<Model> in
    print(result.data) //data is an image..
    print(result.rawData)
    print(result.response)
    
    return Client.default.task(endpoint: Endpoint<Model>(.GET, "https://example.com/getImage"))
}
.then { result in
    print(result.data.size) //data is a model
    print(result.rawData)
    print(result.response)
}
.catch { error in //Catch an error for each request
    print(error)
}
```

Retrying a request:
```Swift
Client.default.task(endpoint: Endpoint<String>(.GET, "https://example.com/getString"))
.retry(3) //The request will try a maximum of 3 times until it succeeds.. if it fails all 3 times, the catch block is called.
//Otherwise the then block is called as soon as it succeeds..
.then { result in
    print(result.data) //A String (serialized response)
    print(result.rawData) //Raw non-serialized data from the response
    print(result.response) //A URLResponse
}
.catch { error in //Catch an error for each request
    print(error)
}
```

Automatic Handling of Session Token Renewal:
```Swift
//When the client receives a 401 http status code, all subsequent requests are entered into a queue.
//The session token is renewed.
//When the session token is renewed, all requests are automatically retried.
//If the session token renewal fails, all requests are cancelled and the queue is cleared.
Client.default.requestInterceptor = BasicRequestInterceptor(
    renewSession: Client.default.task(endpoint: Endpoint<String>(.GET, "https://example.com/refreshToken")), //The endpoint to call to renew the token 
    onTokenRenewed: { client, token, error in
        
        if let token = token {
            print("Token Renewed")
            client.default.configuration.token = token
        }
        else {
            if let error = error {
                print("Error Renewing Token: \(error)")
            }
            
            client.default.configuration.token = nil
            logoutUser()
        }
})
```

Automatic Handling of Session Token Renewal with a max amount of retries:
```Swift
//When the client receives a 401 http status code, all subsequent requests are entered into a queue.
//The session token is renewed.
//When the session token is renewed, all requests are automatically retried.
//If the session token renewal fails, all requests are cancelled and the queue is cleared.
Client.default.requestInterceptor = BasicRequestInterceptor(

    //The endpoint to call to renew the token 
    renewSession: Client.default.task(endpoint: Endpoint<String>(.GET, "https://example.com/refreshToken")).retry(3), //Retry the renewal of tokens up to 3 times..
    //If all 3 retries fail, the queued requests are cancelled and the queue is cleared.

    onTokenRenewed: { client, token, error in
        
        if let token = token {
            print("Token Renewed")
            client.default.configuration.token = token
        }
        else {
            if let error = error {
                print("Error Renewing Token: \(error)")
            }
            
            client.default.configuration.token = nil
            logoutUser()
        }
})
```

Intercepting Requests:
```Swift
public class CustomRequestInterceptor<Token>: RequestInterceptor {
    
    public func willLaunchRequest<T>(_ request: URLRequest, for endpoint: Endpoint<T>) {
        /// Request being launched.. Log it to the console..
    }
    
    public func requestSucceeded<T>(_ request: URLRequest, for endpoint: Endpoint<T>, response: URLResponse) {
        /// Request succeeded.. Log it to the console..
    }
    
    public func requestFailed<T>(_ request: URLRequest, for endpoint: Endpoint<T>, error: Error, response: URLResponse?, completion: RequestCompletionPromise<RequestSuccess<T>>) {
        /// Request failed.. Log it to the console..

        ///MUST call either completion.reject(error) or completion.resolve(result)
        completion.reject(error)

        /// Can also handle session token renewal here or do something before rejecting or completion the request..
        /// For example: Retrying the request

        Client().task(endpoint).then {
            completion.resolve($0)
        }
        .catch {
            completion.reject($0)
        }
    }
}

Client.default.requestInterceptor = CustomRequestInterceptor()
```