import XCTest
@testable import Objo

final class CompilerTests: XCTestCase {
    
    let compiler = Compiler(coreLibrarySource: "")
    let disassembler = Disassembler()
    
    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.
        compiler.reset()
    }
    
    /// Tests parsing an empty source code input.
    /// Expect:
    /// ```
    /// nothing
    /// return_
    /// ```
    func testEmptySource() throws {
        let f = try compiler.compile(source: "", debugMode: true, scriptID: 0)
        XCTAssertTrue(f.chunk.code.count == 2)
        XCTAssertTrue(f.chunk.code[0] == Opcode.nothing.rawValue)
        XCTAssertTrue(f.chunk.code[1] == Opcode.return_.rawValue)
    }
    
    /// Tests compiling the production of a simple boolean literal.
    func testBooleanLiteral() throws {
        let f1 = try compiler.compile(source: "true", debugMode: true, scriptID: 0)
        XCTAssertTrue(f1.chunk.code.count == 4)
        XCTAssertTrue(f1.chunk.code[0] == Opcode.true_.rawValue)
        XCTAssertTrue(f1.chunk.code[1] == Opcode.pop.rawValue)
        XCTAssertTrue(f1.chunk.code[2] == Opcode.nothing.rawValue)
        XCTAssertTrue(f1.chunk.code[3] == Opcode.return_.rawValue)
        
        let f2 = try compiler.compile(source: "false", debugMode: true, scriptID: 0)
        XCTAssertTrue(f2.chunk.code.count == 4)
        XCTAssertTrue(f2.chunk.code[0] == Opcode.false_.rawValue)
        XCTAssertTrue(f2.chunk.code[1] == Opcode.pop.rawValue)
        XCTAssertTrue(f2.chunk.code[2] == Opcode.nothing.rawValue)
        XCTAssertTrue(f2.chunk.code[3] == Opcode.return_.rawValue)
    }
}
