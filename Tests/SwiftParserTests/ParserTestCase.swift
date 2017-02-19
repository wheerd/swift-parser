import XCTest
@testable import SwiftParser

public protocol RunnableExample {
    var name: String { get }
    func run() throws
}

public class ParserTestCase: XCTestCase {

    open class func examples() -> [RunnableExample] {
        fatalError("Must override examples()")
    }

    public class var allTests : XCTestCaseEntry {
        let tests: [(String, (XCTestCase) throws -> Void)] = examples().map { example in (example.name, { _ in try example.run() }) }
        return (testCaseClass: self, allTests: tests)
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
    let afterPosition: String.Index

    init(
        _ name: String,
        parser: @escaping ParseFunction,
        input: String,
        error: String? = nil,
        afterPosition: Int? = nil,
        validator: Validator? = nil
    ) {
        self.name = name
        self.parseFunc = parser
        self.input = input
        self.error = error
        self.validator = validator
        if let offset = afterPosition {
            self.afterPosition = input.index(input.startIndex, offsetBy: offset)
        } else {
            self.afterPosition = input.endIndex
        }
    }

    init(
        _ name: String,
        parser: @escaping ParseFunction,
        input: String,
        error: String? = nil,
        afterPosition: String,
        validator: Validator? = nil
    ) {
        let index = input.range(of: afterPosition)!.lowerBound
        let offset = input.distance(from: input.startIndex, to: index)
        self.init(name, parser: parser, input: input, error: error, afterPosition: offset, validator: validator)
    }

    public func run() throws {
        let source = Source(input, identifier: "<string>")
        let parser = Parser(source)
        do {
            let result = try parseFunc(parser)()
            if error != nil { checkError(parser: parser) }
            if let position = String.Index(parser.lexer.index, within: input) {
                checkPosition(input: input, expected: afterPosition, actual: position)
            }
            if let validator = self.validator {
                validator(result)
            }
        } catch let d as Diagnose {
            if error != nil { checkError(parser: parser) }
            if let position = String.Index(parser.lexer.nextToken.range.range.lowerBound, within: input) {
                checkPosition(input: input, expected: afterPosition, actual: position)
            }
        } catch {
            XCTFail("Unexpected error was thrown")
        }
    }

    private func checkPosition(input: String, expected: String.Index, actual: String.Index) {
        if expected != actual {
            let expected_non_end = expected < input.endIndex ? expected : input.index(before: input.endIndex)
            let expected_range = input.lineRange(for: expected_non_end..<expected_non_end)
            let expected_offset = input.distance(from: expected_range.lowerBound, to: expected)

            let actual_non_end = actual < input.endIndex ? actual : input.index(before: input.endIndex)
            let actual_range = input.lineRange(for: actual_non_end..<actual_non_end)
            let actual_offset = input.distance(from: actual_range.lowerBound, to: actual)
            
            var message = "Unexpected position:\n"
            if expected_range == actual_range {
                message += "\(input[expected_range])\n"
                if expected < actual {
                    message += "\(" " * expected_offset)X\(" " * (actual_offset - expected_offset - 1))^"
                } else {
                    message += "\(" " * actual_offset)^\(" " * (expected_offset - actual_offset - 1))X"
                }
            } else {
                message += "\(input[expected_range])\n\(" " * expected_offset)X\n"
                message += "...\n"
                message += "\(input[actual_range])\n\(" " * actual_offset)^" 
            }
            XCTFail(message)
        }
    }

    private func checkError(parser: Parser) {
        let actual_error = parser.diagnoses.map { String(describing: $0) }.joined(separator: "\n\n")
        let stripped = actual_error.replacingOccurrences(of: "<string>:[\\d:\\-]+\\s*", with: "", options: String.CompareOptions.regularExpression)
        XCTAssertEqual(error!, stripped, "The actual error message was different than the expected one.")
    }
}