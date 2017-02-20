import XCTest
@testable import SwiftParser

class ParsePrecedenceGroupTests: ParserTestCase {
    override class func examples() -> [RunnableExample] {
        return [
            ParserExample(
                "syntax error",
                parser: Parser.parsePrecedenceGroup,
                input:
                    "precedencegroup [ fubar ]",
                error:
                    "Error: Expected identifier after 'precedencegroup'\n" +
                    "precedencegroup [ fubar ]\n" +
                    "                ^",
                afterPosition: "fubar"
            ),
            ParserExample(
                "syntax error 2",
                parser: Parser.parsePrecedenceGroup,
                input:
                    "precedencegroup { fubar }",
                error:
                    "Error: Expected identifier after 'precedencegroup'\n" +
                    "precedencegroup { fubar }\n" +
                    "                ^"
            ),
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
                "associativity right",
                parser: Parser.parsePrecedenceGroup,
                input:
                    "precedencegroup test { associativity: right }",
                validator: checkResult(associativity: .Right)
            ),
            ParserExample(
                "associativity none",
                parser: Parser.parsePrecedenceGroup,
                input:
                    "precedencegroup test { associativity: none }",
                validator: checkResult(associativity: Associativity.None)
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
                "assignment true",
                parser: Parser.parsePrecedenceGroup,
                input:
                    "precedencegroup test { assignment: true }",
                validator: checkResult(assignment: true)
            ),
            ParserExample(
                "assignment false",
                parser: Parser.parsePrecedenceGroup,
                input:
                    "precedencegroup test { assignment: false }",
                validator: checkResult(assignment: false)
            ),
            ParserExample(
                "higherThan error",
                parser: Parser.parsePrecedenceGroup,
                input:
                    "precedencegroup test { higherThan: other other2 }",
                error:
                    "Error: Expected colon after attribute name in precedence group\n" +
                    "precedencegroup test { higherThan: other other2 }\n" +
                    "                                                ^\n" +
                    "\n" +
                    "Error: 'other2' is not a valid precedence group attribute\n" +
                    "precedencegroup test { higherThan: other other2 }\n" +
                    "                                         ^^^^^^"
            ),
            ParserExample(
                "higherThan single",
                parser: Parser.parsePrecedenceGroup,
                input:
                    "precedencegroup test { higherThan: other }",
                validator: checkResult(higherThan: ["other"])
            ),
            ParserExample(
                "higherThan multiple",
                parser: Parser.parsePrecedenceGroup,
                input:
                    "precedencegroup test { higherThan: other, other2 }",
                validator: checkResult(higherThan: ["other", "other2"])
            ),
            ParserExample(
                "lowerThan error",
                parser: Parser.parsePrecedenceGroup,
                input:
                    "precedencegroup test { lowerThan: other other2 }",
                error:
                    "Error: Expected colon after attribute name in precedence group\n" +
                    "precedencegroup test { lowerThan: other other2 }\n" +
                    "                                               ^\n" +
                    "\n" +
                    "Error: 'other2' is not a valid precedence group attribute\n" +
                    "precedencegroup test { lowerThan: other other2 }\n" +
                    "                                        ^^^^^^"
            ),
            ParserExample(
                "lowerThan single",
                parser: Parser.parsePrecedenceGroup,
                input:
                    "precedencegroup test { lowerThan: other }",
                validator: checkResult(lowerThan: ["other"])
            ),
            ParserExample(
                "lowerThan multiple",
                parser: Parser.parsePrecedenceGroup,
                input:
                    "precedencegroup test { lowerThan: other, other2 }",
                validator: checkResult(lowerThan: ["other", "other2"])
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
            let actualHigher = Set(group.higherThan.map { $0.name })
            XCTAssertEqual(actualHigher, higherThan, "Wrong 'higherThan' for precedence group.", file: file, line: line)
            let actualLower = Set(group.lowerThan.map { $0.name })
            XCTAssertEqual(actualLower, lowerThan, "Wrong 'lowerThan' for precedence group.", file: file, line: line)
            XCTAssertEqual(group.associativity, associativity, "Wrong 'associativity' for precedence group.", file: file, line: line)
            XCTAssertEqual(group.assignment, assignment, "Wrong 'assignment' for precedence group.", file: file, line: line)
        }
    }
}
