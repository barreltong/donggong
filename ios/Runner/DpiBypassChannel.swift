import Foundation
import Flutter

class DpiBypassChannel: NSObject {
    private let channelName = "com.donggong/dpi"
    
    static func register(with messenger: FlutterBinaryMessenger) {
        let channel = FlutterMethodChannel(name: "com.donggong/dpi", binaryMessenger: messenger)
        let instance = DpiBypassChannel()
        channel.setMethodCallDelegate(instance)
    }
    
    func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        if call.method == "fetch" {
            guard let args = call.arguments as? [String: Any],
                  let url = args["url"] as? String else {
                result(FlutterError(code: "INVALID_ARGS", message: "Missing URL", details: nil))
                return
            }
            
            let headers = args["headers"] as? [String: String]
            
            fetch(url: url, headers: headers, attempt: 1, result: result)
        } else {
            result(FlutterMethodNotImplemented)
        }
    }
    
    private func fetch(url: String, headers: [String: String]?, attempt: Int, result: @escaping FlutterResult) {
        // 1. Dot URL trick for SNI/Host bypass
        var targetUrlStr = url
        if targetUrlStr.contains("hitomi.la/") {
             targetUrlStr = targetUrlStr.replacingOccurrences(of: "hitomi.la/", with: "hitomi.la./")
        }
        
        guard let targetUrl = URL(string: targetUrlStr) else {
            result(FlutterError(code: "INVALID_URL", message: "Invalid URL string: \(targetUrlStr)", details: nil))
            return
        }
        
        var request = URLRequest(url: targetUrl)
        request.httpMethod = "GET"
        request.timeoutInterval = 30
        
        // 2. Padding Headers
        for i in 0..<21 {
            let padding = String(repeating: "x", count: 500)
            request.setValue(padding, forHTTPHeaderField: "X-Padding-\(i)")
        }
        
        // 3. User Headers
        if let headers = headers {
            for (key, value) in headers {
                // Manually handling Host header if possible, though URLSession usually manages it.
                // We add all headers provided.
                request.setValue(value, forHTTPHeaderField: key)
            }
        }
        
        // Use ephemeral session configuration to avoid caching issues
        let config = URLSessionConfiguration.ephemeral
        // Ensure we don't carry over cookies/cache that might identify us or block
        config.httpCookieStorage = nil
        config.urlCache = nil
        
        let session = URLSession(configuration: config)
        
        let task = session.dataTask(with: request) { data, response, error in
            if let error = error {
                print("[DpiBypass] Attempt \(attempt) failed: \(error.localizedDescription)")
                if attempt < 3 {
                    // Retry after delay (200ms)
                    DispatchQueue.global().asyncAfter(deadline: .now() + 0.2) {
                        self.fetch(url: url, headers: headers, attempt: attempt + 1, result: result)
                    }
                } else {
                    result(FlutterError(code: "FETCH_ERROR", message: "All 3 attempts failed: \(error.localizedDescription)", details: nil))
                }
                return
            }
            
            guard let httpResponse = response as? HTTPURLResponse else {
                result(FlutterError(code: "FETCH_ERROR", message: "Invalid response type", details: nil))
                return
            }
            
            if (200...299).contains(httpResponse.statusCode) {
                let body = data != nil ? String(data: data!, encoding: .utf8) ?? "" : ""
                result([
                    "body": body,
                    "statusCode": httpResponse.statusCode
                ])
            } else {
                if httpResponse.statusCode == 404 || attempt >= 3 {
                    let body = data != nil ? String(data: data!, encoding: .utf8) ?? "" : ""
                    result([
                        "body": body,
                        "statusCode": httpResponse.statusCode
                    ])
                } else {
                    // Retry
                    DispatchQueue.global().asyncAfter(deadline: .now() + 0.2) {
                        self.fetch(url: url, headers: headers, attempt: attempt + 1, result: result)
                    }
                }
            }
        }
        task.resume()
    }
}
