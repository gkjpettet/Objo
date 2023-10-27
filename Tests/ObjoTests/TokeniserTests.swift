import XCTest
@testable import Objo

final class TokeniserTests: XCTestCase {
    
    let tokeniser = Tokeniser()
    
    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.
        tokeniser.reset()
    }

    func testEmptySource() throws {
       let tokens = try! tokeniser.tokenise(source: "", scriptId: -1)
        
        XCTAssert(!tokens.isEmpty && tokens.last!.type == .eof)
    }
    
    /// Expects an unexpected character error.
    func testUnexpectedCharacter() throws {
        XCTAssertThrowsError(try tokeniser.tokenise(source: ";", scriptId: -1)) { error in
            let type = (error as? LexerError)?.type
            XCTAssertEqual(type, .unexpectedCharacter)
        }
    }
    
    func testReturnedTokensAreIndependent() throws {
        let tokens = try! tokeniser.tokenise(source: "1 2 3", scriptId: -1)
        
        XCTAssertTrue(tokens.count == 5)
        XCTAssertTrue(tokens[0].type == .number)
        
        // Reset the tokeniser and make sure it doesn't interfere with our local token array.
        tokeniser.reset()
        
        XCTAssertTrue(tokens.count == 0)
    }
}
