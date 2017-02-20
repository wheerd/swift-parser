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
        type_switch: switch token.type {
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
                if let actual_value = value {
                    type = .DictionaryType(key, actual_value)
                } else {
                    type = .ArrayType(key)
                }
            case .Punctuator(.LeftParenthesis):
                var after: Token
                var tuple_args = [Type]()
                repeat {
                    let inner = self.parseType()
                    after = self.lexer.lexNextToken()
                    tuple_args.append(inner)
                } while after.type == .Punctuator(.Comma)
                guard after.type == .Punctuator(.RightParenthesis) else {
                    self.diagnose("Expected ), found \(after.content)")
                    break
                }
                after = self.lexer.peekNextToken()
                if after.type == .Punctuator(.Arrow) {
                    _ = self.lexer.lexNextToken()
                    let return_type = self.parseType()
                    type = .FunctionType(tuple_args, return_type)
                } else {
                    type = .TupleType(tuple_args)
                }
            case .Identifier(_):
                var parts = [((Identifier, [Type]))]()
                var ident_token = token
                identifier_loop: repeat {
                    let identifier = Identifier(ident_token.content)
                    switch self.lexer.peekNextToken().type {
                        case .Punctuator(.Period):
                            parts.append((identifier, []))
                            let dot = self.lexer.lexNextToken()
                            ident_token = self.lexer.lexNextToken()
                            if ident_token.type == .Identifier(false) && (ident_token.content == "Type" || ident_token.content == "Protocol") {
                                self.lexer.resetToBeginning(of: dot)
                                break identifier_loop
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
                                    let next_index = self.lexer.getIndex(after: after.range.range.lowerBound)
                                    self.lexer.resetIndex(to: next_index)
                                }
                            } else {
                                self.diagnose("Expected >, found \(after.content)")
                                break type_switch
                            }
                            parts.append((identifier, generics))
                            guard self.lexer.peekNextToken().type == .Punctuator(.Period) else {
                                break identifier_loop
                            }
                            _ = self.lexer.lexNextToken()
                            ident_token = self.lexer.lexNextToken()
                        default:
                            parts.append((identifier, []))
                            break identifier_loop
                    }
                } while true
                type = .TypeIdentifier(parts)
            case .Keyword(.UpperCaseSelf):
                type = .`Self`
            default:
                print("Error: " + String(describing: token))
        }

        postfix_loop: while true {
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
                                break postfix_loop
                        }
                    }
                default:
                    break postfix_loop
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
        let ident_token = lexer.lexNextToken()
        guard case .Identifier(_) = ident_token.type else {
            let error = self.diagnose("Expected identifier after 'precedencegroup'")
            if ident_token.type == .Punctuator(.LeftBrace) || lexer.peekNextToken().type == .Punctuator(.LeftBrace) {
                skipWhile { $0.type != .Punctuator(.RightBrace) }
            }
            consumeIf(type: .Punctuator(.RightBrace))
            throw error
        }

        var valid = true
        let name = ident_token.content
        var higherThan: [Identifier]? = nil
        var lowerThan: [Identifier]? = nil
        var associativity: Associativity? = nil
        var assignment: Bool? = nil

        func abortBlock() {
            valid = false
            skipWhile { $0.type != .Punctuator(.RightBrace) }
            consumeIf(type: .Punctuator(.RightBrace))
        }

        let open_brace = lexer.lexNextToken()
        guard open_brace.type == .Punctuator(.LeftBrace) else {
            throw self.diagnose("Expected '{' after name of precedence group")
        }
        var attribute_name_token: Token = lexer.lexNextToken()
        while attribute_name_token.type == .Identifier(false) {
            let name = attribute_name_token.content
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
                    } while (consumeIf(type: .Punctuator(.Comma)))
                    if name == "higherThan" {
                        higherThan = groups.map { Identifier($0) }
                    } else {
                        lowerThan = groups.map { Identifier($0) }
                    }
                default:
                    let error = self.diagnose("'\(name)' is not a valid precedence group attribute", at: attribute_name_token)
                    abortBlock()
                    throw error
            }
            attribute_name_token = lexer.lexNextToken()
        }
        guard attribute_name_token.type == .Punctuator(.RightBrace) else {
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
