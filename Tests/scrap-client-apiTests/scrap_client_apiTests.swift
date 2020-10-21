import XCTest
@testable import scrap_client_api

final class scrap_client_apiTests: XCTestCase {
    func testExample() {
        // This is an example of a functional test case.
        // Use XCTAssert and related functions to verify your tests produce the correct
        // results.
        XCTAssertEqual(scrap_client_api().text, "Hello, World!")
    }

    static var allTests = [
        ("testExample", testExample),
    ]
}
