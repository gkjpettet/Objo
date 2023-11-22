import XCTest
@testable import Objo

final class VMTests: XCTestCase {
    
    public func printCallback(_ s: String) {
        print(s)
    }
    
    let compiler = Compiler(coreLibrarySource: Core.library)
    var vm = VM()
    
    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.
        compiler.reset()
        vm.reset()
        vm.print = printCallback
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
    
    /// Tests printing a number literal
    func testSimplePrint() throws {
        do {
            let f = try compiler.compile(source: "System.print(42)", debugMode: true, scriptID: 0)
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
    
    /// Tests a fibonacci function.
    func testFib() throws {
        do {
            let source = """
            function fib(n) {
            if (n < 2) then return n
            return fib(n - 2) + fib(n - 1)
            }

            var start = System.clock

            System.print(fib(10))
            
            System.print((System.clock - start) / 1000 + " ms")
            """
            
            let f = try compiler.compile(source: source, debugMode: true, scriptID: 0)
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
}
