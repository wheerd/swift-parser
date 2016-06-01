import Foundation
import Swift

public enum TokenType
{
  case Unknown
  case EOF
  case Identifier
  case Operator(String)
  case IntegerLiteral
  case FloatLiteral
  case StringLiteral
  case Comment
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
    let index: String.CharacterView.Index
}

class Lexer : Sequence
{
  typealias Index = String.CharacterView.Index

  var line = 1
  var column = 1
  var source : String
  var index : Index

  var nextChar : Character?
  {
    get
    {
      if self.index == self.source.endIndex
      {
        return nil
      }
      let nextIndex = self.source.characters.index(after: self.index)
      if nextIndex == self.source.endIndex
      {
        return nil
      }
      return self.source[nextIndex]
    }
  }

  var currentChar : Character?
  {
    get
    {
      if self.index == self.source.endIndex
      {
        return nil
      }
      return self.source[self.index]
    }
  }

  init(_ source: String)
  {
    self.source = source
    self.index = source.startIndex
  }

  func makeIterator() -> AnyIterator<Token> {
    self.line = 1
    self.column = 1
    self.index = self.source.startIndex
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
    while self.index < self.source.endIndex
    {
      switch self.source[self.index]
      {
        case "[", "]", "{", "}", "(", ")", ":", ",", ";", ".", "=":
          return makeTokenAndAdvance(type: .Punctuator(String(self.source[self.index])))
        case "\r":
          return lexNewline(isCRLF: self.nextChar == "\n")
        case "\n":
          return lexNewline()
        case "\t", "\u{B}", "\u{C}", " ":
          return lexAllMatchingAs(type: .Whitespace)
          {
            switch $0
            {
              case "\t", "\u{B}", "\u{C}", " ":
                return true
              default:
                return false
            }
          }
        case "a"..."z", "A"..."Z":
          return lexIdentifier()
        default:
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
    self.index = self.source.characters.index(after: self.index)
    self.column += 1
  }

  func advanceWhile(pred: (Character) -> Bool)
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

    func lexAllMatchingAs(type: TokenType, pred: (Character) -> Bool) -> Token
    {
      let start = self.index
      let line = self.line
      let column = self.column

      self.advanceWhile(pred: pred)

      return Token(
        type: type,
        content: self.source[start..<self.index],
        line: line,
        column: column,
        index: start
      )
    }

  func lexIdentifier() -> Token
  {
    return lexAllMatchingAs(type: .Identifier)
    {
      switch $0
      {
        case "a"..."z", "A"..."Z":
          return true
        default:
          return false
      }
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
      self.index = self.source.characters.index(after: self.index)
      self.column += 1
    }

    let token = Token(
      type: type,
      content: self.source[start..<self.index],
      line: self.line,
      column: column,
      index: start
    )

    return token
  }

  func findEndOfLine() -> Index
  {
    var index = self.index
    while index < self.source.endIndex
    {
      if self.source[index] == "\r" || self.source[index] == "\n"
      {
        return index
      }

      index = self.source.characters.index(after: index)
    }

    return index
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
      print(token.type, token.content.literalString)
    }
}
