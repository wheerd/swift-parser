import Foundation
import Swift

var 会意字 = "foo"

public enum TokenType
{
  case Unknown
  case EOF
  case Identifier
  case Operator(String)
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
  case Hashbang(String)
}

public struct Token
{
    let type: TokenType
    let content: String
    let line: Int
    let column: Int
    let index: String.UnicodeScalarView.Index
}

class Lexer : Sequence
{
  typealias Index = String.UnicodeScalarView.Index

  var line = 1
  var column = 1
  var source : String
  var index : Index

  var nextChar : UnicodeScalar?
  {
    get
    {
      if self.index == self.source.unicodeScalars.endIndex
      {
        return nil
      }
      let nextIndex = self.source.unicodeScalars.index(after: self.index)
      if nextIndex == self.source.unicodeScalars.endIndex
      {
        return nil
      }
      return self.source.unicodeScalars[nextIndex]
    }
  }

  var currentChar : UnicodeScalar?
  {
    get
    {
      if self.index == self.source.unicodeScalars.endIndex
      {
        return nil
      }
      return self.source.unicodeScalars[self.index]
    }
  }

  init(_ source: String)
  {
    self.source = source
    self.index = source.unicodeScalars.startIndex
  }

  func makeIterator() -> AnyIterator<Token> {
    self.line = 1
    self.column = 1
    self.index = self.source.unicodeScalars.startIndex
    var lastType : TokenType = .Unknown

    return AnyIterator {
      switch lastType
      {
        case .EOF:
          return nil
        default:
          let token = self.lexNextToken()
          lastType = token.type
          return token
      }
    }
  }

  func lexNextToken() -> Token
  {
    while let char = self.currentChar
    {
      switch char
      {
        case "[", "]", "{", "}", "(", ")", ":", ",", ";", ".", "=":
          return makeTokenAndAdvance(type: .Punctuator(String(char)))
        case "\r":
          return lexNewline(isCRLF: self.nextChar == "\n")
        case "\n":
          return lexNewline()
        case "\t", "\u{B}", "\u{C}", " ":
          return lexAllMatching(as: .Whitespace)
          {
            switch $0
            {
              case "\t", "\u{B}", "\u{C}", " ":
                return true
              default:
                return false
            }
          }
        case "/":
          switch self.nextChar
          {
            case "/"?:
              return lexSinglelineComment()
            case "*"?:
              return lexMultilineComment()
            default:
              return makeTokenAndAdvance(type: .Operator("/"))
          }
        case "a"..."z", "A"..."Z", "_", "$":
          return lexIdentifier()
        default:
          if self.isIdentifierHead(char)
          {
              return self.lexIdentifier()
          }

          return makeTokenAndAdvance(type: .Unknown)
      }
    }

    return Token(
      type: .EOF,
      content: "",
      line: self.line,
      column: self.column,
      index: self.index
    )
  }

  func advance()
  {
    self.index = self.source.unicodeScalars.index(after: self.index)
    self.column += 1
  }

  func isIdentifierHead(_ c: UnicodeScalar) -> Bool
  {
    if c.isASCII
    {
      switch c
      {
        case "a"..."z", "A"..."Z", "_", "$":
          return true
        default:
          return false
      }
    }

    switch c
    {
      case "\u{00A8}", "\u{00AA}", "\u{00AD}", "\u{00AF}", "\u{00B2}"..."\u{00B5}", "\u{00B7}"..."\u{00BA}",
           "\u{00BC}"..."\u{00BE}", "\u{00C0}"..."\u{00D6}", "\u{00D8}"..."\u{00F6}", "\u{00F8}"..."\u{00FF}",
           "\u{0100}"..."\u{02FF}", "\u{0370}"..."\u{167F}", "\u{1681}"..."\u{180D}", "\u{180F}"..."\u{1DBF}",
           "\u{1E00}"..."\u{1FFF}",
           "\u{200B}"..."\u{200D}", "\u{202A}"..."\u{202E}", "\u{203F}"..."\u{2040}", "\u{2054}", "\u{2060}"..."\u{206F}",
           "\u{2070}"..."\u{20CF}", "\u{2100}"..."\u{218F}", "\u{2460}"..."\u{24FF}", "\u{2776}"..."\u{2793}",
           "\u{2C00}"..."\u{2DFF}", "\u{2E80}"..."\u{2FFF}",
           "\u{3004}"..."\u{3007}", "\u{3021}"..."\u{302F}", "\u{3031}"..."\u{303F}", "\u{3040}"..."\u{D7FF}",
           "\u{F900}"..."\u{FD3D}", "\u{FD40}"..."\u{FDCF}", "\u{FDF0}"..."\u{FE1F}", "\u{FE30}"..."\u{FE44}",
           "\u{FE47}"..."\u{FFFD}",
           "\u{10000}"..."\u{1FFFD}", "\u{20000}"..."\u{2FFFD}", "\u{30000}"..."\u{3FFFD}", "\u{40000}"..."\u{4FFFD}",
           "\u{50000}"..."\u{5FFFD}", "\u{60000}"..."\u{6FFFD}", "\u{70000}"..."\u{7FFFD}", "\u{80000}"..."\u{8FFFD}",
           "\u{90000}"..."\u{9FFFD}", "\u{A0000}"..."\u{AFFFD}", "\u{B0000}"..."\u{BFFFD}", "\u{C0000}"..."\u{CFFFD}",
           "\u{D0000}"..."\u{DFFFD}", "\u{E0000}"..."\u{EFFFD}":
        return true
      default:
        return false
    }
  }

  func isIdentifierBody(_ c: UnicodeScalar) -> Bool
  {
    if isIdentifierHead(c) && c != "$"
    {
      return true
    }

    switch c
    {
      case "0"..."9",
           "\u{0300}", "\u{036F}", "\u{1DC0}"..."\u{1DFF}", "\u{20D0}"..."\u{20FF}", "\u{FE20}"..."\u{FE2F}":
        return true
      default:
        return false
    }
  }

  func advanceWhile(pred: (UnicodeScalar) -> Bool)
  {
    while let char = self.currentChar
    {
      if pred(char)
      {
        self.advance()
      }
      else
      {
          break
      }
    }
  }

  func lexSinglelineComment() -> Token
  {
    return lexUntilEndOfLine(as: .Comment(false))
  }

  func lexMultilineComment() -> Token
  {
    let start = self.index
    let line = self.line
    let column = self.column

    self.advance()
    self.advance()

    var depth = 1
    while let char = self.currentChar
    {
      if depth == 0
      {
        break
      }

      switch char
      {
        case "*":
          if self.nextChar == "/"
          {
            depth -= 1
            self.advance()
          }
          self.advance()
        case "/":
          if self.nextChar == "*"
          {
            depth += 1
            self.advance()
          }
          self.advance()
        case "\r":
          if self.nextChar == "\n"
          {
            self.advance()
          }
          fallthrough
        case "\n":
          self.advance()
          self.line += 1
          self.column = 0
        default:
          self.advance()
      }
    }

    if depth > 0
    {
      // TODO: Error
    }

    return Token(
      type: .Comment(true),
      content: String(self.source.unicodeScalars[start..<self.index]),
      line: line,
      column: column,
      index: start
    )
  }

  func lexAllMatching(as type: TokenType, pred: (UnicodeScalar) -> Bool) -> Token
  {
    let start = self.index
    let line = self.line
    let column = self.column

    self.advanceWhile(pred: pred)

    return Token(
      type: type,
      content: String(self.source.unicodeScalars[start..<self.index]),
      line: line,
      column: column,
      index: start
    )
  }

  func lexUntilEndOfLine(as type: TokenType) -> Token
  {
    return lexAllMatching(as: type)
    {
      switch $0
      {
        case "\r", "\n":
          return false
        default:
          return true
      }
    }
  }

  func lexIdentifier() -> Token
  {
    assert(self.currentChar != nil, "Cannot lex identifier at EOF")
    assert(self.isIdentifierHead(self.currentChar!), "Not a valid starting point for an identifier")

    let start = self.index
    let line = self.line
    let column = self.column

    self.advance()

    while let char = self.currentChar
    {
      if self.isIdentifierBody(char)
      {
        self.advance()
      }
      else
      {
          break
      }
    }

    let content = String(self.source.unicodeScalars[start..<self.index])
    let type = self.identifierType(identifier: content)

    return Token(
      type: type,
      content: content,
      line: line,
      column: column,
      index: start
    )
  }

  func lexHash() -> Token
  {
    assert(self.currentChar == "#", "Cannot lex # at current position")

    if self.nextChar == "!" && self.index == self.source.unicodeScalars.startIndex
    {
      return lexUntilEndOfLine(as: .Hashbang)
    }

    // TODO

    return makeTokenAndAdvance(.Punctuator("#"))
  }

  /*

  case "#column", "#file", "#function", "#sourceLocation",
     "#available", "#else", "#elseif", "#endif", "#if", "#selector":
  return .PoundKeyword(identifier.substring(from: identifier.characters.index(after: identifier.startIndex)))
  case "#available":
  return .PoundConfig(identifier.substring(from: identifier.characters.index(after: identifier.startIndex)))
  */

  func identifierType(identifier: String) -> TokenType
  {
    switch identifier
    {
      case "associatedtype", "class", "deinit", "enum", "extension", "func",
           "import", "init", "inout", "internal", "let", "operator", "private",
           "protocol", "public", "static", "struct", "subscript", "typealias",
           "var":
        return .DeclarationKeyword(identifier)
      case "break", "case", "continue", "default", "defer", "do", "else",
           "fallthrough", "for", "guard", "if", "in", "repeat", "return",
           "switch", "where", "while":
        return .StatementKeyword(identifier)
      case "as", "catch", "dynamicType", "false", "is", "nil", "rethrows",
           "super", "self", "Self", "throw", "throws", "true", "try", "_":
        return .Keyword(identifier)
      default:
        return .Identifier
    }
  }

func lexNewline(isCRLF: Bool = false) -> Token
{
  let token = makeTokenAndAdvance(type: .Newline, numberOfChars: isCRLF ? 2 : 1)

  self.column = 1
  self.line += 1

  return token
}

  func makeTokenAndAdvance(type: TokenType, numberOfChars: Int = 1) -> Token
  {
    let start = self.index
    let column = self.column

    for _ in 1...numberOfChars
    {
      self.index = self.source.unicodeScalars.index(after: self.index)
      self.column += 1
    }

    let token = Token(
      type: type,
      content: String(self.source.unicodeScalars[start..<self.index]),
      line: self.line,
      column: column,
      index: start
    )

    return token
  }
}

extension String
{
  var literalString : String
  {
    get
    {
      return "\"" + self.characters.map {
        switch $0
        {
          case "\n":
            return "\\n"
          case "\r":
            return "\\r"
          case "\t":
            return "\\t"
          case "\"":
            return "\\\""
          default:
            return String($0)
        }
      }.joined(separator: "") + "\""
    }
  }
}


if let data = try? NSString(contentsOfFile: #file, encoding: NSUTF8StringEncoding)
{
    var l = Lexer(String(data))

    for token in l
    {
      print("\(token.line),\(token.column) \(token.type): \(token.content.literalString)")
    }
}
