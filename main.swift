import Foundation
import Swift

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
        case "#":
          return self.lexHash()
        case "a"..."z", "A"..."Z", "_", "$":
          return lexIdentifier()
        default:
          if char.isIdentifierHead
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
    assert(self.currentChar!.isIdentifierHead, "Not a valid starting point for an identifier")

    let start = self.index
    let line = self.line
    let column = self.column

    self.advance()

    while let char = self.currentChar
    {
      if char.isIdentifierBody
      {
        self.advance()
      }
      else
      {
          break
      }
    }

    let content = String(self.source.unicodeScalars[start..<self.index])
    let type = TokenType(forIdentifier: content)

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

    let start = self.index
    let line = self.line
    let column = self.column

    self.advance()

    let nameStart = self.index

    identifierLoop: while let char = self.currentChar
    {
      switch char
      {
        case "a"..."z", "A"..."Z":
          self.advance()
        default:
          break identifierLoop
      }
    }

    if self.index > nameStart
    {
      let name = String(self.source.unicodeScalars[nameStart..<self.index])
      if let type = TokenType(forPoundKeyword: name)
      {
        let content = String(self.source.unicodeScalars[start..<self.index])
        return Token(
          type: type,
          content: content,
          line: line,
          column: column,
          index: start
        )
      }
    }

    self.index = start
    self.line = line
    self.column = column

    return self.makeTokenAndAdvance(type: .Punctuator("#"))
  }

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

  func poundKeywordType(identifier: String) -> TokenType?
  {
    switch identifier
    {
      case "column", "file", "function", "sourceLocation", "else", "elseif",
           "endif", "if", "selector":
        return .PoundKeyword(identifier)
      case "available":
        return .PoundConfig(identifier)
      default:
        return nil
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
          case "\\":
            return "\\\\"
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

    for token in l.filter({
        switch $0.type {
          case .Whitespace:
            return false
          default:
            return true
        }
      })
    {
      print("\(token.line),\(token.column) \(token.type): \(token.content.literalString)")
    }
}
