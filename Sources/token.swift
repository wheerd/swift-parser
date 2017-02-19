public enum PunctuatorType: String {

  case LeftParenthesis   = "("
  case RightParenthesis  = ")"
  case LeftBrace         = "{"
  case RightBrace        = "}"
  case LeftSquare        = "["
  case RightSquare       = "]"

  case Period            = "."
  case PrefixPeriod      = " ."
  case Comma             = ","
  case Colon             = ":"
  case Semicolon         = ";"
  case EqualSign         = "="
  case AtSign            = "@"
  case Hash              = "#"

  case PrefixAmpersand   = "&"
  case Arrow             = "->"

  case Backtick          = "`"

  case PostfixExclaimationMark = "!" // if left-bound

  case PostfixQuestionMark     = "? " // if left-bound
  case InfixQuestionMark       = " ?" // if not left-bound

}

public enum StatementKeywordType: String {

  case Defer
  case If
  case Guard
  case Do
  case Repeat
  case Else
  case For
  case In
  case While
  case Return
  case Break
  case Continue
  case Fallthrough
  case Switch
  case Case
  case Default
  case Where
  case Catch

  init?(string: String) {
    switch string {
      case "defer":
        self = .Defer
      case "if":
        self = .If
      case "guard":
        self = .Guard
      case "do":
        self = .Do
      case "repeat":
        self = .Repeat
      case "else":
        self = .Else
      case "for":
        self = .For
      case "in":
        self = .In
      case "while":
        self = .While
      case "return":
        self = .Return
      case "break":
        self = .Break
      case "continue":
        self = .Continue
      case "fallthrough":
        self = .Fallthrough
      case "switch":
        self = .Switch
      case "case":
        self = .Case
      case "default":
        self = .Default
      case "where":
        self = .Where
      case "catch":
        self = .Catch

      default:
        return nil
    }
  }

}

public enum KeywordType: String {

  case As
  case DynamicType
  case False
  case Is
  case Nil
  case Rethrows
  case Super
  case LowerCaseSelf
  case UpperCaseSelf
  case Throw
  case True
  case Try
  case Throws

  init?(string: String) {
    switch string {
      case "as":
        self = .As
      case "dynamicType":
        self = .DynamicType
      case "false":
        self = .False
      case "is":
        self = .Is
      case "nil":
        self = .Nil
      case "rethrows":
        self = .Rethrows
      case "super":
        self = .Super
      case "self":
        self = .LowerCaseSelf
      case "Self":
        self = .UpperCaseSelf
      case "throw":
        self = .Throw
      case "true":
        self = .True
      case "try":
        self = .Try
      case "throws":
        self = .Throws

      default:
        return nil
    }
  }

}

public enum DeclarationKeywordType: String {

  case Class
  case Deinit
  case Enum
  case Extension
  case Func
  case Import
  case Init
  case InOut
  case Let
  case Operator
  case PrecedenceGroup
  case ProtocolKeyword
  case Struct
  case Subscript
  case TypeAlias
  case AssociatedType
  case Var

  case Internal
  case Private
  case Public
  case Static

  init?(string: String) {
    switch string {
      case "class":
        self = .Class
      case "deinit":
        self = .Deinit
      case "enum":
        self = .Enum
      case "extension":
        self = .Extension
      case "func":
        self = .Func
      case "import":
        self = .Import
      case "init":
        self = .Init
      case "inout":
        self = .InOut
      case "let":
        self = .Let
      case "operator":
        self = .Operator
      case "precedencegroup":
        self = .PrecedenceGroup
      case "protocol":
        self = .ProtocolKeyword
      case "struct":
        self = .Struct
      case "subscript":
        self = .Subscript
      case "typealias":
        self = .TypeAlias
      case "associatedtype":
        self = .AssociatedType
      case "var":
        self = .Var

      case "internal":
        self = .Internal
      case "private":
        self = .Private
      case "public":
        self = .Public
      case "static":
        self = .Static

      default:
        return nil
    }
  }

}

public enum HashKeywordType: String {

  case Column
  case File
  case Function
  case SourceLocation
  case Else
  case ElseIf
  case EndIf
  case If
  case Selector

  init?(string: String) {
    switch string {
      case "column":
        self = .Column
      case "file":
        self = .File
      case "function":
        self = .Function
      case "sourceLocation":
        self = .SourceLocation
      case "else":
        self = .Else
      case "elseif":
        self = .ElseIf
      case "endif":
        self = .EndIf
      case "if":
        self = .If
      case "selector":
        self = .Selector

      default:
        return nil
    }
  }

}

public enum HashConfigType: String {

  case Availiable

  init?(string: String) {
    switch string {
      case "availiable":
        self = .Availiable

      default:
        return nil
    }
  }

}

public enum IntegerLiteralKind {
  case Decimal, Binary, Octal, Hexadecimal
}

public enum FloatLiteralKind {
  case Decimal, Hexadecimal
}

public enum StringLiteralKind {
  case Static, InterpolatedStart, InterpolatedMiddle, InterpolatedEnd
}

public enum TokenType {

  case Unknown
  case EOF
  case Identifier(Bool)
  case DollarIdentifier
  case BinaryOperator(String)
  case PrefixOperator(String)
  case PostfixOperator(String)
  case IntegerLiteral(IntegerLiteralKind)
  case FloatLiteral(FloatLiteralKind)
  case StringLiteral(StringLiteralKind)
  case Comment(Bool)
  case Whitespace
  case Newline
  case Keyword(KeywordType)
  case StatementKeyword(StatementKeywordType)
  case DeclarationKeyword(DeclarationKeywordType)
  case HashKeyword(HashKeywordType)
  case HashConfig(HashConfigType)
  case Punctuator(PunctuatorType)
  case Hashbang

  init?(forPunctuator punctuator: String) {
    if let type = PunctuatorType(rawValue: punctuator) {
      self = .Punctuator(type)
    }
    else {
      return nil
    }
  }

  init(forIdentifier identifier: String) {
    if let kw = DeclarationKeywordType(string: identifier) {
      self = .DeclarationKeyword(kw)
    }
    else if let kw = StatementKeywordType(string: identifier) {
      self = .StatementKeyword(kw)
    }
    else if let kw = KeywordType(string: identifier) {
      self = .Keyword(kw)
    }
    else {
      self = .Identifier(false)
    }
  }

  init?(forHashKeyword hashKeyword: String) {
    if let kw = HashKeywordType(string: hashKeyword) {
      self = .HashKeyword(kw)
    }
    else if let kw = HashConfigType(string: hashKeyword) {
      self = .HashConfig(kw)
    }
    else {
      return nil
    }
  }

  var isWhitespace: Bool {
    switch (self) {
        case .Whitespace, .Comment(_): return true
        default: return false
    }

  }
}

extension TokenType: Equatable {}

public func == (a: TokenType, b: TokenType) -> Bool {
  // tailor:off
  switch (a, b) {
      case (.Unknown,                   .Unknown):                                return true
      case (.EOF,                       .EOF):                                    return true
      case (.DollarIdentifier,          .DollarIdentifier):                       return true
      case (.StringLiteral,             .StringLiteral):                          return true
      case (.Whitespace,                .Whitespace):                             return true
      case (.Newline,                   .Newline):                                return true
      case (.Hashbang,                  .Hashbang):                               return true
      case (.Identifier(let a),         .Identifier(let b))         where a == b: return true
      case (.BinaryOperator(let a),     .BinaryOperator(let b))     where a == b: return true
      case (.PrefixOperator(let a),     .PrefixOperator(let b))     where a == b: return true
      case (.PostfixOperator(let a),    .PostfixOperator(let b))    where a == b: return true
      case (.IntegerLiteral(let a),     .IntegerLiteral(let b))     where a == b: return true
      case (.FloatLiteral(let a),       .FloatLiteral(let b))       where a == b: return true
      case (.Comment(let a),            .Comment(let b))            where a == b: return true
      case (.Keyword(let a),            .Keyword(let b))            where a == b: return true
      case (.StatementKeyword(let a),   .StatementKeyword(let b))   where a == b: return true
      case (.DeclarationKeyword(let a), .DeclarationKeyword(let b)) where a == b: return true
      case (.HashKeyword(let a),        .HashKeyword(let b))        where a == b: return true
      case (.HashConfig(let a),         .HashConfig(let b))         where a == b: return true
      case (.Punctuator(let a),         .Punctuator(let b))         where a == b: return true
      default: return false
  }
  // tailor:on
}

public struct Token: CustomStringConvertible, CustomDebugStringConvertible {
  let type: TokenType
  let range: SourceRange
  let prefixStart: SourceLocation
  let atStartOfLine: Bool
  let value: String?

  public var content: String {
    return range.content
  }

  public var prefix: String {
    return range.source.substring(range: prefixStart.index..<range.range.lowerBound)
  }

  public var description: String {
    return range.source.substring(range: prefixStart.index..<range.range.upperBound)
  }

  public var debugDescription: String {
    if let value = self.value {
      return "Token(type: \(type), range: \(range), value: \(String(reflecting: value)))"
    }
    return "Token(type: \(type), range: \(range))"
  }

  init(type: TokenType, range: SourceRange, prefixStart: SourceLocation? = nil, atStartOfLine: Bool = false, value: String? = nil) {
    self.type = type
    self.range = range
    self.prefixStart = prefixStart ?? range.start
    self.atStartOfLine = atStartOfLine
    self.value = value
  }

  init(type: TokenType, range: SourceRange, prefixStart: Source.Index, atStartOfLine: Bool = false, value: String? = nil) {
    self.init(type: type, range: range, prefixStart: SourceLocation(source: range.source, index: prefixStart), atStartOfLine: atStartOfLine, value: value)
  }
}
