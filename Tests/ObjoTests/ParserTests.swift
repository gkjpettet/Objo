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
        let tokens = try tokeniser.tokenise(source: "", scriptId: 0)
        let ast = parser.parse(tokens: tokens)
        
        // Should produce an empty AST.
        XCTAssertTrue(ast.count == 0)
    }
    
    func testVarDeclaration() throws {
        let source = """
        var name = \"Garry\"
        var age
        """
        let ast = try parser.parse(tokens: tokeniser.tokenise(source: source, scriptId: 0))
        
        XCTAssertTrue(ast.count == 2)
        
        // var name = "Garry"
        XCTAssertTrue(ast[0] is VarDeclStmt)
        let s1: VarDeclStmt = ast[0] as! VarDeclStmt
        XCTAssertTrue(s1.identifier.lexeme == "name")
        XCTAssertTrue(s1.initialiser is StringLiteral)
        XCTAssertTrue((s1.initialiser as! StringLiteral).value == "Garry")
        
        // var age # Implicitly initialised to nothing.
        XCTAssertTrue(ast[1] is VarDeclStmt)
        let s2: VarDeclStmt = ast[1] as! VarDeclStmt
        XCTAssertTrue(s2.identifier.lexeme == "age")
        XCTAssertTrue(s2.initialiser is NothingLiteral)
    }
}
