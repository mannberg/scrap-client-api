//
//  TokenTests.swift
//  scrap-client-apiTests
//
//  Created by Anders Mannberg on 2020-10-21.
//

import XCTest
@testable import scrap_client_api

class TokenTests: XCTestCase {

    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    func testCanSaveAndLoadToken() throws {
        let tokenToSave = Token(value: "bhAIuuJDLOeiNuAHHhwHHA==")
        
        let handler = TokenHandler()
        
        if case .failure(_) = handler.saveToken(tokenToSave) {
            XCTFail()
        }
        
        let result = TokenHandler.loadToken()
        
        switch result {
        case .success(let loadedToken):
            XCTAssertEqual(loadedToken, tokenToSave)
        case .failure(_):
            XCTFail()
        }
    }
    
    func testCanDeleteToken() throws {
        let tokenToSave = Token(value: "bhAIuuJDLOeiNuAHHhwHHA==")
        
        let handler = TokenHandler()
        
        if case .failure(_) = handler.saveToken(tokenToSave) {
            XCTFail()
        }
        
        handler.clearToken()
        
        let result = TokenHandler.loadToken()
        
        if case .success(_) = result {
            XCTFail()
        }
    }
    
    func test_token_key_does_not_change() throws {
        XCTAssertEqual(TokenHandler.tokenKey, "AuthorizationToken")
    }
}
