import XCTest
@testable import Objo

final class VMTests: XCTestCase {
    
    let compiler = Compiler(coreLibrarySource: "")
    let vm = VM()
    
    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.
        compiler.reset()
        vm.reset()
    }
    
//    /// Tests parsing an empty source code input.
//    func testEmptySource() throws {
//        let f = try compiler.compile(source: "", debugMode: true, scriptID: 0)
//        do {
//            try vm.interpret(function: f)
//        } catch {
//            print(error)
//        }
//    }
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
