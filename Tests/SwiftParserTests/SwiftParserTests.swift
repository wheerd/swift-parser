import XCTest
@testable import SwiftParser

func XCTAssertThrows<T>(_ expression: @autoclosure () throws -> T, message: String = "", file: StaticString = #file, line: UInt = #line) {
    do {
        _ = try expression()
        XCTFail("No error to catch! - \(message)", file: file, line: line)
    } catch {
    }
}

func assertParserHasError(_ input: String, error: String, file: StaticString = #file, line: UInt = #line) {
    let source = Source("precedencegroup test { associativity: fubar }", identifier: "<string>")
    let parser = Parser(source)
    _ = parser.parse()
    let actual_error = parser.diagnoses.map { String(describing: $0) }.joined(separator: "\n\n")
    XCTAssertEqual(error, actual_error, "The actual error message was different than the expected one.")
}

class SwiftParserTests: XCTestCase {
    func testAssociativityError() {
        assertParserHasError(
            "precedencegroup test { associativity: fubar }",
            error:
            "<string>:1:39 Error: Expected 'none', 'left', or 'right' after 'associativity'\n" +
            "precedencegroup test { associativity: fubar }\n" +
            "                                      ^"
        )
    }


    static var allTests : [(String, (SwiftParserTests) -> () throws -> Void)] {
        return [
            ("testAssociativityError", testAssociativityError),
        ]
    }
}
