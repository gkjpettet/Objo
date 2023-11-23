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

            System.print(fib(5))
            
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
    
    func testForeachStress() throws {
        do {
            let source = """
            var list = []

            var start = System.clock
            foreach i in 0...1000 {
            list.add(i)
            }

            var sum = 0
            foreach i in list {
            sum = sum + i
            }

            System.print(sum)
            var end = (System.clock - start) / 1_000_000
            System.print("elapsed: " + end + " seconds")
            """
            
            let f = try compiler.compile(source: source, debugMode: false, scriptID: 0)
            
//            let dissassembler = Disassembler()
//            if let output = try? dissassembler.disassembleFunction(function: f) {
//                print("")
//                print(output)
//                print("")
//            } else {
//                print("")
//                print("CANNOT DISASSEMBLE")
//                print("")
//            }
            
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
