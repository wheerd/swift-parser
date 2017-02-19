import XCTest
@testable import SwiftParser

class ParsePrecedenceGroupTests: ParserTestCase {
    override class func examples() -> [RunnableExample] {
        return [
            ParserExample(
                "associativity error",
                parser: Parser.parsePrecedenceGroup,
                input:
                    "precedencegroup test { associativity: fubar }",
                error:
                    "Error: Expected 'none', 'left', or 'right' after 'associativity'\n" +
                    "precedencegroup test { associativity: fubar }\n" +
                    "                                      ^"
            ),
            ParserExample(
                "associativity left",
                parser: Parser.parsePrecedenceGroup,
                input:
                    "precedencegroup test { associativity: left }",
                validator: checkResult(associativity: .Left)
            ),
            ParserExample(
                "assignment error",
                parser: Parser.parsePrecedenceGroup,
                input:
                    "precedencegroup test { assignment: fubar }",
                error:
                    "Error: Expected 'true' or 'false' after 'assignment'\n" +
                    "precedencegroup test { assignment: fubar }\n" +
                    "                                   ^"
            ),
            ParserExample(
                "associativity true",
                parser: Parser.parsePrecedenceGroup,
                input:
                    "precedencegroup test { assignment: true }",
                validator: checkResult(assignment: true)
            ),
            ParserExample(
                "associativity false",
                parser: Parser.parsePrecedenceGroup,
                input:
                    "precedencegroup test { assignment: false }",
                validator: checkResult(assignment: false)
            ),
            ParserExample(
                "higherThan single",
                parser: Parser.parsePrecedenceGroup,
                input:
                    "precedencegroup test { higherThan: other }",
                validator: checkResult(higherThan: ["other"])
            ),
        ]
    }

    private static func checkResult(
        higherThan: Set<String> = [],
        lowerThan: Set<String> = [],
        associativity: Associativity = .None,
        assignment: Bool = false,
        file: StaticString = #file,
        line: UInt = #line
    ) -> (PrecedenceGroupDeclaration) -> () {
        return { group in
            let actual_higher = Set(group.higherThan.map { $0.name })
            XCTAssertEqual(actual_higher, higherThan, "Wrong 'higherThan' for precedence group.", file: file, line: line)
            let actual_lower = Set(group.lowerThan.map { $0.name })
            XCTAssertEqual(actual_lower, lowerThan, "Wrong 'lowerThan' for precedence group.", file: file, line: line)
            XCTAssertEqual(group.associativity, associativity, "Wrong 'associativity' for precedence group.", file: file, line: line)
            XCTAssertEqual(group.assignment, assignment, "Wrong 'assignment' for precedence group.", file: file, line: line)
        }
    }
}
