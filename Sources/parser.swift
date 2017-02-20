class Parser {
    let lexer: Lexer
    var diagnoses = [Diagnose]()

    init(_ source: Source) {
        self.lexer = Lexer(source)
    }

    func parse() -> Any? {
        switch lexer.peekNextToken().type {
            case .DeclarationKeyword(.PrecedenceGroup):
                return try? parsePrecedenceGroup() as Any
            default:
                return nil
        }
    }

    func parseType() -> Type {
        var type: Type = .Unknown
        let token = self.lexer.lexNextToken()
        typeSwitch: switch token.type {
            case .Punctuator(.LeftSquare):
                let key = self.parseType()
                var value: Type? = nil
                var after = self.lexer.lexNextToken()
                if after.type == .Punctuator(.Colon) {
                    value = self.parseType()
                    after = self.lexer.lexNextToken()
                }
                guard after.type == .Punctuator(.RightSquare) else {
                    self.diagnose("Expected ], found \(after.content)")
                    break
                }
                if let actualValue = value {
                    type = .DictionaryType(key, actualValue)
                } else {
                    type = .ArrayType(key)
                }
            case .Punctuator(.LeftParenthesis):
                var after: Token
                var tupleArgs = [Type]()
                repeat {
                    let inner = self.parseType()
                    after = self.lexer.lexNextToken()
                    tupleArgs.append(inner)
                } while after.type == .Punctuator(.Comma)
                guard after.type == .Punctuator(.RightParenthesis) else {
                    self.diagnose("Expected ), found \(after.content)")
                    break
                }
                after = self.lexer.peekNextToken()
                if after.type == .Punctuator(.Arrow) {
                    _ = self.lexer.lexNextToken()
                    let returnType = self.parseType()
                    type = .FunctionType(tupleArgs, returnType)
                } else {
                    type = .TupleType(tupleArgs)
                }
            case .Identifier(_):
                var parts = [(Identifier, [Type])]()
                var identToken = token
                identifierLoop: repeat {
                    let identifier = Identifier(identToken.content)
                    switch self.lexer.peekNextToken().type {
                        case .Punctuator(.Period):
                            parts.append((identifier, []))
                            let dot = self.lexer.lexNextToken()
                            identToken = self.lexer.lexNextToken()
                            if identToken.type == .Identifier(false) && (identToken.content == "Type" || identToken.content == "Protocol") {
                                self.lexer.resetToBeginning(of: dot)
                                break identifierLoop
                            }
                        case .BinaryOperator("<"):
                            var generics = [Type]()
                            repeat {
                                _ = self.lexer.lexNextToken()
                                generics.append(self.parseType())
                            } while self.lexer.peekNextToken().type == .Punctuator(.Comma)
                            let after = self.lexer.lexNextToken()
                            if case let .PostfixOperator(op) = after.type, op.hasPrefix(">") {
                                if op != ">" {
                                    let nextIndex = self.lexer.getIndex(after: after.range.range.lowerBound)
                                    self.lexer.resetIndex(to: nextIndex)
                                }
                            } else {
                                self.diagnose("Expected >, found \(after.content)")
                                break typeSwitch
                            }
                            parts.append((identifier, generics))
                            guard self.lexer.peekNextToken().type == .Punctuator(.Period) else {
                                break identifierLoop
                            }
                            _ = self.lexer.lexNextToken()
                            identToken = self.lexer.lexNextToken()
                        default:
                            parts.append((identifier, []))
                            break identifierLoop
                    }
                } while true
                type = .TypeIdentifier(parts)
            case .Keyword(.UpperCaseSelf):
                type = .`Self`
            default:
                print("Error: " + String(describing: token))
        }

        postfixLoop: while true {
            let nextToken = self.lexer.peekNextToken()
            switch nextToken.type {
                case .Punctuator(.PostfixExclaimationMark):
                    type = .ImplicitlyUnwrappedOptionalType(type)
                    _ = self.lexer.lexNextToken()
                case .Punctuator(.PostfixQuestionMark):
                    type = .OptionalType(type)
                    _ = self.lexer.lexNextToken()
                case .Punctuator(.Period):
                    _ = self.lexer.lexNextToken()
                    let afterDot = self.lexer.lexNextToken()
                    if afterDot.type == .Identifier(false) {
                        switch afterDot.content {
                            case "Type":
                                type = .MetaType(type)
                            case "Protocol":
                                type = .MetaProtocol(type)
                            default:
                                self.lexer.resetToBeginning(of: nextToken)
                                break postfixLoop
                        }
                    }
                default:
                    break postfixLoop
            }
        }

        return type
    }

    func parseExpression() -> Expression {
        return BaseExpression()
    }

    func parsePrecedenceGroup() throws -> PrecedenceGroupDeclaration {
        let kwtoken = lexer.lexNextToken()
        guard kwtoken.type == .DeclarationKeyword(.PrecedenceGroup) else {
            preconditionFailure("Should only parsePrecedenceGroup at the beginning of a precedencegroup declaration")
        }
        let identToken = lexer.lexNextToken()
        guard case .Identifier(_) = identToken.type else {
            let error = self.diagnose("Expected identifier after 'precedencegroup'")
            if identToken.type == .Punctuator(.LeftBrace) || lexer.peekNextToken().type == .Punctuator(.LeftBrace) {
                skipWhile { $0.type != .Punctuator(.RightBrace) }
            }
            consumeIf(type: .Punctuator(.RightBrace))
            throw error
        }

        var valid = true
        let name = identToken.content
        var higherThan: [Identifier]? = nil
        var lowerThan: [Identifier]? = nil
        var associativity: Associativity? = nil
        var assignment: Bool? = nil

        func abortBlock() {
            valid = false
            skipWhile { $0.type != .Punctuator(.RightBrace) }
            consumeIf(type: .Punctuator(.RightBrace))
        }

        let openBrace = lexer.lexNextToken()
        guard openBrace.type == .Punctuator(.LeftBrace) else {
            throw self.diagnose("Expected '{' after name of precedence group")
        }
        var attributeNameToken: Token = lexer.lexNextToken()
        while attributeNameToken.type == .Identifier(false) {
            let name = attributeNameToken.content
            let colon = lexer.lexNextToken()
            if colon.type != .Punctuator(.Colon) {
                self.diagnose("Expected colon after attribute name in precedence group")
                lexer.resetToBeginning(of: colon)
                valid = false
            }
            switch name {
                case "associativity":
                    let value = lexer.lexNextToken()
                    guard case .Identifier(_) = value.type else {
                        let error = self.diagnose("Expected 'none', 'left', or 'right' after 'associativity'")
                        abortBlock()
                        throw error
                    }
                    switch value.content {
                        case "left":
                            associativity = .Left
                        case "right":
                            associativity = .Right
                        case "none":
                            associativity = Associativity.None
                        default:
                            let error = self.diagnose("Expected 'none', 'left', or 'right' after 'associativity'")
                            abortBlock()
                            throw error
                    }
                case "assignment":
                    let value = lexer.lexNextToken()
                    switch value.type {
                        case .Keyword(.True):
                            assignment = true
                        case .Keyword(.False):
                            assignment = false
                        default:
                            let error = self.diagnose("Expected 'true' or 'false' after 'assignment'")
                            abortBlock()
                            throw error
                    }
                case "higherThan", "lowerThan":
                    var groups = [String]()
                    repeat {
                        let group = lexer.lexNextToken()
                        guard case .Identifier(_) = group.type else {
                            let error = self.diagnose("Expected name of related precedence group after '\(name)'")
                            abortBlock()
                            throw error
                        }
                        groups.append(group.content)
                    } while consumeIf(type: .Punctuator(.Comma))
                    if name == "higherThan" {
                        higherThan = groups.map { Identifier($0) }
                    } else {
                        lowerThan = groups.map { Identifier($0) }
                    }
                default:
                    let error = self.diagnose("'\(name)' is not a valid precedence group attribute", at: attributeNameToken)
                    abortBlock()
                    throw error
            }
            attributeNameToken = lexer.lexNextToken()
        }
        guard attributeNameToken.type == .Punctuator(.RightBrace) else {
            throw self.diagnose("Expected operator attribute identifier in precedence group body")
        }
        return PrecedenceGroupDeclaration(
            name,
            higherThan: higherThan ?? [],
            lowerThan: lowerThan ?? [],
            associativity: associativity ?? .None,
            assignment: assignment ?? false
        )
    }

    @discardableResult
    func skipWhile(_ predicate: (Token) -> Bool) -> Token {
        var token = lexer.peekNextToken()
        while predicate(token) && token.type != .EOF {
            _ = lexer.lexNextToken()
            token = lexer.peekNextToken()
        }
        return token
    }

    @discardableResult
    func consumeIf(type: TokenType) -> Bool {
        if lexer.peekNextToken().type == type {
            _ = lexer.lexNextToken()
            return true
        }
        return false
    }

    @discardableResult
    func diagnose(_ message: String, type: Diagnose.DiagnoseType = .Error) -> Diagnose {
        let diag = Diagnose(
            message,
            type: type,
            at: lexer.lastToken!.range.start
        )
        diagnoses.append(diag)
        return diag
    }

    @discardableResult
    func diagnose(_ message: String, after token: Token, type: Diagnose.DiagnoseType = .Error) -> Diagnose {
        let diag = Diagnose(
            message,
            type: type,
            range: SourceRange(source: token.range.source, index: token.range.end.index)
        )
        diagnoses.append(diag)
        return diag
    }

    @discardableResult
    func diagnose(_ message: String, at token: Token, type: Diagnose.DiagnoseType = .Error) -> Diagnose {
        let diag = Diagnose(
            message,
            type: type,
            range: token.range
        )
        diagnoses.append(diag)
        return diag
    }

}
