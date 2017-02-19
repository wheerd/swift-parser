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

    init(_ name: String, parser: @escaping ParseFunction, input: String, error: String? = nil, validator: Validator? = nil) {
        self.name = name
        self.parseFunc = parser
        self.input = input
        self.error = error
        self.validator = validator
    }

    public func run() throws {
        let source = Source(input, identifier: "<string>")
        let parser = Parser(source)
        do {
            let result = try parseFunc(parser)()
            if error != nil { checkError(parser: parser) }
            if let validator = self.validator {
                validator(result)
            }
        } catch let d as Diagnose {
            if error != nil { checkError(parser: parser) }
        } catch {
            XCTFail("Unexpected error was thrown")
        }
    }

    private func checkError(parser: Parser) {
        let actual_error = parser.diagnoses.map { String(describing: $0) }.joined(separator: "\n\n")
        let stripped = actual_error.replacingOccurrences(of: "<string>:[\\d:\\-]+\\s*", with: "", options: String.CompareOptions.regularExpression)
        XCTAssertEqual(error!, stripped, "The actual error message was different than the expected one.")
    }
}