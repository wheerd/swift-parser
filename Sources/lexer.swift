class Lexer: Sequence {
  typealias Index = String.UnicodeScalarView.Index

  let source: Source
  var index: Index
  var diagnoses = [Diagnose]()
  let characters: String.UnicodeScalarView
  let startIndex: Index
  let endIndex: Index
  var lastToken: Token?
  var nextToken: Token!
  let lexComments: Bool

  private var parenthesisDepth: Int
  private var subLexer: Lexer? = nil
  private var interpolatedStringQuoteType: UnicodeScalar? = nil

  private var prefixStart: Source.Index
  private var atStartOfLine = true

  var prevChar: UnicodeScalar? {
    get {
      if self.index == self.startIndex {
        return nil
      }
      let prevIndex = self.characters.index(before: self.index)
      return self.characters[prevIndex]
    }
  }

  var currentChar: UnicodeScalar? {
    get {
      if self.index == self.endIndex {
        return nil
      }
      return self.characters[self.index]
    }
  }

  var nextChar: UnicodeScalar? {
    get {
      if self.index == self.endIndex {
        return nil
      }
      let nextIndex = self.characters.index(after: self.index)
      if nextIndex == self.endIndex {
        return nil
      }
      return self.characters[nextIndex]
    }
  }

  convenience init(_ source: Source) {
    self.init(source, parenthesisDepth: 0)
  }

  init(_ source: Source, parenthesisDepth: Int, startIndex: Index? = nil, endIndex: Index? = nil, currentIndex: Index? = nil, lexComments: Bool = false) {
    self.source = source
    self.characters = source.characters
    self.startIndex = startIndex ?? source.start
    self.prefixStart = self.startIndex
    self.endIndex = endIndex ?? source.end

    self.index = currentIndex ?? startIndex ?? source.start
    self.parenthesisDepth = parenthesisDepth
    self.lexComments = lexComments

    self.lastToken = nil
    self.nextToken = self.lex()
  }

  @discardableResult
  func diagnose(_ message: String, type: Diagnose.DiagnoseType, start: Index? = nil, end: Index? = nil) -> Diagnose {
    let start = start ?? self.index
    let end = end ?? start

    let diag = Diagnose(
      message,
      type: type,
      range: SourceRange(source: source, range: start..<end)
    )
    diagnoses.append(diag)

    return diag
  }

  func makeIterator() -> AnyIterator<Token> {
    self.index = self.startIndex

    return AnyIterator { [weak self] in
      switch self!.nextToken.type {
        case .EOF:
          return nil
        default:
          return self!.lexNextToken()
      }
    }
  }

  func lexNextToken() -> Token {
    lastToken = nextToken!
    if lastToken!.type != .EOF {
      nextToken = lex()
    }
    return lastToken!
  }

  func peekNextToken() -> Token {
    return self.nextToken!
  }

  private func lex() -> Token {
    if let subLexer = self.subLexer {
      let oldIndex = subLexer.index
      let token = subLexer.lexNextToken()

      if token.type == .Newline || token.type == .EOF {
        self.index = subLexer.index
        self.subLexer = nil
        self.interpolatedStringQuoteType = nil

        diagnose("unterminated string literal", type: .Error, start: oldIndex)
        return token
      }

      if let quoteType = self.interpolatedStringQuoteType {
        if subLexer.parenthesisDepth == 0 {
          self.index = oldIndex
          self.subLexer = nil
          self.interpolatedStringQuoteType = nil

          return self.lexStringLiteral(quoteType: quoteType, interpolated: true)
        }
      }

      return token
    }

    prefixStart = index
    atStartOfLine = index == startIndex

    while let char = self.currentChar {
      switch char {
        case "0":
          if self.nextChar == "x" {
            return self.lexHexNumberLiteral()
          }
          if self.nextChar == "o" {
            return self.lexIntegerLiteral(type: .Octal, prefix: "o", numChars: Set("01234567".unicodeScalars))
          }
          if self.nextChar == "b" {
            return self.lexIntegerLiteral(type: .Binary, prefix: "b", numChars: Set("01".unicodeScalars))
          }
          fallthrough
        case "1"..."9":
          return self.lexDecimalNumberLiteral()
        case "(", ")":
          self.parenthesisDepth += char == "(" ? 1 : -1
          fallthrough
        case "[", "]", "{", "}", ":", ",", ";":
          return makeTokenAndAdvance(type: TokenType(forPunctuator: String(char))!)
        case "\n", "\r":
          atStartOfLine = true
          fallthrough
        case "\t", "\u{B}", "\u{C}", " ":
          self.advance()
          continue
        case "/":
          switch self.nextChar {
            case "/"?:
              let comment = lexSinglelineComment()
              if lexComments {
                return comment
              } else {
                prefixStart = comment.prefixStart.index
                continue
              }
            case "*"?:
              let comment = lexMultilineComment()
              if lexComments {
                return comment
              } else {
                prefixStart = comment.prefixStart.index
                continue
              }
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
          return lexStringLiteral(quoteType: self.currentChar!, interpolated: false)
        case "\u{201D}":
          diagnose("unicode curly quote found, replace with '\"'", type: .Error, end: self.characters.index(after: self.index))
            .withReplaceFix("\"")
          return makeTokenAndAdvance(type: .Unknown)
        case "\u{201C}":
          if let endIndex = self.findEndOfCurlyQuoteStringLiteral() {
            let startIndex = self.index
            self.index = endIndex
            return makeToken(type: .Unknown, range: startIndex..<endIndex)
          }
          return makeTokenAndAdvance(type: .Unknown)
        default:
          if char.isIdentifierHead {
            return self.lexIdentifier()
          }
          if char.isOperatorHead {
            return self.lexOperator()
          }
          if char.isIdentifierBody {
            let start = self.index
            self.advanceWhile { $0.isIdentifierBody }
            return makeToken(type: .Unknown, range: start..<self.index)
          }

          diagnose("invalid character in source file", type: .Error, end: self.characters.index(after: self.index))
            .withReplaceFix(" ")
          return makeTokenAndAdvance(type: .Unknown)
      }
    }

    return makeToken(type: .EOF, numberOfChars: 0)
  }

  func advance() {
    self.index = self.characters.index(after: self.index)
  }

  func skipWhile(pred: (UnicodeScalar) -> Bool) -> Index {
    var index = self.index
    while index != self.endIndex {
      if pred(self.characters[index]) {
        index = self.characters.index(after: index)
      }
      else {
          break
      }
    }
    return index
  }

  func advanceWhile(pred: (UnicodeScalar) -> Bool) {
    while let char = self.currentChar {
      if pred(char) {
        self.advance()
      }
      else {
          break
      }
    }
  }

  func lexSinglelineComment() -> Token {
    return lexUntilEndOfLine(as: .Comment(false))
  }

  func lexMultilineComment() -> Token {
    let start = self.index

    self.advance()
    self.advance()

    var depth: Int = 1
    while let char = self.currentChar {
      if depth == 0 {
        break
      }

      switch char {
        case "*":
          if self.nextChar == "/" {
            depth -= 1
            self.advance()
          }
          self.advance()
        case "/":
          if self.nextChar == "*" {
            depth += 1
            self.advance()
          }
          self.advance()
        default:
          self.advance()
      }
    }

    if depth > 0 {
      var endIndex = self.index
      if let prevChar = source.character(before: endIndex) {
        if prevChar == "\n" {
          endIndex = source.index(before: endIndex)!
          if let prevChar = source.character(before: endIndex) {
            if prevChar == "\n" {
              endIndex = source.index(before: endIndex)!
            }
          }
        }
        else if prevChar == "\r" {
          endIndex = source.index(before: endIndex)!
        }
      }

      diagnose("unterminated '/*' comment", type: .Error, start: endIndex)
        .withInsertFix("*/" * depth, at: endIndex)
        .withNote("comment started here", range: start..<start)
    }

    return makeToken(type: .Comment(true), range: start..<self.index)
  }

  func lexAllMatching(as type: TokenType, pred: (UnicodeScalar) -> Bool) -> Token {
    let start = self.index
    self.advanceWhile(pred: pred)

    return makeToken(type: type, range: start..<self.index)
  }

  func lexUntilEndOfLine(as type: TokenType) -> Token {
    return lexAllMatching(as: type) {
      switch $0 {
        case "\r", "\n":
          return false
        default:
          return true
      }
    }
  }

  func lexIdentifier() -> Token {
    assert(self.currentChar != nil, "Cannot lex identifier at EOF")
    assert(self.currentChar!.isIdentifierHead, "Not a valid starting point for an identifier")

    let start = self.index

    self.advance()

    while let char = self.currentChar {
      if char.isIdentifierBody {
        self.advance()
      }
      else {
          break
      }
    }

    let content = String(self.characters[start..<self.index])
    let type = TokenType(forIdentifier: content)

    return makeToken(type: type, range: start..<self.index, value: content)
  }

  func lexDollarIdentifier() -> Token {
    assert(self.currentChar == "$", "Not a valid starting point for a dollar identifier")

    let start = self.index
    var allDigits = true

    self.advance()
    let nameStart = self.index

    charLoop: while let char = self.currentChar {
      switch char {
        case "0"..."9":
          break
        case "a"..."z", "A"..."Z":
          allDigits = false
        default:
          break charLoop
      }

      self.advance()
    }


    if nameStart == self.index {
      self.diagnose("expected numeric value following '$'", type: .Error, start: nameStart)
      return makeToken(type: .Unknown, range: start..<self.index)
    }
    if !allDigits {
      self.diagnose("expected numeric value following '$'", type: .Error, start: nameStart, end: self.index)
      return makeToken(type: .Identifier(false), range: start..<self.index)
    }

    let content = String(self.characters[nameStart..<self.index])
    return makeToken(type: .DollarIdentifier, range: start..<self.index, value: content)
  }

  func lexEscapedIdentifier() -> Token {
    assert(self.currentChar != nil, "Cannot lex identifier at EOF")
    assert(self.currentChar! == "`", "Not a valid starting point for an escaped identifier")

    let start = self.index
    self.advance()
    let contentStart = self.index

    if self.currentChar!.isIdentifierHead {
      while let char = self.currentChar {
        if char.isIdentifierBody {
          self.advance()
        }
        else {
            break
        }
      }

      if self.currentChar == "`" {
        let contentEnd = self.index
        self.advance()

        return Token(
          type: .Identifier(true),
          range: SourceRange(source: source, range: start..<self.index),
          prefixStart: prefixStart,
          atStartOfLine: atStartOfLine,
          value: source.substring(range: contentStart..<contentEnd)
        )
      }
    }

    self.index = start
    return makeTokenAndAdvance(type: .Punctuator(.Backtick))
  }

  func lexOperator() -> Token {
    assert(self.currentChar != nil, "Cannot lex operator at EOF")
    assert(self.currentChar!.isOperatorHead, "Not a valid starting point for an operator")

    let start = self.index
    let allowDot = self.currentChar == "."
    var error: String? = nil

    self.advance()

    while let char = self.currentChar {
      if !allowDot && char == "." {
        break
      }
      if char.isOperatorBody {
        if char == "/" {
          if self.nextChar == "*" || self.nextChar == "/" {
            break
          }

          if self.prevChar == "*" {
            error = "unexpected end of block comment"
          }
        }

        self.advance()
      }
      else {
          break
      }
    }

    let content = String(self.characters[start..<self.index])

    if error != nil {
        self.diagnose(error!, type: .Error, start: start, end: self.index)
        return makeToken(type: .Unknown, range: start..<self.index)
    }

    let leftBound = self.isLeftBound(startIndex: start)
    let rightBound = self.isRightBound(endIndex: self.index, isLeftBound: leftBound)

    switch content {
      case "=":
        if leftBound != rightBound {
          let d = diagnose("'=' must have consistent whitespace on both sides", type: .Error, start: start, end: self.index)
          if leftBound {
            d.withInsertFix(" ", at: start)
          }
          else {
            d.withInsertFix(" ", at: self.index)
          }
        }
        return makeToken(type: .Punctuator(.EqualSign), range: start..<self.index)

      case "&":
        if rightBound && !leftBound {
          return makeToken(type: .Punctuator(.PrefixAmpersand), range: start..<self.index)
        }

      case ".":
        if rightBound == leftBound {
          return makeToken(type: .Punctuator(.Period), range: start..<self.index)
        }

        if rightBound {
          return makeToken(type: .Punctuator(.PrefixPeriod), range: start..<self.index)
        }

        let afterWhitespaceIndex = self.skipWhile {
          switch $0 {
            case "\t", " ":
              return true
            default:
              return false
          }
        }

        if let char = self.source.character(at: afterWhitespaceIndex) {
          if isRightBound(endIndex: afterWhitespaceIndex, isLeftBound: leftBound) && char != "/" {
            self.diagnose("extraneous whitespace after '.' is not permitted", type: .Error, start: self.index, end: afterWhitespaceIndex).withRemoveFix()
            return makeToken(type: .Punctuator(.Period), range: start..<self.index)
          }
        }

        self.diagnose("expected member name following '.'", type: .Error, start: self.index)
        return makeToken(type: .Unknown, range: self.index..<self.index)

      case "?":
        if leftBound {
          return makeToken(type: .Punctuator(.PostfixQuestionMark), range: start..<self.index)
        }
        return makeToken(type: .Punctuator(.InfixQuestionMark), range: start..<self.index)

      case "!":
        if leftBound {
          return makeToken(type: .Punctuator(.PostfixExclaimationMark), range: start..<self.index)
        }

      case "->":
        return makeToken(type: .Punctuator(.Arrow), range: start..<self.index)

      case "*/":
        self.diagnose("unexpected end of block comment", type: .Error, start: start, end: self.index)
        return makeToken(type: .Unknown, range: start..<self.index)

      default:
        break
    }

    let type: TokenType
      = leftBound == rightBound
      ? .BinaryOperator(content) : leftBound
        ? .PostfixOperator(content) : .PrefixOperator(content)

    return makeToken(type: type, range: start..<self.index)
  }

  func lexHash() -> Token {
    assert(self.currentChar == "#", "Cannot lex # at current position")

    if self.nextChar == "!" && self.index == self.startIndex {
      return lexUntilEndOfLine(as: .Hashbang)
    }

    let start = self.index

    self.advance()

    let nameStart = self.index

    identifierLoop: while let char = self.currentChar {
      switch char {
        case "a"..."z", "A"..."Z":
          self.advance()
        default:
          break identifierLoop
      }
    }

    if self.index > nameStart {
      let name = String(self.characters[nameStart..<self.index])
      if let type = TokenType(forHashKeyword: name) {
        return makeToken(type: type, range: start..<self.index)
      }
    }

    self.index = start

    return self.makeTokenAndAdvance(type: .Punctuator(.Hash))
  }

  func makeToken(type: TokenType, range: Range<Index>, value: String? = nil) -> Token {
    return Token(
      type: type,
      range: SourceRange(source: source, range: range),
      prefixStart: prefixStart,
      atStartOfLine: atStartOfLine,
      value: value
    )
  }

  func makeToken(type: TokenType, numberOfChars: Int = 1) -> Token {
    let start = self.index
    var end = self.index

    for _ in 0..<numberOfChars {
      end = self.characters.index(after: end)
    }

    return makeToken(type: type, range: start..<end)
  }

  func makeTokenAndAdvance(type: TokenType, numberOfChars: Int = 1) -> Token {
    let token = makeToken(type: type, numberOfChars: numberOfChars)
    self.index = token.range.range.upperBound

    return token
  }

  func isLeftBound(startIndex: Index) -> Bool {
    if startIndex == self.startIndex {
      return false
    }

    let prevIndex = self.characters.index(before: startIndex)
    switch self.characters[prevIndex] {
      case " ", "\t", "\r", "\n", "\0",
           "(", "[", "{",
           ",", ";", ":":
        return false
      case "/":
        if prevIndex > self.startIndex {
          let prevPrevIndex = self.characters.index(before: prevIndex)
          if self.characters[prevPrevIndex] == "*" {
            return false
          }
        }
        fallthrough
      default:
        return true
    }
  }

  func isRightBound(endIndex: Index, isLeftBound: Bool) -> Bool {
    if endIndex == self.endIndex {
      return false
    }

    switch self.characters[endIndex] {
      case " ", "\t", "\r", "\n", "\0",
           ")", "]", "}",
           ",", ";", ":":
        return false
      case ".":
        return !isLeftBound
      case "/":
        let nextIndex = self.characters.index(after: endIndex)
        if nextIndex != self.endIndex {
          if self.characters[nextIndex] == "*" || self.characters[nextIndex] == "/" {
            return false
          }
        }
        fallthrough
      default:
        return true
    }
  }

  func lexIntegerLiteral(type: IntegerLiteralKind, prefix: UnicodeScalar, numChars: Set<UnicodeScalar>) -> Token {
    assert(self.currentChar == "0", "Invalid starting point for integer literal")
    assert(self.nextChar == prefix, "Invalid starting point for integer literal")

    let start = self.index
    self.advance()
    self.advance()
    let literalStart = self.index

    if let char = self.currentChar, !numChars.contains(char) {
        self.diagnose("expected a digit after integer literal prefix", type: .Error)
        self.advanceWhile { $0.isIdentifierBody }

        return makeToken(type: .Unknown, range: start..<self.index)
    }

    self.advanceWhile { numChars.contains($0) || $0 == "_" }

    let content = self.characters[literalStart..<self.index].filter { $0 != "_" }.map { String($0) }.joined(separator: "")

    return makeToken(type: .IntegerLiteral(type), range: start..<self.index, value: content)
  }

  func lexHexNumberLiteral() -> Token {
    assert(self.currentChar == "0", "Invalid starting point for integer literal")
    assert(self.nextChar == "x", "Invalid starting point for integer literal")

    let start = self.index
    self.advance()
    self.advance()
    let literalStart = self.index

    if let char = self.currentChar, !char.isHexDigit {
        self.diagnose("expected a digit after integer literal prefix", type: .Error)
        self.advanceWhile { $0.isIdentifierBody }

        return makeToken(type: .Unknown, range: start..<self.index)
    }

    self.advanceWhile { $0.isHexDigit || $0 == "_" }

    if (currentChar != "." || !(nextChar?.isHexDigit ?? false)) && currentChar != "p" && currentChar != "P" {
      let content = self.characters[literalStart..<self.index].filter { $0 != "_" }.map { String($0) }.joined(separator: "")

      return makeToken(type: .IntegerLiteral(.Hexadecimal), range: start..<self.index, value: content)
    }

    if currentChar == "." {
      self.advance()
      self.advanceWhile { $0.isHexDigit || $0 == "_" }

      if self.currentChar != "p" && self.currentChar != "P" {
        self.diagnose("hexadecimal floating point literal must end with an exponent", type: .Error)
        return makeToken(type: .Unknown, range: start..<self.index)
      }
    }

    assert(self.currentChar == "p" || self.currentChar == "P", "Invalid starting point for integer literal")
    self.advance()

    if self.currentChar == "+" || self.currentChar == "-" {
      self.advance()
    }

    if let char = self.currentChar, !char.isDigit {
        self.diagnose("expected a digit in floating point exponent", type: .Error)

        return makeToken(type: .Unknown, range: start..<self.index)
    }

    self.advanceWhile { $0.isDigit || $0 == "_" }

    let content = self.characters[literalStart..<self.index].filter { $0 != "_" }.map { String($0) }.joined(separator: "")

    return makeToken(type: .FloatLiteral(.Hexadecimal), range: start..<self.index, value: content)
  }

  func lexDecimalNumberLiteral() -> Token {
    assert(self.currentChar?.isDigit ?? false, "Invalid starting point for a number literal")

    let start = self.index

    self.advanceWhile { $0.isDigit || $0 == "_" }

    var isFloat = false
    if currentChar == "." {
      isFloat = nextChar?.isDigit ?? false
      if self.nextToken.type == .Punctuator(.Period) {
        isFloat = false
      }
    }
    else if currentChar == "e" || currentChar == "E" {
      isFloat = true
    }

    if !isFloat {
      let content = self.characters[start..<self.index].filter { $0 != "_" }.map { String($0) }.joined(separator: "")

      return makeToken(type: .IntegerLiteral(.Decimal), range: start..<self.index, value: content)
    }

    if currentChar == "." {
      self.advance()
      self.advanceWhile { $0.isDigit || $0 == "_" }
    }

    if currentChar == "e" || currentChar == "E" {
      self.advance()

      if self.currentChar == "+" || self.currentChar == "-" {
        self.advance()
      }

      if let char = self.currentChar, !char.isDigit {
          self.diagnose("expected a digit in floating point exponent", type: .Error)

          return makeToken(type: .Unknown, range: start..<self.index)
      }

      self.advanceWhile { $0.isDigit || $0 == "_" }
    }

    let content = self.characters[start..<self.index].filter { $0 != "_" }.map { String($0) }.joined(separator: "")

    return makeToken(type: .FloatLiteral(.Decimal), range: start..<self.index, value: content)
  }

  func lexUnicodeEscape(start: Index) throws -> UnicodeScalar {
    assert(self.currentChar == "{", "Invalid unicode escape")
    self.advance()

    var hexValue: UInt32 = 0
    var numDigits: UInt  = 0

    while let digitValue = self.currentChar?.hexValue {
      hexValue = (hexValue << 4) | digitValue
      numDigits += 1
      self.advance()
    }

    if self.currentChar != "}" {
      throw Diagnose("expected '}' in \\u{...} escape sequence", type: .Error, at: SourceLocation(source: self.source, index: self.index))
    }
    self.advance()

    if numDigits < 1 || numDigits > 8 {
      throw Diagnose("\\u{...} escape sequence expects between 1 and 8 hex digits", type: .Error, range: SourceRange(source: self.source, range: start..<self.index))
    }

    if let value = UnicodeScalar(hexValue) {
      return value
    }
    else {
      throw Diagnose("Invalid \\u{...} escape sequence, invalid unicode scalar", type: .Error, range: SourceRange(source: self.source, range: start..<self.index))
    }
  }

  func makeDoubleQuotedLiteral(singleQuoted: String) -> String {
    var replacement = ""
    var i = singleQuoted.startIndex

    while i != singleQuoted.endIndex {
      var nextIndex = singleQuoted.index(after: i)

      if singleQuoted[i] == "\"" {
        replacement += "\\\""
      }
      else if nextIndex != singleQuoted.endIndex && singleQuoted[i] == "\\" {
        if singleQuoted[nextIndex] != "'" {
          replacement += String(singleQuoted[i])
        }
        replacement += String(singleQuoted[nextIndex])
        nextIndex = singleQuoted.index(after: nextIndex)
      }
      else if nextIndex == singleQuoted.endIndex || singleQuoted[i] != "\\" || singleQuoted[nextIndex] != "'" {
        replacement += String(singleQuoted[i])
      }

      i = nextIndex
    }

    return replacement
  }

  enum StringEnd: Error {
    case End
  }

  func lexCharacter(quoteType: UnicodeScalar) throws -> UnicodeScalar {
    assert(self.currentChar != nil, "Cannot lex character at end of source")

    var char: UnicodeScalar = "\0"

    switch self.currentChar! {
      case "\\":
        let start = self.index
        self.advance()
        guard self.nextChar != nil else {
          throw Diagnose("invalid escape sequence in literal", type: .Error, at: SourceLocation(source: self.source, index: self.index))
        }
        switch self.currentChar! {
          case "\\", "\"", "'":
            char = self.currentChar!
          case "t":
            char = "\t"
          case "n":
            char = "\n"
          case "r":
            char = "\r"
          case "0":
            char = "\0"
          case "u":
            self.advance()
            if self.currentChar != "{" {
              throw Diagnose("expected hexadecimal code in braces after unicode escape", type: .Error, at: SourceLocation(source: self.source, index: self.index))
            }

            return try self.lexUnicodeEscape(start: start)
          default:
            throw Diagnose("invalid escape sequence in literal", type: .Error, at: SourceLocation(source: self.source, index: self.index))
        }
      case "\"", "'":
        if self.currentChar! == quoteType {
          throw StringEnd.End
        }
        fallthrough
      default:
        char = self.currentChar!
    }
    self.advance()
    return char
  }

  func lexStringLiteral(quoteType: UnicodeScalar, interpolated: Bool) -> Token {
    assert(interpolated || self.currentChar == "\"" || self.currentChar == "\'", "Invalid starting point for a string literal")
    assert(!interpolated || self.currentChar == ")", "Invalid starting point for an interpolated string literal")

    let start = self.index
    var wasErroneous: Bool = false
    var content = ""

    self.advance()
    let charactersStartIndex = self.index

    characterLoop: while true {
      guard self.currentChar != nil && self.currentChar != "\r" && self.currentChar != "\n"else {
        diagnose("unterminated string literal", type: .Error)
        return makeToken(type: .Unknown, range: start..<self.index)
      }

      if self.currentChar == "\\" && self.nextChar == "(" {
        self.advance()
        self.advance()

        let type: TokenType = wasErroneous ? .Unknown : .StringLiteral(interpolated ? .InterpolatedMiddle : .InterpolatedStart)
        let token = makeToken(type: type, range: start..<self.index)

        self.subLexer = Lexer(self.source, parenthesisDepth: 1, startIndex: self.index)
        self.interpolatedStringQuoteType = quoteType

        return token
      }

      do {
        content += String(try self.lexCharacter(quoteType: quoteType))
      }
      catch StringEnd.End {
        break characterLoop
      }
      catch let err  {
        if let diag = err as? Diagnose {
          self.diagnoses.append(diag)
        }

        wasErroneous = true
      }
    }

    self.advance()

    if quoteType == "'" {
      let charactersEndIndex = self.characters.index(before: self.index)
      let str = String(self.characters[charactersStartIndex..<charactersEndIndex])
      let replacement = "\"\(makeDoubleQuotedLiteral(singleQuoted: str))\""

      diagnose("single-quoted string literal found, use '\"'", type: .Error, start: start, end: self.index)
        .withReplaceFix(replacement)
    }

    let type: TokenType = wasErroneous ? .Unknown : .StringLiteral(interpolated ? .InterpolatedEnd : .Static)
    return makeToken(type: type, range: start..<self.index, value: content)
  }

  func findEndOfCurlyQuoteStringLiteral() -> Index? {
    let oldIndex = self.index
    while true {
      // Don"t bother with string interpolations.
      if self.currentChar == "\\" && self.nextChar  == "(" {
        return nil
      }

      // We didn"t find the end of the string literal if we ran to end of line.
      if self.currentChar == "\r" || self.currentChar == "\n" || self.currentChar == nil {
        return nil
      }

      do {
        let index = self.index
        let char = try lexCharacter(quoteType: "\"")

        // If we found an ending curly quote (common since this thing started with
        // an opening curly quote) diagnose it with a fixit and then return.
        if char == "\u{201D}" {
          diagnose("unicode curly quote found, replace with '\"'", type: .Error, start: oldIndex)
            .withReplaceFix("\"", range: oldIndex..<self.characters.index(after: oldIndex))
            .withReplaceFix("\"", range: index..<self.index)

          let endIndex = self.index
          self.index = oldIndex
          return endIndex
        }
      }
      catch StringEnd.End {
        let endIndex = self.index
        self.index = oldIndex
        return endIndex
      }
      catch {
        return nil
      }

      // Otherwise, keep scanning.
    }
  }

  func getIndex(after index: Index) -> Index {
    return self.characters.index(after: index)
  }

  func resetToBeginning(of token: Token) {
    resetIndex(to: token.range.range.lowerBound)
  }

  func resetIndex(to index: Index) {
    self.index = index
    self.nextToken = self.lex()
  }

}
