//
//  File.swift
//  
//
//  Created by Anders Mannberg on 2020-10-21.
//

import Foundation
import Security

public struct TokenHandler {
    //MARK: Typealiases
    typealias SaveToken = (Token) -> Result<Token, API.Error>
    typealias LoadToken = () -> Result<Token, API.Error>
    typealias ClearToken = () -> Void
    
    //TODO: Check if this is a good name...
    static let tokenKey = "AuthorizationToken"
    
    public init() {}
    
    //TODO: Write test that verifies new server token is always saved when retrieved.
    var saveToken: SaveToken = { token in
        guard let tokenData = token.value.data(using: .utf8) else {
            //TODO: Notify server if token changes format
            //TODO: Write test that verifies our token structure does not change.
            return .failure(.parse)
        }
        
        let query = [
            kSecClass as String: kSecClassGenericPassword as String,
            kSecAttrAccount as String: TokenHandler.tokenKey,
            kSecValueData as String: tokenData
        ] as [String: Any]
                
        SecItemDelete(query as CFDictionary)
        
        let status = SecItemAdd(query as CFDictionary, nil)
        
        //TODO: Failure should be logged to the server + the user should be notified
        return status == noErr ? .success(token) : .failure(.silent)
    }
    
    //TODO: Should this be static?
    static var loadToken: LoadToken = {
        let query = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: TokenHandler.tokenKey,
            kSecReturnData as String: kCFBooleanTrue!,
            kSecMatchLimit as String: kSecMatchLimitOne
        ] as [String : Any]
        
        var dataTypeRef: AnyObject?
        
        let status: OSStatus = SecItemCopyMatching(query as CFDictionary, &dataTypeRef)
        
        guard
            status == noErr,
            let data = dataTypeRef as? Data,
            let tokenAsString = String(data: data, encoding: .utf8)
        else {
            return .failure(.silent)
        }
        
        return .success(Token(value: tokenAsString))
    }
    
    var clearToken: ClearToken = {
        let query = [
            kSecClass as String: kSecClassGenericPassword as String,
            kSecAttrAccount as String: TokenHandler.tokenKey
        ] as [String: Any]
                
        SecItemDelete(query as CFDictionary)
    }
    
    public var tokenValue: () -> Token? = {
        if case .success(let token) = TokenHandler.loadToken() {
            return token
        } else {
            return nil
        }
    }
}
