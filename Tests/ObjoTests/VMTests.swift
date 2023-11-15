import XCTest
@testable import Objo

final class VMTests: XCTestCase {
    
    let compiler = Compiler(coreLibrarySource: Core.library)
    let vm = VM()
    
    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.
        compiler.reset()
        vm.reset()
    }
    
    /// Tests parsing an empty source code input.
    func testEmptySource() throws {
        do {
            let f = try compiler.compile(source: "", debugMode: true, scriptID: 0)
            try vm.interpret(function: f)
        } catch let te as TokeniserError {
            XCTFail("Tokeniser error: \(te.message)")
        } catch let pe as ParserError {
            for e in compiler.parser.errors {
                print(e.pretty)
            }
            XCTFail(pe.message)
        } catch let ce as CompilerError {
            XCTFail("Compiler error: \(ce.message)")
        } catch let ve as VMError {
            XCTFail("VM runtime error: \(ve.pretty)")
        }
    }
//    
//    func testSimpleAddition() throws {
//        let f = try compiler.compile(source: "1 + 2", debugMode: true, scriptID: 0)
//        do {
//            try vm.interpret(function: f)
//        } catch {
//            print(error)
//        }
//    }
}
