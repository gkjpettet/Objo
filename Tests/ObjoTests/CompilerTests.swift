import XCTest
@testable import Objo

final class CompilerTests: XCTestCase {
    
    let compiler = Compiler(coreLibrarySource: "")
    let disassembler = Disassembler()
    
    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }
    
    /// Tests parsing an empty source code input.
    func testBasic() throws {
//        let source = "1 + 2"
//        
//        do {
//            let function = try compiler.compile(source: source, debugMode: true, scriptID: 0)
//            var offset = 0
//            let bytecode = try disassembler.disassembleFunction(function: function)
//            print(bytecode)
//            XCTAssertTrue(bytecode != "")
//        } catch {
//            print("\(error)")
//        }
    }
}
