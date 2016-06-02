public enum PunctuatorType : String
{
  case LeftParenthesis   = "("
  case LRightParenthesis = ")"
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

public enum StatementKeywordType : String
{
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

  init?(string: String)
  {    
    switch string
    {
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

public enum KeywordType : String
{
  case As
  case DynamicType
  case False
  case Is
  case Nil
  case Rethrows
  case Super
  case `self`
  case `Self`
  case Throw
  case True
  case Try
  case Throws

  init?(string: String)
  {    
    switch string
    {
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
        self = .`self`
      case "Self":
        self = .`Self`
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

public enum DeclarationKeywordType : String
{
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
  case `Protocol`
  case Struct
  case Subscript
  case TypeAlias
  case AssociatedType
  case Var

  case Internal
  case Private
  case Public
  case Static

  init?(string: String)
  {    
    switch string
    {
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
      case "protocol":
        self = .`Protocol`
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

public enum HashKeywordType : String
{
  case Column
  case File
  case Function
  case SourceLocation
  case Else
  case ElseIf
  case EndIf
  case If
  case Selector

  init?(string: String)
  {    
    switch string
    { 
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

public enum HashConfigType : String
{
  case Availiable

  init?(string: String)
  {    
    switch string
    { 
      case "availiable":
        self = .Availiable

      default:
        return nil
    }
  }
}

public enum TokenType
{
  case Unknown
  case EOF
  case Identifier(Bool)
  case DollarIdentifier
  case BinaryOperator(String)
  case PrefixOperator(String)
  case PostfixOperator(String)
  case IntegerLiteral
  case FloatLiteral
  case StringLiteral
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

  init?(forPunctuator punctuator: String)
  {
    if let type = PunctuatorType(rawValue: punctuator)
    {
      self = .Punctuator(type)
    }
    else
    {
      return nil
    }
  }

  init(forIdentifier identifier: String)
  {
    if let kw = DeclarationKeywordType(string: identifier)
    {
      self = .DeclarationKeyword(kw)
    }
    else if let kw = StatementKeywordType(string: identifier)
    {
      self = .StatementKeyword(kw)
    }
    else if let kw = KeywordType(string: identifier)
    {
      self = .Keyword(kw)
    }
    else 
    {
      self = .Identifier(false)      
    }
  }

  init?(forHashKeyword hashKeyword: String)
  {
    if let kw = HashKeywordType(string: hashKeyword)
    {
      self = .HashKeyword(kw)
    }
    else if let kw = HashConfigType(string: hashKeyword)
    {
      self = .HashConfig(kw)
    }
    else
    {
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
