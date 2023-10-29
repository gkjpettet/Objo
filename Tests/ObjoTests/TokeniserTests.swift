import XCTest
@testable import Objo

final class TokeniserTests: XCTestCase {
    
    let tokeniser = Tokeniser()
    
    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.
        tokeniser.reset()
    }

    func testEmptySource() throws {
       let tokens = try tokeniser.tokenise(source: "", scriptId: -1)
        
        XCTAssert(!tokens.isEmpty && tokens.last!.type == .eof)
    }
    
    /// Expects an unexpected character error.
    func testUnexpectedCharacter() throws {
        XCTAssertThrowsError(try tokeniser.tokenise(source: ";", scriptId: -1)) { error in
            let type = (error as? LexerError)?.type
            XCTAssertEqual(type, .unexpectedCharacter)
        }
    }
    
    /// Resetting the tokeniser should not affect the returned Token array.
    func testReturnedTokensAreIndependent() throws {
        let tokens = try tokeniser.tokenise(source: "1 2 3", scriptId: -1)
        
        XCTAssertTrue(tokens.count == 5)
        
        // Reset the tokeniser and make sure it doesn't interfere with our local token array.
        tokeniser.reset()
        
        XCTAssertTrue(tokens.count == 5)
    }
    
    /// Tests a mixture of integers, decimal numbers and numbers with exponents.
    func testNumbers() throws {
        let source = "1 + 2.1 + 3.456 + 4e2 + 5e-1 + 65e+2 + 7.1e3 + 8.7e-2 + 9.10e2 + 0"
        let tokens = try tokeniser.tokenise(source: source, scriptId: -1)
        
        // 19 tokens.
        XCTAssertTrue(tokens.count == 21)
        
        // 1
        let n1: NumberToken = tokens[0] as! NumberToken
        XCTAssertTrue(n1.value == 1 && n1.isInteger == true)
        
        // 2.1
        let n2: NumberToken = tokens[2] as! NumberToken
        XCTAssertTrue(n2.value == 2.1 && n2.isInteger == false)
        
        // 3.456
        let n3: NumberToken = tokens[4] as! NumberToken
        XCTAssertTrue(n3.value == 3.456 && n3.isInteger == false)
        
        // 4e2
        let n4: NumberToken = tokens[6] as! NumberToken
        XCTAssertTrue(n4.value == 400 && n4.isInteger == true)
        
        // 5e-1
        let n5: NumberToken = tokens[8] as! NumberToken
        XCTAssertTrue(n5.value == 0.5 && n5.isInteger == false)
        
        // 65e+2
        let n6: NumberToken = tokens[10] as! NumberToken
        XCTAssertTrue(n6.value == 6500 && n6.isInteger == true)
        
        // 7.1e3
        let n7: NumberToken = tokens[12] as! NumberToken
        XCTAssertTrue(n7.value == 7100 && n7.isInteger == true)
        
        // 8.7e-2
        let n8: NumberToken = tokens[14] as! NumberToken
        XCTAssertTrue(n8.value == 0.087 && n8.isInteger == false)
        
        // 9.10e2
        let n9: NumberToken = tokens[16] as! NumberToken
        XCTAssertTrue(n9.value == 910 && n9.isInteger == true)
        
        // 0
        let n10: NumberToken = tokens[18] as! NumberToken
        XCTAssertTrue(n10.value == 0 && n10.isInteger == true)
    }
    
    /// Tests hex literal tokenising.
    func testHexLiterals() throws {
        let source = "0xFF + 0xABC78"
        let tokens = try tokeniser.tokenise(source: source, scriptId: -1)
        
        XCTAssertTrue(tokens.count == 5)
        
        // 0xFF
        let n1: NumberToken = tokens[0] as! NumberToken
        XCTAssertTrue(n1.value == 255 && n1.isInteger == true)
        
        // 0xABC78
        let n2: NumberToken = tokens[2] as! NumberToken
        XCTAssertTrue(n2.value == 703608 && n2.isInteger == true)
    }
    
    /// Tests binary literal tokenising.
    func testBinaryLiterals() throws {
        let source = "0b1001 + 0b0"
        let tokens = try tokeniser.tokenise(source: source, scriptId: -1)
        
        XCTAssertTrue(tokens.count == 5)
        
        // 0b1001
        let n1: NumberToken = tokens[0] as! NumberToken
        XCTAssertTrue(n1.value == 9 && n1.isInteger == true)
        
        // 0b0
        let n2: NumberToken = tokens[2] as! NumberToken
        XCTAssertTrue(n2.value == 0 && n2.isInteger == true)
    }
}
