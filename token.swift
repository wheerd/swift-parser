
public enum TokenType
{
  case Unknown
  case EOF
  case Identifier(Bool)
  case BinaryOperator(String)
  case PrefixOperator(String)
  case PostfixOperator(String)
  case IntegerLiteral
  case FloatLiteral
  case StringLiteral
  case Comment(Bool)
  case Whitespace
  case Newline
  case Keyword(String)
  case StatementKeyword(String)
  case DeclarationKeyword(String)
  case PoundKeyword(String)
  case PoundConfig(String)
  case Punctuator(String)
  case Hashbang

  init(forIdentifier identifier: String)
  {
    switch identifier
    {
      case "associatedtype", "class", "deinit", "enum", "extension", "func",
           "import", "init", "inout", "internal", "let", "operator", "private",
           "protocol", "public", "static", "struct", "subscript", "typealias",
           "var":
        self = .DeclarationKeyword(identifier)
      case "break", "case", "continue", "default", "defer", "do", "else",
           "fallthrough", "for", "guard", "if", "in", "repeat", "return",
           "switch", "where", "while":
        self = .StatementKeyword(identifier)
      case "as", "catch", "dynamicType", "false", "is", "nil", "rethrows",
           "super", "self", "Self", "throw", "throws", "true", "try", "_":
        self = .Keyword(identifier)
      default:
        self = .Identifier(false)
    }
  }

  init?(forPoundKeyword poundKeyword: String)
  {
    switch poundKeyword
    {
      case "column", "file", "function", "sourceLocation", "else", "elseif",
           "endif", "if", "selector":
        self = .PoundKeyword(poundKeyword)
      case "available":
        self = .PoundConfig(poundKeyword)
      default:
        return nil
    }
  }
}

public struct Token
{
    let type: TokenType
    let content: String
    let range: Range<String.UnicodeScalarView.Index>
}
