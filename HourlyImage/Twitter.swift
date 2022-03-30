//
//  Twitter.swift
//  HourlyImage
//
//  Created by Pascal on 30/03/2022.
//

import Foundation
//import _Concurrency
import CryptoKit
import AppKit

enum TwitterAPIError: Error {
    case error
    case message(String)
    case requieresNewerMacos
    case encodingFailed
}

struct TwitterError: Decodable {
    var code: Int16
    var message: String
}

struct ErrorResponse: Decodable {
    var errors: [TwitterError]
}

struct StatusResponse: Decodable {
    var created_at: String?
    var id_str: String?
    var text: String?
}

struct JSONResponse: Decodable {
    var created_at: String?
    var id_str: String?
    var text: String?
    var media_id_string: String?
}

struct APIResponse<T: Decodable>: Decodable {
    var data:T
}

class Twitter {
    // MARK: -- endpoints
    private let STATUSES_UPDATE = "statuses/update"
    private let STATUSES_DESTROY = "statuses/destroy"
    private let MEDIA_UPLOAD = "media/upload"
    
    private let USER_ID = "71585979"
    
    // MARK: -- instances
    private var connection: TwitterOAuth
    
    // MARK: - methodes
    init(consumerKey: String, consumerSecret: String, oauthToken: String, oauthTokenSecret: String) {
        connection = TwitterOAuth(consumerKey: consumerKey, consumerSecret: consumerSecret, oauthToken: oauthToken, oauthTokenSecret: oauthTokenSecret)
    }
    
    func update(status: String, media_ids: [String] = [], coordinates: (Double, Double)) async throws -> JSONResponse {
        var parameters:Dictionary<String, String> = [
            "status": status,
            "lat": "\(coordinates.0)",
            "long": "\(coordinates.1)",
            "display_coordinates": "true",
        ]
        if !media_ids.isEmpty {
            parameters["media_ids"] = media_ids.joined(separator: ",")
        }
        return try await connection.post(path: STATUSES_UPDATE, parameters: parameters)
    }
    
    func destroy(id: String) async throws -> JSONResponse {
        return try await connection.post(path: "\(STATUSES_DESTROY)/\(id)", parameters: [:])
    }
    
    func upload(data: String, mediaCategory: String = "tweet_image") async throws -> JSONResponse {
        let parameters: Dictionary<String, String> = [
            "media_data": data,
            "media_category": mediaCategory,
            "additional_owners": USER_ID, // user-id
        ];
        return try await connection.upload(path: MEDIA_UPLOAD, parameters: parameters)
    }
}

class Utils {
    static func generateNonce() -> String {
        let inputData = "\(Date())adsf".data(using: String.Encoding.utf8) ?? Data()
        let hashedData = Insecure.MD5.hash(data: inputData)
        let hashString = hashedData.compactMap {
            return String(format: "%02x", $0)
        }.joined()
        return hashString
    }
    
    static func rawurlencode(_ string: String) -> String? {
        // .urlQueryAllowed includes / and ? as well (which has to be encoded) since it was added later to the RFC
        let unreserved = "-._~"
        let allowed = NSMutableCharacterSet.alphanumeric()
        allowed.addCharacters(in: unreserved)
        return string.addingPercentEncoding(withAllowedCharacters: allowed as CharacterSet)
    }
}

class Request {
    // oauth version
    private let version = "1.0"
    private let signatureMethod = "HMAC-SHA1"
    
    /// instance properties
    private var consumerKey: String
    private var consumerSecret: String
    private var oauthToken: String
    private var oauthTokenSecret: String
    private var url: String
    private var method: String
    private var parameters: Dictionary<String, String>
    private var getParameters: Dictionary<String, String>
    
    private var defaults: Dictionary<String, String>
    private var keys: [String]
    
    init(consumerKey: String, consumerSecret: String, oauthToken: String, oauthTokenSecret: String, url: String, method: String = "GET", parameters: Dictionary<String, String> = [:]) {
        self.consumerKey = consumerKey
        self.consumerSecret = consumerSecret
        self.oauthToken = oauthToken
        self.oauthTokenSecret = oauthTokenSecret
        self.url = url
        self.method = method
        
        // oauth fields (for signature and for headers)
        self.defaults = [
            "oauth_consumer_key": self.consumerKey,
            "oauth_nonce": Utils.generateNonce(), // from CryptoKit
            "oauth_timestamp": String(Int(Date().timeIntervalSince1970)),
            "oauth_token": self.oauthToken,
            "oauth_signature_method": self.signatureMethod,
            "oauth_version": version,
        ]
        
        self.parameters = parameters.mapValues { Utils.rawurlencode($0) ?? $0 }
        self.getParameters = self.parameters
        
        self.parameters.merge(self.defaults){ (current, _) in current }
        
        self.keys = Array(parameters.keys).sorted(by: <)
    }
    
    private func getNormalizedUrl() -> String {
        guard let uc = URLComponents(string: self.url) else { fatalError() }
        guard let host = uc.host?.lowercased() else { fatalError() }
        let url = "\(uc.scheme ?? "https")://\(host)\(uc.path)"
        return url
    }
    
    private func getSignableParameters() -> String {
        var urlComponents = URLComponents()
        let keys = Array(self.parameters.keys).sorted(by: <)
        let queryItems = keys.map { URLQueryItem(name: $0, value: parameters[$0]) }
        urlComponents.queryItems = queryItems
        guard let query = urlComponents.query else { fatalError("Encoding failed") }
        return query
    }
    
    private func getSignatureBaseString() -> String {
        var parts = [self.method.uppercased(), self.getNormalizedUrl(), self.getSignableParameters()]
        parts = parts.map { Utils.rawurlencode($0) ?? $0 }
        return parts.joined(separator: "&")
    }
    
    public func buildSignature(string: String, signingKey: String) -> String {
        let key = SymmetricKey(data: signingKey.data(using: .utf8)!)
        let signatureData = Data(HMAC<Insecure.SHA1>.authenticationCode(for: Data(string.utf8), using: key))
        guard let signature = Utils.rawurlencode(signatureData.base64EncodedString()) else { fatalError("failed to create signature") }
        return signature
    }
    
    private func getKey() -> String {
        let key = "\(self.consumerSecret)&\(self.oauthTokenSecret)"
        return key
    }
    
    public func buildAuthHeader() -> String {
        let baseString = self.getSignatureBaseString()
        let signature = buildSignature(string: baseString, signingKey: self.getKey())
        debugPrint(signature)
        var params = self.parameters
        params["oauth_signature"] = signature
        let value = params
            .filter{ $0.key.starts(with: "oauth") }
            .map{ "\($0)=\($1)" }
            .joined(separator: ",")
        let header = "OAuth \(value)"
        return header
    }
    
    public func buildRequest() -> URLRequest {
        let url = self.getNormalizedUrl()
        debugPrint(url)
        var request = URLRequest(url: URL(string: url)!)
        request.httpMethod = self.method
        var uc = URLComponents()
        uc.setQueryItems(with: getParameters)
        let httpBody = uc.query?.data(using: String.Encoding.utf8)
        request.httpBody = httpBody
        let auth = self.buildAuthHeader()
        request.addValue(auth, forHTTPHeaderField: "Authorization")
        return request
    }
}

class TwitterOAuth {
    // Only for 1.1 API (no support for 2.0 or Bearer Tokens)
    private let API_BASE = "https://api.twitter.com"
    private let UPLOAD_BASE = "https://upload.twitter.com"
    private let API_VERSION = "1.1"
    private let EXTENSION = ".json"
    
    /// instance properties
    private var consumerKey: String
    private var consumerSecret: String
    private var oauthToken: String
    private var oauthTokenSecret: String
    
    /**
     Contstructor
     
     - parameter consumerKey: Application Consumer Key
     - parameter consumerSecret: Application Consumer Secret
     - parameter oauthToken: Client Token (optional)
     - parameter oauthTokenSectret: Client Secret (optional)
     */
    init(consumerKey: String, consumerSecret: String, oauthToken: String, oauthTokenSecret: String) {
        self.consumerKey = consumerKey
        self.consumerSecret = consumerSecret
        self.oauthToken = oauthToken
        self.oauthTokenSecret = oauthTokenSecret
    }
    
    // MARK: -- public methods
    func get(path: String, parameters: Dictionary<String, String>) async throws -> JSONResponse {
        return try await http(method: "GET", host: self.API_BASE, path: path, parameters: parameters)
    }
    
    func post(path: String, parameters: Dictionary<String, String>) async throws -> JSONResponse {
        return try await http(method: "POST", host: self.API_BASE, path: path, parameters: parameters)
    }
    
    func delete(path: String, parameters: Dictionary<String, String>) async throws -> JSONResponse {
        return try await http(method: "DELETE", host: self.API_BASE, path: path, parameters: parameters)
    }
    
    func put(path: String, parameters: Dictionary<String, String>) async throws -> JSONResponse {
        return try await http(method: "PUT", host: self.API_BASE, path: path, parameters: parameters)
    }
    
    func upload(path: String, parameters: Dictionary<String, String>) async throws -> JSONResponse {
        return try await http(method: "POST", host: self.UPLOAD_BASE, path: path, parameters: parameters)
    }
    
    func http(method: String, host: String, path: String, parameters: Dictionary<String, String>) async throws -> JSONResponse {
        let url = "\(host)/\(API_VERSION)/\(path)\(EXTENSION)"
        let request = Request(consumerKey: self.consumerKey, consumerSecret: self.consumerSecret, oauthToken: self.oauthToken, oauthTokenSecret: self.oauthTokenSecret, url: url, method: method, parameters: parameters)
        
        return try await makeRequest(request: request.buildRequest())
    }
    
    private func makeRequest(request: URLRequest) async throws -> JSONResponse {
        var statusResponse = JSONResponse(text: "leer")
        do {
            if #available(macOS 12.0, *) {
                let (data, urlResponse) = try await URLSession.shared.data(for: request)
                if let httpResponse = urlResponse as? HTTPURLResponse {
                    print("Status Code: \(httpResponse.statusCode)")
                    if httpResponse.statusCode == 400 {
                        print(String(data: data, encoding: String.Encoding.utf8) ?? "Data could not be printed")
                        let parsedData = try! JSONDecoder().decode(ErrorResponse.self, from: data)
                        throw TwitterAPIError.message(parsedData.errors.first?.message ?? "no error messagen")
                    }
                    if httpResponse.statusCode == 401 {
                        print(String(data: data, encoding: String.Encoding.utf8) ?? "Data could not be printed")
                        let parsedData = try! JSONDecoder().decode(ErrorResponse.self, from: data)
                        throw TwitterAPIError.message(parsedData.errors.first?.message ?? "no error messagen")
                    }
                }
                let parsedData = try! JSONDecoder().decode(JSONResponse.self, from: data)
                statusResponse = parsedData
            } else {
                throw TwitterAPIError.requieresNewerMacos
            }
        }
        catch {
            print("post-error", error, error.localizedDescription)
            throw TwitterAPIError.error
        }
        
        return statusResponse
    }
}

extension URLComponents {
    mutating func setQueryItems(with parameters: [String: String]) {
        self.queryItems = parameters.map { URLQueryItem(name: $0.key, value: $0.value) }
    }
}
