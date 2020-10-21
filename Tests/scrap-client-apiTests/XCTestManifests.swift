import XCTest

#if !canImport(ObjectiveC)
public func allTests() -> [XCTestCaseEntry] {
    return [
        testCase(scrap_client_apiTests.allTests),
    ]
}
#endif
