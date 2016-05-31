import Foundation

public enum TokenType
{
  case Unknown
  case EOF
  case Identifier
  case BinaryOperator(Bool)
  case PostfixOperator
  case PrefixOperator
  case IntegerLiteral
  case FloatLiteral
  case StringLiteral
  case Comment
  case Keyword(String)
  case StatementKeyword(String)
  case DeclarationKeyword(String)
  case PoundKeyword(String)
  case PoundConfig(String)
  case Punctuator(String)
}

public struct Token
{
    let Kind: TokenType
    let Content: String
    let Line: Int
    let Column: Int
    let Offset: Int
}

if let data = try? NSString(contentsOfFile: #file, encoding: NSUTF8StringEncoding)
{
    print (String(data))
}
