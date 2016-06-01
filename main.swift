import Foundation
import Swift

class Lexer : Sequence
{
  typealias Index = String.UnicodeScalarView.Index

  let source : Source
  var index : Index
  var diagnoses = [Diagnose]()
  let characters: String.UnicodeScalarView
  let startIndex: Index
  let endIndex: Index

  var prevChar : UnicodeScalar?
  {
    get
    {
      if self.index == self.startIndex
      {
        return nil
      }
      let prevIndex = self.characters.index(before: self.index)
      return self.characters[prevIndex]
    }
  }

  var currentChar : UnicodeScalar?
  {
    get
    {
      if self.index == self.endIndex
      {
        return nil
      }
      return self.characters[self.index]
    }
  }

  var nextChar : UnicodeScalar?
  {
    get
    {
      if self.index == self.endIndex
      {
        return nil
      }
      let nextIndex = self.characters.index(after: self.index)
      if nextIndex == self.endIndex
      {
        return nil
      }
      return self.characters[nextIndex]
    }
  }

  init(_ source: Source)
  {
    self.source = source
    self.characters = source.characters
    self.startIndex = source.start
    self.endIndex = source.end

    self.index = source.start
  }

  func diagnose(_ message: String, type: Diagnose.DiagnoseType, start: Index? = nil, end: Index? = nil) -> Diagnose
  {
    let start = start ?? self.index
    let end = end ?? start

    let diag = Diagnose(
      message,
      type: type,
      range: start..<end,
      source: source
    )
    diagnoses.append(diag)

    return diag
  }

  func makeIterator() -> AnyIterator<Token> {
    self.index = self.startIndex
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
        case "[", "]", "{", "}", "(", ")", ":", ",", ";":
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
        case "=", "-", "+", "*", ">", "&", "|", "^", "~", ".":
          return lexOperator();
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
      range: self.index..<self.index
    )
  }

  func advance()
  {
    self.index = self.characters.index(after: self.index)
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
        default:
          self.advance()
      }
    }

    if depth > 0
    {
      var endIndex = self.index
      if let prevChar = source.character(before: endIndex)
      {
        if prevChar == "\n"
        {
          endIndex = source.index(before: endIndex)!
          if let prevChar = source.character(before: endIndex)
          {
            if prevChar == "\n"
            {
              endIndex = source.index(before: endIndex)!
            }
          }
        }
        else if prevChar == "\r"
        {
          endIndex = source.index(before: endIndex)!
        }
      }

      diagnose("unterminated '/*' comment", type: .Error, start: endIndex)
        .withInsertFix(at: endIndex, insert: "*/" * depth)
        .withNote("comment started here", range: start..<start)
    }

    return Token(
      type: .Comment(true),
      content: String(self.characters[start..<self.index]),
      range: start..<self.index
    )
  }

  func lexAllMatching(as type: TokenType, pred: (UnicodeScalar) -> Bool) -> Token
  {
    let start = self.index

    self.advanceWhile(pred: pred)

    return Token(
      type: type,
      content: String(self.characters[start..<self.index]),
      range: start..<self.index
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

    let content = String(self.characters[start..<self.index])
    let type = TokenType(forIdentifier: content)

    return Token(
      type: type,
      content: content,
      range: start..<self.index
    )
  }

  func lexOperator() -> Token
  {
    assert(self.currentChar != nil, "Cannot lex operator at EOF")
    assert(self.currentChar!.isOperatorHead, "Not a valid starting point for an operator")

    let start = self.index

    self.advance()

    while let char = self.currentChar
    {
      if char.isOperatorBody
      {
        self.advance()
      }
      else
      {
          break
      }
    }

    let content = String(self.characters[start..<self.index])
    let leftBound = self.isLeftBound(startIndex: start)
    let rightBound = self.isRightBound(endIndex: self.index, isLeftBound: leftBound)

    switch content
    {
      case "=":
        if (leftBound != rightBound) {
          let d = diagnose("'=' must have consistent whitespace on both sides", type: .Error, start: start, end: self.index);
          if (leftBound) {
            d.fixIts.append(Diagnose.FixIt(
              range: start..<start,
              replacement: " "
            ))
          }
          else
          {
            d.fixIts.append(Diagnose.FixIt(
              range: self.index..<self.index,
              replacement: " "
            ))
          }
        }
      default:
        break
    }
    return Token(
      type: .Operator(content),
      content: content,
      range: start..<self.index
    )
  }

  func lexHash() -> Token
  {
    assert(self.currentChar == "#", "Cannot lex # at current position")

    if self.nextChar == "!" && self.index == self.startIndex
    {
      return lexUntilEndOfLine(as: .Hashbang)
    }

    let start = self.index

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
      let name = String(self.characters[nameStart..<self.index])
      if let type = TokenType(forPoundKeyword: name)
      {
        let content = String(self.characters[start..<self.index])
        return Token(
          type: type,
          content: content,
          range: start..<self.index
        )
      }
    }

    self.index = start

    return self.makeTokenAndAdvance(type: .Punctuator("#"))
  }

  func lexNewline(isCRLF: Bool = false) -> Token
  {
    return makeTokenAndAdvance(type: .Newline, numberOfChars: isCRLF ? 2 : 1)
  }

  func makeTokenAndAdvance(type: TokenType, numberOfChars: Int = 1) -> Token
  {
    let start = self.index

    for _ in 1...numberOfChars
    {
      self.index = self.characters.index(after: self.index)
    }

    let token = Token(
      type: type,
      content: String(self.characters[start..<self.index]),
      range: start..<self.index
    )

    return token
  }

  func isLeftBound(startIndex: Index) -> Bool
  {
    if startIndex == self.startIndex
    {
      return false
    }

    let prevIndex = self.characters.index(before: startIndex)
    switch self.characters[prevIndex]
    {
      case " ", "\t", "\r", "\n", "\0",
           "(", "[", "{",
           ",", ";", ":":
        return false
      case "/":
        if prevIndex > self.startIndex
        {
          let prevPrevIndex = self.characters.index(before: prevIndex)
          if self.characters[prevPrevIndex] == "*"
          {
            return false
          }
        }
        fallthrough
      default:
        return true
    }
  }

  func isRightBound(endIndex: Index, isLeftBound: Bool) -> Bool
  {
    if endIndex == self.endIndex
    {
      return false
    }

    switch self.characters[endIndex]
    {
      case " ", "\t", "\r", "\n", "\0",
           ")", "]", "}",
           ",", ";", ":":
        return false
      case ".":
        return !isLeftBound
      case "/":
        let nextIndex = self.characters.index(after: endIndex)
        if nextIndex != self.endIndex
        {
          if self.characters[nextIndex] == "*" || self.characters[nextIndex] == "/"
          {
            return false
          }
        }
        fallthrough
      default:
        return true
    }
  }
}

func relativePath(_ path: String) -> String?
{
  return NSURL(fileURLWithPath: #file, isDirectory: false).URLByDeletingLastPathComponent?.URLByAppendingPathComponent(path)?.path
}

if let source = Source(path: relativePath("tests/test.swift")!)
{
    var l = Lexer(source)

    for _ in l {

    }

    for diag in l.diagnoses
    {
      let (lineRange, line, col) = diag.getContext()
      let range = diag.range.clamped(to: lineRange)
      let count = diag.source.characters.getCount(range: range)
      print("\(diag.source.identifier):\(line):\(col) \(diag.type): \(diag.message)")
      print(String(diag.source.characters[lineRange]))
      print(" " * (col - 1), terminator: "")
      print("^" * max(count, 1))
      if !diag.fixIts.isEmpty
      {
        print("Fix:")
        for fixIt in diag.fixIts
        {
          let (lineRange, line, col) = diag.source.getContext(index: fixIt.range.lowerBound)
          let range = fixIt.range.clamped(to: lineRange)
          let count = diag.source.characters.getCount(range: range)
          print(String(diag.source.characters[lineRange]))
          print(" " * (col - 1), terminator: "")
          print("^" * max(count, 1))
          print(" " * (col - 1), terminator: "")
          print(fixIt.replacement)
        }
      }
      if !diag.related.isEmpty
      {
        for related in diag.related
        {
          let (lineRange, line, col) = related.source.getContext(index: related.range.lowerBound)
          let range = related.range.clamped(to: lineRange)
          let count = related.source.characters.getCount(range: range)
          print("  \(related.source.identifier):\(line):\(col) \(related.type): \(related.message)")
          print("  " + String(related.source.characters[lineRange]))
          print(" " * (col + 1), terminator: "")
          print("^" * max(count, 1))
        }
      }
    }
    /*
    for token in l.filter({
        switch $0.type {
          case .Whitespace:
            return false
          default:
            return true
        }
      })
    {
      print("\(token.type): \(token.content.literalString)")
    }
    */
}
