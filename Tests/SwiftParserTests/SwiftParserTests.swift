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

public protocol RunnableExample {
    var name: String { get }
    func run() throws
}

public class ParserTestCase: XCTestCase {

    open class func examples() -> [RunnableExample] {
        fatalError("Must override examples()")
    }

    public class var allTests : [(String, (XCTestCase) -> () throws -> Void)] {
        return examples().map {
            example in (example.name, { _ in { try example.run() } })
        }
    }
}

public struct ParserExample<T> : RunnableExample {
    typealias Validator = (T) -> ()
    typealias ParseFunction = (Parser) -> () throws -> T

    public let name: String
    let input: String
    let error: String?
    let parseFunc: ParseFunction
    let validator: Validator?

    init(_ name: String, parser: @escaping ParseFunction, input: String, error: String? = nil, validator: Validator? = nil) {
        self.name = name
        self.parseFunc = parser
        self.input = input
        self.error = error
        self.validator = validator
    }

    /*
    init(_ name: String, parser: @escaping (Parser) -> () throws -> T, input: String, error: String? = nil, validator: Validator? = nil) {
        self.init(name, parser: { p in try parser(p)() }, input: input, error: error, validator: validator)
    }
    */

    public func run() throws {
        let source = Source(input, identifier: "<string>")
        let parser = Parser(source)
        do {
            let result = try parseFunc(parser)()
            if let error = self.error {
                let actual_error = parser.diagnoses.map { String(describing: $0) }.joined(separator: "\n\n")
                XCTAssertEqual(error, actual_error, "The actual error message was different than the expected one.")
            } else if let validator = self.validator {
                validator(result)
            }
        } catch let d as Diagnose {
        } catch {
            XCTFail("Unexpected error was thrown")
        }
    }
}


class SwiftParserTests: ParserTestCase {
    override class func examples() -> [RunnableExample] {
        return [
            ParserExample(
                "associativity error",
                parser: Parser.parsePrecedenceGroup,
                input:
                    "precedencegroup test { associativity: fubar }",
                error:
                    "<string>:1:39 Error: Expected 'none', 'left', or 'right' after 'associativity'\n" +
                    "precedencegroup test { associativity: fubar }\n" +
                    "                                      ^"
            ),
            ParserExample(
                "associativity left",
                parser: Parser.parsePrecedenceGroup,
                input:
                    "precedencegroup test { associativity: left }",
                validator: { group in
                    XCTAssertEqual(group.associativity, Associativity.Left)
                }
            ),
            ParserExample(
                "assignment error",
                parser: Parser.parsePrecedenceGroup,
                input:
                    "precedencegroup test { assignment: fubar }",
                error:
                    "<string>:1:36 Error: Expected 'true' or 'false' after 'assignment'\n" +
                    "precedencegroup test { assignment: fubar }\n" +
                    "                                   ^"
            )
        ]
    }
}
