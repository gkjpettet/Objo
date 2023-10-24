import XCTest
@testable import Objo

// XCTest Documentation
// https://developer.apple.com/documentation/xctest

// Defining Test Cases and Test Methods
// https://developer.apple.com/documentation/xctest/defining_test_cases_and_test_methods

final class TokeniserTests: XCTestCase {
    
    let tokeniser = Tokeniser()
    
    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.
        tokeniser.reset()
    }
    
    func testAdd() throws {
        XCTAssertEqual(tokeniser.add(5, 10), 15)
    }

}
