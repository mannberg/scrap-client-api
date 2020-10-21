import XCTest
@testable import scrap_client_api

final class APITests: XCTestCase {
    func test_sets_authorization_header_for_url_request() throws {
        let expectedToken = "bhAIuuJDLOeiNuAHHhwHHA=="
        let expectedHeaderValue = "Bearer \(expectedToken)"

        let req = try XCTUnwrap(URLRequest.get(.test).tokenAuthorized(token: Token(value: "bhAIuuJDLOeiNuAHHhwHHA==")))
        XCTAssertEqual(req.value(forHTTPHeaderField: "Authorization"), expectedHeaderValue)
    }
}
