import XCTest
@testable import SwiftParser

func XCTAssertThrows<T>(_ expression: @autoclosure () throws -> T, message: String = "", file: StaticString = #file, line: UInt = #line) {
    do {
        _ = try expression()
        XCTFail("No error to catch! - \(message)", file: file, line: line)
    } catch {
    }
}

class SwiftParserTests: XCTestCase {
    func testAssociativityError() {
        let source = Source("precedencegroup test { associativity: fubar }", identifier: "<string>")
        let parser = Parser(source)
        XCTAssertThrows(try parser.parsePrecedenceGroup())
    }


    static var allTests : [(String, (SwiftParserTests) -> () throws -> Void)] {
        return [
            ("testAssociativityError", testAssociativityError),
        ]
    }
}
