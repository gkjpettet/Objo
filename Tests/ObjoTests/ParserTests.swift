import XCTest
@testable import Objo

final class ParserTests: XCTestCase {
    
    let tokeniser = Tokeniser()
    let parser = Parser()
    
    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.
        tokeniser.reset()
        parser.reset()
    }

    /// Tests parsing an empty source code input.
    func testEmptySource() throws {
        let tokens = try tokeniser.tokenise(source: "", scriptId: -1)
        let ast = parser.parse(tokens: tokens)
        
        // Should produce an empty AST.
        XCTAssertTrue(ast.count == 0)
    }
}
