import Foundation
import Swift

class Lexer : Sequence
{
  typealias Index = String.UnicodeScalarView.Index

  let source : Source
  var index : Index
  var diagnoses = [Diagnose]()
  let characters : String.UnicodeScalarView
  let startIndex : Index
  let endIndex : Index
  var lastToken : Token? = nil

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

    return AnyIterator { [weak self] in
      switch self!.lastToken?.type
      {
        case .EOF?:
          return nil
        default:
          self!.lastToken = self!.lexNextToken()
          return self!.lastToken
      }
    }
  }

  func lexNextToken() -> Token
  {
    while let char = self.currentChar
    {
      switch char
      {
        case "0":
          if self.nextChar == "x"
          {
            return self.lexHexNumberLiteral()
          }
          if self.nextChar == "o"
          {
            return self.lexIntegerLiteral(type: .Octal, prefix: "o", numChars: Set("01234567".unicodeScalars))
          }
          if self.nextChar == "b"
          {
            return self.lexIntegerLiteral(type: .Binary, prefix: "b", numChars: Set("01".unicodeScalars))
          }
          fallthrough
        case "1"..."9":
          return self.lexDecimalNumberLiteral()
        case "[", "]", "{", "}", "(", ")", ":", ",", ";":
          return makeTokenAndAdvance(type: TokenType(forPunctuator: String(char))!)
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
              return self.lexOperator()
          }
        case "#":
          return self.lexHash()
        case "=", "-", "+", "*", ">", "&", "|", "^", "~", ".":
          return lexOperator()
        case "a"..."z", "A"..."Z", "_":
          return lexIdentifier()
        case "$":
          return lexDollarIdentifier()
        case "`":
          return lexEscapedIdentifier()
        case "\"", "'":
          return lexStringLiteral()
        default:
          if char.isIdentifierHead
          {
              return self.lexIdentifier()
          }

          return makeTokenAndAdvance(type: .Unknown)
      }
    }

    return makeToken(type: .EOF, numberOfChars: 0)
  }

  func advance()
  {
    self.index = self.characters.index(after: self.index)
  }

  func skipWhile(pred: (UnicodeScalar) -> Bool) -> Index
  {
    var index = self.index
    while index != self.endIndex
    {
      if pred(self.characters[index])
      {
        index = self.characters.index(after: index)
      }
      else
      {
          break
      }
    }
    return index
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

    var depth : Int = 1
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
        .withInsertFix(insert: "*/" * depth, at: endIndex)
        .withNote("comment started here", range: start..<start)
    }

    return makeToken(type: .Comment(true), range: start..<self.index)
  }

  func lexAllMatching(as type: TokenType, pred: (UnicodeScalar) -> Bool) -> Token
  {
    let start = self.index
    self.advanceWhile(pred: pred)

    return makeToken(type: type, range: start..<self.index)
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

    return Token(type: type, content: content, range: start..<self.index)
  }

  func lexDollarIdentifier() -> Token
  {
    assert(self.currentChar == "$", "Not a valid starting point for a dollar identifier")

    let start = self.index
    var allDigits = true

    self.advance()
    let nameStart = self.index

    charLoop: while let char = self.currentChar
    {
      switch char
      {
        case "0"..."9":
          break
        case "a"..."z", "A"..."Z":
          allDigits = false
        default:
          break charLoop        
      }

      self.advance()
    }


    if nameStart == self.index
    {
      self.diagnose("expected numeric value following '$'", type: .Error, start: nameStart)
      return makeToken(type: .Unknown, range: start..<self.index)
    }
    if !allDigits
    {
      self.diagnose("expected numeric value following '$'", type: .Error, start: nameStart, end: self.index)
      return makeToken(type: .Identifier(false), range: start..<self.index)
    }

    let content = String(self.characters[nameStart..<self.index])
    return Token(type: .DollarIdentifier, content: content, range: start..<self.index)
  }

  func lexEscapedIdentifier() -> Token
  {
    assert(self.currentChar != nil, "Cannot lex identifier at EOF")
    assert(self.currentChar! == "`", "Not a valid starting point for an escaped identifier")

    let start = self.index
    self.advance()
    let contentStart = self.index

    if self.currentChar!.isIdentifierHead
    {
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

      if self.currentChar == "`"
      {
        let contentEnd = self.index
        self.advance()

        return Token(
          type: .Identifier(true),
          content: String(self.characters[contentStart..<contentEnd]),
          range: start..<self.index
        )
      }
    }

    self.index = start
    return makeTokenAndAdvance(type: .Punctuator(.Backtick))
  }

  func lexOperator() -> Token
  {
    assert(self.currentChar != nil, "Cannot lex operator at EOF")
    assert(self.currentChar!.isOperatorHead, "Not a valid starting point for an operator")

    let start = self.index
    let allowDot = self.currentChar == "."
    var error: String? = nil

    self.advance()

    while let char = self.currentChar
    {
      if (!allowDot && char == ".")
      {
        break
      }
      if char.isOperatorBody
      {
        if char == "/"
        {
          if self.nextChar == "*" || self.nextChar == "/"
          {
            break
          }

          if self.prevChar == "*"
          {
            error = "unexpected end of block comment"
          }
        }

        self.advance()
      }
      else
      {
          break
      }
    }

    let content = String(self.characters[start..<self.index])

    if error != nil
    {
        self.diagnose(error!, type: .Error, start: start, end: self.index)
        return Token(type: .Unknown, content: content, range: start..<self.index)      
    }

    let leftBound = self.isLeftBound(startIndex: start)
    let rightBound = self.isRightBound(endIndex: self.index, isLeftBound: leftBound)

    switch content
    {
      case "=":
        if (leftBound != rightBound) {
          let d = diagnose("'=' must have consistent whitespace on both sides", type: .Error, start: start, end: self.index)
          if (leftBound) {
            d.withInsertFix(insert: " ", at: start)
          }
          else
          {
            d.withInsertFix(insert: " ", at: self.index)
          }
        }
        return Token(type: .Punctuator(.EqualSign), content: "=", range: start..<self.index)

      case "&":
        if (rightBound && !leftBound)
        {
          return Token(type: .Punctuator(.PrefixAmpersand), content: "&", range: start..<self.index)
        }

      case ".":
        if (rightBound == leftBound)
        {
          return Token(type: .Punctuator(.Period), content: ".", range: start..<self.index)
        }

        if (rightBound)
        {
          return Token(type: .Punctuator(.PrefixPeriod), content: ".", range: start..<self.index)
        }

        let afterWhitespaceIndex = self.skipWhile
        {
          switch $0
          {
            case "\t", " ":
              return true
            default:
              return false
          }
        }

        if let char = self.source.character(at: afterWhitespaceIndex)
        {
          if (isRightBound(endIndex: afterWhitespaceIndex, isLeftBound: leftBound) && char != "/")
          {
            self.diagnose("extraneous whitespace after '.' is not permitted", type: .Error, start: self.index, end: afterWhitespaceIndex).withRemoveFix()
            return Token(type: .Punctuator(.Period), content: ".", range: start..<self.index)
          }
        }

        self.diagnose("expected member name following '.'", type: .Error, start: self.index)
        return Token(type: .Unknown, content: content, range: self.index..<self.index)

      case "?":
        if (leftBound)
        {
          return Token(type: .Punctuator(.PostfixQuestionMark), content: "?", range: start..<self.index)
        }
        return Token(type: .Punctuator(.InfixQuestionMark), content: "?", range: start..<self.index)

      case "->":
        return Token(type: .Punctuator(.Arrow), content: "->", range: start..<self.index)

      case "*/":
        self.diagnose("unexpected end of block comment", type: .Error, start: start, end: self.index)
        return Token(type: .Unknown, content: content, range: start..<self.index)

      default:
        break
    }

    let type : TokenType
      = leftBound == rightBound
      ? .BinaryOperator(content)
      : leftBound
        ? .PostfixOperator(content)
        : .PrefixOperator(content)

    return Token(type: type, content: content, range: start..<self.index)
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
      if let type = TokenType(forHashKeyword: name)
      {
        return Token(type: type, content: name, range: start..<self.index)
      }
    }

    self.index = start

    return self.makeTokenAndAdvance(type: .Punctuator(.Hash))
  }

  func lexNewline(isCRLF: Bool = false) -> Token
  {
    return makeTokenAndAdvance(type: .Newline, numberOfChars: isCRLF ? 2 : 1)
  }

  func makeToken(type: TokenType, range: Range<Index>) -> Token
  {
    return Token(
      type: type,
      content: String(self.characters[range]),
      range: range
    )
  }

  func makeToken(type: TokenType, numberOfChars: Int = 1) -> Token
  {
    let start = self.index
    var end = self.index

    for _ in 0..<numberOfChars
    {
      end = self.characters.index(after: end)
    }

    return makeToken(type: type, range: start..<end)
  }

  func makeTokenAndAdvance(type: TokenType, numberOfChars: Int = 1) -> Token
  {
    let token = makeToken(type: type, numberOfChars: numberOfChars)
    self.index = token.range.upperBound

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

  func lexIntegerLiteral(type: IntegerLiteralType, prefix: UnicodeScalar, numChars: Set<UnicodeScalar>) -> Token
  {
    assert(self.currentChar == "0", "Invalid starting point for integer literal")
    assert(self.nextChar == prefix, "Invalid starting point for integer literal")

    let start = self.index
    self.advance()
    self.advance()
    let literalStart = self.index

    if let char = self.currentChar where !numChars.contains(char)
    {
        self.diagnose("expected a digit after integer literal prefix", type: .Error)
        self.advanceWhile { $0.isIdentifierBody }

        return makeToken(type: .Unknown, range: start..<self.index)      
    }

    self.advanceWhile { numChars.contains($0) || $0 == "_" }

    let content = self.characters[literalStart..<self.index].filter { $0 != "_" }.map { String($0) }.joined(separator: "")

    return Token(type: .IntegerLiteral(type), content: content, range: start..<self.index)
  }

  func lexHexNumberLiteral() -> Token
  {
    assert(self.currentChar == "0", "Invalid starting point for integer literal")
    assert(self.nextChar == "x", "Invalid starting point for integer literal")

    let start = self.index
    self.advance()
    self.advance()
    let literalStart = self.index

    if let char = self.currentChar where !char.isHexDigit
    {
        self.diagnose("expected a digit after integer literal prefix", type: .Error)
        self.advanceWhile { $0.isIdentifierBody }

        return makeToken(type: .Unknown, range: start..<self.index)      
    }

    self.advanceWhile { $0.isHexDigit || $0 == "_" }

    if (currentChar != "." || !(nextChar?.isHexDigit ?? false)) && currentChar != "p" && currentChar != "P"
    {
      let content = self.characters[literalStart..<self.index].filter { $0 != "_" }.map { String($0) }.joined(separator: "")

      return Token(type: .IntegerLiteral(.Hexadecimal), content: content, range: start..<self.index)      
    }

    if currentChar == "."
    {
      self.advance()
      self.advanceWhile { $0.isHexDigit || $0 == "_" }

      if self.currentChar != "p" && self.currentChar != "P"
      {
        self.diagnose("hexadecimal floating point literal must end with an exponent", type: .Error)       
        return makeToken(type: .Unknown, range: start..<self.index) 
      }
    }

    assert(self.currentChar == "p" || self.currentChar == "P", "Invalid starting point for integer literal")
    self.advance()

    if self.currentChar == "+" || self.currentChar == "-"
    {
      self.advance()
    }

    if let char = self.currentChar where !char.isDigit
    {
        self.diagnose("expected a digit in floating point exponent", type: .Error)

        return makeToken(type: .Unknown, range: start..<self.index)      
    }

    self.advanceWhile { $0.isDigit || $0 == "_" }

    let content = self.characters[literalStart..<self.index].filter { $0 != "_" }.map { String($0) }.joined(separator: "")

    return Token(type: .FloatLiteral(.Hexadecimal), content: content, range: start..<self.index)
  }

  func lexDecimalNumberLiteral() -> Token
  {
    assert(self.currentChar?.isDigit ?? false, "Invalid starting point for a number literal")

    let start = self.index

    self.advanceWhile { $0.isDigit || $0 == "_" }

    var isFloat = false
    if currentChar == "."
    {
      isFloat = nextChar?.isDigit ?? false
      if let lastType = self.lastToken?.type where lastType == TokenType.Punctuator(.Period)
      {
        isFloat = false
      }
    }
    else if currentChar == "e" || currentChar == "E"
    {
      isFloat = true
    }

    print (isFloat, currentChar, nextChar)

    if !isFloat
    {
      let content = self.characters[start..<self.index].filter { $0 != "_" }.map { String($0) }.joined(separator: "")

      return Token(type: .IntegerLiteral(.Decimal), content: content, range: start..<self.index)      
    }

    if currentChar == "."
    {
      self.advance()
      self.advanceWhile { $0.isDigit || $0 == "_" }
    }

    if currentChar == "e" || currentChar == "E"
    {
      self.advance()

      if self.currentChar == "+" || self.currentChar == "-"
      {
        self.advance()
      }

      if let char = self.currentChar where !char.isDigit
      {
          self.diagnose("expected a digit in floating point exponent", type: .Error)

          return makeToken(type: .Unknown, range: start..<self.index)      
      }

      self.advanceWhile { $0.isDigit || $0 == "_" }
    }

    let content = self.characters[start..<self.index].filter { $0 != "_" }.map { String($0) }.joined(separator: "")

    return Token(type: .FloatLiteral(.Decimal), content: content, range: start..<self.index)
  }

  func lexUnicodeEscape() -> UnicodeScalar?
  {
    assert(self.currentChar == "{", "Invalid unicode escape")
    self.advance()

    var hexValue : UInt32 = 0
    var numDigits : UInt  = 0

    while let digitValue = self.currentChar?.hexValue
    {
      hexValue = (hexValue << 4) | digitValue
      numDigits += 1
      self.advance()
    }

    if self.currentChar != "}"
    {
      diagnose("expected '}' in \\u{...} escape sequence", type: .Error)
      return nil
    }
    self.advance()

    if numDigits < 1 || numDigits > 8
    {
      diagnose("\\u{...} escape sequence expects between 1 and 8 hex digits", type: .Error)
      return nil
    }

    return UnicodeScalar(hexValue)
  }

  func makeDoubleQuotedLiteral(singleQuoted: String) -> String
  {
    var replacement = ""
    var i = singleQuoted.startIndex

    while i != singleQuoted.endIndex
    {
      var nextIndex = singleQuoted.index(after: i)

      if singleQuoted[i] == "\""
      {
        replacement += "\\\""            
      }
      else if nextIndex != singleQuoted.endIndex && singleQuoted[i] == "\\"
      {
        if singleQuoted[nextIndex] != "'"
        {          
          replacement += String(singleQuoted[i])
        }
        replacement += String(singleQuoted[nextIndex])
        nextIndex = singleQuoted.index(after: nextIndex)
      }
      else if nextIndex == singleQuoted.endIndex || singleQuoted[i] != "\\" || singleQuoted[nextIndex] != "'"
      {
        replacement += String(singleQuoted[i])
      }

      i = nextIndex
    }

    return replacement
  }

  func lexStringLiteral() -> Token
  {
    assert(self.currentChar == "\"" || self.currentChar == "\'", "Invalid starting point for a string literal")

    let quoteType = self.currentChar!
    let start = self.index
    var wasErroneous = false
    var content = ""
    
    self.advance()
    let charactersStartIndex = self.index

    characterLoop: while true
    {
      guard self.currentChar != nil else
      {
        diagnose("unterminated string literal", type: .Error)
        return makeToken(type: .Unknown, range: start..<self.index)        
      }

      switch self.currentChar!
      {
        case "\r", "\n":
          diagnose("unterminated string literal", type: .Error)
          return makeToken(type: .Unknown, range: start..<self.index)
        case "\\":
          guard self.nextChar != nil else
          {
            diagnose("unterminated string literal", type: .Error)
            return makeToken(type: .Unknown, range: start..<self.index)  
          }
          switch self.nextChar!
          {
            case "\\", "\"", "'":
              content += String(self.nextChar!)
            case "t":
              content += "\t"
            case "n":
              content += "\t"
            case "r":
              content += "\t"
            case "0":
              content += "\0"
            case "u":
              self.advance()
              self.advance()
              if self.currentChar != "{"
              {
                diagnose("expected hexadecimal code in braces after unicode escape", type: .Error)
                wasErroneous = true
              }
              else if let char = self.lexUnicodeEscape()
              {
                content += String(char)                
              }
              else
              {                
                wasErroneous = true
              }
              continue characterLoop
            default:
              diagnose("invalid escape sequence in literal", type: .Error)
              wasErroneous = true
          }
          self.advance()
        case "\"", "'":
          if self.currentChar! == quoteType
          {
            break characterLoop            
          }
          fallthrough
        default:
          content += String(self.currentChar!)
      }

      self.advance()
    }

    self.advance()

    if quoteType == "'"
    {
      let charactersEndIndex = self.characters.index(before: self.index)
      let str = String(self.characters[charactersStartIndex..<charactersEndIndex])
      let replacement = "\"\(makeDoubleQuotedLiteral(singleQuoted: str))\""

      diagnose("single-quoted string literal found, use '\"'", type: .Error, start: start, end: self.index)
        .withFixIt(replacement: replacement)
    }

    return Token(type: wasErroneous ? .Unknown : .StringLiteral, content: content, range: start..<self.index)
  }
}

func relativePath(_ path: String) -> String?
{
  return NSURL(fileURLWithPath: #file, isDirectory: false).URLByDeletingLastPathComponent?.URLByAppendingPathComponent(path)?.path
}

if let source = Source(path: relativePath("tests/test.swift")!)
{
    var l = Lexer(source)

    for token in l.filter({ $0.type != .Whitespace })
    {
      print("\(token.type): \(token.content.literalString)")
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
}
